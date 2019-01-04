defmodule MetricsTest do
  use ExUnit.Case
  doctest Metrics

  test "starts with no metrics" do
    list = Metrics.new()
           |> Metrics.list
    assert list == []
  end

  test "adds a metric" do
    name = '::name::'
    criteria = '::criteria::'
    list = Metrics.new()
           |> Metrics.add(name, criteria)
           |> Metrics.list
    assert list == [%{:name => name, :criteria => criteria}]
  end
end
