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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <header class="bg-gray-800 border-b border-gray-700 px-6 py-4 flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold tracking-tight">Orquest</h1>
          <p class="text-sm text-gray-400">Multi-Agent Kanban Orchestrator</p>
        </div>
        <div class="flex gap-3">
          <button phx-click="trigger_orchestrator" class="px-4 py-2 bg-purple-600 hover:bg-purple-500 rounded-lg text-sm font-medium transition">
            Trigger Orchestrator
          </button>
        </div>
      </header>

      <main class="p-6 overflow-x-auto">
        <div class="flex gap-4 min-w-max">
          <%= for column <- @board.columns do %>
            <div class="w-80 shrink-0">
              <div class="rounded-t-lg px-4 py-3 font-semibold text-sm flex items-center gap-2" style={"background-color: #{column.color}20; border-top: 3px solid #{column.color}"}>
                <div class="w-3 h-3 rounded-full" style={"background-color: #{column.color}"}></div>
                <%= column.name %>
                <span class="ml-auto text-xs bg-gray-800 px-2 py-0.5 rounded-full"><%= length(column.cards) %></span>
              </div>

              <div class="bg-gray-800/50 rounded-b-lg p-3 min-h-[400px] space-y-3 border border-gray-700/50">
                <%= if column.id == "backlog" do %>
                  <form phx-submit="add_card" class="mb-2">
                    <input type="hidden" name="column_id" value={column.id} />
                    <div class="flex gap-2">
                      <input type="text" name="title" placeholder="New task..." class="flex-1 bg-gray-700 border border-gray-600 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500" required />
                      <button type="submit" class="bg-blue-600 hover:bg-blue-500 px-3 py-2 rounded text-sm font-medium">+</button>
                    </div>
                  </form>
                <% end %>

                <%= for card <- column.cards do %>
                  <div class={[
                    "bg-gray-800 rounded-lg p-4 border transition-all hover:border-gray-500 group relative",
                    if(card.borrowed_by, do: "border-yellow-500/50 shadow-lg shadow-yellow-500/10", else: "border-gray-700")
                  ]}>
                    <%= if @editing == card.id do %>
                      <form phx-submit="save_card" class="space-y-2">
                        <input type="hidden" name="card_id" value={card.id} />
                        <input type="text" name="title" value={@form[:title]} class="w-full bg-gray-700 border border-gray-600 rounded px-2 py-1 text-sm" />
                        <textarea name="description" rows="2" class="w-full bg-gray-700 border border-gray-600 rounded px-2 py-1 text-sm"><%= @form[:description] %></textarea>
                        <div class="flex gap-2">
                          <button type="submit" class="bg-green-600 hover:bg-green-500 px-3 py-1 rounded text-xs">Save</button>
                          <button type="button" phx-click="cancel_edit" class="bg-gray-600 hover:bg-gray-500 px-3 py-1 rounded text-xs">Cancel</button>
                        </div>
                      </form>
                    <% else %>
                      <div class="flex items-start justify-between mb-2">
                        <h3 class="font-medium text-sm leading-tight"><%= card.title %></h3>
                        <div class="opacity-0 group-hover:opacity-100 transition flex gap-1">
                          <button phx-click="edit_card" phx-value-card_id={card.id} class="text-gray-400 hover:text-white p-1">
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/></svg>
                          </button>
                          <button phx-click="delete_card" phx-value-card_id={card.id} data-confirm="Delete this card?" class="text-gray-400 hover:text-red-400 p-1">
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
                          </button>
                        </div>
                      </div>

                      <p class="text-xs text-gray-400 mb-3 line-clamp-2"><%= card.description %></p>

                      <%= if card.borrowed_by do %>
                        <div class="flex items-center gap-2 text-xs text-yellow-400 mb-2">
                          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
                          <span class="font-medium"><%= card.borrowed_by %></span>
                          <%= if card.workspace_path do %>
                            <span class="text-gray-500 truncate max-w-[120px]"><%= card.workspace_path %></span>
                          <% end %>
                        </div>
                      <% end %>

                      <div class="flex items-center justify-between">
                        <div class="flex gap-1">
                          <%= for tag <- card.tags do %>
                            <span class="text-[10px] bg-gray-700 px-1.5 py-0.5 rounded"><%= tag %></span>
                          <% end %>
                        </div>
                        <span class={[
                          "text-[10px] px-1.5 py-0.5 rounded font-medium",
                          card.agent_status == "running" && "bg-purple-500/20 text-purple-400",
                          card.agent_status == "completed" && "bg-green-500/20 text-green-400",
                          card.agent_status == "idle" && "bg-gray-700 text-gray-400"
                        ]}>
                          <%= card.agent_status %>
                        </span>
                      </div>

                      <div class="mt-3 pt-2 border-t border-gray-700/50 flex flex-wrap gap-1">
                        <%= for target_col <- @board.columns do %>
                          <%= if target_col.id != column.id do %>
                            <button
                              phx-click="move_card"
                              phx-value-card_id={card.id}
                              phx-value-to_column={target_col.id}
                              class="text-[10px] px-2 py-1 rounded bg-gray-700/50 hover:bg-gray-600 transition text-gray-300"
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
