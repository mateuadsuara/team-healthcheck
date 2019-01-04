defmodule Metrics do
  def new() do
    []
  end

  def list(instance) do
    instance
  end

  def add(instance, name, criteria) do
    instance ++ [%{:name => name, :criteria => criteria}]
  end
end
