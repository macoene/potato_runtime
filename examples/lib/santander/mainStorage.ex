defmodule Potato.Santander.MainStorage do
    alias Observables.Obs
    alias Observables.Subject
    alias Potato.Network.Observables, as: Net
    require Logger
    use Potato.DSL
  
    @doc """
    The main storage keeps track of the available parking spots, by querying
    the status of the ferromagnetic wireless sensors, which indicate whether
    or not a certain parking spot is taken. It also keeps statistics as for
    example the average available parking spots. Public displays and
    end-user applications (e.g., smartphone) can also query the current or
    the average available parking spots.
    """
  
    def init(id) do
      # Node descriptor
      nd = %{
        hardware: :mainStorage,
        type: :mainStorage,
        name: "main storage",
        uuid: id
      }
  
      Potato.Network.Meta.set_local_nd(nd)
    end

		def countTakenSpots(list, count \\ 0) do
			if length(list) == 0 do
				count
			else
				{_, status} = hd(list)
				countTakenSpots(tl(list), (count + status))
			end
		end
  
    def storage(sensorList) do
      receive do
        {:update, sensor, status} ->
					curr = Keyword.get(sensorList, sensor)
					if curr do
          	if (curr == status) do
            	storage(sensorList)
          	else
            	new_list = Keyword.replace(sensorList, sensor, status)
          		storage(new_list)
						end
					else 
						new_list = Keyword.put_new(sensorList, sensor, status)
						storage(new_list)
					end
        {:getTotal, from} ->
          send(from, length(sensorList))
					storage(sensorList)
        {:getAvailable, from} ->
					total = length(sensorList)
					taken = countTakenSpots(sensorList)
					available = total - taken
          send(from, available)
          storage(sensorList)
				{:getTaken, from} ->
					taken = countTakenSpots(sensorList)
					send(from, taken)
					storage(sensorList)
      end
    end
    
    def create_storage(), do: spawn(fn -> storage([]) end)
  
    def update(storage, sensor, status), do: send(storage, {:update, sensor, status})
  
    def getTotal(storage) do
      send(storage, {:getTotal, self()})
      receive do
        res ->
          res
      end
    end

    def getAvailable(storage) do
      send(storage, {:getAvailable, self()})
      receive do
        res ->
          res
      end
    end

    def getTaken(storage) do
      send(storage, {:getTaken, self()})
      receive do
        res ->
          res
      end
    end

    def trackAvgAvailableLoop(ms, sink, storage, totalTicks, totAvail) do
      Process.sleep(ms)
      currAvail = getAvailable(storage)
      newTotAvail = totAvail + currAvail
      res = newTotAvail / (totalTicks + 1)
      Subject.next(use_sink(sink), res)
      trackAvgAvailableLoop(ms, sink, storage, totalTicks + 1, newTotAvail)
    end


    def trackAvgAvailable(milliseconds, sink, storage) do
      spawn_link(fn -> trackAvgAvailableLoop(milliseconds, sink, storage, 0, 0) end)
    end
  
    def run(id \\ 1) do
      init(id)
  
      sensorStorage = create_storage()

      connected_before = create_slave_node_database()
  
      joins = 
        Net.network()
        |> Obs.filter(&match?({:join, _}, &1))
        |> Obs.filter(fn {:join, v} ->
          v.type == :spotSensor
        end)
        |> Obs.map(&elem(&1, 1))
        |> Obs.each(fn nd ->
          Logger.debug("Joined FMSensor: #{inspect(nd)}")
        end)
  
      {sink, sink_to_pass} = create_sink("main storage sink")
  
      prog = program [after_life: :kill, leasing_time: 1000, restart: :restart, sinks: [{sink, sink_to_pass}]] do
          Obs.range(1, :infinity)
          |> Obs.map(fn _ ->
            Potato.Santander.FmSensor.get_status()
          end, true)
          |> Obs.map(fn v ->
            Subject.next(use_sink(sink_to_pass), v)
          end)
      end
  
      sink
      |> Obs.filter(fn {{t, _}, _} -> t == :spotSensor end)
      |> Obs.each(fn {{_, i}, v} -> 
        update(sensorStorage, i, v)
        spawn(fn -> IO.puts(getTotal(sensorStorage)) end)
        spawn(fn -> IO.puts(getAvailable(sensorStorage)) end)
      end)
  
      send_program(prog, joins, connected_before)
    end
  end