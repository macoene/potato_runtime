defmodule Potato.Smarthouse.Windows do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger

  @doc """
  The windows of the house will open when it is inside lower than 24C while
  it is warmer outside or when it is inside 24C or more and colder outside.
  """

  def init() do
    # Node descriptor
    nd = %{
      hardware: :windows,
      type: :windows,
      name: "windows",
      uuid: ""
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def actor(inTemp, outTemp) do
    receive do
        {:in, temp} ->
            actor(temp, outTemp)
        {:out, temp} ->
            actor(inTemp, temp)
        {:getIn, from} ->
            send(from, inTemp)
            actor(inTemp, outTemp)
        {:getOut, from} ->
          send(from, outTemp)
          actor(inTemp, outTemp)
    end
end

def make_actor(inTemp, outTemp), do: spawn(fn -> actor(inTemp, outTemp) end)

def setIn(temp, ac), do: send(ac, {:in, temp})

def setOut(temp, ac), do: send(ac, {:out, temp})

def getIn(ac) do
    send(ac, {:getIn, self()})
    receive do
        temp ->
            temp
    end
end

def getOut(ac) do
    send(ac, {:getOut, self()})
    receive do
        temp ->
            temp
    end
end

def run() do
  init()

  state = make_actor(false, false)

  thermometerJoins =
    Net.network()
    |> Obs.filter(&match?({:join, _}, &1))
    |> Obs.filter(fn {:join, v} ->
      v.type == :thermometer
    end)

  thermometerJoins
  |> Obs.map(fn {:join, node} ->
    IO.inspect node
    node.broadcast
    |> Obs.map(fn {k, v} ->
      if k == :insideTemp do
        setIn(v, state)
        outTemp = getOut(state)
        if outTemp do
          if v < 24 do
            if v < outTemp do
              IO.puts("Windows open")
            else
              IO.puts("Windows closed")
            end
          else
            if v > outTemp do
              IO.puts("Windows open")
            else
              IO.puts("Windows closed")
            end
          end
        end
      else
        setOut(v, state)
        inTemp = getIn(state)
        if inTemp do
          if inTemp < 24 do
            if inTemp < v do
              IO.puts("Windows open")
            else
              IO.puts("Windows closed")
            end
          else
            if inTemp > v do
              IO.puts("Windows open")
            else
              IO.puts("Windows closed")
            end
          end
        end
      end
    end)
  end)

  end
end