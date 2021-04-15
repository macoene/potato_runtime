defmodule Potato.Santander.FmSensor do
    alias Observables.Obs
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    Ferromagnetic wireless sensor buried underground at each parking 
    spot to feel whether or not a car is parked on it.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :fmSensor,
        type: :spotSensor,
        name: "ferromagnetic wireless sensor",
        uuid: Node.self(),
        sinks: new_sinks_register()
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run() do
      init()
    end
  
    def get_status() do
      # 0 means parking spot free, 1 means its taken
      status = Enum.random(0..1)
      IO.puts(status)
      {{myself().type, Node.self()}, status}
    end
  end