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
    crm_sources = resolve_crm_sources(owner.id)

    {:ok,
     socket
     |> assign(page_title: "CRM Copilot")
     |> assign(crm_sources: crm_sources)
     |> assign(sessions: CrmCopilot.sessions_for_user(owner.id))
     |> assign(active_session: nil, turns: [])
     |> assign(pinned_contact: nil, mention_hits: [], mention_q: nil, mention_searching: false)
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

  def handle_event("mention_lookup", %{"q" => q}, socket) when byte_size(q) < 2 do
    # Show the popup immediately but don't search yet (need 2+ chars)
    {:noreply, assign(socket, mention_q: q, mention_hits: [], mention_searching: false)}
  end

  def handle_event("mention_lookup", %{"q" => q}, socket) do
    send(self(), {:run_mention_search, q})
    {:noreply, assign(socket, mention_q: q, mention_searching: true)}
  end

  def handle_event("dismiss_mentions", _p, socket) do
    {:noreply, assign(socket, mention_hits: [], mention_q: nil, mention_searching: false)}
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
    hits = do_mention_search_all(q, socket.assigns.crm_sources)
    {:noreply, assign(socket, mention_hits: hits, mention_searching: false)}
  end

  def handle_info({:copilot_thinking, sess, human_turn, contact_snapshot}, socket) do
    ctx = %{
      tagged_record: maybe_fetch_record(contact_snapshot, socket.assigns.crm_sources),
      crm_type: primary_provider(socket.assigns.crm_sources),
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
     |> assign(
       thinking: true,
       pinned_contact: nil,
       mention_hits: [],
       mention_q: nil,
       mention_searching: false
     )
     |> maybe_push_new_session_url(sess)}
  end

  # Build a list of %{provider: atom, credential: struct} for every connected CRM.
  defp resolve_crm_sources(uid) do
    sources = []

    sources =
      case Accounts.get_user_hubspot_credential(uid) do
        nil -> sources
        c -> sources ++ [%{provider: :hubspot, credential: c}]
      end

    case Accounts.get_user_salesforce_credential(uid) do
      nil -> sources
      c -> sources ++ [%{provider: :salesforce, credential: c}]
    end
  end

  defp primary_provider([]), do: nil
  defp primary_provider([%{provider: p} | _]), do: p

  # Search ALL connected CRMs and merge results.
  defp do_mention_search_all(_q, []), do: []

  defp do_mention_search_all(q, sources) do
    sources
    |> Enum.flat_map(fn %{provider: prov, credential: cred} ->
      search_single_crm(q, prov, cred)
    end)
  end

  defp search_single_crm(q, :hubspot, cred) do
    case HubspotApiBehaviour.search_contacts(cred, q) do
      {:ok, list} -> normalize_contacts(list, "hubspot")
      _ -> []
    end
  end

  defp search_single_crm(q, :salesforce, cred) do
    case SalesforceClientSpec.search_contacts(cred, q) do
      {:ok, list} -> normalize_contacts(list, "salesforce")
      _ -> []
    end
  end

  defp search_single_crm(_q, _prov, _cred), do: []

  defp normalize_contacts(records, src) do
    records
    |> Enum.reject(&is_nil/1)
    |> Enum.map(
      &%{id: to_string(&1[:id] || ""), label: &1[:display_name] || "Unknown", source: src}
    )
  end

  # Fetch the full record for a pinned contact, picking the right credential.
  defp maybe_fetch_record(nil, _sources), do: nil

  defp maybe_fetch_record(%{source: src, id: id}, sources) do
    provider = String.to_existing_atom(src)

    case Enum.find(sources, fn s -> s.provider == provider end) do
      nil ->
        nil

      %{credential: cred} ->
        fetch_from_crm(provider, cred, id)
    end
  end

  defp fetch_from_crm(:hubspot, cred, id) do
    case HubspotApiBehaviour.get_contact(cred, id) do
      {:ok, rec} -> rec
      _ -> nil
    end
  end

  defp fetch_from_crm(:salesforce, cred, id) do
    case SalesforceClientSpec.get_contact(cred, id) do
      {:ok, rec} -> rec
      _ -> nil
    end
  end

  defp fetch_from_crm(_prov, _cred, _id), do: nil

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

  @doc false
  attr :provider, :atom, required: true
  attr :size, :atom, default: :sm

  def crm_icon(%{provider: :hubspot} = assigns) do
    size_class =
      case assigns.size do
        :xs -> "w-4 h-4 text-[8px]"
        _ -> "w-5 h-5 text-[9px]"
      end

    assigns = assign(assigns, :size_class, size_class)

    ~H"""
    <span
      class={"#{@size_class} rounded-full bg-[#FF7A59] flex items-center justify-center flex-shrink-0"}
      title="HubSpot"
    >
      <span class="text-white font-bold leading-none">H</span>
    </span>
    """
  end

  def crm_icon(%{provider: :salesforce} = assigns) do
    size_class =
      case assigns.size do
        :xs -> "w-4 h-4 text-[8px]"
        _ -> "w-5 h-5 text-[9px]"
      end

    assigns = assign(assigns, :size_class, size_class)

    ~H"""
    <span
      class={"#{@size_class} rounded-full bg-[#0176D3] flex items-center justify-center flex-shrink-0"}
      title="Salesforce"
    >
      <svg class="w-3 h-3" viewBox="0 0 24 24" fill="white">
        <path d="M10 3.2c1-.8 2.2-1.2 3.5-1.2 1.8 0 3.4.9 4.4 2.2.8-.4 1.7-.6 2.6-.6C23 3.6 25 5.7 25 8.2c0 .3 0 .5-.1.8 1.3.8 2.1 2.2 2.1 3.8 0 2.5-2 4.5-4.5 4.5-.4 0-.8-.1-1.2-.2-.8 1.3-2.2 2.1-3.8 2.1-1 0-1.9-.3-2.7-.8-.7 1.5-2.3 2.6-4.1 2.6-1.8 0-3.4-1.1-4.1-2.6-.3.1-.7.1-1 .1-2.8 0-5-2.2-5-5 0-1.7.8-3.2 2.1-4.1 0-.3-.1-.6-.1-.9 0-2.5 2-4.5 4.5-4.5 1 0 1.9.3 2.4.9z" />
      </svg>
    </span>
    """
  end

  def crm_icon(assigns) do
    ~H"""
    <span
      class="w-5 h-5 rounded-full bg-gray-300 flex items-center justify-center flex-shrink-0"
      title="Unknown"
    >
      <span class="text-white text-[9px] font-bold leading-none">?</span>
    </span>
    """
  end
end
