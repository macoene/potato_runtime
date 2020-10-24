defmodule Potato.DSL do
  @moduledoc """

  The DSL module implements the language constructs needed to effectively write
  Potato programs.
  """

  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
      require unquote(__MODULE__)
    end
  end

  #
  # ------------------------ Macros
  #

  @doc """
  broadcast() evaluates to the local broadcast subject.
  """
  def broadcast() do
    broadcast = Potato.Network.Observables.broadcast()
    broadcast
  end

  defmacro program(lease, after_life, do: body) do
    data = [lease: lease, after_life: after_life]
    quote do
      heartbeat = Observables.Subject.create()

      Observables.Obs.range(0, :infinity, 450)
      |> Observables.Obs.map(fn _ ->
        Observables.Subject.next(heartbeat, :alive)
      end)

      {{unquote(lease), heartbeat}, fn -> unquote(body) end}
 
    end
  end

  @doc """
  msyelf() evaluates to the local node descriptor.
  """
  def myself() do
    nd = Potato.Network.Meta.get_local_nd()
    nd
  end  
end
