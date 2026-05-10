defmodule Orquest.Workspace do
  @moduledoc """
  Gerencia workspaces físicos e o conceito de Borrow/Return.

  Cada workspace é criado dentro de um diretório de projeto:

      <project_path>/orquestor/<note_name>/

  Exemplo: /saas1/orquestor/refatorar-modulo-x/
  """
  use Agent

  require Logger

  @default_root "/tmp/orquest_workspaces"

  defstruct [:id, :path, :card_id, :project_path, :note_name, :borrowed_by, :borrowed_at, :status, :hooks]

  def start_link(_opts) do
    File.mkdir_p!(@default_root)
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Reserva um workspace para um card.

  ## Parâmetros

    - `card_id` - ID do card
    - `project_path` - Caminho raiz do projeto (ex: "/saas1"). Se nil, usa @default_root.
    - `note_name` - Nome da nota/pasta (ex: "refatorar-modulo-x"). Se nil, usa o card_id.

  O workspace será criado em `<project_path>/orquestor/<note_name>/`.
  """
  def borrow(card_id, project_path \\ nil, note_name \\ nil) do
    Agent.get_and_update(__MODULE__, fn state ->
      case find_workspace_by_card(state, card_id) do
        {_id, ws} when ws.status == :borrowed ->
          {{:error, :already_borrowed}, state}

        {id, ws} ->
          ws = %{ws |
            borrowed_by: "agent-#{System.unique_integer([:positive])}",
            borrowed_at: DateTime.utc_now(),
            status: :borrowed,
            card_id: card_id
          }
          {{:ok, ws}, Map.put(state, id, ws)}

        nil ->
          ws = create_workspace(card_id, project_path, note_name)
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

  defp create_workspace(card_id, project_path, note_name) do
    root = project_path || @default_root
    slug = note_name && sanitize(note_name) || sanitize("nota-#{card_id}")

    path = Path.join([root, "orquestor", slug])
    File.mkdir_p!(path)

    %__MODULE__{
      id: Uniq.UUID.uuid4(),
      path: path,
      card_id: card_id,
      project_path: root,
      note_name: slug,
      borrowed_by: "agent-#{System.unique_integer([:positive])}",
      borrowed_at: DateTime.utc_now(),
      status: :borrowed,
      hooks: %{}
    }
  end

  defp find_workspace_by_card(state, card_id) do
    Enum.find(state, fn {_id, ws} -> ws.card_id == card_id end)
  end

  @doc false
  def sanitize(key) do
    key
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9._-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> String.slice(0, 80)
  end
end
