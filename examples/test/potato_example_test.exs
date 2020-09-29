defmodule PotatoExampleTest do
  use ExUnit.Case
  doctest PotatoExample

  test "greets the world" do
    assert PotatoExample.hello() == :world
  end
end
