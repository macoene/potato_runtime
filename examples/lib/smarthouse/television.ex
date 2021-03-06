defmodule Potato.Smarthouse.Television do
    alias Observables.Obs
    alias Observables.Subject
    alias Potato.Network.Observables, as: Net
    require Logger
  
    @doc """
    The television has to be on between 18h and midnight, but only when 
    someone is home.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :television,
        type: :output,
        name: "television",
        uuid: ""
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end

    def actor(time, pres) do
        receive do
            :outOfTimeWindow ->
                actor(false, pres)
            :inTimeWindow ->
                actor(true, pres)
            :presence ->
                actor(time, true)
            :noPresence ->
                actor(time, false)
            {:getTime, from} ->
                send(from, time)
                actor(time, pres)
            {:getPres, from} ->
                send(from, pres)
                actor(time, pres)
        end
    end

    def make_actor(time, pres), do: spawn(fn -> actor(time, pres) end)

    def outOfTimeWindow(ac), do: send(ac, :outOfTimeWIndow)

    def inTimeWindow(ac), do: send(ac, :inTimeWIndow)

    def noPresence(ac), do: send(ac, :noPresence)

    def presence(ac), do: send(ac, :presence)

    def get_stored_time(ac) do
        send(ac, {:getTime, self()})
        receive do
            time ->
                time
        end
    end

    def get_stored_presence(ac) do
        send(ac, {:getPres, self()})
        receive do
            pres ->
                pres
        end
    end

    def run() do
      init()

      state = make_actor(false, false)

      clockJoins =
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :clock
        end)

      presenceSensorJoins =
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :presenceSensor
        end)

      clockJoins
      |> Obs.map(fn {:join, node} ->
        IO.inspect node
        node.broadcast
        |> Obs.map(fn {_, v} ->
          if v >= 18 do
            inTimeWindow(state)
            if get_stored_presence(state) do
              IO.puts("TV On")
            end
          else
            outOfTimeWindow(state)
            IO.puts("TV Off")
          end
        end)
      end)

      presenceSensorJoins
      |> Obs.map(fn {:join, node} ->
        IO.inspect node
        node.broadcast
        |> Obs.map(fn {_, v} ->
          if v do
            presence(state)
            if get_stored_time(state) do
              IO.puts("TV On")
            end
          else
            noPresence(state)
            IO.puts("TV Off")
          end
        end)
      end)

    end
end



