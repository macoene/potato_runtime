defmodule Potato.Santander.EnergySensor do
    alias Observables.Obs
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    Energy consumption sensor measures how much energy
    is being used in a building at a certain moment.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :energySensor,
        type: :consumptionSensor,
        name: "energy consumption sensor",
        uuid: Node.self(),
        sinks: new_sinks_register()
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run() do
      init()
    end
  
    def energy_usage() do
      # From 0 to 100 kWh
      status = Enum.random(0..100)
      IO.inspect(status, label: "Energy being used")
      {{myself().type, :energy}, status}
    end
  end