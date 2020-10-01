defmodule Potato.Smarthouse.Thermometer do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger
  use Potato.DSL

  @doc """
  Thermometer, can be used for inside as well as outside.
  """

  def init() do
    # Node descriptor.
    nd = %{
      hardware: :thermometer,
      type: :thermometer,
      name: "Thermometer",
      uuid: ""
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  # inside parameter indicates whether its a thermometer used inside or
  # outside the house
  def run(inside) do
    init()
    spawn(fn -> publish_temperature(inside) end)
  end

  def publish_temperature(inside) do
    temp = Enum.random(0..60)
    if inside do
      myself().broadcast
      |> Observables.Subject.next({:insideTemp, temp})
      IO.puts("Inside Temperature: #{temp}")
    else
      myself().broadcast
      |> Observables.Subject.next({:outsideTemp, temp})
      IO.puts("Outside Temperature: #{temp}")
    end
    :timer.sleep(2000)
    publish_temperature(inside)
  end
end