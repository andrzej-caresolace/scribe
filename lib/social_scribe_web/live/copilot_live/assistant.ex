defmodule SocialScribeWeb.CopilotLive.Assistant do
  @moduledoc """
  LiveView powering the CRM Copilot — an AI assistant that can query
  HubSpot / Salesforce contacts via @-mentions and answer questions
  about them. Uses a split-pane layout: session list + active dialogue.
  """

  use SocialScribeWeb, :live_view
  require Logger

  alias SocialScribe.{Accounts, CrmCopilot, AIContentGeneratorApi}
  alias SocialScribe.{HubspotApiBehaviour, SalesforceClientSpec}

  # ── Lifecycle ──────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    owner = socket.assigns.current_user
    {provider, cred} = resolve_crm(owner.id)

    {:ok,
     socket
     |> assign(page_title: "CRM Copilot")
     |> assign(crm_provider: provider, crm_cred: cred)
     |> assign(sessions: CrmCopilot.sessions_for_user(owner.id))
     |> assign(active_session: nil, turns: [])
     |> assign(pinned_contact: nil, mention_hits: [], mention_q: nil)
     |> assign(thinking: false, panel: :dialogue)}
  end

  @impl true
  def handle_params(%{"session_id" => sid}, _uri, socket) do
    sess = CrmCopilot.load_session!(sid)

    if sess.user_id == socket.assigns.current_user.id do
      {:noreply, assign(socket, active_session: sess, turns: sess.turns, panel: :dialogue)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Session not found")
       |> push_navigate(to: ~p"/dashboard/copilot")}
    end
  end

  def handle_params(_rest, _uri, socket) do
    {:noreply, assign(socket, active_session: nil, turns: [], pinned_contact: nil)}
  end

  # ── Events ─────────────────────────────────────────────────

  @impl true
  def handle_event("submit_question", %{"question" => raw}, socket) do
    question = String.trim(raw)
    if question == "", do: {:noreply, socket}, else: process_question(question, socket)
  end

  def handle_event("begin_session", _p, socket) do
    {:noreply,
     socket
     |> assign(
       active_session: nil,
       turns: [],
       pinned_contact: nil,
       mention_hits: [],
       mention_q: nil,
       thinking: false
     )
     |> push_patch(to: ~p"/dashboard/copilot")}
  end

  def handle_event("open_session", %{"sid" => sid}, socket) do
    {:noreply, push_patch(socket, to: ~p"/dashboard/copilot/#{sid}")}
  end

  def handle_event("show_panel", %{"which" => which}, socket) do
    panel = if which == "sessions", do: :sessions, else: :dialogue

    {:noreply,
     socket
     |> assign(panel: panel)
     |> then(fn s ->
       if panel == :sessions,
         do: assign(s, sessions: CrmCopilot.sessions_for_user(s.assigns.current_user.id)),
         else: s
     end)}
  end

  def handle_event("mention_lookup", %{"q" => q}, socket) do
    send(self(), {:run_mention_search, q})
    {:noreply, assign(socket, mention_q: q)}
  end

  def handle_event("dismiss_mentions", _p, socket) do
    {:noreply, assign(socket, mention_hits: [], mention_q: nil)}
  end

  def handle_event("pin_contact", %{"cid" => cid, "label" => label, "src" => src}, socket) do
    {:noreply,
     socket
     |> assign(
       pinned_contact: %{id: cid, label: label, source: src},
       mention_hits: [],
       mention_q: nil
     )
     |> push_event("contact_pinned", %{label: label})}
  end

  def handle_event("remove_session", %{"sid" => sid}, socket) do
    sess = CrmCopilot.fetch_session!(sid)
    if sess.user_id == socket.assigns.current_user.id, do: CrmCopilot.destroy_session(sess)

    refreshed = CrmCopilot.sessions_for_user(socket.assigns.current_user.id)

    cleared =
      if socket.assigns.active_session && socket.assigns.active_session.id == sess.id,
        do: assign(socket, active_session: nil, turns: []),
        else: socket

    {:noreply, assign(cleared, sessions: refreshed)}
  end

  # ── Info handlers ──────────────────────────────────────────

  @impl true
  def handle_info({:run_mention_search, q}, socket) do
    hits = do_mention_search(q, socket.assigns.crm_provider, socket.assigns.crm_cred)
    {:noreply, assign(socket, mention_hits: hits)}
  end

  def handle_info({:copilot_thinking, sess, human_turn, contact_snapshot}, socket) do
    ctx = %{
      tagged_record: maybe_fetch_record(contact_snapshot, socket.assigns.crm_cred),
      crm_type: socket.assigns.crm_provider,
      prior_turns: socket.assigns.turns
    }

    reply_text =
      case AIContentGeneratorApi.compose_copilot_reply(human_turn.body, ctx) do
        {:ok, text} ->
          text

        {:error, err} ->
          Logger.error("Copilot reply failed: #{inspect(err)}")
          "Sorry, I couldn't produce a reply right now. Please try again."
      end

    extras =
      if contact_snapshot,
        do: %{
          "sources" => [%{"crm" => contact_snapshot.source, "name" => contact_snapshot.label}]
        },
        else: %{}

    {:ok, copilot_turn} =
      CrmCopilot.add_turn(%{
        session_id: sess.id,
        sender: "copilot",
        body: reply_text,
        extras: extras
      })

    # Auto-label session from first question
    sess = maybe_label_session(sess, human_turn.body)
    refreshed = CrmCopilot.sessions_for_user(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(turns: socket.assigns.turns ++ [copilot_turn], thinking: false)
     |> assign(active_session: sess, sessions: refreshed)}
  end

  # ── Private ────────────────────────────────────────────────

  defp process_question(question, socket) do
    owner = socket.assigns.current_user

    sess =
      case socket.assigns.active_session do
        nil ->
          {:ok, s} = CrmCopilot.start_session(%{user_id: owner.id})
          s

        existing ->
          existing
      end

    contact_snapshot = socket.assigns.pinned_contact
    human_extras = if contact_snapshot, do: %{"tagged" => [contact_snapshot]}, else: %{}

    {:ok, human_turn} =
      CrmCopilot.add_turn(%{
        session_id: sess.id,
        sender: "human",
        body: question,
        extras: human_extras
      })

    send(self(), {:copilot_thinking, sess, human_turn, contact_snapshot})

    {:noreply,
     socket
     |> assign(active_session: sess, turns: socket.assigns.turns ++ [human_turn])
     |> assign(thinking: true, pinned_contact: nil, mention_hits: [], mention_q: nil)
     |> maybe_push_new_session_url(sess)}
  end

  defp resolve_crm(uid) do
    case Accounts.get_user_hubspot_credential(uid) do
      nil ->
        case Accounts.get_user_salesforce_credential(uid) do
          nil -> {nil, nil}
          c -> {:salesforce, c}
        end

      c ->
        {:hubspot, c}
    end
  end

  defp do_mention_search(_q, nil, _cred), do: []

  defp do_mention_search(q, :hubspot, cred) when not is_nil(cred) do
    case HubspotApiBehaviour.search_contacts(cred, q) do
      {:ok, list} -> normalize_contacts(list, "hubspot")
      _ -> []
    end
  end

  defp do_mention_search(q, :salesforce, cred) when not is_nil(cred) do
    case SalesforceClientSpec.search_contacts(cred, q) do
      {:ok, list} -> normalize_contacts(list, "salesforce")
      _ -> []
    end
  end

  defp do_mention_search(_q, _p, _c), do: []

  defp normalize_contacts(records, src) do
    records
    |> Enum.reject(&is_nil/1)
    |> Enum.map(
      &%{id: to_string(&1[:id] || ""), label: &1[:display_name] || "Unknown", source: src}
    )
  end

  defp maybe_fetch_record(nil, _cred), do: nil

  defp maybe_fetch_record(%{source: "hubspot", id: id}, cred) when not is_nil(cred) do
    case HubspotApiBehaviour.get_contact(cred, id) do
      {:ok, rec} -> rec
      _ -> nil
    end
  end

  defp maybe_fetch_record(%{source: "salesforce", id: id}, cred) when not is_nil(cred) do
    case SalesforceClientSpec.get_contact(cred, id) do
      {:ok, rec} -> rec
      _ -> nil
    end
  end

  defp maybe_fetch_record(_c, _cred), do: nil

  defp maybe_label_session(%{label: nil} = sess, first_question) do
    short = first_question |> String.slice(0..44)
    label = if String.length(first_question) > 45, do: short <> "…", else: short

    {:ok, updated} =
      sess
      |> SocialScribe.CrmCopilot.Session.changeset(%{label: label})
      |> SocialScribe.Repo.update()

    updated
  end

  defp maybe_label_session(sess, _q), do: sess

  defp maybe_push_new_session_url(socket, sess) do
    if socket.assigns.active_session && socket.assigns.active_session.id == sess.id do
      socket
    else
      push_patch(socket, to: ~p"/dashboard/copilot/#{sess.id}", replace: true)
    end
  end

  # ── Helpers used by template ───────────────────────────────

  def ts_label(nil), do: ""
  def ts_label(%{inserted_at: dt}), do: Calendar.strftime(dt, "%I:%M%P · %b %d, %Y")

  def short_date(nil), do: ""
  def short_date(dt), do: Calendar.strftime(dt, "%b %d, %Y")
end
