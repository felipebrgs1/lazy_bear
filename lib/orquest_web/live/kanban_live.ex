defmodule OrquestWeb.KanbanLive do
  use OrquestWeb, :live_view

  alias Orquest.Kanban
  alias Orquest.Orchestrator
  alias Orquest.Projects

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Kanban.subscribe()

    {:ok,
     assign(socket,
       board: Kanban.get_board(),
       editing: nil,
       deleting_card_id: nil,
       form: %{},
       projects: Projects.list(),
       show_project_modal: false,
       project_form: %{}
     )}
  end

  @impl true
  def handle_info(:board_updated, socket) do
    {:noreply, assign(socket, board: Kanban.get_board())}
  end

  def handle_info(:projects_updated, socket) do
    {:noreply, assign(socket, projects: Projects.list())}
  end

  @impl true
  def handle_event("add_card", %{"column_id" => column_id, "title" => title} = params, socket) do
    if String.trim(title) != "" do
      project_path = Map.get(params, "project_path", "")
      attrs = %{title: title, description: "New task", priority: 2}
      attrs = if project_path != "", do: Map.put(attrs, :project_path, project_path), else: attrs
      Kanban.add_card(column_id, attrs)
    end

    {:noreply, assign(socket, form: %{})}
  end

  def handle_event(
        "move_card",
        %{"card_id" => card_id, "to_column" => to_column} = params,
        socket
      ) do
    new_index = Map.get(params, "new_index", :end)
    Kanban.move_card(card_id, to_column, new_index)
    {:noreply, socket}
  end

  def handle_event("delete_card", %{"card_id" => card_id}, socket) do
    Kanban.remove_card(card_id)
    {:noreply, assign(socket, deleting_card_id: nil)}
  end

  def handle_event("trigger_delete_prompt", %{"card_id" => card_id}, socket) do
    {:noreply, assign(socket, deleting_card_id: card_id)}
  end

  def handle_event("cancel_delete", _, socket) do
    {:noreply, assign(socket, deleting_card_id: nil)}
  end

  def handle_event("edit_card", %{"card_id" => card_id}, socket) do
    card = Kanban.get_card(card_id)

    {:noreply,
     assign(socket, editing: card_id, form: %{
       title: card.title,
       description: card.description,
       project_path: card.project_path || ""
     })}
  end

  def handle_event(
        "save_card",
        %{"card_id" => card_id, "title" => title, "description" => description} = params,
        socket
      ) do
    attrs = %{title: title, description: description}
    attrs = if project_path = Map.get(params, "project_path"), do: Map.put(attrs, :project_path, project_path), else: attrs
    Kanban.update_card(card_id, attrs)
    {:noreply, assign(socket, editing: nil, form: %{})}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing: nil, form: %{})}
  end

  def handle_event("trigger_orchestrator", _, socket) do
    send(Orchestrator, :tick)
    {:noreply, socket}
  end

  def handle_event("start_card", %{"card_id" => card_id}, socket) do
    Kanban.start_card(card_id)
    {:noreply, socket}
  end

  # --- Gerenciamento de Projetos ---

  def handle_event("open_project_modal", _, socket) do
    {:noreply, assign(socket, show_project_modal: true, project_form: %{})}
  end

  def handle_event("close_project_modal", _, socket) do
    {:noreply, assign(socket, show_project_modal: false, project_form: %{})}
  end

  def handle_event("add_project", %{"alias" => alias_name, "path" => path}, socket) do
    if String.trim(alias_name) != "" and String.trim(path) != "" do
      Projects.add(String.trim(alias_name), String.trim(path))
      Process.send(self(), :projects_updated, [])
    end

    {:noreply, assign(socket, project_form: %{})}
  end

  def handle_event("remove_project", %{"alias" => alias_name}, socket) do
    Projects.remove(alias_name)
    Process.send(self(), :projects_updated, [])
    {:noreply, socket}
  end

  def handle_event("folder_selected", %{"name" => dir_name}, socket) do
    {:noreply, assign(socket, project_form: Map.put(socket.assigns.project_form, "alias", dir_name))}
  end

  defp status_badge("running"), do: "bg-blue-500/10 text-blue-500 border-blue-500/20"
  defp status_badge("completed"), do: "bg-emerald-500/10 text-emerald-500 border-emerald-500/20"
  defp status_badge("failed"), do: "bg-red-500/10 text-red-500 border-red-500/20"
  defp status_badge(_), do: "bg-muted/50 text-muted-foreground border-border"

  defp column_header_accent("backlog"), do: "border-muted-foreground/30"
  defp column_header_accent("todo"), do: "border-blue-500/50"
  defp column_header_accent("in_progress"), do: "border-amber-500/50"
  defp column_header_accent("review"), do: "border-purple-500/50"
  defp column_header_accent("done"), do: "border-emerald-500/50"
  defp column_header_accent(_), do: "border-muted-foreground/30"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-foreground antialiased">
      <!-- Global Header -->
      <header class="sticky top-0 z-50 bg-background/60 backdrop-blur-lg border-b border-border/40 px-8 py-4 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 rounded-lg bg-foreground text-background flex items-center justify-center">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
              />
            </svg>
          </div>
          <div>
            <h1 class="text-lg font-semibold tracking-tight">Orquest</h1>
            <p class="text-[11px] text-muted-foreground font-medium uppercase tracking-wider opacity-80">
              Kanban
            </p>
          </div>
        </div>

        <div class="flex items-center gap-4">
          <div class="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-full bg-muted/30 border border-border/50 text-[12px] font-medium text-muted-foreground">
            <span class="relative flex h-1.5 w-1.5">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-1.5 w-1.5 bg-emerald-500"></span>
            </span>
            Orchestrator Active
          </div>

          <button
            type="button"
            onclick="document.documentElement.classList.toggle('dark'); localStorage.setItem('theme', document.documentElement.classList.contains('dark') ? 'dark' : 'light')"
            class="w-9 h-9 flex items-center justify-center rounded-full border border-border/50 text-muted-foreground hover:bg-muted/50 hover:text-foreground transition-all"
            aria-label="Toggle Theme"
          >
            <!-- Sun icon -->
            <svg class="w-4 h-4 dark:hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"
              />
            </svg>
            <!-- Moon icon -->
            <svg
              class="w-4 h-4 hidden dark:block"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
              />
            </svg>
          </button>

          <button
            phx-click="open_project_modal"
            class="px-3 py-1.5 rounded-full border border-border/50 text-muted-foreground hover:bg-muted/50 hover:text-foreground transition-all flex items-center gap-1.5 text-xs font-medium"
          >
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
            </svg>
            Projetos
          </button>

          <button
            phx-click="trigger_orchestrator"
            class="group px-4 py-1.5 bg-foreground hover:bg-foreground/90 text-background rounded-full text-sm font-medium shadow-sm hover:shadow transition-all flex items-center gap-2"
          >
            <svg
              class="w-3.5 h-3.5 group-hover:rotate-180 transition-transform duration-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
              />
            </svg>
            <span>Sync</span>
          </button>
        </div>
      </header>
      
    <!-- Board Container -->
      <main class="p-8 overflow-x-auto">
        <div class="flex gap-6 items-start">
          <%= for column <- @board.columns do %>
            <div class="w-[320px] shrink-0 flex flex-col">
              <!-- Column Header -->
              <div class="flex items-center justify-between px-1 mb-3">
                <div class="flex items-center gap-2">
                  <div class={[
                    "w-2 h-2 rounded-full",
                    column_header_accent(column.id)
                    |> String.replace("border", "bg")
                    |> String.replace("/50", "")
                  ]}>
                  </div>
                  <h2 class="font-semibold text-[14px] tracking-tight text-foreground/90">
                    {column.name}
                  </h2>
                  <span class="text-[11px] text-muted-foreground font-mono bg-muted/50 px-1.5 py-0.5 rounded">
                    {length(column.cards)}
                  </span>
                </div>
              </div>
              
    <!-- Column Body -->
              <div class="flex flex-col gap-3 min-h-[500px]">
                <%= if column.id == "backlog" do %>
                  <form
                    phx-submit="add_card"
                    class="group flex flex-col bg-muted/30 hover:bg-muted/50 border border-dashed border-border/60 hover:border-border rounded-xl transition-all shrink-0"
                  >
                    <input type="hidden" name="column_id" value={column.id} />
                    <div class="flex">
                      <input
                        type="text"
                        name="title"
                        placeholder="+ Add New Task"
                        class="flex-1 bg-transparent border-none px-4 py-3 text-sm text-foreground placeholder-muted-foreground/60 focus:outline-none focus:ring-0"
                        required
                        autocomplete="off"
                      />
                      <button
                        type="submit"
                        class="hidden group-focus-within:block px-4 text-xs font-semibold text-muted-foreground hover:text-foreground"
                      >
                        ADD
                      </button>
                    </div>
                    <div class="flex items-center gap-2 border-t border-dashed border-border/30 px-3 py-1.5">
                      <svg class="w-3 h-3 text-muted-foreground/40 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                      </svg>
                      <select
                        name="project_path"
                        class="flex-1 bg-transparent border-none text-[11px] text-muted-foreground/70 placeholder-muted-foreground/40 focus:outline-none focus:ring-0 font-mono cursor-pointer appearance-none"
                      >
                        <option value="">— sem projeto —</option>
                        <%= for p <- @projects do %>
                          <option value={p.path}><%= p.alias %></option>
                        <% end %>
                      </select>
                    </div>
                  </form>
                <% end %>

                <div
                  class="flex-1 space-y-3 min-h-[100px]"
                  id={"cards-list-#{column.id}"}
                  phx-hook="Sortable"
                  data-column={column.id}
                >
                  <%= for card <- column.cards do %>
                    <% locked = card.agent_status in ["running", "completed"] %>
                    <% card_class = if locked do
                      "group bg-card border border-amber-500/30 bg-amber-500/[0.02] rounded-xl p-3.5 shadow-sm relative cursor-default transition-all duration-300 flex flex-col h-auto"
                    else
                      "group bg-card border border-border/60 hover:border-border/100 rounded-xl p-3.5 shadow-sm hover:shadow-md relative cursor-pointer active:cursor-grabbing transition-all duration-300 h-[114px] hover:h-auto overflow-hidden flex flex-col"
                    end %>
                    <div
                      id={"card-#{card.id}"}
                      data-id={card.id}
                      phx-click={unless locked, do: "edit_card"}
                      phx-value-card_id={unless locked, do: card.id}
                      class={card_class}
                    >
                      <!-- Lock Overlay para running -->
                      <%= if card.agent_status == "running" do %>
                        <div class="absolute inset-0 rounded-xl bg-gradient-to-b from-amber-500/[0.03] to-transparent pointer-events-none">
                        </div>
                      <% end %>

                      <!-- Header Row -->
                      <div class="flex items-start justify-between gap-3 w-full shrink-0">
                        <% title_class = if locked, do: "font-semibold text-[13px] leading-snug line-clamp-1 flex-1 text-foreground", else: "font-semibold text-[13px] leading-snug line-clamp-1 flex-1 text-foreground/90 group-hover:text-foreground" %>
                        <h3 class={title_class}>
                          {card.title}
                        </h3>

                        <div class="flex items-center gap-1.5 shrink-0 -mt-0.5">
                          <!-- Status Badge -->
                          <span class={[
                            "text-[9px] font-bold px-1.5 py-0.5 rounded border uppercase tracking-tighter",
                            status_badge(card.agent_status)
                          ]}>
                            {String.slice(card.agent_status, 0, 3)}
                          </span>

                          <!-- Lock Icon for running -->
                          <%= if card.agent_status == "running" do %>
                            <span class="p-1 rounded text-amber-500" title="Em execução">
                              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                              </svg>
                            </span>
                          <% end %>

                          <!-- Delete Button (hidden for locked cards) -->
                          <%= unless locked do %>
                            <button
                              type="button"
                              phx-click={JS.push("trigger_delete_prompt", value: %{card_id: card.id})}
                              onclick="event.stopPropagation()"
                              class="opacity-0 group-hover:opacity-100 p-1 rounded text-muted-foreground hover:text-red-500 hover:bg-red-500/10 transition"
                              title="Delete"
                            >
                              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                              </svg>
                            </button>
                          <% end %>
                        </div>
                      </div>
                      
                      <!-- Description (Visible by default, expands on hover for unlocked) -->
                      <%= if card.description && String.trim(card.description) != "" do %>
                        <% desc_class = if locked, do: "line-clamp-6", else: "line-clamp-3 group-hover:line-clamp-6" %>
                        <p class={"text-[12px] text-muted-foreground mt-2 leading-relaxed transition-all #{desc_class}"}>
                          {card.description}
                        </p>
                      <% end %>

                      <!-- Start Button (only for idle cards in todo) -->
                      <%= if column.id == "todo" && card.agent_status == "idle" do %>
                        <div class="mt-3 pt-2 border-t border-border/40">
                          <button
                            type="button"
                            phx-click="start_card"
                            phx-value-card_id={card.id}
                            class="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-lg bg-emerald-500 hover:bg-emerald-600 text-white text-xs font-semibold shadow-sm hover:shadow-emerald-500/20 transition-all"
                          >
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            Start Agent
                          </button>
                        </div>
                      <% end %>
                      
                      <!-- Running Info (for running cards) -->
                      <%= if card.agent_status == "running" && card.tmux_session do %>
                        <div class="mt-3 pt-2 border-t border-border/40 space-y-1.5">
                          <div class="flex items-center gap-2">
                            <span class="relative flex h-2 w-2">
                              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                            </span>
                            <span class="text-[10px] font-mono text-muted-foreground truncate" title={card.tmux_session}>
                              tmux: {card.tmux_session}
                            </span>
                          </div>
                          <%= if card.workspace_path do %>
                            <div class="flex items-center gap-1.5 pl-4">
                              <svg class="w-2.5 h-2.5 text-muted-foreground/60 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                              </svg>
                              <span class="text-[10px] font-mono text-muted-foreground/70 truncate" title={card.workspace_path}>
                                {card.workspace_path}
                              </span>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                      
                      <!-- Completed Info -->
                      <%= if card.agent_status == "completed" do %>
                        <div class="mt-3 pt-2 border-t border-border/40">
                          <span class="inline-flex items-center gap-1 text-[10px] font-semibold text-emerald-500">
                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            Completed
                          </span>
                        </div>
                      <% end %>

                      <!-- Tags (only visible on hover for unlocked) -->
                      <% tags_class = if locked, do: "mt-3 pt-2 border-t border-border/40", else: "hidden group-hover:block mt-3 pt-2 border-t border-border/40 animate-in fade-in duration-200" %>
                      <div class={tags_class}>
                        <div class="flex items-center gap-1.5 flex-wrap">
                          <span class={[
                            "text-[10px] font-bold px-1.5 py-0.5 rounded border uppercase tracking-tight",
                            status_badge(card.agent_status)
                          ]}>
                            {card.agent_status}
                          </span>
                          <%= for tag <- card.tags do %>
                            <span class="text-[10px] font-medium text-muted-foreground bg-muted/40 px-1.5 py-0.5 rounded">
                              {tag}
                            </span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </main>
      
    <!-- Minimal Confirmation Dialog -->
      <%= if @deleting_card_id do %>
        <div class="fixed inset-0 z-[100] flex items-center justify-center p-4">
          <div
            class="fixed inset-0 bg-background/40 backdrop-blur-sm animate-in fade-in duration-200"
            phx-click="cancel_delete"
          >
          </div>
          <div class="relative bg-card border border-border shadow-2xl rounded-2xl p-6 w-full max-w-[340px] animate-in zoom-in-95 duration-200">
            <div class="flex items-center justify-center w-10 h-10 rounded-full bg-red-500/10 mb-4 text-red-500">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                />
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-foreground leading-tight">Excluir tarefa?</h3>
            <p class="text-sm text-muted-foreground mt-1 mb-6">
              Esta ação não pode ser desfeita e a tarefa será removida permanentemente.
            </p>

            <div class="flex items-center gap-3 w-full">
              <button
                phx-click="cancel_delete"
                class="flex-1 px-4 py-2 rounded-lg text-sm font-medium text-muted-foreground hover:bg-muted transition border border-transparent hover:border-border/50"
              >
                Cancelar
              </button>
              <button
                phx-click="delete_card"
                phx-value-card_id={@deleting_card_id}
                class="flex-1 px-4 py-2 rounded-lg text-sm font-semibold bg-red-500 hover:bg-red-600 text-white shadow-md shadow-red-500/20 transition"
              >
                Excluir
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Edit Task Modal -->
      <%= if @editing do %>
        <div class="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-6">
          <div
            class="fixed inset-0 bg-background/40 backdrop-blur-sm animate-in fade-in duration-200"
            phx-click="cancel_edit"
          >
          </div>
          <div class="relative bg-card border border-border shadow-2xl rounded-2xl w-full max-w-3xl max-h-[90vh] animate-in zoom-in-95 duration-200 overflow-hidden flex flex-col">
            <div class="px-6 py-4 border-b border-border/60 flex items-center justify-between bg-muted/10 flex-shrink-0">
              <h3 class="text-base font-semibold text-foreground tracking-tight">Editar Tarefa</h3>
              <button
                phx-click="cancel_edit"
                class="p-1 rounded text-muted-foreground hover:text-foreground transition"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <form phx-submit="save_card" class="p-6 space-y-5 overflow-y-auto">
              <input type="hidden" name="card_id" value={@editing} />
              <div class="space-y-1.5">
                <label class="text-[11px] font-semibold text-muted-foreground uppercase tracking-widest px-1">
                  Título
                </label>
                <input
                  type="text"
                  name="title"
                  value={@form[:title]}
                  class="w-full bg-muted/20 border border-border/60 hover:border-border rounded-xl px-4 py-3 text-sm text-foreground focus:outline-none focus:border-foreground/30 focus:ring-4 focus:ring-foreground/5 transition-all"
                  placeholder="O que precisa ser feito?"
                  required
                  autocomplete="off"
                />
              </div>

              <div class="space-y-1.5 flex-1 flex flex-col min-h-[400px]">
                <label class="text-[11px] font-semibold text-muted-foreground uppercase tracking-widest px-1">
                  Descrição
                </label>
                <textarea
                  name="description"
                  rows="16"
                  class="w-full flex-1 bg-muted/20 border border-border/60 hover:border-border rounded-xl px-4 py-3 text-sm text-foreground font-mono resize-none focus:outline-none focus:border-foreground/30 focus:ring-4 focus:ring-foreground/5 transition-all leading-relaxed placeholder:font-sans"
                  placeholder="# Sua documentação aqui..."
                ><%= @form[:description] %></textarea>
              </div>

              <div class="space-y-1.5">
                <label class="text-[11px] font-semibold text-muted-foreground uppercase tracking-widest px-1">
                  Projeto
                </label>
                <select
                  name="project_path"
                  class="w-full bg-muted/20 border border-border/60 hover:border-border rounded-xl px-4 py-2.5 text-sm text-foreground font-mono focus:outline-none focus:border-foreground/30 focus:ring-4 focus:ring-foreground/5 transition-all cursor-pointer"
                >
                  <option value="">— sem projeto —</option>
                  <%= for p <- @projects do %>
                    <option value={p.path} selected={@form[:project_path] == p.path}><%= p.alias %> — <%= p.path %></option>
                  <% end %>
                </select>
              </div>

              <div class="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  phx-click="cancel_edit"
                  class="px-4 py-2 rounded-lg text-sm font-medium text-muted-foreground hover:bg-muted transition"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  class="px-6 py-2 rounded-lg text-sm font-semibold bg-foreground text-background hover:bg-foreground/90 shadow-sm hover:shadow transition-all"
                >
                  Salvar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
      
    <!-- Project Management Modal -->
      <%= if @show_project_modal do %>
        <div class="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-6">
          <div
            class="fixed inset-0 bg-background/40 backdrop-blur-sm animate-in fade-in duration-200"
            phx-click="close_project_modal"
          >
          </div>
          <div class="relative bg-card border border-border shadow-2xl rounded-2xl w-full max-w-lg animate-in zoom-in-95 duration-200 overflow-hidden flex flex-col max-h-[90vh]">
            <div class="px-6 py-4 border-b border-border/60 flex items-center justify-between bg-muted/10 flex-shrink-0">
              <h3 class="text-base font-semibold text-foreground tracking-tight">Gerenciar Projetos</h3>
              <button
                phx-click="close_project_modal"
                class="p-1 rounded text-muted-foreground hover:text-foreground transition"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div class="p-6 space-y-4 overflow-y-auto">
              <!-- Lista de projetos -->
              <div class="space-y-2">
                <h4 class="text-[11px] font-semibold text-muted-foreground uppercase tracking-widest">
                  Projetos cadastrados
                </h4>
                <%= if @projects == [] do %>
                  <p class="text-sm text-muted-foreground/60 italic">Nenhum projeto cadastrado ainda.</p>
                <% else %>
                  <div class="space-y-2">
                    <%= for p <- @projects do %>
                      <div class="flex items-center justify-between bg-muted/20 border border-border/40 rounded-lg px-4 py-2.5">
                        <div class="flex flex-col min-w-0">
                          <span class="text-sm font-semibold text-foreground"><%= p.alias %></span>
                          <span class="text-[11px] font-mono text-muted-foreground truncate"><%= p.path %></span>
                        </div>
                        <button
                          phx-click="remove_project"
                          phx-value-alias={p.alias}
                          class="p-1.5 rounded text-muted-foreground hover:text-red-500 hover:bg-red-500/10 transition shrink-0 ml-3"
                          title="Remover projeto"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <!-- Adicionar novo projeto -->
              <div class="pt-3 border-t border-border/40">
                <h4 class="text-[11px] font-semibold text-muted-foreground uppercase tracking-widest mb-3">
                  Adicionar projeto
                </h4>
                <form phx-submit="add_project" class="space-y-3">
                  <div>
                    <label class="text-[10px] font-medium text-muted-foreground px-1">Alias</label>
                    <input
                      type="text"
                      name="alias"
                      placeholder="ex: saas1"
                      value={@project_form[:alias]}
                      class="w-full bg-muted/20 border border-border/60 hover:border-border rounded-xl px-4 py-2 text-sm text-foreground font-mono focus:outline-none focus:border-foreground/30 focus:ring-4 focus:ring-foreground/5 transition-all"
                      required
                      autocomplete="off"
                    />
                  </div>
                  <div>
                    <label class="text-[10px] font-medium text-muted-foreground px-1">Caminho</label>
                    <div class="flex gap-2">
                      <input
                        type="text"
                        name="path"
                        placeholder="/home/user/meu-projeto"
                        class="flex-1 bg-muted/20 border border-border/60 hover:border-border rounded-xl px-4 py-2 text-sm text-foreground font-mono focus:outline-none focus:border-foreground/30 focus:ring-4 focus:ring-foreground/5 transition-all"
                        required
                        autocomplete="off"
                      />
                      <button
                        type="button"
                        id="folder-picker-btn"
                        phx-hook="FolderPicker"
                        class="px-3 py-2 rounded-xl bg-muted/20 border border-border/60 hover:bg-muted/40 hover:border-border text-muted-foreground hover:text-foreground transition-all shrink-0"
                        title="Selecionar pasta"
                      >
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                        </svg>
                      </button>
                    </div>
                  </div>
                  <button
                    type="submit"
                    class="w-full px-4 py-2 rounded-lg text-sm font-semibold bg-foreground text-background hover:bg-foreground/90 shadow-sm hover:shadow transition-all"
                  >
                    Adicionar Projeto
                  </button>
                </form>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
