defmodule Potato.Smarthouse.PresenceSensor do
  alias Observables.Obs
  alias Observables.Subject
  alias Potato.Network.Observables, as: Net
  require Logger
  use Potato.DSL

  @doc """
  The presence sensor checks if someone is present in the house, using
  the data received from the key reader. It will keep count of the entrance
  and exit signals. If there are more entrances than exits, someone is home,
  if not, no one is home.
  """

  def init() do
    # Node descriptor
    nd = %{
      hardware: :presenceSensor,
      type: :presenceSensor,
      name: "presence sensor",
      uuid: Node.self(),
      sndb: create_slave_node_database(:presenceSensor)
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def actor(state) do
    receive do
      :inc ->
        actor(state + 1)
      :dec ->
        if state > 0 do
          actor(state - 1)
        else
          actor(state)
        end
      {:get, from} ->
        send(from, state)
        actor(state)
    end
  end
  
  def make_counter(new), do: spawn(fn -> actor(new) end)

  def inc(counter), do: send(counter, :inc)

  def dec(counter), do: send(counter, :dec)

  def get_value(counter) do
    send(counter, {:get, self()})
    receive do
      state ->
        state
    end
  end

  def run() do
    init()

    presenceCounter = make_counter(0)

    joins = 
      Net.network()
      |> Obs.filter(&match?({:join, _}, &1))
      |> Obs.filter(fn {:join, v} ->
        v.type == :access
      end)
      |> Obs.map(&elem(&1, 1))
      |> Obs.each(fn nd ->
        Logger.debug("Joined Key Reader: #{inspect(nd)}")
      end)

    {sink, sink_to_pass} = create_remote_variable("sink")

    prog = program [after_life: :kill, leasing_time: 1000, restart: :restart, sinks: [{sink, sink_to_pass}]] do
        Obs.range(1, :infinity)
        |> Obs.map(fn _ ->
          Potato.Smarthouse.KeyReader.read_key()
        end, true)
        |> Obs.map(fn v ->
          Subject.next(use_sink(sink_to_pass), v)
        end)
    end

    sink
    |> Obs.filter(fn {k, v} -> v == 1 end)
    |> Obs.each(fn {k, _} -> 
      IO.puts("Entered!")
      inc(presenceCounter)
      c = get_value(presenceCounter)
      if c > 0 do 
        IO.puts("People are home")
        myself().broadcast
        |> Observables.Subject.next({:presenceSensor, true})
      else
        IO.puts("No ones home")
        myself().broadcast
        |> Observables.Subject.next({:presenceSensor, false})
      end
    end)

    sink
    |> Obs.filter(fn {k, v} -> v == 2 end)
    |> Obs.each(fn {k, _} -> 
      IO.puts("Left!")
      dec(presenceCounter)
      c = get_value(presenceCounter)
      if c > 0 do 
        IO.puts("People are home")
        myself().broadcast
        |> Observables.Subject.next({:presenceSensor, true})
      else
        IO.puts("No one is home")
        myself().broadcast
        |> Observables.Subject.next({:presenceSensor, false})
      end
    end)

    send_program(prog, joins)
  end
end