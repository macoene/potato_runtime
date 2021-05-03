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
      {:start, heartbeat, sinks} ->
        link_sinks(sinks)
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
      |> Obs.each(fn {_, {v, s}} ->
        send(reconnect_actor, {:start, v, s})
      end)
    end)
  end

  def sinks_actor(sinks) do
    receive do
      {:add, {sink, name}} ->
        if Keyword.get(sinks, name) do
          new_sinks = Keyword.replace(sinks, name, sink)
          sinks_actor(new_sinks)
        else
          new_sinks = Keyword.put_new(sinks, name, sink)
          sinks_actor(new_sinks)
        end
      {:get, from, name} ->
        res = Keyword.get(sinks, name)
        send(from, {:sink, res})
        sinks_actor(sinks)
    end
  end

  def new_sinks_register() do
    spawn(fn -> sinks_actor([]) end)
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
  def start(hbt, heartbeat, sinks), do: send(hbt, {:start, heartbeat, sinks})

  def link_sinks(sinks) do
    db = myself().sinks
    Enum.each(sinks, fn s ->
      send(db, {:add, s})
    end)
  end

  def createNewBody(lease, heartbeat, body, reconnect, sinks) do
    if reconnect do
      heartbeatTimer = make_heartbeat_listener_reconnect(lease, body)
      start(heartbeatTimer, heartbeat, sinks)
      wait_for_reconnect(reconnect, heartbeatTimer)
    else
      programPid = spawn(fn -> program_runner(body) end)
      heartbeatTimer = make_heartbeat_listener(lease, programPid)
      link_sinks(sinks)
          
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
      sinks = Keyword.get(options, :sinks)
      if after_life == :kill do
        heartbeat = Subject.create()
        restart = Keyword.get(options, :restart)

        leasing_time = Keyword.get(options, :leasing_time)

        Obs.range(0, :infinity, round(leasing_time / 3))
        |> Obs.map(fn _ ->
          Subject.next(heartbeat, :alive)
        end)

        if (restart == :no_restart) or (restart == nil) do          
          newBody = quote(do: createNewBody(var!(leasing_time), var!(heartbeat), var!(body), false, var!(sinks)))
          {{__ENV__, [leasing_time: leasing_time, heartbeat: heartbeat, body: fn -> unquote(body) end, sinks: sinks], newBody}, nil}
        else
          newBody = quote(do: createNewBody(var!(leasing_time), var!(heartbeat), var!(body), var!(sender), var!(sinks)))
          {{__ENV__, [leasing_time: leasing_time, sender: myself().uuid, heartbeat: heartbeat, body: fn -> unquote(body) end, sinks: sinks], newBody}, {restart, heartbeat, sinks}}
        end
      else
        if after_life == :keep_alive do
          {{__ENV__, [body: fn -> unquote(body) end], quote(do: var!(body).())}, nil}
        end
      end
    end
  end

  def write_nodes_to_file(nodes) do
    File.rm("connected_before" <> "#{myself().uuid}" <> "#{myself().type}")
    {_, file} = File.open("connected_before" <> "#{myself().uuid}" <> "#{myself().type}", [:write])
    IO.write(file, "#{inspect nodes}")
    File.close(file)
  end

  def slave_nodes(nodes) do
    receive do
      {:store, type, address} ->
        addresses = Keyword.get(nodes, type)
        if addresses do
          new = [address | addresses]
          new_nodes = Keyword.replace(nodes, type, new)
          write_nodes_to_file(new_nodes)
          slave_nodes(new_nodes)
        else
          new_nodes = Keyword.put_new(nodes, type, [address])
          write_nodes_to_file(new_nodes)
          slave_nodes(new_nodes)
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
    after 1000 ->
      check_node_connected(db, type, address)
    end
  end

  def create_slave_node_database(type) do
    {m, v} = File.read("connected_before" <> "#{Node.self()}" <> "#{type}")
    if m == :error do
      spawn(fn -> slave_nodes([]) end)
    else
      {nodes, _} = Code.eval_string(v)
      spawn(fn -> slave_nodes(nodes) end)
    end
  end

  def store_slave_node(db, type, address) do
    send(db, {:store, type, address})
  end

  defmacro send_program(prog, joins) do
    data = [joins: joins]
    quote do
      joins = unquote(joins)
      connected_before = myself().sndb
      prog = unquote(prog)
      {program, heartbeat} = prog
      if heartbeat do
        joins
        |> Obs.each(fn nd -> spawn(fn ->
          if check_node_connected(connected_before, nd.type, nd.uuid) do
            {restart, h, s} = heartbeat
            if restart == :restart_and_new do
              myself().broadcast
              |> Subject.next({nd.uuid, {h, s}})

              nd.deploy
              |> Subject.next(program)
            else
              myself().broadcast
              |> Subject.next({nd.uuid, {h, s}})
            end
          else
            store_slave_node(connected_before, nd.type, nd.uuid)
            nd.deploy
            |> Subject.next(program)
          end
        end) end)
      else
        joins
        |> Obs.each(fn nd ->
          nd.deploy
          |> Subject.next(program)
        end)
      end
    end
  end

  def get_sink(db, name) do
    send(db, {:get, self(), name})
    receive do
      {:sink, ans} ->
        ans
    end
  end

  defmacro use_sink(name) do
    data = [name: name]
    quote do
      name = unquote(name)
      db = myself().sinks
      res = get_sink(db, name)
      res
    end
  end

  # Creates a remote variable, and sink by default
  def create_remote_variable(name, new_sink \\ true) do
    regname = String.to_atom("#{myself().uuid}" <> "#{myself().type}:" <> name)
    if new_sink do
      sink = Observables.Subject.create()
      {sink, regname}
    else
      {nil, regname}
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
