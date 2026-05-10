defmodule Orquest.Kanban.CardParser do
  @moduledoc """
  Lê e escreve cards como arquivos .md dentro de `{project_path}/orquestrator/`.

  ## Formato do .md

  ```markdown
  # Título do Card
  tags: backend, auth, refactor
  priority: 1
  status: backlog

  Body content here...
  ```

  A primeira linha `# ` define o título.
  Linhas antes do primeiro espaço em branco viram metadados (tags, priority, status).
  O resto é o body/descrição.
  """

  alias Orquest.Kanban.Card

  @doc """
  Parseia um arquivo .md e retorna um struct Card.
  """
  def parse(file_path, project_path \\ nil) do
    content = File.read!(file_path)
    lines = String.split(content, "\n")

    {title, rest} = extract_title(lines)
    {meta, body_lines} = extract_metadata(rest)
    body = Enum.join(body_lines, "\n") |> String.trim()

    id =
      file_path
      |> Path.basename()
      |> Path.rootname()

    %Card{
      id: id,
      title: title || "Untitled",
      description: body,
      tags: Map.get(meta, "tags", "") |> parse_tags(),
      priority: Map.get(meta, "priority", "3") |> parse_int(3),
      status: Map.get(meta, "status", "backlog"),
      project_path: project_path,
      agent_status: "idle"
    }
  end

  @doc """
  Gera o conteúdo .md a partir de um Card.
  """
  def serialize(card) do
    meta = %{
      "tags" => Enum.join(card.tags || [], ", "),
      "priority" => Integer.to_string(card.priority || 3),
      "status" => card.status || "backlog"
    }

    meta_lines =
      meta
      |> Enum.filter(fn {_k, v} -> v != nil && v != "" && v != [] && v != "3" end)
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
      |> Enum.join("\n")

    body = String.trim(card.description || "")

    parts = ["# #{card.title}"]
    parts = if meta_lines != "", do: parts ++ [meta_lines], else: parts
    parts = if body != "", do: parts ++ ["", body], else: parts

    Enum.join(parts, "\n") <> "\n"
  end

  @doc """
  Nome do arquivo .md para o card (usando o id).
  """
  def file_name(card) do
    "#{card.id}.md"
  end

  @doc """
  Caminho completo do .md dentro do projeto.
  """
  def file_path(project_path, card_id) do
    Path.join([project_path, "orquestrator", "#{card_id}.md"])
  end

  # Helpers

  defp extract_title([first | rest]) do
    if String.starts_with?(first, "# ") do
      {String.trim_leading(first, "# "), rest}
    else
      {nil, [first | rest]}
    end
  end

  defp extract_title([]), do: {nil, []}

  defp extract_metadata(lines) do
    {meta_lines, body_lines} = split_at_blank_line(lines)

    meta =
      meta_lines
      |> Enum.map(fn line ->
        case String.split(line, ":", parts: 2) do
          [k, v] -> {String.trim(k), String.trim(v)}
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)
      |> Map.new()

    {meta, body_lines}
  end

  defp split_at_blank_line(lines) do
    Enum.split_while(lines, fn line -> String.trim(line) != "" end)
  end

  defp parse_tags(""), do: []
  defp parse_tags(nil), do: []
  defp parse_tags(str) when is_binary(str) do
    str
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end
  defp parse_tags(list) when is_list(list), do: list

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end
  defp parse_int(n, _default) when is_integer(n), do: n
  defp parse_int(_, default), do: default
end
