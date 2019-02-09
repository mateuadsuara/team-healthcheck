defmodule PerspectivesServer do
  use GenServer

  def serialise() do
    GenServer.call(this(), :serialise)
  end

  def deserialise(serialised_state) do
    GenServer.call(this(), {:deserialise, serialised_state})
  end

  def graph() do
    GenServer.call(this(), :graph)
  end

  @spec add_metric(Perspectives.metric_to_add()) :: {atom(), any()}
  def add_metric(metric_to_add) do
    GenServer.call(this(), {:add_metric, [metric_to_add]})
  end

  @spec register_point_of_view(Perspectives.point_of_view_to_register()) :: {atom(), any()}
  def register_point_of_view(point_of_view_to_register) do
    GenServer.call(this(), {:register_point_of_view, [point_of_view_to_register]})
  end

  defp this() do
    GenServer.whereis(__MODULE__)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :init, opts)
  end

  def init(:init) do
    {:ok, Perspectives.new()}
  end

  def handle_call(:graph, _from, current_perspectives) do
    graph = Perspectives.graph(current_perspectives)
    {:reply, graph, current_perspectives}
  end
  def handle_call(:serialise, _from, current_perspectives) do
    serialised = Perspectives.serialise(current_perspectives)
    {:reply, serialised, current_perspectives}
  end
  def handle_call({:deserialise, serialised_state}, _from, current_perspectives) do
    result = Perspectives.deserialise(serialised_state)
    next_perspectives = case result do
      {:ok, new_perspectives} ->
        new_perspectives
      _ ->
        current_perspectives
    end
    {:reply, result, next_perspectives}
  end
  def handle_call({function, args}, _from, current_perspectives) do
    result = apply(Perspectives, function, [current_perspectives | args])
    next_perspectives = case result do
      {:ok, new_perspectives} ->
        new_perspectives
      _ ->
        current_perspectives
    end
    {:reply, result, next_perspectives}
  end
end
