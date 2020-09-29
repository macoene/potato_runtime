defmodule Potato.Publish.Temperature do
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
    spawn(fn -> publish_temperature() end)
  end

  def publish_temperature() do
    myself().broadcast
    |> Observables.Subject.next({:temperature, Enum.random(0..100)})

    :timer.sleep(2000)
    publish_temperature()
  end
end
