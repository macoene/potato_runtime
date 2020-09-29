defmodule Potato.Deploy.Phone do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger
  use Potato.DSL

  @moduledoc """
  This example expects the phone and the temperature sensor to be running.

  Start the example with two repls as follows.

  ```
  iex --sname bob --cookie "secret" -S mix
  1> Potato.Deploy.Phone.run()
  ```
  and

  ```
  iex --sname alice --cookie "secret" -S mix
  1> Potato.Deploy.Temperature.run()
  ```

  The phone will simply deploy a program on the remote nodes that join the network.
  This program will be evaluated on that remote node. In thise case it will print the
  local name of that remote node.

  So keep an eye out on the repl of the remote node.
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

    _parts =
      Net.network()
      |> Obs.filter(&match?({:part, _}, &1))

    # Deploy a program on all the joined devices.
    joins
    |> Obs.map(fn {:join, node} ->
      node.deploy
      |> Observables.Subject.next(fn ->
        IO.puts("Ik word uitgevoerd, en ik kom van de telefoon!")

        Obs.range(1, :infinity, 2000)
        |> Obs.map(fn _ ->
          myself().broadcast
          |> Observables.Subject.next({:temperature, Enum.random(0..100)})
        end)
      end)
    end)

    joins
    |> Obs.map(fn {:join, node} ->
      # broadcast is een stream die van de remote komt
      node.broadcast
      |> Obs.map(fn v ->
        IO.puts("Remote node says: #{inspect(v)}")
      end)
    end)
  end
end
