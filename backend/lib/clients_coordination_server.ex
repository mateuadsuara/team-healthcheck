defmodule ClientsCoordinationServer do
  use GenServer

  def state() do
    GenServer.call(this(), :get_state)
  end

  def set_active_metric(active_metric) do
    GenServer.call(this(), {:set_active_metric, active_metric})
  end

  defp this() do
    GenServer.whereis(__MODULE__)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :init, opts)
  end

  def init(:init) do
    initial_state = %{active_metric: nil}
    {:ok, initial_state}
  end

  def handle_call(:get_state, _from, current_state) do
    {:reply, current_state, current_state}
  end

  def handle_call({:set_active_metric, active_metric}, _from, current_state) do
    next_state = current_state |> Map.put(:active_metric, active_metric)
    {:reply, nil, next_state}
  end
end
