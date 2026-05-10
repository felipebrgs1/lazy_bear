defmodule Orquest.Kanban do
  @moduledoc """
  Gerencia o board Kanban, com persistência em arquivos .md nos projetos.

  Cards são armazenados como arquivos .md em `{project_path}/orquestrator/`.
  O app mantém um cache em memória para acesso rápido.
  """
  use Agent
  alias Orquest.Kanban.Board
  alias Orquest.Projects

  # Runtime fields that should NOT be overwritten when reloading from .md
  @runtime_fields [:agent_status, :tmux_session, :workspace_path, :borrowed_by, :output_log]

  def start_link(_opts) do
    Agent.start_link(fn -> init_board() end, name: __MODULE__)
  end

  defp init_board do
    board = Board.new()
    projects = Projects.list()
    Board.load_cards(board, projects)
  end

  @doc "Retorna o board atual (cache em memória)."
  def get_board, do: Agent.get(__MODULE__, & &1)

  @doc "Recarrega todos os cards dos projetos (Sync). Preserva estado runtime."
  def reload do
    Agent.update(__MODULE__, fn board ->
      runtime = capture_runtime(board)
      projects = Projects.list()
      board = Board.load_cards(board, projects)
      restore_runtime(board, runtime)
    end)
    broadcast_change()
  end

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

      note_name = Orquest.Workspace.sanitize(card.title || "nota-#{card_id}")
      {:ok, ws} = Orquest.Workspace.borrow(card_id, card.project_path, note_name)

      session_name = "orquest-#{card_id}"

      update_card(card_id, %{
        workspace_path: ws.path,
        agent_status: "running",
        tmux_session: session_name,
        borrowed_by: ws.borrowed_by,
        project_path: ws.project_path
      })

      Orquest.Orchestrator.start_agent(card_id, session_name, ws.path, card.description)
    end

    broadcast_change()
  end

  @doc """
  Para um card: mata a sessão tmux, move de volta para backlog e limpa status.
  """
  def stop_card(card_id) do
    card = get_card(card_id)

    if card do
      Orquest.Orchestrator.stop_agent(card_id)

      move_card(card_id, "backlog", :start)

      update_card(card_id, %{
        agent_status: "idle",
        tmux_session: nil,
        workspace_path: nil,
        borrowed_by: nil
      })

      Orquest.Workspace.return(card_id)
    end

    broadcast_change()
  end

  def subscribe, do: Phoenix.PubSub.subscribe(Orquest.PubSub, "kanban")

  def broadcast_change do
    Phoenix.PubSub.broadcast(Orquest.PubSub, "kanban", :board_updated)
  end

  # --- Helpers ---

  defp capture_runtime(board) do
    board.columns
    |> Enum.flat_map(& &1.cards)
    |> Enum.filter(fn c -> c.agent_status && c.agent_status != "idle" end)
    |> Enum.map(fn c ->
      {c.id, Map.take(c, @runtime_fields)}
    end)
    |> Map.new()
  end

  defp restore_runtime(board, runtime) do
    Enum.reduce(runtime, board, fn {card_id, fields}, acc ->
      Board.update_card(acc, card_id, fields)
    end)
  end
end
