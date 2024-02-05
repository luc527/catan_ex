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

  # ACTIONS
  # Since I couldn't figure out how to do this with Elixir macros,
  # I did it manually with Vim, first writing lines like these by hand:
  #   place_starting_pieces settlement_rocer, road_side
  # then doing search-and-replace with regex capture groups:
  #   %s/(\w+) (.*?)/def \1(room, \2) etc
  # :^)

  # TODO test

  def place_starting_pieces(room, settlement_corner, road_side) do
    GenServer.call(room, {:play, [:place_starting_pieces, settlement_corner, road_side]})
  end

  def trade_with_bank(room, player_resource, amount, bank_resource) do
    GenServer.call(room, {:play, [:trade_with_bank, player_resource, amount, bank_resource]})
  end

  def trade_with_player(room, other_player, resources_given, resources_received) do
    GenServer.call(room, {:play, [:trade_with_player, other_player, resources_given, resources_received]})
  end

  def finish_trading(room) do
    GenServer.call(room, {:play, [:finish_trading]})
  end

  def choose_stolen_cards(room, player, cards) do
    GenServer.call(room, {:play, [:choose_stolen_cards, player, cards]})
  end

  def move_robber(room, tile, player_to_steal) do
    GenServer.call(room, {:play, [:move_robber, tile, player_to_steal]})
  end

  def build_road(room, side) do
    GenServer.call(room, {:play, [:build_road, side]})
  end

  def build_city(room, side) do
    GenServer.call(room, {:play, [:build_city, side]})
  end

  def buy_development_card(room) do
    GenServer.call(room, {:play, [:buy_development_card]})
  end

  def use_knight_card(room, robber_tile, player_to_steal) do
    GenServer.call(room, {:play, [:use_knight_card, robber_tile, player_to_steal]})
  end

  def use_monopoly_card(room, resource) do
    GenServer.call(room, {:play, [:use_monopoly_card, resource]})
  end

  def use_road_building_card(room, side1, side2) do
    GenServer.call(room, {:play, [:use_road_building_card, side1, side2]})
  end

  def use_year_of_plenty_card(room, resource1, resource2) do
    GenServer.call(room, {:play, [:use_year_of_plenty_card, resource1, resource2]})
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

  @impl true
  def handle_call({:play, [name | args]}, {pid, _}, room) do
    current_color = Game.current_player_color(room.game)
    {_, {player_color, _}} = Enum.find(room.clients, fn {_, {_, pids}} -> pid in pids end)

    with ^current_color <- player_color,
        {:ok, game} <- apply(Game, name, [room.game | args])
    do
      broadcast_game(room.clients, game)
      {:reply, :ok, put_in(room.game, game)}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, room}
      nil ->
        {:reply, {:error, :unauthorized}, room}
      _color ->
        {:reply, {:error, :not_your_turn}, room}
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
    take_keys = case Game.current_player_color(game0) do
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

  defp broadcast_game(clients, game) do
    for {_, {color, pids}} <- clients do
      message = game_message_for(game, color)
      for pid <- pids do
        Catan.Client.notify(pid, message)
      end
    end
  end

end
