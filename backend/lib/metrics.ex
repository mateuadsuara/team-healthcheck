defmodule Metrics do
  def new do
    initial_state = %{
      :metrics => [],
      :names => MapSet.new()
    }
    {:ok, initial_state}
  end

  def graph({:ok, %{metrics: metrics}}) do
    metrics
  end

  def add({:ok, %{metrics: metrics, names: names} = state}, name, criteria) do
    if MapSet.member?(names, name) do
      {:error, :existent_metric}
    else
      new_metric = %{
        name: name,
        criteria: criteria,
        points_of_view: []
      }
      {:ok, %{state |
        metrics: [new_metric | metrics],
        names: MapSet.put(names, name)
      }}
    end
  end

  def register({:ok, %{metrics: metrics, names: names} = state}, name, date, person, health, slope) do
    if !MapSet.member?(names, name) do
      {:error, :nonexistent_metric}
    else
      updated_metrics = Enum.map(metrics, fn(metric) ->
        if metric.name == name do
          new_pov = %{
            date: date,
            person: person,
            health: health,
            slope: slope
          }
          %{metric |
            points_of_view: [new_pov | metric.points_of_view]
          }
        else
          metric
        end
      end)
      {:ok, %{state |
        metrics: updated_metrics
      }}
    end
  end
end
