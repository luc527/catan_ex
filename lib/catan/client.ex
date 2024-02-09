defmodule Catan.Client do

  # The implementation will change later (GenServer probably)
  # what matters for now is just the interface

  def notify(pid, state) do
    send(pid, state)
  end


  def start(room, client_id) do
    spawn(fn ->
      :ok = Catan.Room.join(room, client_id)
      loop(client_id)
    end)
  end

  def loop(client_id) do
    receive do
      msg ->
        IO.puts("client #{client_id} got: #{inspect msg}")
        loop(client_id)
    end
  end

  # TODO for iex testing, remove later
  def recv() do
    receive do
      msg -> msg
    after
      1000 -> nil
    end
  end
end
