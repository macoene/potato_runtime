defmodule Potato.Smarthouse.Clock do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger
  use Potato.DSL

  @doc """
  Main clock for the whole house.
  The time for this clock can get changed manually, which will change
  the time for all devices in the house, i.e. no device can ever just
  "assume" the correct time by looking at a previous time-request.
  """

  def init() do
    # Node descriptor
    nd = %{
      hardware: :clock,
      type: :sensor,
      name: "main clock",
      uuid: ""
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def run() do
    init()
    spawn(fn -> read_time() end)
  end

  def read_time() do
    myself().broadcast
    |> Observables.Subject.next({:clock, 1})

    :timer.sleep(15000)
    read_time()
  end
end
