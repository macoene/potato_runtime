defmodule Potato.Smarthouse.MotionSensor do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger
  use Potato.DSL

  @doc """
  Motion sensor, checks for motion outside of the house.
  """

  def init() do
    # Node descriptor
    nd = %{
      hardware: :motionSensor,
      type: :motionSensor,
      name: "Motion Sensor",
      uuid: ""
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def run() do
    init()
    spawn(fn -> check_motion() end)
  end

  def check_motion() do
    motion = Enum.random(1..4)
    myself().broadcast
    |> Observables.Subject.next({:motionSensor, motion})
    if motion == 1 do
      IO.puts("Motion outside!")
    else
      IO.puts("No motion detected")
    end
    :timer.sleep(1000)
    check_motion()
  end
end