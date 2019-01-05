defmodule Metrics do
  @opaque state :: %{
    required(:metrics) => [stored_metric],
    required(:names) => MapSet.t
  }

  @type stored_metric :: %{
    required(:name) => String.t,
    required(:criteria) => String.t,
    required(:points_of_view) => [point_of_view]
  }
  @type point_of_view :: %{
    required(:date) => date,
    required(:person) => String.t,
    required(:health) => -127..128,
    required(:slope) => -127..128
  }
  @type date :: any

  @spec new() :: {:ok, state}
  def new do
    initial_state = %{
      metrics: [],
      names: MapSet.new()
    }
    {:ok, initial_state}
  end

  @spec graph({:ok, state} | state) :: [stored_metric]
  def graph({:ok, state}), do: graph(state)
  def graph(%{metrics: metrics, names: _names}) do
    metrics
  end

  @type metric_to_add :: %{
    required(:name) => String.t,
    required(:criteria) => String.t
  }
  @spec add({:ok, state} | state, metric_to_add) :: {:error, :existent_metric} | {:ok, state}
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
