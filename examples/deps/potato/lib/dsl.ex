defmodule Potato.DSL do
  alias Observables.Obs
  alias Observables.Subject
  alias Potato.Network.Observables, as: Net
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

  def reconnect_actor(lease, programPid, heartPid, program) do
    ourPid = self()
    receive do
      {:start, heartbeat} ->
        programPid = spawn(fn -> program_runner(program, heartbeat, ourPid) end)
        heartPid = spawn(fn -> heartbeatTimer(lease, programPid) end)
        reconnect_actor(lease, programPid, heartPid, program)
      :refresh ->
        Process.exit(heartPid, :kill)
        heartPid = spawn(fn -> heartbeatTimer(lease, programPid) end)
        reconnect_actor(lease, programPid, heartPid, program)
    end
  end

  def wait_for_reconnect(sender, reconnect_actor) do
    Net.network()
    |> Obs.filter(&match?({:join, _}, &1))
    |> Obs.filter(fn {:join, v} ->
      v.uuid == sender
    end)
    |> Obs.each(fn {:join, v} ->
      v.broadcast
      |> Obs.filter(fn {m, _} ->
        m == myself().uuid 
      end)
      |> Obs.each(fn {_, v} ->
        send(reconnect_actor, {:start, v})
      end)
    end)
  end

  def program_runner(program) do
    runner = program.()
    receive do
      :stop ->
        Process.exit(runner, :kill)
    end
  end

  def program_runner(program, heartbeat, heartbeatTimer) do
    runner = program.()
    heartbeat
      |> Obs.filter(fn m -> m == :alive end)
      |> Obs.each(fn _ -> refresh(heartbeatTimer) end, true)
    
    receive do
      :stop ->
        Process.exit(runner, :kill)
    end
  end

  def make_heartbeat_listener(lease, programPid), do: 
    spawn_link(fn -> actor(lease, programPid, spawn_link(fn -> heartbeatTimer(lease, programPid) end)) end)
  
  def make_heartbeat_listener_reconnect(lease, body), do: 
    spawn(fn -> reconnect_actor(lease, nil, nil, body) end)
  def refresh(hbt), do: send(hbt, :refresh)
  def start(hbt, heartbeat), do: send(hbt, {:start, heartbeat})

  def createNewBody(lease, heartbeat, body, reconnect) do
    if reconnect do
      heartbeatTimer = make_heartbeat_listener_reconnect(lease, body)
      start(heartbeatTimer, heartbeat)
      wait_for_reconnect(reconnect, heartbeatTimer)
    else
      programPid = spawn(fn -> program_runner(body) end)
      heartbeatTimer = make_heartbeat_listener(lease, programPid)
          
      heartbeat
      |> Obs.filter(fn m -> m == :alive end)
      |> Obs.each(fn _ -> refresh(heartbeatTimer) end, true)
    end
  end

  defmacro program(options, do: body) do
    data = [options: options]
    quote do
      options = unquote(options)
      after_life = Keyword.get(options, :after_life)
      if after_life == :kill do
        heartbeat = Subject.create()
        restart = Keyword.get(options, :restart)

        leasing_time = Keyword.get(options, :leasing_time)

        Obs.range(0, :infinity, round(leasing_time / 3))
        |> Obs.map(fn _ ->
          Subject.next(heartbeat, :alive)
        end)

        if (restart == :no_restart) or (restart == nil) do          
          newBody = quote(do: createNewBody(var!(leasing_time), var!(heartbeat), var!(body), false))
          {{__ENV__, [leasing_time: leasing_time, heartbeat: heartbeat, body: fn -> unquote(body) end], newBody}, nil}
        else
          newBody = quote(do: createNewBody(var!(leasing_time), var!(heartbeat), var!(body), var!(sender)))
          {{__ENV__, [leasing_time: leasing_time, sender: myself().uuid, heartbeat: heartbeat, body: fn -> unquote(body) end], newBody}, heartbeat}
        end
      else
        if after_life == :keep_alive do
          {{__ENV__, [body: fn -> unquote(body) end], quote(do: var!(body).())}, nil}
        end
      end
    end
  end

  def slave_nodes(nodes) do
    receive do
      {:store, type, address} ->
        addresses = Keyword.get(nodes, type)
        if addresses do
          new = [address | addresses]
          slave_nodes(Keyword.replace(nodes, type, new))
        else
          slave_nodes(Keyword.put_new(nodes, type, [address]))
        end
      {:check_presence, from, type, address} ->
        addresses = Keyword.get(nodes, type)
        if addresses do
          send(from, Enum.member?(addresses, address))
          slave_nodes(nodes)
        else
          send(from, false)
          slave_nodes(nodes)
        end
    end
  end

  def check_node_connected(db, type, address) do
    send(db, {:check_presence, self(), type, address})
    receive do
      ans ->
        ans
    end
  end

  def create_slave_node_database() do
    spawn(fn -> slave_nodes([]) end)
  end

  def store_slave_node(db, type, address) do
    send(db, {:store, type, address})
  end

  defmacro send_program(prog, joins, connected_before \\ false) do
    data = [joins: joins, connected_before: connected_before]
    quote do
      joins = unquote(joins)
      connected_before = unquote(connected_before)
      prog = unquote(prog)
      {program, heartbeat} = prog
      if heartbeat do
        joins
        |> Obs.each(fn nd ->
          if check_node_connected(connected_before, nd.type, nd.uuid) do
            myself().broadcast
            |> Subject.next({nd.uuid, heartbeat})
          else
            store_slave_node(connected_before, nd.type, nd.uuid)
            nd.deploy
            |> Subject.next(program)
          end
        end)
      else
        joins
        |> Obs.each(fn nd ->
          nd.deploy
          |> Subject.next(program)
        end)
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
