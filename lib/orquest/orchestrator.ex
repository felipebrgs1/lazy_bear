defmodule Orquest.Orchestrator do
  @moduledoc """
  Orchestrator GenServer que gerencia o ciclo de vida dos agentes.

  - Cria sessões tmux com opencode para cada card
  - Monitora sessões ativas e move cards entre colunas
  - Libera recursos quando o agente termina
  """
  use GenServer

  require Logger

  alias Orquest.Kanban
  alias Orquest.Workspace

  @poll_interval 5_000

  defstruct [:timer_ref, :running, :max_concurrent]

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Inicia um agente para o card: cria sessão tmux com opencode.
  Chamado pelo Kanban.start_card/1 após mover o card para in_progress.
  """
  def start_agent(card_id, session_name, workspace_path, description) do
    GenServer.call(__MODULE__, {:start_agent, card_id, session_name, workspace_path, description}, :infinity)
  end

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      timer_ref: nil,
      running: %{},
      max_concurrent: 3
    }
    {:ok, schedule_tick(state)}
  end

  @impl true
  def handle_call({:start_agent, card_id, session_name, workspace_path, description}, _from, state) do
    case create_tmux_session(card_id, session_name, workspace_path, description) do
      {:ok, _pid} ->
        Logger.info("[Orchestrator] Agent started for card #{card_id} in tmux session #{session_name}")
        {:reply, :ok, %{state | running: Map.put(state.running, card_id, session_name)}}

      {:error, reason} ->
        Logger.error("[Orchestrator] Failed to start agent for card #{card_id}: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    state = reconcile_runs(state)
    {:noreply, schedule_tick(state)}
  end

  # Catch-all para mensagens inesperadas
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Funções Privadas ---

  defp create_tmux_session(_card_id, session_name, workspace_path, description) do
    File.mkdir_p!(workspace_path)

    task_file = Path.join(workspace_path, "TASK.md")

    File.write!(task_file, description)

    case System.cmd("tmux", [
      "new-session", "-d", "-s", session_name, "-c", workspace_path
    ], stderr_to_stdout: true, into: []) do
      {_output, 0} ->
        cmd = "opencode \"#{task_file}\""

        System.cmd("tmux", [
          "send-keys", "-t", session_name, cmd, "Enter"
        ], stderr_to_stdout: true, into: [])

        {:ok, session_name}

      {output, _exit_code} ->
        {:error, "tmux failed: #{output}"}
    end
  end

  defp reconcile_runs(state) do
    active_sessions =
      state.running
      |> Enum.filter(fn {_card_id, session_name} ->
        tmux_session_alive?(session_name)
      end)
      |> Map.new()

    finished_ids = Map.keys(state.running) -- Map.keys(active_sessions)

    state = Enum.reduce(finished_ids, state, fn card_id, st ->
      Logger.info("[Orchestrator] Session ended for card #{card_id}")
      finish_run(st, card_id)
    end)

    %{state | running: active_sessions}
  end

  defp tmux_session_alive?(session_name) do
    case System.cmd("tmux", ["has-session", "-t", session_name], stderr_to_stdout: true, into: []) do
      {_output, 0} -> true
      _ -> false
    end
  end

  defp finish_run(state, card_id) do
    state = %{state | running: Map.delete(state.running, card_id)}

    Kanban.move_card(card_id, "done")
    Kanban.update_card(card_id, %{agent_status: "completed"})

    Workspace.return(card_id)
    state
  end

  defp schedule_tick(state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)
    ref = Process.send_after(self(), :tick, @poll_interval)
    %{state | timer_ref: ref}
  end
end
