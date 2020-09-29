defmodule Potato.Smarthouse.Television do
    alias Observables.Obs
    alias Observables.Subject
    alias Potato.Network.Observables, as: Net
    require Logger
  
    @doc """
    The television has to be on between 19h and midnight, but only when 
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
        |> Obs.map(&elem(&1, 1))
        |> Obs.each(fn nd ->
          Logger.debug("Joined Clock: #{inspect(nd)}")
        end)

      presenceSensorJoins =
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :presenceSensor
        end)
        |> Obs.map(&elem(&1, 1))
        |> Obs.each(fn nd ->
          Logger.debug("Joined Presence Sensor: #{inspect(nd)}")
        end)

      clockJoins
      |> Obs.map(fn {:join, node} ->
        IO.inspect node
        node.broadcast
        |> Obs.each(fn v ->

          IO.puts(v)

          if v >= 190000 do
            inTimeWindow(state)
            if get_stored_presence(state) do
              IO.puts("TV On")
            end
          else
            outOfTimeWindow(state)
          end
        end)
      end)

      presenceSensorJoins
      |> Obs.map(fn {:join, node} ->
        IO.inspect node
        node.broadcast
        |> Obs.each(fn v ->
          if v == 1 do
            presence(state)
            if get_stored_time(state) do
              IO.puts("TV On")
            end
          else
            noPresence(state)
          end
        end)
      end)

    end
end



