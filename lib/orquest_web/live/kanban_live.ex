defmodule OrquestWeb.KanbanLive do
  use OrquestWeb, :live_view

  alias Orquest.Kanban
  alias Orquest.Orchestrator

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Kanban.subscribe()

    {:ok, assign(socket, board: Kanban.get_board(), editing: nil, form: %{})}
  end

  @impl true
  def handle_info(:board_updated, socket) do
    {:noreply, assign(socket, board: Kanban.get_board())}
  end

  @impl true
  def handle_event("add_card", %{"column_id" => column_id, "title" => title}, socket) do
    if String.trim(title) != "" do
      Kanban.add_card(column_id, %{title: title, description: "New task", priority: 2})
    end
    {:noreply, assign(socket, form: %{})}
  end

  def handle_event("move_card", %{"card_id" => card_id, "to_column" => to_column}, socket) do
    Kanban.move_card(card_id, to_column)
    {:noreply, socket}
  end

  def handle_event("delete_card", %{"card_id" => card_id}, socket) do
    Kanban.remove_card(card_id)
    {:noreply, socket}
  end

  def handle_event("edit_card", %{"card_id" => card_id}, socket) do
    card = Kanban.get_card(card_id)
    {:noreply, assign(socket, editing: card_id, form: %{title: card.title, description: card.description})}
  end

  def handle_event("save_card", %{"card_id" => card_id, "title" => title, "description" => description}, socket) do
    Kanban.update_card(card_id, %{title: title, description: description})
    {:noreply, assign(socket, editing: nil, form: %{})}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing: nil, form: %{})}
  end

  def handle_event("trigger_orchestrator", _, socket) do
    send(Orchestrator, :tick)
    {:noreply, socket}
  end

  defp priority_dot(1), do: "bg-rose-500"
  defp priority_dot(2), do: "bg-amber-500"
  defp priority_dot(3), do: "bg-sky-500"
  defp priority_dot(_), do: "bg-slate-500"

  defp status_badge("running"), do: "bg-violet-500/15 text-violet-300 border-violet-500/30"
  defp status_badge("completed"), do: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30"
  defp status_badge("failed"), do: "bg-rose-500/15 text-rose-300 border-rose-500/30"
  defp status_badge(_), do: "bg-slate-700/50 text-slate-400 border-slate-600/40"

  defp column_header_bg("backlog"), do: "bg-slate-800/60 border-slate-600"
  defp column_header_bg("todo"), do: "bg-blue-500/10 border-blue-500/40"
  defp column_header_bg("borrowed"), do: "bg-amber-500/10 border-amber-500/40"
  defp column_header_bg("in_progress"), do: "bg-violet-500/10 border-violet-500/40"
  defp column_header_bg("review"), do: "bg-pink-500/10 border-pink-500/40"
  defp column_header_bg("done"), do: "bg-emerald-500/10 border-emerald-500/40"
  defp column_header_bg(_), do: "bg-slate-800/60 border-slate-600"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950">
      <!-- Header -->
      <header class="sticky top-0 z-50 backdrop-blur-xl bg-slate-950/70 border-b border-slate-800/60 px-6 py-4 flex items-center justify-between">
        <div class="flex items-center gap-4">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-600 to-indigo-600 flex items-center justify-center shadow-lg shadow-violet-500/20">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
            </svg>
          </div>
          <div>
            <h1 class="text-xl font-bold tracking-tight text-white">Orquest</h1>
            <p class="text-xs text-slate-400 font-medium">Multi-Agent Kanban Orchestrator</p>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <div class="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-800/60 border border-slate-700/50 text-xs text-slate-400">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            Orchestrator Active
          </div>
          <button
            phx-click="trigger_orchestrator"
            class="group relative px-4 py-2 bg-gradient-to-r from-violet-600 to-indigo-600 hover:from-violet-500 hover:to-indigo-500 rounded-lg text-sm font-semibold text-white shadow-lg shadow-violet-500/25 transition-all hover:shadow-violet-500/40 hover:-translate-y-0.5 active:translate-y-0"
          >
            <span class="flex items-center gap-2">
              <svg class="w-4 h-4 group-hover:animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              Trigger Orchestrator
            </span>
          </button>
        </div>
      </header>

      <!-- Board -->
      <main class="p-6 overflow-x-auto">
        <div class="flex gap-5 min-w-max">
          <%= for column <- @board.columns do %>
            <div class="w-80 shrink-0 flex flex-col">
              <!-- Column Header -->
              <div class={["rounded-t-xl px-4 py-3 border-t border-x flex items-center gap-2.5", column_header_bg(column.id)]}>
                <div class={["w-2.5 h-2.5 rounded-full ring-2 ring-white/10", priority_dot(column.id |> String.to_atom() |> then(fn _ -> 1 end))]} style={if column.id != "backlog", do: "background-color: #{column.color}", else: ""}></div>
                <span class="font-semibold text-sm text-slate-200"><%= column.name %></span>
                <span class="ml-auto text-[11px] font-bold bg-slate-950/40 text-slate-400 px-2 py-0.5 rounded-md min-w-[20px] text-center">
                  <%= length(column.cards) %>
                </span>
              </div>

              <!-- Column Body -->
              <div class="flex-1 bg-slate-900/40 backdrop-blur-sm rounded-b-xl border border-slate-800/60 border-t-0 p-3 space-y-3 min-h-[450px]">
                <%= if column.id == "backlog" do %>
                  <form phx-submit="add_card" class="mb-1">
                    <input type="hidden" name="column_id" value={column.id} />
                    <div class="flex gap-2">
                      <input
                        type="text"
                        name="title"
                        placeholder="Add a new task..."
                        class="flex-1 bg-slate-800/80 border border-slate-700/50 rounded-lg px-3.5 py-2.5 text-sm text-slate-200 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-violet-500/40 focus:border-violet-500/50 transition-all"
                        required
                      />
                      <button
                        type="submit"
                        class="bg-slate-800 hover:bg-slate-700 border border-slate-700/50 px-3.5 py-2.5 rounded-lg text-sm font-bold text-slate-300 transition-all hover:text-white hover:border-slate-600"
                      >
                        +
                      </button>
                    </div>
                  </form>
                <% end %>

                <%= for card <- column.cards do %>
                  <div class={[
                    "group relative bg-slate-800/80 hover:bg-slate-800 rounded-xl p-4 border transition-all duration-200 hover:shadow-xl hover:shadow-black/20",
                    if(card.borrowed_by, do: "border-amber-500/40 ring-1 ring-amber-500/20 shadow-lg shadow-amber-500/5", else: "border-slate-700/40 hover:border-slate-600/60")
                  ]}>
                    <%= if @editing == card.id do %>
                      <form phx-submit="save_card" class="space-y-3">
                        <input type="hidden" name="card_id" value={card.id} />
                        <input
                          type="text"
                          name="title"
                          value={@form[:title]}
                          class="w-full bg-slate-900/80 border border-slate-600/60 rounded-lg px-3 py-2 text-sm text-slate-200 focus:outline-none focus:ring-2 focus:ring-violet-500/40"
                        />
                        <textarea
                          name="description"
                          rows="2"
                          class="w-full bg-slate-900/80 border border-slate-600/60 rounded-lg px-3 py-2 text-sm text-slate-300 resize-none focus:outline-none focus:ring-2 focus:ring-violet-500/40"
                        ><%= @form[:description] %></textarea>
                        <div class="flex gap-2">
                          <button type="submit" class="bg-emerald-600/90 hover:bg-emerald-500 px-4 py-1.5 rounded-lg text-xs font-semibold text-white transition">Save</button>
                          <button type="button" phx-click="cancel_edit" class="bg-slate-700/60 hover:bg-slate-600/60 px-4 py-1.5 rounded-lg text-xs font-medium text-slate-300 transition">Cancel</button>
                        </div>
                      </form>
                    <% else %>
                      <!-- Card Header -->
                      <div class="flex items-start justify-between gap-3 mb-2.5">
                        <h3 class="font-semibold text-sm text-slate-200 leading-snug group-hover:text-white transition-colors"><%= card.title %></h3>
                        <div class="opacity-0 group-hover:opacity-100 transition-opacity flex gap-0.5 shrink-0">
                          <button phx-click="edit_card" phx-value-card_id={card.id} class="p-1.5 rounded-md hover:bg-slate-700/60 text-slate-500 hover:text-slate-200 transition">
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/></svg>
                          </button>
                          <button phx-click="delete_card" phx-value-card_id={card.id} data-confirm="Delete this card?" class="p-1.5 rounded-md hover:bg-rose-500/20 text-slate-500 hover:text-rose-400 transition">
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
                          </button>
                        </div>
                      </div>

                      <!-- Description -->
                      <p class="text-[13px] text-slate-400 mb-3 line-clamp-2 leading-relaxed"><%= card.description %></p>

                      <!-- Borrowed Info -->
                      <%= if card.borrowed_by do %>
                        <div class="flex items-center gap-2 mb-3 px-2.5 py-1.5 rounded-lg bg-amber-500/8 border border-amber-500/15">
                          <svg class="w-3.5 h-3.5 text-amber-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                          </svg>
                          <span class="text-[11px] font-semibold text-amber-300"><%= card.borrowed_by %></span>
                          <%= if card.workspace_path do %>
                            <span class="text-[10px] text-amber-500/60 truncate max-w-[100px] font-mono"><%= Path.basename(card.workspace_path) %></span>
                          <% end %>
                        </div>
                      <% end %>

                      <!-- Footer -->
                      <div class="flex items-center justify-between pt-2 border-t border-slate-700/30">
                        <div class="flex gap-1.5 flex-wrap">
                          <%= for tag <- card.tags do %>
                            <span class="text-[10px] font-semibold bg-slate-700/50 text-slate-400 px-2 py-0.5 rounded-md border border-slate-600/30"><%= tag %></span>
                          <% end %>
                        </div>
                        <span class={["text-[10px] font-bold px-2 py-0.5 rounded-md border", status_badge(card.agent_status)]}>
                          <%= card.agent_status %>
                        </span>
                      </div>

                      <!-- Move Actions -->
                      <div class="mt-3 pt-2 border-t border-slate-700/20 flex flex-wrap gap-1">
                        <%= for target_col <- @board.columns do %>
                          <%= if target_col.id != column.id do %>
                            <button
                              phx-click="move_card"
                              phx-value-card_id={card.id}
                              phx-value-to_column={target_col.id}
                              class="text-[10px] font-medium px-2.5 py-1 rounded-md bg-slate-900/40 hover:bg-slate-700/50 text-slate-400 hover:text-slate-200 transition border border-transparent hover:border-slate-600/30"
                            >
                              <%= target_col.name %>
                            </button>
                          <% end %>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
