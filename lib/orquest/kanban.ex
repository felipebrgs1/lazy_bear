defmodule Orquest.Kanban do
  @moduledoc """
  Gerencia o estado do board Kanban em memória.
  """
  use Agent

  alias Orquest.Kanban.Board

  def start_link(_opts) do
    Agent.start_link(fn ->
      Board.new()
      |> Board.add_card("backlog", %{title: "Implementar autenticação JWT", description: "Adicionar login com tokens JWT no backend", priority: 1, tags: ["backend", "auth"]})
      |> Board.add_card("backlog", %{title: "Criar pipeline CI/CD", description: "GitHub Actions para testes e deploy", priority: 2, tags: ["devops"]})
      |> Board.add_card("backlog", %{title: "Documentar API REST", description: "Swagger/OpenAPI para todos os endpoints", priority: 3, tags: ["docs"]})
      |> Board.add_card("todo", %{title: "Refatorar módulo de pagamentos", description: "Separar concerns e adicionar testes", priority: 1, tags: ["refactor"]})
      |> Board.add_card("todo", %{title: "Otimizar queries do dashboard", description: "Adicionar índices e cache Redis", priority: 2, tags: ["perf"]})
      |> Board.add_card("done", %{title: "Setup inicial do projeto", description: "Configurar Elixir, Phoenix e Docker", priority: 1, tags: ["setup"]})
    end, name: __MODULE__)
  end

  def get_board, do: Agent.get(__MODULE__, & &1)

  def add_card(column_id, attrs) do
    Agent.update(__MODULE__, fn board ->
      Board.add_card(board, column_id, attrs)
    end)
    broadcast_change()
  end

  def move_card(card_id, to_column_id, position \\ :end) do
    Agent.update(__MODULE__, fn board ->
      Board.move_card(board, card_id, to_column_id, position)
    end)
    broadcast_change()
  end

  def update_card(card_id, attrs) do
    Agent.update(__MODULE__, fn board ->
      Board.update_card(board, card_id, attrs)
    end)
    broadcast_change()
  end

  def remove_card(card_id) do
    Agent.update(__MODULE__, fn board ->
      Board.remove_card(board, card_id)
    end)
    broadcast_change()
  end

  def get_card(card_id) do
    Agent.get(__MODULE__, fn board ->
      Board.find_card(board, card_id)
    end)
  end

  def start_card(card_id) do
    card = get_card(card_id)

    if card do
      move_card(card_id, "in_progress", :start)

      {:ok, ws} = Orquest.Workspace.borrow(card_id, "workspace-#{card_id}")

      session_name = "orquest-#{card_id}"

      update_card(card_id, %{
        workspace_path: ws.path,
        agent_status: "running",
        tmux_session: session_name,
        borrowed_by: ws.borrowed_by
      })

      Orquest.Orchestrator.start_agent(card_id, session_name, ws.path, card.description)
    end

    broadcast_change()
  end

  def subscribe, do: Phoenix.PubSub.subscribe(Orquest.PubSub, "kanban")

  def broadcast_change do
    Phoenix.PubSub.broadcast(Orquest.PubSub, "kanban", :board_updated)
  end
end
