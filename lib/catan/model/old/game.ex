_ = """
defmodule Catan.Model.Game do
  alias Catan.Model.Graphs
  alias Catan.Model.Game
  alias Catan.Model.{Player, T, Board}

  defstruct [
    :state,
    :board,
    :players,
    :buildings,
    :roads,
    :previous_dice_roll,
    :robber_tile,
    :player_order,
    :longest_road_card_holder,
    :largest_army_card_holder,
    :new_development_cards,
    :development_card_stack,
  ]

  @type t() :: %__MODULE__{
    state:                    T.game_state(),
    board:                    Board.t(),
    players:                  %{T.color() => Player.t()},
    buildings:                %{T.corner() => T.building()},
    roads:                    %{T.path() => T.color()},
    previous_dice_roll:       T.dice_roll() | nil,
    robber_tile:              T.tile(),
    player_order:             [T.color()],
    longest_road_card_holder: T.color() | nil,
    largest_army_card_holder: T.color() | nil,
    new_development_cards:    [T.development_card()],
    development_card_stack:   [T.development_card()],
  }

  defp update_player_resource(game, player, resource, amount) do
    update_in(game.players[player], &Player.update_resource(&1, resource, amount))
  end

  defp update_player_resources(game, player, resource_amounts) do
    resource_amounts
    |> Enum.reduce(game, fn {resource, amount}, game ->
      update_player_resource(game, player, resource, amount)
    end)
  end

  defp update_player_piece(game, player, piece, amount) do
    update_in(game.players[player], &Player.update_piece(&1, piece, amount))
  end

  defp update_player_development_card(game, player, card, amount) do
    update_in(game.players[player], &Player.update_development_card(&1, card, amount))
  end

  defp add_new_development_card(game, player, card) do
    update_in(game.new_development_cards, &[{player, card} | &1])
  end

  defp add_settlement(game, corner, player) do
    update_in(
      game.buildings[corner],
      fn nil -> %{kind: :settlement, color: player} end
    )
    |> update_player_piece(player, :settlement, -1)
  end

  defp update_to_city(game, corner, player) do
    update_in(
      game.buildings[corner],
      fn %{kind: :settlement, color: ^player} = building ->
        %{building | kind: :city}
      end
    )
    |> update_player_piece(player, :city,       -1)
    |> update_player_piece(player, :settlement, +1)
  end

  defp add_road(game, path, color) do
    update_in(game.roads[path], fn nil -> color end)
    |> update_player_piece(color, :road, -1)
  end

  def initial(board, player_order) do
    {robber_tile, _} = Enum.find(board.terrains, fn {_, terrain} -> terrain == :desert end)
    %__MODULE__{
      state: {:foundation, 1, player_order},
      board: board,
      players:
        player_order
        |> Stream.map(&{&1, Player.initial()})
        |> Map.new(),
      buildings: %{},
      roads: %{},
      previous_dice_roll: nil,
      robber_tile: robber_tile,
      player_order: player_order,
      longest_road_card_holder: nil,
      largest_army_card_holder: nil,
      development_card_stack:
        Enum.shuffle(
          Enum.concat([
            :knight_card |> List.duplicate(14),
            T.victory_point_cards(), # one of each
            T.progress_cards() |> Enum.flat_map(&List.duplicate(&1, 2))
          ])
        )
    }
  end

  defp beginner_settlements() do
    [
      {9, :red},
      {15, :orange},
      {18, :white},
      {29, :red},
      {32, :white},
      {40, :blue},
      {41, :orange},
      {42, :blue},
    ]
  end

  defp producing_beginner_settlements() do
    [
      {41, :orange},
      {40, :blue},
      {32, :white},
      {29, :red},
    ]
  end

  defp beginner_roads() do
    [
      {14, :red},
      {16, :orange},
      {26, :white},
      {38, :white},
      {42, :red},
      {53, :blue},
      {57, :blue},
      {59, :orange},
    ]
  end

  defp set_state(game, state) do
    %{game | state: state}
  end

  defp reduce(game, enum, fun) do
    Enum.reduce(enum, game, fun)
  end

  def beginner(players) do
    board = Board.beginner()

    settlements =
      beginner_settlements()
      |> Enum.filter(fn {_, color} -> color in players end)
    roads =
      beginner_roads()
      |> Enum.filter(fn {_, color} -> color in players end)
    resources_produced =
      producing_beginner_settlements()
      |> Enum.filter(fn {_, color} -> color in players end)
      |> Enum.flat_map(fn {corner, color} ->
        Graphs.corner_tiles[corner]
        |> Enum.map(fn tile ->
          resource = T.terrain_resource(board.terrains[tile])
          {resource, color}
        end)
      end)

    initial(board, players)
    |> reduce(settlements, fn {corner, color}, game ->
      add_settlement(game, corner, color)
    end)
    |> reduce(roads, fn {path, color}, game ->
      add_road(game, path, color)
    end)
    |> reduce(resources_produced, fn {resource, color}, game ->
      update_player_resource(game, color, resource, 1)
    end)
    |> set_state({:ongoing, :trading, players})
  end

  def place_starting_settlement_and_road(
    %Game{state: {:foundation, 1, queue}} = game, corner, path
  ) do
    [player | rest] = queue
    next_state =
      case rest do
        [] -> {:foundation, 2, Enum.reverse(game.player_order)}
        _  -> {:foundation, 1, rest}
      end
    game
    |> add_settlement(corner, player)
    |> add_road(path, player)
    |> set_state(next_state)
  end

  def place_starting_settlement_and_road(
    %Game{state: {:foundation, 2, queue}} = game,
    corner, path
  ) do
    [player | rest] = queue
    resources_produced =
      for tile <- Graphs.corner_tiles[corner] do
        resource = T.terrain_resource(game.board.terrains[tile])
        {resource, 1}
      end
    game =
      game
      |> add_settlement(corner, player)
      |> add_road(path, player)
      |> update_player_resources(player, resources_produced)
    case rest do
      [] -> advance_player_turn(game)
      _  -> set_state(game, {:foundation, 2, rest})
    end
  end

  def advance_player_turn(
    %Game{state: {:founding, 2, []}, player_order: queue} = game
  ), do: advance_player_turn(game, queue)

  def advance_player_turn(
    %Game{state: {:ongoing, :building, queue}} = game
  ), do: advance_player_turn(game, queue)

  defp tile_resource_production(game, tile) do
    resource = T.terrain_resource(game.board.terrains[tile])
    Graphs.tile_corners[tile]
    |> Stream.map(fn corner ->
      building = game.buildings[corner]
      case building do
        nil -> nil
        %{kind: kind, color: player} ->
          amount = T.building_weight(kind)
          {resource, player, amount}
      end
    end)
    |> Stream.filter(&(&1))
  end

  defp affected_tiles(game, dice_roll) do
    T.tiles()
    |> Stream.filter(fn tile -> game.board.tokens[tile] == dice_roll end)
    |> Stream.reject(fn tile -> tile == game.robber_tile end)
  end

  defp distribute_resources(game, resources) do
    resources
    |> Enum.reduce(game, fn {resource, player, amount}, game ->
      update_player_resource(game, player, resource, amount)
    end)
  end

  defp advance_player_turn(game, [prev_player | next_players]) do
    queue = next_players ++ [prev_player]
    dice_roll = :rand.uniform(6) + :rand.uniform(6)
    game = %{game | previous_dice_roll: dice_roll}
    case dice_roll do
      7 ->
        game
        |> set_state({:ongoing, :moving_robber, queue})
      _ ->
        produced_resources =
          affected_tiles(game, dice_roll)
          |> Stream.flat_map(&tile_resource_production(game, &1))
        game
        |> set_state({:ongoing, :trading, queue})
        |> distribute_resources(produced_resources)
    end
  end

  def move_robber(
    %Game{state: {:ongoing, :moving_robber, [player | _] = queue}} = game,
    tile, player_to_steal
  ) do
    game = %{game |
      robber_tile: tile,
      state: {:ongoing, :trading, queue}
    }
    stealable_resources =
      game.players[player_to_steal].resources
      |> Enum.flat_map(fn {resource, amount} -> List.duplicate(resource, amount) end)
    case stealable_resources do
      [] -> game
      _  ->
        index = :rand.uniform(length(stealable_resources)) - 1
        stolen_resource = Enum.at(stealable_resources, index)
        transfer_resource(game, player_to_steal, player, stolen_resource, 1)
    end
  end

  def trade_with_bank(
    %Game{state: {:ongoing, :trading, [player | _]}} = game,
    player_resource, amount, bank_resource
  ) do
    game
    |> update_player_resource(player, player_resource, -amount)
    |> update_player_resource(player,   bank_resource,       1)
  end

  defp transfer_resource(game, from_player, to_player, resource, amount) do
    game
    |> update_player_resource(from_player, resource, -amount)
    |> update_player_resource(  to_player, resource, +amount)
  end

  def trade_with_player(
    %Game{state: {:ongoing, :trading, [player | _]}} = game,
    other_player, giving, receiving
  ) do
    game
    |> reduce(giving, fn {resource, amount}, game ->
      transfer_resource(game, player, other_player, resource, amount)
    end)
    |> reduce(receiving, fn {resource, amount}, game ->
      transfer_resource(game, other_player, player, resource, amount)
    end)
  end

  def finish_trading(%Game{state: {:ongoing, :trading, queue}} = game) do
    game
    |> set_state({:ongoing, :building, queue})
  end

  def build_settlement(
    %Game{state: {:ongoing, :building, [player | _]}} = game,
    corner
  ) do
    game
    |> add_settlement(corner, player)
    |> update_player_resources(player, T.cost(:settlement))
  end

  def build_city(
    %Game{state: {:ongoing, :building, [player | _]}} = game,
    corner
  ) do
    game
    |> update_to_city(corner, player)
    |> update_player_resources(player, T.cost(:city))
  end

  def build_road(
    %Game{state: {:ongoing, :building, [player | _]}} = game,
    path
  ) do
    game
    |> add_road(path, player)
    |> update_player_resources(player, T.cost(:road))
  end

  defp pop_development_card(game) do
    [card | stack] = game.development_card_stack
    {card, %{game | development_card_stack: stack}}
  end

  def buy_development_card(
    %Game{state: {:ongoing, :building, [player | _]}} = game
  ) do
    {card, game} = pop_development_card(game)
    game
    |> add_new_development_card(player, card)
    |> update_player_resources(player, T.cost(:development_card))
  end

  # TODO: could also be stored in the game
  defp victory_points_by_player(game) do
    building_points =
      game.buildings
      |> Enum.map(fn {_corner, %{color: player, kind: kind}} ->
        {player, T.building_weight(kind)}
      end)

    card_points =
      game.players
      |> Enum.map(fn {color, player} ->
        {color,
          player.development_cards
          |> Enum.map(&T.card_victory_points/1)
          |> Enum.sum}
      end)

    special_card_points =
      [game.largest_army_card_holder, game.longest_road_card_holder]
      |> Enum.filter(&(&1))
      |> Enum.map(&{&1, 2})

    (building_points ++ card_points ++ special_card_points)
    |> Enum.group_by(
      fn {player, _points} -> player end,
      fn {_player, points} -> points end
    )
    |> Map.new(fn {player, point_list} -> {player, Enum.sum(point_list)} end)
  end

  defp consolidate_new_development_cards(game) do
    game = reduce(game, game.new_development_cards, fn {player, card}, game ->
      update_player_development_card(game, player, card, 1)
    end)
    put_in(game.new_development_cards, [])
  end

  defp check_largest_army_card_holder(game) do
    largest_army_card_holder =
      game.players
      |> Enum.filter(fn {_color, player} -> player.development_cards.knight_cards >= 3 end)
      |> Enum.max_by(fn {_color, player} -> player.development_cards.knight_cards end)
      |> case do
        {color, _player} -> color
        _ -> nil
      end
    put_in(game.largest_army_card_holder, largest_army_card_holder)
  end

  defp check_longest_road_card_holder(game) do
    # TODO
    game
  end

  defp check_winner_or_advance_turn(game) do
    victory_points_by_player(game)
    |> Enum.filter(fn {_player, points} -> points >= 10 end)
    |> case do
      [{player, _points}] ->
        set_state(game, {:won_by, player})
      _ ->
        advance_player_turn(game)
    end
  end

  def finish_turn(game) do
    game
    |> consolidate_new_development_cards()
    |> check_largest_army_card_holder()
    |> check_longest_road_card_holder()
    |> check_winner_or_advance_turn()
  end

  # TODO: test!!
  # TODO: write tests?
  # TODO: redo @specs?

  # TODO: play_development_card()
  # can be used at any stage of the turn

  # TODO: difference between _new_ development cards (cannot be used in the current)
  # and ones that the player has already had for a turn
  # -- when finishing the turn, the "new" cards are transferred to the :development_cards entry

end
"""
