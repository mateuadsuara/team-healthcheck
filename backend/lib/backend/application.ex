defmodule Backend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    port = 9292
    default_options = [
      port: port,
      dispatch: [
        {:_,
          [
            {"/ws", Backend.SocketHandler, []},
            {:_, Plug.Cowboy.Handler, {Backend.Router, []}}
          ]
        }
      ]
    ]

    cert_dir = System.get_env("CERT_DIR")
    scheme = if cert_dir do
      :https
    else
      :http
    end
    options = if cert_dir do
      default_options ++ [
        keyfile: "#{cert_dir}/key.pem",
        certfile: "#{cert_dir}/cert.pem",
      ]
    else
      default_options
    end

    # List all child processes to be supervised
    children = [
      # Starts a server by calling: Backend.Router.start_link(...)
      {Plug.Cowboy, scheme: scheme, plug: Backend.Router, options: options},
      {PerspectivesServer, name: PerspectivesServer},
      {ClientsCoordinationServer, name: ClientsCoordinationServer},
      Registry.child_spec(keys: :duplicate, name: Registry.SocketHandler)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Backend.Supervisor]

    :ok = Logger.info("Server listening on port #{port}")

    Supervisor.start_link(children, opts)
  end
end
