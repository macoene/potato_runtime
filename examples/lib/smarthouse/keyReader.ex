defmodule Potato.Smarthouse.KeyReader do
  alias Observables.Obs
  alias Potato.Network.Observables, as: Net
  require Logger
  use Potato.DSL

  @doc """
  The key reader to access the house. People will use this scan reader to
  enter and leave the house.
  """

  def init(id) do
    # Node descriptor
    nd = %{
      hardware: :keyReader,
      type: :access,
      name: "key reader",
      uuid: id
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def run(id \\ 1) do
    init(id)
  end

  def read_key() do
    IO.puts("read")
    # 1 is an entrance signal (= someone comes in), 2 is an exit signal
    # (= someone leaves the house)
    {Node.self(), Enum.random(1..2)}
  end
end