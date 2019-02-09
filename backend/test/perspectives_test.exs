defmodule PerspectivesTest do
  use ExUnit.Case
  import Perspectives
  alias Perspectives.Metric
  alias Perspectives.PointOfView

  test "starts with no metrics" do
    g = new()
        |> graph()

    assert g == []
  end

  test "adds a metric" do
    name = '::name::'
    criteria = '::criteria::'

    g = new()
        |> add_metric(%{name: name, criteria: criteria})
        |> graph()

    assert g == [
      %Metric{
        name: name,
        criteria: criteria,
        points_of_view: []
      }
    ]
  end

  test "cannot add two metrics with the same name" do
    res = new()
          |> add_metric(%{name: '::name1::', criteria: '::criteria1::'})
          |> add_metric(%{name: '::name1::', criteria: '::criteria2::'})

    assert res == {:error, :existent_metric}
  end

  test "adds two metrics" do
    name1 = '::name1::'
    criteria1 = '::criteria1::'
    name2 = '::name2::'
    criteria2 = '::criteria2::'

    g = new()
        |> add_metric(%{name: name1, criteria: criteria1})
        |> add_metric(%{name: name2, criteria: criteria2})
        |> graph()

    assert g == [
      %Metric{
        name: name2,
        criteria: criteria2,
        points_of_view: []
      },
      %Metric{
        name: name1,
        criteria: criteria1,
        points_of_view: []
      }
    ]
  end

  test "registers a point of view" do
    name = '::name::'
    criteria = '::criteria::'
    date = Time.utc_now()
    person = '::person::'
    health = 1
    slope = 0

    g = new()
        |> add_metric(%{name: name, criteria: criteria})
        |> register_point_of_view(%{metric_name: name, date: date, person: person, health: health, slope: slope})
        |> graph()

    assert g == [
      %Metric{
        name: name,
        criteria: criteria,
        points_of_view: [
          %PointOfView{
            date: date,
            person: person,
            health: health,
            slope: slope
          }
        ]
      }
    ]
  end

  test "cannot register a point of view for an unexisting metric name" do
    res = new()
          |> register_point_of_view(%{metric_name: '::name::', date: Time.utc_now, person: '::person::', health: 1, slope: 0})

    assert res == {:error, :nonexistent_metric}
  end

  test "registers two points of view" do
    name = '::name::'
    criteria = '::criteria::'
    date1 = Time.utc_now()
    person1 = '::person1::'
    health1 = 1
    slope1 = 0
    date2 = Time.utc_now()
    person2 = '::person2::'
    health2 = -1
    slope2 = 1

    g = new()
        |> add_metric(%{name: name, criteria: criteria})
        |> register_point_of_view(%{metric_name: name, date: date1, person: person1, health: health1, slope: slope1})
        |> register_point_of_view(%{metric_name: name, date: date2, person: person2, health: health2, slope: slope2})
        |> graph()

    assert g == [
      %Metric{
        name: name,
        criteria: criteria,
        points_of_view: [
          %PointOfView{
            date: date2,
            person: person2,
            health: health2,
            slope: slope2
          },
          %PointOfView{
            date: date1,
            person: person1,
            health: health1,
            slope: slope1
          }
        ]
      }
    ]
  end

  test "can be serialised and deserialised" do
    name = '::name::'
    date = Time.utc_now()
    person = '::person1::'
    health = 1
    slope = 0

    perspectives_a = new()
                     |> add_metric(%{name: name, criteria: '::criteria::'})

    {:ok, perspectives_b} = perspectives_a
                            |> serialise()
                            |> deserialise()

    graph_a = perspectives_a
               |> register_point_of_view(%{metric_name: name, date: date, person: person, health: health, slope: slope})
               |> graph()

    graph_b = perspectives_b
               |> register_point_of_view(%{metric_name: name, date: date, person: person, health: health, slope: slope})
               |> graph()

    assert graph_a == graph_b
  end

  test "fails to deserialise invalid state" do
    invalid_state = "::invalid serialised state::"

    res = invalid_state
          |> deserialise()

    assert res == {:error, :invalid_serialised_state}
  end
end
