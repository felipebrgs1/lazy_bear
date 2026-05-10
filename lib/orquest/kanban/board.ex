defmodule Orquest.Kanban.Board do
  @moduledoc """
  Estrutura e operações do Board Kanban.
  Cards podem ser carregados de arquivos .md nos projetos ou gerenciados em memória.
  """
  alias Orquest.Kanban.{Column, Card, CardParser}

  defstruct [:id, :name, :columns]

  def new do
    %__MODULE__{
      id: Uniq.UUID.uuid4(),
      name: "Orquest Board",
      columns: [
        Column.new("backlog", "Backlog", "#6b7280"),
        Column.new("todo", "To Do", "#3b82f6"),
        Column.new("in_progress", "In Progress", "#8b5cf6"),
        Column.new("review", "Review", "#ec4899"),
        Column.new("done", "Done", "#10b981")
      ]
    }
  end

  @doc """
  Carrega cards dos projetos a partir dos arquivos .md em `{project}/orquestrator/`.
  Retorna um board atualizado com os cards lidos.
  Projetos que não existem no disco são ignorados.
  """
  def load_cards(board, projects) do
    new_cards =
      projects
      |> Enum.flat_map(fn project ->
        orquestrator_dir = Path.join(project.path, "orquestrator")

        if File.dir?(orquestrator_dir) do
          orquestrator_dir
          |> File.ls!()
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.map(fn filename ->
            file_path = Path.join(orquestrator_dir, filename)
            CardParser.parse(file_path, project.path)
          end)
        else
          []
        end
      end)

    # Remove cards whose project no longer exists
    active_projects = MapSet.new(projects, & &1.path)
    board =
      Enum.reduce(board.columns, board, fn col, acc ->
        Enum.reduce(col.cards, acc, fn card, inner_acc ->
          if card.project_path && !MapSet.member?(active_projects, card.project_path) do
            remove_card(inner_acc, card.id)
          else
            inner_acc
          end
        end)
      end)

    # Place cards from .md into appropriate columns
    Enum.reduce(new_cards, board, fn card, acc ->
      col_id = if card.status && card.status != "", do: card.status, else: "backlog"
      col_exists? = Enum.any?(acc.columns, &(&1.id == col_id))
      target_col = if col_exists?, do: col_id, else: "backlog"
      add_card_to_board(acc, target_col, card)
    end)
  end

  def add_card(board, column_id, attrs) do
    card = Card.new(attrs)
    write_card_file(card, column_id)
    add_card_to_board(board, column_id, card)
  end

  def move_card(board, card_id, to_column_id, position) do
    case find_card_with_column(board, card_id) do
      {card, from_col} ->
        board = remove_card_from_column(board, from_col.id, card_id)
        board = add_card_to_column(board, to_column_id, card, position)
        write_card_file(card, to_column_id)
        board

      nil ->
        board
    end
  end

  def update_card(board, card_id, attrs) do
    update_in(board.columns, fn columns ->
      Enum.map(columns, fn col ->
        %{col | cards: Enum.map(col.cards, fn c ->
          if c.id == card_id do
            updated = Card.update(c, attrs)
            write_card_file(updated, col.id)
            updated
          else
            c
          end
        end)}
      end)
    end)
  end

  def remove_card(board, card_id) do
    {card, _col} = find_card_with_column(board, card_id)

    if card do
      delete_card_file(card)
    end

    update_in(board.columns, fn columns ->
      Enum.map(columns, fn col ->
        %{col | cards: Enum.reject(col.cards, &(&1.id == card_id))}
      end)
    end)
  end

  def find_card(board, card_id) do
    board.columns
    |> Enum.flat_map(& &1.cards)
    |> Enum.find(&(&1.id == card_id))
  end

  def find_card_with_column(board, card_id) do
    board.columns
    |> Enum.flat_map(fn col -> Enum.map(col.cards, &{&1, col}) end)
    |> Enum.find(fn {card, _col} -> card.id == card_id end)
  end

  # Persistence helpers — escreve/deleta .md files no projeto

  defp write_card_file(card, column_id) do
    if card.project_path && File.dir?(card.project_path) do
      orquestrator_dir = Path.join(card.project_path, "orquestrator")
      File.mkdir_p!(orquestrator_dir)
      md = CardParser.serialize(%{card | status: column_id})
      path = CardParser.file_path(card.project_path, card.id)
      File.write!(path, md)
    end
  end

  defp delete_card_file(card) do
    if card.project_path do
      path = CardParser.file_path(card.project_path, card.id)
      File.rm(path)
    end
  end

  # Board manipulation helpers

  defp add_card_to_board(board, column_id, card) do
    update_column(board, column_id, fn col ->
      %{col | cards: col.cards ++ [card]}
    end)
  end

  defp remove_card_from_column(board, column_id, card_id) do
    update_column(board, column_id, fn col ->
      %{col | cards: Enum.reject(col.cards, &(&1.id == card_id))}
    end)
  end

  defp add_card_to_column(board, column_id, card, position) do
    update_column(board, column_id, fn col ->
      cards = case position do
        :start -> [card | col.cards]
        :end -> col.cards ++ [card]
        idx when is_integer(idx) -> List.insert_at(col.cards, idx, card)
        _ -> col.cards ++ [card]
      end
      %{col | cards: cards}
    end)
  end

  defp update_column(board, column_id, fun) do
    update_in(board.columns, fn columns ->
      Enum.map(columns, fn col ->
        if col.id == column_id, do: fun.(col), else: col
      end)
    end)
  end
end
