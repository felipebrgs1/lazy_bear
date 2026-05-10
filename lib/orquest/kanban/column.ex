defmodule Orquest.Kanban.Column do
  @moduledoc """
  Coluna do Kanban.
  """
  defstruct [:id, :name, :color, :cards]

  def new(id, name, color) do
    %__MODULE__{
      id: id,
      name: name,
      color: color,
      cards: []
    }
  end
end
