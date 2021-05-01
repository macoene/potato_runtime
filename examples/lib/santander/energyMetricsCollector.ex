defmodule Potato.Santander.EnergyMetricsCollector do
    alias Observables.Obs
    alias Observables.Subject
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    Energy metrics collector collects metrics on the energy
    consumption of buildings, using data from the energy sensors.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :energyMetricsCollector,
        type: :energyMetrics,
        name: "energy metrics collector",
        uuid: Node.self(),
        sndb: create_slave_node_database(:energyMetrics)
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def actor(state) do
      receive do
        {:add, amount} ->
          actor(state + amount)
        {:get, from} ->
          send(from, state)
          actor(state)
      end
    end
    
    def make_collector(), do: spawn(fn -> actor(0) end)
  
    def add(collector, amount), do: send(collector, {:add, amount})
  
    def get_value(collector) do
      send(collector, {:get, self()})
      receive do
        state ->
          state
      end
    end
  
    def run() do
      init()
  
      collector = make_collector()
  
      joins = 
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :consumptionSensor
        end)
        |> Obs.map(&elem(&1, 1))
        |> Obs.each(fn nd ->
          Logger.debug("Joined Consumption Sensor: #{inspect(nd)}")
        end)
  
      {sink, sink_to_pass} = create_remote_variable("collector sink")
  
      prog = program [after_life: :keep_alive, leasing_time: 1000] do
          Obs.range(1, :infinity)
          |> Obs.map(fn _ ->
            Potato.Santander.EnergySensor.energy_usage()
          end, true)
          |> Obs.map(fn v ->
            Subject.next(sink, v)
          end)
      end
  
      sink
      |> Obs.filter(fn {{t, _}, _} -> t == :consumptionSensor end)
      |> Obs.each(fn {_, v} -> 
        add(collector, v)
        IO.inspect(get_value(collector), label: "Total Energy Consumption")
      end)
  
      send_program(prog, joins)
    end
  end