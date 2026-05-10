defmodule Orquest.Kanban.Board do
  @moduledoc """
  Estrutura e operações do Board Kanban.
  """
  alias Orquest.Kanban.{Column, Card}

  defstruct [:id, :name, :columns]

  def new do
    %__MODULE__{
      id: Uniq.UUID.uuid4(),
      name: "Orquest Board",
      columns: [
        Column.new("backlog", "Backlog", "#6b7280"),
        Column.new("todo", "To Do", "#3b82f6"),
        Column.new("borrowed", "Borrowed", "#f59e0b"),
        Column.new("in_progress", "In Progress", "#8b5cf6"),
        Column.new("review", "Review", "#ec4899"),
        Column.new("done", "Done", "#10b981")
      ]
    }
  end

  def add_card(board, column_id, attrs) do
    card = Card.new(attrs)
    update_column(board, column_id, fn col ->
      %{col | cards: col.cards ++ [card]}
    end)
  end

  def move_card(board, card_id, to_column_id, position) do
    case find_card_with_column(board, card_id) do
      {card, from_col} ->
        board = remove_card_from_column(board, from_col.id, card_id)
        add_card_to_column(board, to_column_id, card, position)

      nil ->
        board
    end
  end

  def update_card(board, card_id, attrs) do
    update_in(board.columns, fn columns ->
      Enum.map(columns, fn col ->
        %{col | cards: Enum.map(col.cards, fn c ->
          if c.id == card_id, do: Card.update(c, attrs), else: c
        end)}
      end)
    end)
  end

  def remove_card(board, card_id) do
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
