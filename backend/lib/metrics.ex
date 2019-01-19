defmodule Metrics do
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

  @spec new() :: {:ok, internal_state :: t()}
  def new do
    internal_state = %Metrics{
      _metrics: [],
      _names: MapSet.new()
    }
    {:ok, internal_state}
  end

  @spec graph(internal_state :: t()) :: {:ok, graph :: graph()}
  def graph(
    %Metrics{_metrics: metrics}
  ) do
    {:ok, metrics}
  end
  def graph({:ok, internal_state}), do: graph(internal_state)

  @type metric_to_add :: %{
    required(:name) => Metric.name(),
    required(:criteria) => Metric.criteria()
  }
  @spec add(internal_state :: t(), metric_to_add()) :: {:error, :existent_metric} | {:ok, internal_state :: t()}
  def add(
    %Metrics{_metrics: metrics, _names: names} = internal_state,
    %{name: name, criteria: criteria}
  ) do
    if MapSet.member?(names, name) do
      {:error, :existent_metric}
    else
      new_metric = %Metric{name: name, criteria: criteria, points_of_view: []}
      {:ok, %Metrics{internal_state |
        _metrics: [new_metric | metrics],
        _names: MapSet.put(names, name)
      }}
    end
  end
  def add({:ok, internal_state}, metric_to_add), do: add(internal_state, metric_to_add)

  @type point_of_view_to_register :: %{
    required(:metric_name) => Metric.name(),
    required(:date) => PointOfView.date(),
    required(:person) => PointOfView.person(),
    required(:health) => PointOfView.range(),
    required(:slope) => PointOfView.range()
  }
  @spec register(internal_state :: t(), point_of_view_to_register()) :: {:error, :nonexistent_metric} | {:ok, internal_state :: t()}
  def register(
    %Metrics{_metrics: metrics, _names: names} = internal_state,
    %{metric_name: metric_name, date: date, person: person, health: health, slope: slope}
  ) do
    if !MapSet.member?(names, metric_name) do
      {:error, :nonexistent_metric}
    else
      new_point_of_view = %PointOfView{date: date, person: person, health: health, slope: slope}
      {:ok, %Metrics{internal_state |
        _metrics: update_metrics(metrics, metric_name, new_point_of_view)
      }}
    end
  end
  def register({:ok, internal_state}, point_of_view_to_register), do: register(internal_state, point_of_view_to_register)
  defp update_metrics(metrics, metric_name, new_point_of_view) do
    Enum.map(metrics, fn(metric) ->
      if metric.name == metric_name do
        %{metric |
          points_of_view: [new_point_of_view | metric.points_of_view]
        }
      else
        metric
      end
    end)
  end
end
