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

  def heartbeatTimer(time, program) do
    :timer.sleep(time)
    IO.puts("We have to die now")
    send(program, :stop)
  end

  def actor(lease, programPid, heartPid) do
    receive do
      :refresh ->
        Process.unlink(heartPid)
        Process.exit(heartPid, :kill)
        actor(lease, programPid, spawn_link(fn -> heartbeatTimer(lease, programPid) end))
    end
  end

  def program_runner(program) do
    runner = program.()
    receive do
      :stop ->
        Process.exit(runner, :kill)
    end
  end

  def make_heartbeat_listener(lease, programPid), do: 
    spawn(fn -> actor(lease, programPid, spawn_link(fn -> heartbeatTimer(lease, programPid) end)) end)
  def refresh(hbt), do: send(hbt, :refresh)

  def createNewBody(lease, heartbeat, body) do
    programPid = spawn(fn -> program_runner(body) end)
    #programPid = body.()

    heartbeatTimer = make_heartbeat_listener(lease, programPid)
          
    heartbeat
    |> Observables.Obs.filter(fn m -> m == :alive end)
    |> Observables.Obs.each(fn _ -> refresh(heartbeatTimer) end, true)
  end

  
  defmacro program(lease, after_life, restart, do: body) do
    data = [lease: lease, after_life: after_life, restart: restart]
    quote do
      heartbeat = Observables.Subject.create()
      lease = unquote(lease)
      
      newBody = quote(do: createNewBody(var!(lease), var!(heartbeat), var!(body)))

      Observables.Obs.range(0, :infinity, round(lease / 3))
      |> Observables.Obs.map(fn _ ->
        Observables.Subject.next(heartbeat, :alive)
      end)

      {{lease, heartbeat}, {__ENV__, [lease: lease, heartbeat: heartbeat, body: fn -> unquote(body) end], newBody}}
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
