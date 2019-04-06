defmodule Backend.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger

  def init(request, _state) do
    :ok = Logger.info("ws init")

    state = %{registry_key: request.path}

    {:cowboy_websocket, request, state}
  end

  def websocket_handle({:text, "ping"}, state) do
    {:ok, state}
  end

  def websocket_handle({:text, json}, state) do
    :ok = Logger.info("ws handle #{json}")

    {:reply, {:text, json}, state}
  end

  def websocket_info(info, state) do
    :ok = Logger.info("ws info")

    {:reply, {:text, info}, state}
  end
end
