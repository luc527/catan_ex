defmodule CatanTest do
  use ExUnit.Case
  doctest Catan

  test "greets the world" do
    assert Catan.hello() == :world
  end
end
