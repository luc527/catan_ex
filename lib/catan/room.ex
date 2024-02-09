defmodule Catan.Room do
  alias Catan.Model.Player
  alias Catan.Model.Game
  alias Catan.Model.Board
  alias Catan.Model.T
  alias Catan.Room
  use GenServer

  @type client_id() :: any()  # TODO any for testing, later change to int?
  @type client() :: %{color: T.color(), pids: MapSet.t(pid())}

  defstruct [
    :game,
    :clients,
  ]

  @type t() :: %{
    game: Game.t(),
    clients: %{client_id() => [client()]},
  }

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

  def place_starting_pieces(room, client_id, settlement_corner, road_side) do
    GenServer.call(room, {:play, client_id, [:place_starting_pieces, settlement_corner, road_side]})
  end

  def trade_with_bank(room, client_id, player_resource, amount, bank_resource) do
    GenServer.call(room, {:play, client_id, [:trade_with_bank, player_resource, amount, bank_resource]})
  end

  def trade_with_player(room, client_id, other_player, resources_given, resources_received) do
    GenServer.call(room, {:play, client_id, [:trade_with_player, other_player, resources_given, resources_received]})
  end

  def finish_trading(room, client_id) do
    GenServer.call(room, {:play, client_id, [:finish_trading]})
  end

  def choose_stolen_cards(room, client_id, player, cards) do
    GenServer.call(room, {:play, client_id, [:choose_stolen_cards, player, cards]})
  end

  def move_robber(room, client_id, tile, player_to_steal) do
    GenServer.call(room, {:play, client_id, [:move_robber, tile, player_to_steal]})
  end

  def build_road(room, client_id, side) do
    GenServer.call(room, {:play, client_id, [:build_road, side]})
  end

  def build_city(room, client_id, side) do
    GenServer.call(room, {:play, client_id, [:build_city, side]})
  end

  def buy_development_card(room, client_id) do
    GenServer.call(room, {:play, client_id, [:buy_development_card]})
  end

  def use_knight_card(room, client_id, robber_tile, player_to_steal) do
    GenServer.call(room, {:play, client_id, [:use_knight_card, robber_tile, player_to_steal]})
  end

  def use_monopoly_card(room, client_id, resource) do
    GenServer.call(room, {:play, client_id, [:use_monopoly_card, resource]})
  end

  def use_road_building_card(room, client_id, side1, side2) do
    GenServer.call(room, {:play, client_id, [:use_road_building_card, side1, side2]})
  end

  def use_year_of_plenty_card(room, client_id, resource1, resource2) do
    GenServer.call(room, {:play, client_id, [:use_year_of_plenty_card, resource1, resource2]})
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
    with {:ok, room} <- add_client(room, client_id, pid) do
      Process.monitor(pid)
      send(self(), :broadcast_players)
      color = room.clients[client_id].color
      Catan.Client.notify(pid, game_message_for(room.game, color))
      {:reply, :ok, room}
    else
      error -> {:reply, error, room}
    end
  end

  @impl true
  def handle_call({:play, client_id, [fun | args]}, {pid, _}, room) do
    with :ok <- check_is_authorized(room.clients, client_id, pid),
         color = room.clients[client_id].color,
         :ok <- check_is_current_player(room.game, color),
         {:ok, game} <- apply(Game, fun, [room.game | args])
    do
      send(self(), :broadcast_game)
      {:reply, :ok, put_in(room.game, game)}
    else
      error -> {:reply, error, room}
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
      update_in(room.clients, fn {client_id, client} ->
        {client_id, update_in(client.pids, &MapSet.delete(&1, dead_pid))}
      end)
    broadcast_online_players(room.clients)
    {:noreply, room}
  end

  @impl true
  def handle_info(:broadcast_game, room) do
    broadcast_game(room.clients, room.game)
    {:noreply, room}
  end

  @impl true
  def handle_info(:broadcast_players, room) do
    broadcast_online_players(room.clients)
    {:noreply, room}
  end

  defp check_is_current_player(game, color) do
    if color == Game.current_player_color(game) do
      :ok
    else
      {:error, :not_your_turn}
    end
  end

  defp check_is_authorized(clients, client_id_attempt, pid) do
    clients
    |> Enum.any?(fn {client_id, client} -> client_id_attempt == client_id and pid in client.pids end)
    |> case do
      true -> :ok
      false -> {:error, :unauthorized}
    end
  end

  defp add_client(room, client_id, pid) do
    case room.clients[client_id] do
      nil ->
        case remaining_colors(room) do
          [color | _] ->
            client = %{color: color, pids: MapSet.new([pid])}
            {:ok, put_in(room.clients[client_id], client)}
          [] ->
            {:error, :room_full}
        end
      client ->
        client = update_in(client.pids, &MapSet.put(&1, pid))
        {:ok, put_in(room.clients[client_id], client)}
    end
  end

  defp remaining_colors(room) do
    game_colors = room.game.player_order
    used_colors = room.clients |> Map.values() |> Enum.map(fn client -> client.color end)
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

  defp broadcast_online_players(clients) do
    message = %{
      players:
        Map.new(clients, fn {client_id, client} ->
          {client.color, %{
            id: client_id,
            online: client.pids != [],
          }}
        end)
    }
    for {_, client} <- clients, pid <- client.pids do
      Catan.Client.notify(pid, message)
    end
  end

  defp broadcast_game(clients, game) do
    for {_, client} <- clients do
      message = game_message_for(game, client.color)
      for pid <- client.pids do
        Catan.Client.notify(pid, message)
      end
    end
  end

end
