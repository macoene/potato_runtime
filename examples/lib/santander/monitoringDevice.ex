defmodule Potato.Santander.MonitoringDevice do
    alias Observables.Obs
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    Monitoring device, attached to lamp posts, that contains
    air pollution and noise sensors.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :monitoringDevice,
        type: :monitorEnvironment,
        name: "environment monitoring device",
        uuid: Node.self(),
        sinks: new_sinks_register()
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run() do
      init()
    end
  
    def air_pollution() do
      # From 0 (low) to 500 (hazardous), following the official
      # Air Quality Index (airnow.gov)
      status = Enum.random(0..500)
      IO.inspect(status, label: "Air pollution")
      {{myself().type, Node.self()}, status}
    end

    def noise() do
        # Noise in decibels
        status = Enum.random(20..150)
        IO.inspect(status, label: "Noise")
        {{myself().type, Node.self()}, status}
      end
  end