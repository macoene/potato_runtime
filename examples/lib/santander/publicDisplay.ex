defmodule Potato.Santander.PublicDisplay do
    alias Observables.Obs
    alias Observables.Subject
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    The public display displays the available parking spots,
    data received from the main storage.
    """
  
    def init() do
      # Node descriptor
      nd = %{
        hardware: :publicDisplay,
        type: :display,
        name: "public display",
        uuid: Node.self()
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end
  
    def run() do
      init()
  
      joins = 
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :mainStorage
        end)
        |> Obs.map(&elem(&1, 1))
        |> Obs.each(fn nd ->
          Logger.debug("Joined Main Storage: #{inspect(nd)}")
        end)
  
        joins
        |> Obs.map(fn node ->
          node.broadcast
          |> Obs.filter(fn {t, _} -> 
            t == :available
          end)
          |> Obs.map(fn {_, v} ->
            IO.puts("Available Parking Spots: #{inspect(v)}")
          end)
        end)
    end
  end