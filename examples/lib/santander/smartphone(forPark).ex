defmodule Potato.Santander.SmartphoneP do
    alias Observables.Obs
    alias Observables.Subject
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    User smartphone that wants to access data (for example soil
    moisture and weather conditions) from a park sensor.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :smartphone,
        type: :smartphoneP,
        name: "smartphone (for park sensors)",
        uuid: Node.self(),
        sndb: create_slave_node_database(:smartphoneP)
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    # Restart number is just a work around to test the 
    # "restart and new" policy on the same local device
    def run(restart_number) do
      init()
  
      joins = 
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :soilAndWeatherSensor
        end)
        |> Obs.map(&elem(&1, 1))
        |> Obs.each(fn nd ->
          Logger.debug("Joined Park Sensor: #{inspect(nd)}")
        end)

      {sink, sink_to_pass} = create_remote_variable("smartphone sink")
  
      prog2 = program [after_life: :kill, leasing_time: 1000, restart: :restart_and_new, sinks: [{sink, sink_to_pass}]] do
          Obs.range(1, :infinity)
          |> Obs.map(fn _ ->
            Potato.Santander.ParkSensor.soil_moisture()
          end, true)
          |> Obs.map(fn v ->
            Subject.next(use_sink(sink_to_pass), v)
          end)
      end

      prog = program [after_life: :kill, leasing_time: 1000, restart: :restart_and_new, sinks: [{sink, sink_to_pass}]] do
        Obs.range(1, :infinity)
        |> Obs.map(fn _ ->
          Potato.Santander.ParkSensor.rain_status()
        end, true)
        |> Obs.map(fn v ->
          Subject.next(use_sink(sink_to_pass), v)
        end)
      end
  
      sink
      |> Obs.filter(fn {{t, k}, _} -> 
        (t == :soilAndWeatherSensor) and (k == :soil)
      end)
      |> Obs.each(fn {_, v} -> 
        IO.inspect(v, label: "Receiven Soil moisture")
      end)

      sink
      |> Obs.filter(fn {{t, k}, _} -> 
        (t == :soilAndWeatherSensor) and (k == :rain)
      end)
      |> Obs.each(fn {_, v} -> 
        IO.inspect(v, label: "Receiven Rain status")
      end)
  
      if restart_number == 1 do
        send_program(prog, joins)
      else
        send_program(prog2, joins)
      end
    end
  end