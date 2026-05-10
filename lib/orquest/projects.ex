defmodule Orquest.Projects do
  @moduledoc """
  Gerencia aliases de projetos no sistema.

  Cada projeto tem um alias (nome curto) e um caminho absoluto.
  Exemplo:
    - "saas1" → "/home/user/saas1"
    - "blog"  → "/home/user/projects/blog"

  Usado nos formulários do Kanban para selecionar o workspace do card.
  """
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc "Lista todos os projetos cadastrados."
  def list do
    Agent.get(__MODULE__, & &1)
    |> Map.values()
    |> Enum.sort_by(& &1.alias)
  end

  @doc "Retorna o caminho de um projeto pelo alias."
  def get_path(alias_name) do
    Agent.get(__MODULE__, fn state ->
      case Map.get(state, alias_name) do
        %{path: path} -> path
        nil -> nil
      end
    end)
  end

  @doc "Adiciona ou atualiza um projeto."
  def add(alias_name, path) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, alias_name, %{alias: alias_name, path: path})
    end)
  end

  @doc "Remove um projeto pelo alias."
  def remove(alias_name) do
    Agent.update(__MODULE__, fn state ->
      Map.delete(state, alias_name)
    end)
  end
end
