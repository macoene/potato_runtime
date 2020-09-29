defmodule Potato.P2P.Temperature do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger
  use Potato.DSL

  def init() do
    # Our node descriptor.
    nd = %{
      hardware: :temperature,
      type: :sensor,
      name: "temperature sensor",
      signals: [],
      uuid: "I am unique as fuck as well"
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def run() do
    init()
  end

  def read_temperature() do
    {Node.self(), Enum.random(0..100)}
  end
end
