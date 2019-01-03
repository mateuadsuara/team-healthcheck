defmodule Backend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    port = 9292

    # List all child processes to be supervised
    children = [
      # Starts a server by calling: Backend.Router.start_link(...)
      {Plug.Cowboy, scheme: :http, plug: Backend.Router, options: [port: port]},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Backend.Supervisor]

    Logger.info("Server listening on port #{port}")

    Supervisor.start_link(children, opts)
  end
end
