defmodule Backend.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger

  def init(request, _state) do
    :ok = Logger.info("init")

    state = %{
      registry_key: request.path,
      peer: request.peer
    }

    {:cowboy_websocket, request, state}
  end

  def websocket_init(state) do
    :ok = Logger.info("ws init")

    {:ok, state}
  end

  def websocket_info(info, state) do
    :ok = Logger.info("ws info")

    {:reply, {:text, info}, state}
  end

  def websocket_handle({:text, json}, state) do
    data = json |> Poison.decode!(%{keys: :atoms!})
    if (data |> Map.has_key?(:ping)) do
      %{ping: id} = data
      pong_response = Poison.encode!(%{pong: id})
      {:reply, {:text, pong_response}, state}
    else
      :ok = Logger.info("ws handle #{json}")
      {:ok, state}
    end
  end
end
