defmodule Potato.P2P.Phone do
  alias Observables.Obs
  alias Observables.Subject
  alias Potato.Network.Observables, as: Net
  require Logger

  @moduledoc """
  This example expects the phone and the temperature sensor to be running.

  Start the example with two repls as follows.

  ```
  iex --sname bob --cookie "secret" -S mix
  1> Potato.P2P.Phone.run()
  ```
  and

  ```
  iex --sname alice --cookie "secret" -S mix
  1> Potato.P2P.Temperature.run()
  ```

  The phone will setup a subject locally to which the remote nodes are supposed to push their data.
  The phone subscribes to this subject locally, so we have many nodes pushing data to this single channel.

  This is more efficient at times than publishing everything on the entire network.

  On the temperature sensors a program is deployed by the phone that will make them read out their
  sensor and then emit that value on the phone's subject.

  Note here that the deployed program captures the sink varaible in its scope before being shipped.
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

    # Create an observable that emits all the nodes we wich to target.
    # I.e., all of them that join.
    joins =
      Net.network()
      |> Obs.filter(&match?({:join, _}, &1))
      |> Obs.map(&elem(&1, 1))
      |> Obs.each(fn nd ->
        Logger.debug("Join: #{inspect(nd)}")
      end)

    parts =
      Net.network()
      |> Obs.filter(&match?({:part, _}, &1))
      |> Obs.map(&elem(&1, 1))
      |> Obs.each(fn nd ->
        Logger.debug("Part: #{inspect(nd)}")
      end)

    # On each of these devices we deploy a program that will 
    # create a specific observable. This will then be broadcast to the network, where
    # we intercept it. 
    # This will then result in peer2peer communication.

    # Create a designated communication channel.
    sink = Observables.Subject.create()

    prog = fn ->
      Obs.range(1, :infinity)
      |> Obs.map(fn _ ->
        Potato.P2P.Temperature.read_temperature()
      end)
      |> Obs.map(fn v ->
        Subject.next(sink, v)
      end)
    end

    # Setup the handler for all values that will flow into this sink.
    sink
    |> Obs.map(fn {from, v} ->
      IO.puts("Remote node #{inspect(from)} says #{inspect(v)}")
    end)

    joins
    |> Obs.each(fn nd ->
      nd.deploy
      |> Subject.next(prog)
    end)
  end
end
