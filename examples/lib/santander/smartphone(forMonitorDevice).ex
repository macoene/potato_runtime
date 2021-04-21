defmodule Potato.Santander.SmartphoneMD do
    alias Observables.Obs
    alias Observables.Subject
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    User smartphone that wants to access data (for example air
    pollution status or noise) from an environment monitoring 
    device.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :smartphone,
        type: :smartphoneMD,
        name: "smartphone (for monitoring device)",
        uuid: Node.self()
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run() do
      init()
  
      joins = 
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :monitorEnvironment
        end)
        |> Obs.map(&elem(&1, 1))
        |> Obs.each(fn nd ->
          Logger.debug("Joined Monitor Device: #{inspect(nd)}")
        end)

      {sink, sink_to_pass} = create_remote_variable("smartphone sink")
  
      prog = program [after_life: :kill, leasing_time: 1500, sinks: [{sink, sink_to_pass}]] do
          Obs.range(1, :infinity)
          |> Obs.map(fn _ ->
            Potato.Santander.MonitoringDevice.air_pollution()
          end, true)
          |> Obs.map(fn v ->
            Subject.next(use_sink(sink_to_pass), v)
          end)
      end
  
      sink
      |> Obs.filter(fn {{t, _}, _} -> t == :monitorEnvironment end)
      |> Obs.each(fn {_, v} -> 
        IO.inspect(v, label: "Receiven AQI value")
      end)
  
      send_program(prog, joins)
    end
  end