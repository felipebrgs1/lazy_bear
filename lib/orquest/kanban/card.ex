defmodule Orquest.Kanban.Card do
  @moduledoc """
  Card do Kanban representa uma unidade de trabalho (issue/task).
  """
  defstruct [
    :id,
    :title,
    :description,
    :priority,
    :project_path,
    :workspace_path,
    :borrowed_by,
    :agent_status,
    :tmux_session,
    :tags,
    :output_log,
    :created_at,
    :updated_at
  ]

  def new(attrs) do
    now = DateTime.utc_now()
    %__MODULE__{
      id: Uniq.UUID.uuid4(),
      title: attrs[:title] || "Untitled",
      description: attrs[:description] || "",
      priority: attrs[:priority] || 3,
      project_path: attrs[:project_path],
      workspace_path: attrs[:workspace_path],
      borrowed_by: nil,
      agent_status: "idle",
      tags: attrs[:tags] || [],
      created_at: now,
      updated_at: now
    }
  end

  def update(card, attrs) do
    now = DateTime.utc_now()
    struct!(card, Map.put(attrs, :updated_at, now))
  end
end
