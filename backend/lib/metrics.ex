defmodule Metrics do
  @type state() :: %{merics: any(), names: any()}

  @spec new() :: {:ok, state()}
  def new do
    initial_state = %{
      :metrics => [],
      :names => MapSet.new()
    }
    {:ok, initial_state}
  end

  def graph({:ok, state}), do: graph(state)
  def graph(%{metrics: metrics}) do
    metrics
  end

  def add({:ok, state}, metric), do: add(state, metric)
  def add(
    %{metrics: metrics, names: names} = state,
    %{name: name, criteria: _criteria} = metric
  ) do
    if MapSet.member?(names, name) do
      {:error, :existent_metric}
    else
      new_metric = Map.put(metric, :points_of_view, [])
      {:ok, %{state |
        metrics: [new_metric | metrics],
        names: MapSet.put(names, name)
      }}
    end
  end

  def register({:ok, state}, metric_name, point_of_view), do: register(state, metric_name, point_of_view)
  def register(
    %{metrics: metrics, names: names} = state,
    metric_name,
    %{date: _date, person: _person, health: _health, slope: _slope} = point_of_view
  ) do
    if !MapSet.member?(names, metric_name) do
      {:error, :nonexistent_metric}
    else
      {:ok, %{state |
        metrics: update_metrics(metrics, metric_name, point_of_view)
      }}
    end
  end
  defp update_metrics(metrics, metric_name, point_of_view) do
    Enum.map(metrics, fn(metric) ->
      if metric.name == metric_name do
        %{metric |
          points_of_view: [point_of_view | metric.points_of_view]
        }
      else
        metric
      end
    end)
  end
end
