defmodule Potato.Smarthouse.DayNightSensor do
    alias Observables.Obs
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    Day and night sensor registers whether the sun is up or not.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :dayNightSensor,
        type: :dayNightSensor,
        name: "Day and Night Sensor",
        uuid: ""
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run() do
      init()
      spawn(fn -> day_night_check() end)
    end
  
    def day_night_check() do
      dayNight = Enum.random(1..2)
      myself().broadcast
      |> Observables.Subject.next({:dayNightSensor, dayNight})
      if dayNight == 1 do
        IO.puts("Day!")
      else
        IO.puts("Night!")
      end
      :timer.sleep(7777)
      day_night_check()
    end
  end