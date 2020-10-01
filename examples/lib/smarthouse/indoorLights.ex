defmodule Potato.Smarthouse.IndoorLights do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger

  @doc """
  Indoor lights will turn on after sunset when someone is home.
  """

  def init() do
    # Node descriptor
    nd = %{
      hardware: :indoorLights,
      type: :indoorLights,
      name: "indoor lights",
      uuid: ""
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def actor(day_night, pres) do
    receive do
        :night ->
            actor(false, pres)
        :day ->
            actor(true, pres)
        :presence ->
            actor(day_night, true)
        :noPresence ->
            actor(day_night, false)
        {:getDayNight, from} ->
            send(from, day_night)
            actor(day_night, pres)
        {:getPres, from} ->
            send(from, pres)
            actor(day_night, pres)
    end
end

def make_actor(day_night, pres), do: spawn(fn -> actor(day_night, pres) end)

def setNight(ac), do: send(ac, :night)

def setDay(ac), do: send(ac, :day)

def noPresence(ac), do: send(ac, :noPresence)

def presence(ac), do: send(ac, :presence)

def get_day_night(ac) do
    send(ac, {:getDayNight, self()})
    receive do
        day_night ->
            day_night
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

  day_nightJoins =
    Net.network()
    |> Obs.filter(&match?({:join, _}, &1))
    |> Obs.filter(fn {:join, v} ->
      v.type == :dayNightSensor
    end)

  presenceSensorJoins =
    Net.network()
    |> Obs.filter(&match?({:join, _}, &1))
    |> Obs.filter(fn {:join, v} ->
      v.type == :presenceSensor
    end)

  day_nightJoins
  |> Obs.map(fn {:join, node} ->
    IO.inspect node
    node.broadcast
    |> Obs.map(fn {_, v} ->
      if v == 2 do
        night(state)
        if get_stored_presence(state) do
          IO.puts("Indoor Lights ON")
        end
      else
        day(state)
        IO.puts("Indoor Lights OFF")
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
        if !get_day_night(state) do
          IO.puts("Indoor Lights ON")
        end
      else
        noPresence(state)
        IO.puts("Indoor Lights OFF")
      end
    end)
  end)

  end
end