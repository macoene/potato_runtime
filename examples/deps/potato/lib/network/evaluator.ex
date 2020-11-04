defmodule Potato.Network.Evaluator do
  @moduledoc """
  The Reactor is the key evaluator on each node.
  Whenever code is sent th
  """
  use GenServer
  require Logger
  import GenServer

  def start_link() do
    start_link(__MODULE__, [], [{:name, __MODULE__}])
  end

  def init([]) do
    deployment_subject = Potato.Network.Observables.deployment()

    deployment_subject
    |> Observables.Obs.map(fn {{lease, sender}, prog} -> 
      #IO.puts(lease)
      #inspect lease
      deploy_program(prog) end)

    {:ok, %{}}
  end

  #
  # ------------------------ API
  #

  @doc """
  Deploys a program locally in the reactor.
  """
  def deploy_program(program), do: cast(__MODULE__, {:deploy_program, program})

  #
  # ------------------------ Callbacks
  #

  def handle_cast({:deploy_program, {env, vars, program}}, state) do
    #res = program.()
    expanded = Code.eval_quoted(program, vars, env)
    res = expanded |> elem(0)
    #IO.inspect expanded

    Logger.debug("""
    Program evaluated
    ======================================
    Result of evaluation: #{inspect(res)}
    ======================================
    """)

    {:noreply, state}
  end
end
