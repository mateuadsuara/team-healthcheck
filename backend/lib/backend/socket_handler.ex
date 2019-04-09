defmodule Backend.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger

  def init(request, _state) do
    state = %{}
    {:cowboy_websocket, request, state}
  end

  def websocket_init(state) do
    {:ok, _} = Registry.SocketHandler
               |> Registry.register("/ws", {})

    {:ok, state}
  end

  def websocket_info({:text, json}, state) do
    {:reply, {:text, json}, state}
  end

  def websocket_handle({:text, json}, state) do
    data = json |> Poison.decode!(%{keys: :atoms!})
    if (data |> Map.has_key?(:ping)) do
      %{ping: id} = data
      pong_response = Poison.encode!(%{pong: id})
      {:reply, {:text, pong_response}, state}
    else
      {:ok, state}
    end
  end
end
