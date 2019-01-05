defmodule MetricsTest do
  use ExUnit.Case
  import Metrics

  test "starts with no metrics" do
    assert new() |> graph == []
  end

  test "adds a metric" do
    name = '::name::'
    criteria = '::criteria::'

    metrics = new()
              |> add(name, criteria)

    assert metrics |> graph == [
      %{
        name: name,
        criteria: criteria,
        points_of_view: []
      }
    ]
  end

  test "cannot add two metrics with the same name" do
    metrics = new()
              |> add('::name1::', '::criteria1::')


    assert metrics |> add('::name1::', '::criteria2::') ==
      {:error, :existent_metric}
  end

  test "adds two metrics" do
    name1 = '::name1::'
    criteria1 = '::criteria1::'
    name2 = '::name2::'
    criteria2 = '::criteria2::'

    metrics = new()
              |> add(name1, criteria1)
              |> add(name2, criteria2)

    assert metrics |> graph == [
      %{
        name: name2,
        criteria: criteria2,
        points_of_view: []
      },
      %{
        name: name1,
        criteria: criteria1,
        points_of_view: []
      }
    ]
  end

  test "registers a point of view" do
    name = '::name::'
    criteria = '::criteria::'
    date = Time.utc_now
    person = '::person::'
    health = 1
    slope = 0

    metrics = new()
              |> add(name, criteria)
              |> register(name, date, person, health, slope)

    assert metrics |> graph == [
      %{
        name: name,
        criteria: criteria,
        points_of_view: [
          %{
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
          |> register('::name::', Time.utc_now, '::person::', 1, 0)

    assert res ==
      {:error, :nonexistent_metric}
  end

  test "registers two points of view" do
    name = '::name::'
    criteria = '::criteria::'
    date1 = Time.utc_now
    person1 = '::person1::'
    health1 = 1
    slope1 = 0
    date2 = Time.utc_now
    person2 = '::person2::'
    health2 = -1
    slope2 = 1

    metrics = new()
              |> add(name, criteria)
              |> register(name, date1, person1, health1, slope1)
              |> register(name, date2, person2, health2, slope2)

    assert metrics |> graph == [
      %{
        name: name,
        criteria: criteria,
        points_of_view: [
          %{
            date: date2,
            person: person2,
            health: health2,
            slope: slope2
          },
          %{
            date: date1,
            person: person1,
            health: health1,
            slope: slope1
          }
        ]
      }
    ]
  end
end
