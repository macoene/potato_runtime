defmodule Potato.Publish.Phone do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger

  @moduledoc """
  This example expects the phone and the temperature sensor to be running.

  Start the example with two repls as follows.

  ```
  iex --sname bob --cookie "secret" -S mix
  1> Potato.Publish.Phone.run()
  ```
  and

  ```
  iex --sname alice --cookie "secret" -S mix
  1> Potato.Publish.Temperature.run()
  ```

  The phone will listen to all the nodes that join the network.
  We assume that this is only the temperature sensor, of course.

  The temperature sensor will start emitting values on its local subject,
  which will broadcast them to the network.
  """
  def init() do
    # Our node descriptor.
    nd = %{
      hardware: :android,
      type: :phone,
      name: "phone",
      uuid: "I am unique as fuck"
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def run() do
    init()

    # Print out all the devices that join the network.
    joins =
      Net.network()
      |> Obs.filter(&match?({:join, _}, &1))

    parts =
      Net.network()
      |> Obs.filter(&match?({:part, _}, &1))

    joins
    |> Obs.map(fn {:join, node} ->
      IO.inspect node 
      node.broadcast
      |> Obs.map(fn v ->
        IO.puts("Remote node says: #{inspect(v)}")
      end)
    end)
  end
end
