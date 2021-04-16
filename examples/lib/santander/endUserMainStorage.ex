defmodule Potato.Santander.EndUserMainStorage do
    alias Observables.Obs
    alias Observables.Subject
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    End-user application through which users can query data from
    the main storage, for example the current available parking
    spots or the average available spots.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :endUserMainStorage,
        type: :endUserMainStorage,
        name: "end user application for the main storage",
        uuid: Node.self()
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run() do
      init()
  
      connected_before = create_slave_node_database()
  
      joins = 
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :mainStorage
        end)
        |> Obs.map(&elem(&1, 1))
        |> Obs.each(fn nd ->
          Logger.debug("Joined Main Storage: #{inspect(nd)}")
        end)
  
      {sink, sink_to_pass} = create_remote_variable("enduserapp sink")
  
      prog = program [after_life: :kill, leasing_time: 1000, restart: :restart, sinks: [{sink, sink_to_pass}]] do
          sensorStorage = Potato.Santander.MainStorage.run()
          Potato.Santander.MainStorage.trackAvgAvailable(5000, sink_to_pass, sensorStorage)
      end
  
      sink
      |> Obs.filter(fn {k, _} -> 
        k == :avg
      end)
      |> Obs.each(fn {_, v} -> 
        IO.puts(v)
      end)
  
      send_program(prog, joins, connected_before)
    end
  end