defmodule Catan.Room do
  alias Catan.Model.Game
  alias Catan.Model.Board
  alias Catan.Model.T
  alias Catan.Room
  use GenServer

  @type client() :: {color :: T.color(), pids :: [pid()]}

  defstruct [
    :game,
    :clients,
  ]

  # TODO should preserve state when restarted
  # TODO when restarted should re-notify the clients (maybe it crashed due to some client's action)

  def via_tuple(uuid) do
    {:via, Registry, {Catan.RoomRegistry, uuid}}
  end

  def start_link({num_players, uuid}) do
    GenServer.start_link(__MODULE__, num_players, name: via_tuple(uuid))
  end

  @impl true
  def init(num_players) do
    player_order =
      T.colors()
      |> Enum.shuffle()
      |> Enum.take(num_players)
    board = Board.random_board_but_default_tokens()
    with {:ok, game} <- Game.initial_game(player_order, board) do
      room = %Room{
        game: game,
        clients: %{},
      }
      {:ok, room}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:join, client_id}, {pid, _}, state) do
    case state.clients[client_id] do
      {color, pids} ->
        Process.monitor(pid)
        state = put_in(state.clients[client_id], {color, Enum.uniq([pid|pids])})
        {:reply, :ok, state}
      nil ->
        case remaining_colors(state) do
          [color|_] ->
            Process.monitor(pid)
            state = put_in(state.clients[client_id], {color, [pid]})
            {:reply, :ok, state}
          [] ->
            {:reply, {:error, :room_full}, state}
        end
    end
  end

  # TODO remove later
  @impl true
  def handle_call(:show, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, dead_pid, _reason}, state) do
    state =
      update_in(state.clients, &Map.new(&1, fn {client_id, {color, pids}} ->
        {client_id, {color, List.delete(pids, dead_pid)}}
      end))
    {:noreply, state}
  end

  defp remaining_colors(state) do
    game_colors = state.game.player_order
    used_colors = state.clients |> Map.values() |> Enum.map(fn {color, _} -> color end)
    Enum.reject(game_colors, &(&1 in used_colors))
  end

  def test_client(room_pid, id) do
    spawn(fn ->
      IO.puts "#{id} joined, #{inspect GenServer.call(room_pid, {:join, id})}"
      Process.sleep(8000)
      IO.puts "#{id} exited"
    end)
  end
end
