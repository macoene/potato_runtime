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
        Process.exit(heartPid, :kill)
        actor(lease, programPid, spawn(fn -> heartbeatTimer(lease, programPid) end))
    end
  end

  def program_runner(program, round_time) do
    receive do
      :stop ->
        Process.exit(self(), :kill)
    after
      round_time -> 
        program.()
        program_runner(program, round_time)
    end
  end


  def make_heartbeat_listener(lease, programPid), do: spawn(fn -> actor(lease, programPid, spawn(fn -> heartbeatTimer(lease, programPid) end)) end)
  def refresh(hbt), do: send(hbt, :refresh)

  def createNewBody(lease, heartbeat, body, {:loop, round_time}) do
    programPid = spawn(fn -> program_runner(body, round_time) end)

    heartbeatTimer = make_heartbeat_listener(lease, programPid)
          
    heartbeat
    |> Observables.Obs.filter(fn m -> m == :alive end)
    |> Observables.Obs.each(fn _ -> refresh(heartbeatTimer) end)
  end

  def executeBody(body) do
    body.()
  end

  
  defmacro program(lease, after_life, do: body) do
    data = [lease: lease, after_life: after_life]
    quote do
      {kind, body} = unquote(body)
      if kind == :run_once do
        newBody = quote(do: executeBody(var!(body)))
        {{[], []}, {__ENV__, [body: body], newBody}}
      else
        heartbeat = Observables.Subject.create()
        lease = unquote(lease)

        newBody = quote(do: createNewBody(var!(lease), var!(heartbeat), var!(body), var!(kind)))

        Observables.Obs.range(0, :infinity, 450)
        |> Observables.Obs.map(fn _ ->
          Observables.Subject.next(heartbeat, :alive)
        end)

        #{{unquote(lease), heartbeat}, fn -> unquote(body) end}
        {{lease, heartbeat}, {__ENV__, [lease: lease, heartbeat: heartbeat, body: body, kind: kind], newBody}}
      end
    end
  end

  defmacro loop(round_time, do: body) do
    data = [round_time: round_time]
    quote do
      {{:loop, unquote(round_time)}, fn -> unquote(body) end}
    end
  end

  defmacro run_once(do: body) do
    quote do
      {:run_once, fn -> unquote(body) end}
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
