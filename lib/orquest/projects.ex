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

  @doc "Lista projetos com cor atribuída."
  def list_with_colors do
    list()
    |> Enum.with_index()
    |> Enum.map(fn {p, i} ->
      Map.put(p, :color, color_for(i))
    end)
  end

  @doc "Retorna um mapa path -> projeto (com cor) para lookup rápido."
  def map_by_path do
    list_with_colors()
    |> Enum.map(fn p -> {p.path, p} end)
    |> Map.new()
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

  defp color_for(index) do
    palette = [
      "#3b82f6", # blue-500
      "#10b981", # emerald-500
      "#f59e0b", # amber-500
      "#8b5cf6", # violet-500
      "#ec4899", # pink-500
      "#06b6d4", # cyan-500
      "#f97316", # orange-500
      "#14b8a6", # teal-500
      "#6366f1", # indigo-500
      "#ef4444", # red-500
      "#84cc16", # lime-500
      "#a855f7", # purple-500
    ]
    Enum.at(palette, rem(index, length(palette)))
  end
end
