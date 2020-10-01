defmodule Potato.Smarthouse.OutdoorLights do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger

  @doc """
  Outdoor lights will turn on after sunset when someone is outside the house.
  """

  def init() do
    # Node descriptor
    nd = %{
      hardware: :outdoorLights,
      type: :outdoorLights,
      name: "outdoor lights",
      uuid: ""
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def actor(day_night, motion) do
    receive do
        :night ->
            actor(false, motion)
        :day ->
            actor(true, motion)
        :motion ->
            actor(day_night, true)
        :noMotion ->
            actor(day_night, false)
        {:getDayNight, from} ->
            send(from, day_night)
            actor(day_night, motion)
        {:getMotion, from} ->
            send(from, motion)
            actor(day_night, motion)
    end
end

def make_actor(day_night, pres), do: spawn(fn -> actor(day_night, pres) end)

def setNight(ac), do: send(ac, :night)

def setDay(ac), do: send(ac, :day)

def noMotion(ac), do: send(ac, :noMotion)

def motion(ac), do: send(ac, :motion)

def get_day_night(ac) do
    send(ac, {:getDayNight, self()})
    receive do
        day_night ->
            day_night
    end
end

def get_stored_motion(ac) do
    send(ac, {:getMotion, self()})
    receive do
        motion ->
            motion
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

  motionSensorJoins =
    Net.network()
    |> Obs.filter(&match?({:join, _}, &1))
    |> Obs.filter(fn {:join, v} ->
      v.type == :motionSensor
    end)

  day_nightJoins
  |> Obs.map(fn {:join, node} ->
    IO.inspect node
    node.broadcast
    |> Obs.map(fn {_, v} ->
      if v == 2 do
        setNight(state)
        if get_stored_motion(state) do
          IO.puts("Outdoor Lights ON")
        end
      else
        setDay(state)
        IO.puts("Outdoor Lights OFF")
      end
    end)
  end)

  motionSensorJoins
  |> Obs.map(fn {:join, node} ->
    IO.inspect node
    node.broadcast
    |> Obs.map(fn {_, v} ->
      if v do
        motion(state)
        if !get_day_night(state) do
          IO.puts("Outdoor Lights ON")
        end
      else
        noMotion(state)
        IO.puts("Outdoor Lights OFF")
      end
    end)
  end)

  end
end