defmodule Potato.Santander.FmSensor do
    alias Observables.Obs
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    Ferromagnetic wireless sensor buried underground at each parking 
    spot to feel whether or not a car is parked on it.
    """
  
    def init(id) do
      # Node descriptor
      nd = %{
        hardware: :fmSensor,
        type: :spotSensor,
        name: "ferromagnetic wireless sensor",
        uuid: id,
        sinks: new_sinks_register()
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run(id \\ 1) do
      init(id)
    end
  
    def get_status() do
      # 0 means parking spot free, 1 means its taken
      {Node.self(), Enum.random(0..1)}
    end
  end