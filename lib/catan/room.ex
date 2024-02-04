defmodule Catan.Room do
  alias Catan.Model.Player
  alias Catan.Model.Game
  alias Catan.Model.Board
  alias Catan.Model.T
  alias Catan.Room
  use GenServer

  @type client() :: {color :: T.color(), pids :: MapSet.t(pid())}

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

  def join(room, client_id) do
    GenServer.call(room, {:join, client_id})
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
  def handle_call({:join, client_id}, {pid, _}, room) do
    case add_client(room, client_id, pid) do
      {:error, reason} ->
        {:reply, {:error, reason}, room}
      {:ok, room} ->
        Process.monitor(pid)
        broadcast_online_players(room.clients)
        {color, _} = room.clients[client_id]
        Catan.Client.notify(pid, game_message_for(room.game, color))
        {:reply, :ok, room}
    end
  end

  # TODO remove later
  @impl true
  def handle_call(:show, _from, room) do
    {:reply, room, room}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, dead_pid, _reason}, room) do
    room =
      update_in(room.clients, &Map.new(&1, fn {client_id, {color, pids}} ->
        {client_id, {color, MapSet.delete(pids, dead_pid)}}
      end))
    broadcast_online_players(room.clients)
    {:noreply, room}
  end

  defp add_client(room, client_id, pid) do
    case room.clients[client_id] do
      {color, pids} ->
        client = {color, MapSet.put(pids, pid)}
        {:ok, put_in(room.clients[client_id], client)}
      nil ->
        case remaining_colors(room) do
          [color | _] ->
            client = {color, MapSet.new() |> MapSet.put(pid)}
            {:ok, put_in(room.clients[client_id], client)}
          [] ->
            {:error, :room_full}
        end
    end
  end

  defp remaining_colors(room) do
    game_colors = room.game.player_order
    used_colors = room.clients |> Map.values() |> Enum.map(fn {color, _} -> color end)
    Enum.reject(game_colors, &(&1 in used_colors))
  end

  defp game_message_for(game0, dest_color) do
    take_keys = [
      :board,
      :player_order,
      :buildings,
      :roads,
      :state,
      :dice_roll,
      :robber_tile,
      :largest_army_holder,
      :longest_road_holder,
    ]
    take_keys = case Game.current_player(game0) do
      ^dest_color -> [:new_development_cards | take_keys]
      _ -> take_keys
    end
    game = Map.take(game0, take_keys)
    game = Map.put(game, :num_development_cards, length(game0.development_card_stack))
    game = Map.put(game, :players, Map.new(game0.players, fn {color, player} ->
      if color == dest_color do
        {color, player}
      else
        {color, %{
          num_resources: Player.card_count(player.resources),
          num_development_cards: Player.card_count(player.development_cards),
          pieces: player.pieces,
          used_knight_cards: player.used_knight_cards,
        }}
      end
    end))
    %{game: game}
  end

  defp online_players_message(clients) do
    %{players:
      Map.new(clients, fn {client_id, {color, pids}} ->
        {color, %{
          id: client_id,
          online: pids != [],
        }}
      end)
    }
  end

  defp broadcast_online_players(clients) do
    message = online_players_message(clients)
    for {_, {_, pids}} <- clients, pid <- pids do
      Catan.Client.notify(pid, message)
    end
  end

end
