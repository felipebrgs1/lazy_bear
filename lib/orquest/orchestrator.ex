defmodule Orquest.Orchestrator do
  @moduledoc """
  Orchestrator GenServer que gerencia o ciclo de vida dos agentes.

  - Poll periódico por cards em "todo"
  - Borrow de workspace
  - Execução simulada de agente
  - Movimentação automática entre colunas
  """
  use GenServer

  require Logger

  alias Orquest.Kanban
  alias Orquest.Workspace

  @poll_interval 5_000

  defstruct [:timer_ref, :running, :max_concurrent]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %__MODULE__{
      timer_ref: nil,
      running: %{},
      max_concurrent: 3
    }
    {:ok, schedule_tick(state)}
  end

  def handle_info(:tick, state) do
    state = dispatch_work(state)
    state = reconcile_runs(state)
    {:noreply, schedule_tick(state)}
  end

  def handle_cast({:agent_done, card_id, result}, state) do
    state = finish_run(state, card_id, result)
    {:noreply, state}
  end

  defp dispatch_work(state) do
    board = Kanban.get_board()
    todo_col = Enum.find(board.columns, &(&1.id == "todo"))

    if todo_col && length(todo_col.cards) > 0 do
      available_slots = state.max_concurrent - map_size(state.running)

      if available_slots > 0 do
        todo_col.cards
        |> Enum.take(available_slots)
        |> Enum.reduce(state, fn card, st ->
          start_run(st, card)
        end)
      else
        state
      end
    else
      state
    end
  end

  defp start_run(state, card) do
    workspace_key = "#{card.id}"

    case Workspace.borrow(card.id, workspace_key) do
      {:ok, ws} ->
        Kanban.move_card(card.id, "borrowed")
        Kanban.update_card(card.id, %{workspace_path: ws.path, agent_status: "running"})

        task = Task.async(fn ->
          simulate_agent_work(card, ws)
        end)

        %{state | running: Map.put(state.running, card.id, task)}

      {:error, _} ->
        state
    end
  end

  defp simulate_agent_work(card, workspace) do
    Logger.info("[Orchestrator] Agent started for card #{card.id} in #{workspace.path}")

    :timer.sleep(:rand.uniform(8_000) + 4_000)

    result = if :rand.uniform() > 0.2 do
      :success
    else
      :failure
    end

    GenServer.cast(__MODULE__, {:agent_done, card.id, result})
    result
  end

  defp finish_run(state, card_id, result) do
    state = %{state | running: Map.delete(state.running, card_id)}

    case result do
      :success ->
        Kanban.move_card(card_id, "done")
        Kanban.update_card(card_id, %{agent_status: "completed"})

      :failure ->
        Kanban.move_card(card_id, "todo")
        Kanban.update_card(card_id, %{agent_status: "idle"})
    end

    Workspace.return(card_id)
    state
  end

  defp reconcile_runs(state) do
    state
  end

  defp schedule_tick(state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)
    ref = Process.send_after(self(), :tick, @poll_interval)
    %{state | timer_ref: ref}
  end
end
