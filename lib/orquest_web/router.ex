defmodule OrquestWeb.Router do
  use OrquestWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OrquestWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OrquestWeb do
    pipe_through :browser

    live "/", KanbanLive
    live "/kanban", KanbanLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", OrquestWeb do
  #   pipe_through :api
  # end
end
