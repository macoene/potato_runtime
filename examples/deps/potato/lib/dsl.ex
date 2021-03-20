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

  
  defmacro program(options, do: body) do
    data = [options: options]
    quote do
      options = unquote(options)
      after_life = Keyword.get(options, :after_life)
      if after_life == :kill do
        heartbeat = Observables.Subject.create()
        leasing_time = Keyword.get(options, :leasing_time)
      
        newBody = quote(do: createNewBody(var!(leasing_time), var!(heartbeat), var!(body)))

        Observables.Obs.range(0, :infinity, round(leasing_time / 3))
        |> Observables.Obs.map(fn _ ->
          Observables.Subject.next(heartbeat, :alive)
        end)

        {__ENV__, [leasing_time: leasing_time, heartbeat: heartbeat, body: fn -> unquote(body) end], newBody}
      end
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
