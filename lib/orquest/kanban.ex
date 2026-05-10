defmodule Orquest.Kanban do
  @moduledoc """
  Gerencia o estado do board Kanban em memória.
  """
  use Agent
  alias Orquest.Kanban.Board

  def start_link(_opts) do
    Agent.start_link(fn -> Board.new() end, name: __MODULE__)
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

  def subscribe, do: Phoenix.PubSub.subscribe(Orquest.PubSub, "kanban")

  def broadcast_change do
    Phoenix.PubSub.broadcast(Orquest.PubSub, "kanban", :board_updated)
  end
end
