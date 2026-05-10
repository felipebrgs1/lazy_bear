defmodule Orquest.Workspace do
  @moduledoc """
  Gerencia workspaces físicos e o conceito de Borrow/Return.

  - Borrow: reserva uma pasta para um card/agente trabalhar isoladamente
  - Return: libera a pasta, permitindo que outro agente a use
  """
  use Agent

  require Logger

  @workspace_root "/tmp/orquest_workspaces"

  defstruct [:id, :path, :card_id, :borrowed_by, :borrowed_at, :status, :hooks]

  def start_link(_opts) do
    File.mkdir_p!(@workspace_root)
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def borrow(card_id, workspace_key) do
    Agent.get_and_update(__MODULE__, fn state ->
      case find_workspace_by_card(state, card_id) do
        {_id, ws} when ws.status == :borrowed ->
          {{:error, :already_borrowed}, state}

        {id, ws} ->
          ws = %{ws | borrowed_by: "agent-#{System.unique_integer([:positive])}", borrowed_at: DateTime.utc_now(), status: :borrowed, card_id: card_id}
          {{:ok, ws}, Map.put(state, id, ws)}

        nil ->
          ws = create_workspace(card_id, workspace_key)
          {{:ok, ws}, Map.put(state, ws.id, ws)}
      end
    end)
  end

  def return(card_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case find_workspace_by_card(state, card_id) do
        {id, ws} ->
          ws = %{ws | borrowed_by: nil, borrowed_at: nil, status: :available, card_id: nil}
          {{:ok, ws}, Map.put(state, id, ws)}

        nil ->
          {{:error, :not_found}, state}
      end
    end)
  end

  def get_workspace(card_id) do
    Agent.get(__MODULE__, fn state ->
      case find_workspace_by_card(state, card_id) do
        {_, ws} -> ws
        nil -> nil
      end
    end)
  end

  def list_workspaces do
    Agent.get(__MODULE__, fn state ->
      Map.values(state)
    end)
  end

  def cleanup do
    Agent.update(__MODULE__, fn state ->
      state
      |> Enum.reject(fn {_id, ws} -> ws.status == :available end)
      |> Enum.into(%{})
    end)
  end

  defp create_workspace(card_id, workspace_key) do
    sanitized = sanitize(workspace_key)
    path = Path.join(@workspace_root, sanitized)
    File.mkdir_p!(path)

    %__MODULE__{
      id: Uniq.UUID.uuid4(),
      path: path,
      card_id: card_id,
      borrowed_by: "agent-#{System.unique_integer([:positive])}",
      borrowed_at: DateTime.utc_now(),
      status: :borrowed,
      hooks: %{}
    }
  end

  defp find_workspace_by_card(state, card_id) do
    Enum.find(state, fn {_id, ws} -> ws.card_id == card_id end)
  end

  defp sanitize(key) do
    key
    |> String.replace(~r/[^A-Za-z0-9._-]/, "_")
    |> String.slice(0, 100)
  end
end
