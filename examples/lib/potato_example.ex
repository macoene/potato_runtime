defmodule PotatoExample do
  alias Observables.Obs
  require Logger

  @moduledoc """
  Documentation for PotatoExample.
  """
  def init() do
    # Our node descriptor.
    nd = %{
      hardware: :android,
      type: :phone,
      name: "phone",
      signals: [],
      uuid: "I am unique as fuck"
    }

    Potato.Network.Meta.set_local_nd(nd)
  end

  def phone() do
    init()

    Potato.Network.Observables.network()
    |> Obs.map(fn {e, nd} ->
      Logger.debug("A node #{inspect(e)}ed the network:")
      Logger.debug("#{inspect(nd)}")
    end)
  end
end
