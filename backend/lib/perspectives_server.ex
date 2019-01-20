defmodule PerspectivesServer do
  use GenServer

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

  def handle_call(:graph, _from, perspectives) do
    {:ok, graph} = Perspectives.graph(perspectives)
    {:reply, graph, perspectives}
  end
  def handle_call({function, args}, _from, perspectives) do
    result = apply(Perspectives, function, [perspectives | args])
    next_perspectives = case result do
      {:ok, new_perspectives} ->
        new_perspectives
      _ ->
        perspectives
    end
    {:reply, result, next_perspectives}
  end
end
