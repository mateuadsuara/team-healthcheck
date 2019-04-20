defmodule Perspectives do
  defmodule PointOfView do
    @enforce_keys [:date, :person, :health, :slope]
    defstruct [:date, :person, :health, :slope]

    @type signed_byte :: -127..128

    @type date :: Time.t()
    @type person :: String.t()
    @type range :: signed_byte()

    @type t :: %__MODULE__{
      date: date(),
      person: person(),
      health: range(),
      slope: range()
    }
  end

  defmodule Metric do
    @enforce_keys [:name, :criteria, :points_of_view]
    defstruct [:name, :criteria, :points_of_view]

    @type name :: String.t()
    @type criteria :: String.t()

    @type t :: %__MODULE__{
      name: name(),
      criteria: criteria(),
      points_of_view: list(PointOfView.t())
    }
  end

  @enforce_keys [:_metrics, :_names]
  defstruct [:_metrics, :_names]

  @opaque t :: %__MODULE__{
    _metrics: list(Metric.t()),
    _names: MapSet.t(Metric.name())
  }

  @type graph :: list(Metric.t())

  @type serialised_state :: graph()

  @spec new() :: {:ok, internal_state :: t()}
  def new do
    internal_state = %Perspectives{
      _metrics: [],
      _names: MapSet.new()
    }
    {:ok, internal_state}
  end

  @spec serialise(internal_state :: t() | {:ok, internal_state :: t()}) :: serialised_state()
  def serialise(internal_state), do: graph(internal_state)

  @spec deserialise(serialised_state :: serialised_state()) :: {:error, :invalid_serialised_state} | {:ok, internal_state :: t()}
  def deserialise(serialised_state) do
    try do
      metrics = serialised_state
      names = Enum.reduce(metrics, MapSet.new(), fn metric, names ->
        MapSet.put(names, metric.name)
      end)
      {:ok, %Perspectives{_metrics: metrics, _names: names}}
    rescue
      _ -> {:error, :invalid_serialised_state}
    end
  end

  @spec graph(internal_state :: t()) :: graph()
  def graph(
    %Perspectives{_metrics: metrics}
  ) do
    metrics
  end
  def graph({:ok, internal_state}), do: graph(internal_state)

  @type metric_to_add :: %{
    required(:name) => Metric.name(),
    required(:criteria) => Metric.criteria()
  }
  @spec add_metric(internal_state :: t(), metric_to_add()) :: {:error, :existent_metric} | {:ok, internal_state :: t()}
  def add_metric(
    %Perspectives{_metrics: metrics, _names: names} = internal_state,
    %{name: name, criteria: criteria}
  ) do
    if MapSet.member?(names, name) do
      {:error, :existent_metric}
    else
      new_metric = %Metric{name: name, criteria: criteria, points_of_view: []}
      {:ok, %Perspectives{internal_state |
        _metrics: [new_metric | metrics],
        _names: MapSet.put(names, name)
      }}
    end
  end
  def add_metric({:ok, internal_state}, metric_to_add), do: add_metric(internal_state, metric_to_add)

  @type point_of_view_to_register :: %{
    required(:metric_name) => Metric.name(),
    required(:date) => PointOfView.date(),
    required(:person) => PointOfView.person(),
    required(:health) => PointOfView.range(),
    required(:slope) => PointOfView.range()
  }
  @spec register_point_of_view(internal_state :: t(), point_of_view_to_register()) :: {:error, :nonexistent_metric} | {:ok, internal_state :: t()}
  def register_point_of_view(
    %Perspectives{_metrics: metrics, _names: names} = internal_state,
    %{metric_name: metric_name, date: date, person: person, health: health, slope: slope}
  ) do
    if !MapSet.member?(names, metric_name) do
      {:error, :nonexistent_metric}
    else
      new_point_of_view = %PointOfView{date: date, person: person, health: health, slope: slope}
      {:ok, %Perspectives{internal_state |
        _metrics: update_metrics(metrics, metric_name, new_point_of_view)
      }}
    end
  end
  def register_point_of_view({:ok, internal_state}, point_of_view_to_register), do: register_point_of_view(internal_state, point_of_view_to_register)
  defp update_metrics(metrics, metric_name, new_point_of_view) do
    Enum.map(metrics, fn(metric) ->
      if metric.name == metric_name do
        %{metric |
          points_of_view: update_points_of_view(metric.points_of_view, new_point_of_view)
        }
      else
        metric
      end
    end)
  end
  defp update_points_of_view(points_of_view, new_point_of_view) do
    if points_of_view |> Enum.any?(fn pov -> matches_person_and_date(pov, new_point_of_view) end) do
      Enum.map(points_of_view, fn(pov) ->
        if matches_person_and_date(pov, new_point_of_view) do
          new_point_of_view
        else
          pov
        end
      end)
    else
      [new_point_of_view | points_of_view]
    end
  end
  defp matches_person_and_date(pov, new_point_of_view) do
    pov.date == new_point_of_view.date && pov.person == new_point_of_view.person
  end
end
