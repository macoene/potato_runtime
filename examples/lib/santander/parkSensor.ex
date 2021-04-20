defmodule Potato.Santander.ParkSensor do
    alias Observables.Obs
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    Park sensor that can measure the soil moisture
    with underground sensors and other weather conditions
    with above ground weather stations.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :parkSensor,
        type: :soilAndWeatherSensor,
        name: "park sensor",
        uuid: Node.self(),
        sinks: new_sinks_register()
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run() do
      init()
    end
  
    def soil_moisture() do
      # From 0 (dry) to 100 very moistly
      status = Enum.random(0..100)
      IO.inspect(status, label: "Measured soil moisture")
      {{myself().type, Node.self()}, status}
    end

    def rain_status() do
        # From 0 (dry) to 5 
        status = Enum.random(0..5)
        IO.inspect(status, label: "Rain status")
        {{myself().type, Node.self()}, status}
    end
  end