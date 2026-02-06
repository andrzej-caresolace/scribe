defmodule SocialScribeWeb.MeetingLive.SalesforceModalComponent do
  use SocialScribeWeb, :live_component

  import SocialScribeWeb.ModalComponents

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :patch, ~p"/dashboard/meetings/#{assigns.meeting}")
    assigns = assign_new(assigns, :modal_id, fn -> "salesforce-modal-wrapper" end)

    ~H"""
    <div class="space-y-6">
      <div>
        <h2 id={"#{@modal_id}-title"} class="text-xl font-medium tracking-tight text-slate-900">Update in Salesforce</h2>
        <p id={"#{@modal_id}-description"} class="mt-2 text-base font-light leading-7 text-slate-500">
          Here are suggested updates to sync with your integrations based on this
          <span class="block">meeting</span>
        </p>
      </div>

      <.salesforce_contact_select
          selected_contact={@selected_contact}
          contacts={@contacts}
          loading={@searching}
          open={@dropdown_open}
          query={@query}
          target={@myself}
          error={@error}
        />

      <%= if @selected_contact do %>
        <.suggestions_section
          suggestions={@suggestions}
          loading={@loading}
          myself={@myself}
          patch={@patch}
        />
      <% end %>
    </div>
    """
  end

  attr :selected_contact, :map, default: nil
  attr :contacts, :list, default: []
  attr :loading, :boolean, default: false
  attr :open, :boolean, default: false
  attr :query, :string, default: ""
  attr :target, :any, default: nil
  attr :error, :string, default: nil
  attr :id, :string, default: "salesforce-contact-select"

  defp salesforce_contact_select(assigns) do
    ~H"""
    <div class="space-y-1">
      <label for={"#{@id}-input"} class="block text-sm font-medium text-slate-700">Select Contact</label>
      <div class="relative">
        <%= if @selected_contact do %>
          <button
            type="button"
            phx-click="toggle_contact_dropdown"
            phx-target={@target}
            role="combobox"
            aria-haspopup="listbox"
            aria-expanded={to_string(@open)}
            aria-controls={"#{@id}-listbox"}
            class="relative w-full bg-white border border-slate-300 rounded-lg pl-1.5 pr-10 py-[5px] text-left cursor-pointer focus:outline-none focus:ring-2 focus:ring-[#00A1E0] focus:border-[#00A1E0] text-sm"
          >
            <span class="flex items-center">
              <.salesforce_avatar firstname={@selected_contact.firstname} lastname={@selected_contact.lastname} size={:sm} />
              <span class="ml-1.5 block truncate text-slate-900">
                {@selected_contact.firstname} {@selected_contact.lastname}
              </span>
            </span>
            <span class="absolute inset-y-0 right-0 flex items-center pr-2 pointer-events-none">
              <.icon name="hero-chevron-up-down" class="h-5 w-5 text-slate-400" />
            </span>
          </button>
        <% else %>
          <div class="relative">
            <input
              id={"#{@id}-input"}
              type="text"
              name="contact_query"
              value={@query}
              placeholder="Search contacts..."
              phx-keyup="contact_search"
              phx-target={@target}
              phx-focus="open_contact_dropdown"
              phx-debounce="150"
              autocomplete="off"
              role="combobox"
              aria-autocomplete="list"
              aria-expanded={to_string(@open)}
              aria-controls={"#{@id}-listbox"}
              class="w-full bg-white border border-slate-300 rounded-lg pl-2 pr-10 py-[5px] text-left focus:outline-none focus:ring-2 focus:ring-[#00A1E0] focus:border-[#00A1E0] text-sm"
            />
            <span class="absolute inset-y-0 right-0 flex items-center pr-2 pointer-events-none">
              <%= if @loading do %>
                <.icon name="hero-arrow-path" class="h-5 w-5 text-slate-400 animate-spin" />
              <% else %>
                <.icon name="hero-chevron-up-down" class="h-5 w-5 text-slate-400" />
              <% end %>
            </span>
          </div>
        <% end %>

        <div
          :if={@open && (@selected_contact || Enum.any?(@contacts) || @loading || @query != "")}
          id={"#{@id}-listbox"}
          role="listbox"
          phx-click-away="close_contact_dropdown"
          phx-target={@target}
          class="absolute z-10 mt-1 w-full bg-white shadow-lg max-h-60 rounded-md py-1 text-base ring-1 ring-black ring-opacity-5 overflow-auto focus:outline-none sm:text-sm"
        >
          <button
            :if={@selected_contact}
            type="button"
            phx-click="clear_contact"
            phx-target={@target}
            role="option"
            aria-selected={"false"}
            class="w-full text-left px-4 py-2 hover:bg-slate-50 text-sm text-slate-700 cursor-pointer"
          >
            Clear selection
          </button>
          <div :if={@loading} class="px-4 py-2 text-sm text-gray-500">
            Searching...
          </div>
          <div :if={!@loading && Enum.empty?(@contacts) && @query != ""} class="px-4 py-2 text-sm text-gray-500">
            No contacts found
          </div>
          <button
            :for={contact <- @contacts}
            type="button"
            phx-click="select_contact"
            phx-value-id={contact.id}
            phx-target={@target}
            role="option"
            aria-selected={"false"}
            class="w-full text-left px-4 py-2 hover:bg-slate-50 flex items-center space-x-3 cursor-pointer"
          >
            <.salesforce_avatar firstname={contact.firstname} lastname={contact.lastname} size={:sm} />
            <div>
              <div class="text-sm font-medium text-slate-900">
                {contact.firstname} {contact.lastname}
              </div>
              <div class="text-xs text-slate-500">
                {contact.email}
              </div>
            </div>
          </button>
        </div>
      </div>
      <.inline_error :if={@error} message={@error} />
    </div>
    """
  end

  attr :firstname, :string, default: ""
  attr :lastname, :string, default: ""
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :class, :string, default: nil

  defp salesforce_avatar(assigns) do
    size_classes = %{
      sm: "h-6 w-6 text-[10px]",
      md: "h-8 w-8 text-[10px]",
      lg: "h-10 w-10 text-sm"
    }

    assigns = assign(assigns, :size_class, size_classes[assigns.size])

    ~H"""
    <div class={[
      "rounded-full bg-[#00A1E0] flex items-center justify-center font-semibold text-white flex-shrink-0",
      @size_class,
      @class
    ]}>
      {String.at(@firstname || "", 0)}{String.at(@lastname || "", 0)}
    </div>
    """
  end

  attr :suggestions, :list, required: true
  attr :loading, :boolean, required: true
  attr :myself, :any, required: true
  attr :patch, :string, required: true

  defp suggestions_section(assigns) do
    assigns = assign(assigns, :selected_count, Enum.count(assigns.suggestions, & &1.apply))

    ~H"""
    <div class="space-y-4">
      <%= if @loading do %>
        <div class="text-center py-8 text-slate-500">
          <.icon name="hero-arrow-path" class="h-6 w-6 animate-spin mx-auto mb-2" />
          <p>Generating suggestions...</p>
        </div>
      <% else %>
        <%= if Enum.empty?(@suggestions) do %>
          <.empty_state
            message="No update suggestions found from this meeting."
            submessage="The AI didn't detect any new contact information in the transcript."
          />
        <% else %>
          <form phx-submit="apply_updates" phx-change="toggle_suggestion" phx-target={@myself}>
            <div class="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
              <.salesforce_suggestion_card :for={suggestion <- @suggestions} suggestion={suggestion} />
            </div>

            <.modal_footer
              cancel_patch={@patch}
              submit_text="Update Salesforce"
              submit_class="bg-[#00A1E0] hover:bg-[#008CBE]"
              disabled={@selected_count == 0}
              loading={@loading}
              loading_text="Updating..."
              info_text={"1 object, #{@selected_count} fields in 1 integration selected to update"}
            />
          </form>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :suggestion, :map, required: true
  attr :class, :string, default: nil

  defp salesforce_suggestion_card(assigns) do
    ~H"""
    <div class={["bg-slate-50 rounded-2xl p-6 mb-4", @class]}>
      <div class="flex items-start justify-between">
        <div class="flex items-start gap-3">
          <div class="flex items-center h-5 pt-0.5">
            <input
              type="checkbox"
              checked={@suggestion.apply}
              phx-click={Phoenix.LiveView.JS.dispatch("click", to: "#sf-suggestion-apply-#{@suggestion.field}")}
              class="h-4 w-4 rounded-[3px] border-slate-300 text-[#00A1E0] accent-[#00A1E0] focus:ring-0 focus:ring-offset-0 cursor-pointer"
            />
          </div>
          <div class="text-sm font-semibold text-slate-900 leading-5">{@suggestion.label}</div>
        </div>

        <div class="flex items-center gap-3 pt-0.5">
          <span
            class={[
              "inline-flex items-center rounded-full bg-[#00A1E0]/10 px-2 py-1 text-xs font-medium text-[#00A1E0]",
              if(@suggestion.apply, do: "opacity-100", else: "opacity-0 pointer-events-none")
            ]}
            aria-hidden={to_string(!@suggestion.apply)}
          >
            1 update selected
          </span>
          <button type="button" class="text-xs text-slate-500 hover:text-slate-700 font-medium">
            Hide details
          </button>
        </div>
      </div>

      <div class="mt-2 pl-8">
        <div class="text-sm font-medium text-slate-700 leading-5 ml-1">{@suggestion.label}</div>

        <div class="relative mt-2">
          <input
            id={"sf-suggestion-apply-#{@suggestion.field}"}
            type="checkbox"
            name={"apply[#{@suggestion.field}]"}
            value="1"
            checked={@suggestion.apply}
            class="absolute -left-8 top-1/2 -translate-y-1/2 h-4 w-4 rounded-[3px] border-slate-300 text-[#00A1E0] accent-[#00A1E0] focus:ring-0 focus:ring-offset-0 cursor-pointer"
          />

          <div class="grid grid-cols-[1fr_32px_1fr] items-center gap-6">
            <input
              type="text"
              readonly
              value={@suggestion.current_value || ""}
              placeholder="No existing value"
              class={[
                "block w-full shadow-sm text-sm bg-white border border-gray-300 rounded-[7px] py-1.5 px-2",
                if(@suggestion.current_value && @suggestion.current_value != "", do: "line-through text-gray-500", else: "text-gray-400")
              ]}
            />

            <div class="w-8 flex justify-center text-slate-300">
              <.icon name="hero-arrow-long-right" class="h-7 w-7" />
            </div>

            <input
              type="text"
              name={"values[#{@suggestion.field}]"}
              value={@suggestion.new_value}
              class="block w-full shadow-sm text-sm text-slate-900 bg-white border border-slate-300 rounded-[7px] py-1.5 px-2 focus:ring-[#00A1E0] focus:border-[#00A1E0]"
            />
          </div>
        </div>

        <div class="mt-3 grid grid-cols-[1fr_32px_1fr] items-start gap-6">
          <button type="button" class="text-xs text-[#00A1E0] hover:text-[#008CBE] font-medium justify-self-start">
            Update mapping
          </button>
          <span></span>
          <span :if={@suggestion[:timestamp]} class="text-xs text-slate-500 justify-self-start">Found in transcript<span
              class="text-[#00A1E0] hover:underline cursor-help"
              title={@suggestion[:context]}
            >
              ({@suggestion[:timestamp]})
            </span></span>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_select_all_suggestions(assigns)
      |> assign_new(:step, fn -> :search end)
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:contacts, fn -> [] end)
      |> assign_new(:selected_contact, fn -> nil end)
      |> assign_new(:suggestions, fn -> [] end)
      |> assign_new(:loading, fn -> false end)
      |> assign_new(:searching, fn -> false end)
      |> assign_new(:dropdown_open, fn -> false end)
      |> assign_new(:error, fn -> nil end)

    {:ok, socket}
  end

  defp maybe_select_all_suggestions(socket, %{suggestions: suggestions}) when is_list(suggestions) do
    assign(socket, suggestions: Enum.map(suggestions, &Map.put(&1, :apply, true)))
  end

  defp maybe_select_all_suggestions(socket, _assigns), do: socket

  @impl true
  def handle_event("contact_search", %{"value" => query}, socket) do
    query = String.trim(query)

    if String.length(query) >= 2 do
      socket = assign(socket, searching: true, error: nil, query: query, dropdown_open: true)
      send(self(), {:salesforce_search, query, socket.assigns.credential})
      {:noreply, socket}
    else
      {:noreply, assign(socket, query: query, contacts: [], dropdown_open: query != "")}
    end
  end

  @impl true
  def handle_event("open_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: true)}
  end

  @impl true
  def handle_event("close_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: false)}
  end

  @impl true
  def handle_event("toggle_contact_dropdown", _params, socket) do
    if socket.assigns.dropdown_open do
      {:noreply, assign(socket, dropdown_open: false)}
    else
      # When opening dropdown with selected contact, search for similar contacts
      socket = assign(socket, dropdown_open: true, searching: true)
      query = "#{socket.assigns.selected_contact.firstname} #{socket.assigns.selected_contact.lastname}"
      send(self(), {:salesforce_search, query, socket.assigns.credential})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_contact", %{"id" => contact_id}, socket) do
    contact = Enum.find(socket.assigns.contacts, &(&1.id == contact_id))

    if contact do
      socket = assign(socket,
        loading: true,
        selected_contact: contact,
        error: nil,
        dropdown_open: false,
        query: "",
        suggestions: []
      )
      send(self(), {:generate_salesforce_suggestions, contact, socket.assigns.meeting, socket.assigns.credential})
      {:noreply, socket}
    else
      {:noreply, assign(socket, error: "Contact not found")}
    end
  end

  @impl true
  def handle_event("clear_contact", _params, socket) do
    {:noreply,
     assign(socket,
       step: :search,
       selected_contact: nil,
       suggestions: [],
       loading: false,
       searching: false,
       dropdown_open: false,
       contacts: [],
       query: "",
       error: nil
     )}
  end

  @impl true
  def handle_event("toggle_suggestion", params, socket) do
    applied_fields = Map.get(params, "apply", %{})
    values = Map.get(params, "values", %{})
    checked_fields = Map.keys(applied_fields)

    updated_suggestions =
      Enum.map(socket.assigns.suggestions, fn suggestion ->
        apply? = suggestion.field in checked_fields

        suggestion =
          case Map.get(values, suggestion.field) do
            nil -> suggestion
            new_value -> %{suggestion | new_value: new_value}
          end

        %{suggestion | apply: apply?}
      end)

    {:noreply, assign(socket, suggestions: updated_suggestions)}
  end

  @impl true
  def handle_event("apply_updates", %{"apply" => selected, "values" => values}, socket) do
    socket = assign(socket, loading: true, error: nil)

    updates =
      selected
      |> Map.keys()
      |> Enum.reduce(%{}, fn field, acc ->
        Map.put(acc, field, Map.get(values, field, ""))
      end)

    send(self(), {:apply_salesforce_updates, updates, socket.assigns.selected_contact, socket.assigns.credential})
    {:noreply, socket}
  end

  @impl true
  def handle_event("apply_updates", _params, socket) do
    {:noreply, assign(socket, error: "Please select at least one field to update")}
  end
end

