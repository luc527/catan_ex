defmodule Catan.Model.Game do
  require Catan.Model.T
  alias Catan.Model.Graphs
  alias Catan.Model.Game
  alias Catan.Model.Player
  alias Catan.Model.Board
  alias Catan.Model.T
  alias Catan.Model.RoadGraph

  defstruct [
    :board,
    :player_order,

    :buildings,
    :roads,

    :state,
    :players,
    :dice_roll,
    :robber_tile,
    :largest_army_holder,
    :longest_road_holder,

    # You cannot use a development card in the same turn you bought it.
    # To ensure this, when a player buys a card, the card is first inserted into this list,
    # and only when the turn is ended that the card is added to the player structure,
    # so it's available to use in the next turn.
    :new_development_cards,
    :development_card_stack,
  ]

  @type t() :: %__MODULE__ {
    board:        Board.t(),
    player_order: [T.color()],

    buildings: %{T.corner() => T.building()},
    roads:     %{T.side() => T.color()},

    players:     %{T.color() => %Player{}},
    state:       T.game_state(),
    dice_roll:   T.dice_roll()|nil,
    robber_tile: T.tile(),

    largest_army_holder: T.color() | nil,
    longest_road_holder: T.color() | nil,

    new_development_cards:  [T.development_card()],
    development_card_stack: [T.development_card()],
  }

  defp resduce(game, enum, fun) do
    # Reduce that works better with |> for games,
    # and that works with T.result()s (hence "res"duce)
    Enum.reduce(enum, {:ok, game}, fn
      elem, {:ok, game} ->
        fun.(elem, game)
      _, error ->
        error
    end)
  end

  @spec beginner_game([T.color()]) :: T.result(Game.t())
  def beginner_game(players) do
    with {:ok, game} <- initial_game(players, Board.beginner_board()),
         {:ok, game} <- place_roads_arbitrary(game, beginner_game_roads_for(players)),
         {:ok, game} <- place_settlements_arbitrary(game, beginner_game_settlements_for(players))
    do
      resources =
        beginner_game_producing_settlements_for(players)
        |> Enum.flat_map(fn {corner, player} ->
          Graphs.corner_tiles[corner]
          |> Enum.map(fn tile ->
            resource = T.terrain_resource(game.board.terrains[tile])
            {player, resource, 1}
          end)
        end)
      {:ok,
        game
        |> distribute_resources(resources)
        |> ongoing_start_turn(players)}
    end
  end

  @spec shuffled_development_cards() :: [T.development_card()]
  defp shuffled_development_cards() do
    Enum.shuffle(
      Enum.concat([
        T.progress_cards() |> Enum.flat_map(&List.duplicate(&1, 2)),
        :knight |> List.duplicate(14),
        T.victory_point_cards(),
      ])
    )
  end

  @spec initial_game([T.color()], Board.t()) :: T.result(Game.t())
  def initial_game([_|_] = player_order, %Board{} = board) do
    cond do
      length(player_order) != length(Enum.uniq(player_order)) ->
        {:error, :repeated_player}

      Enum.any?(player_order, &(&1 not in T.colors())) ->
        {:error, :invalid_player}

      true ->
        {robber_tile, _} =
          board.terrains
          |> Enum.find(fn {_tile, terrain} -> terrain == :desert end)
        {:ok, %Game{
          state: {:foundation, 1, player_order},
          board: board,
          player_order: player_order,
          players: player_order |> Map.new(&{&1, Player.initial()}),
          buildings: %{},
          roads: %{},
          dice_roll: nil,
          robber_tile: robber_tile,
          largest_army_holder: nil,
          longest_road_holder: nil,
          new_development_cards: [],
          development_card_stack: shuffled_development_cards(),
        }}
    end
  end

  @spec place_roads_arbitrary(Game.t(), [{T.side(), T.color()}]) :: T.result(Game.t())
  defp place_roads_arbitrary(game, roads) do
    resduce(game, roads, fn {side, color}, game ->
      place_road_arbitrary(game, color, side)
    end)
  end

  @spec place_settlements_arbitrary(Game.t(), [{T.corner(), T.color()}]) :: T.result(Game.t())
  defp place_settlements_arbitrary(game, settlements) do
    resduce(game, settlements, fn {corner, color}, game ->
      place_settlement_arbitrary(game, color, corner)
    end)
  end

  @spec beginner_game_roads() :: [{T.side(), T.color()}]
  def beginner_game_roads() do
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

  @spec beginner_game_roads_for([T.color()]) :: [{T.side(), T.color()}]
  defp beginner_game_roads_for(players) do
    beginner_game_roads()
    |> Enum.filter(fn {_, player} -> player in players end)
  end

  @spec beginner_game_settlements() :: [{T.corner(), T.color()}]
  def beginner_game_settlements() do
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

  @spec beginner_game_settlements_for([T.color()]) :: [{T.side(), T.color()}]
  defp beginner_game_settlements_for(players) do
    beginner_game_settlements()
    |> Enum.filter(fn {_, player} -> player in players end)
  end

  @spec beginner_game_producing_settlements() :: [{T.corner(), T.color()}]
  def beginner_game_producing_settlements() do
    [
      {41, :orange},
      {40, :blue},
      {32, :white},
      {29, :red},
    ]
  end

  @spec beginner_game_producing_settlements_for([T.color()]) :: [{T.side(), T.color()}]
  defp beginner_game_producing_settlements_for(players) do
    beginner_game_producing_settlements()
    |> Enum.filter(fn {_, player} -> player in players end)
  end

  @spec update_player_piece(Game.t(), T.color(), T.piece(), integer()) :: T.result(Game.t())
  defp update_player_piece(game, player, piece, amount) do
    T.update_nonnegative(game.players[player].pieces[piece], amount)
  end

  @spec corner_adjacent_roads(Game.t(), T.corner()) :: [T.color()]
  defp corner_adjacent_roads(game, corner) do
    Graphs.corner_sides[corner]
    |> Enum.flat_map(fn {side, _destination} ->
      case game.roads[side] do
        nil -> []
        color -> [color]
      end
    end)
  end

  @spec side_adjacent_roads(Game.t(), T.side()) :: [T.color()]
  defp side_adjacent_roads(game, side) do
    Graphs.side_corners[side]
    |> Enum.flat_map(fn corner -> Graphs.corner_sides[corner] end)
    |> Enum.flat_map(fn {other_side, _} ->
      if other_side == side do
        []
      else
        case game.roads[other_side] do
          nil -> []
          road -> [road]
        end
      end
    end)
  end

  @spec corner_adjacent_buildings(Game.t(), T.corner()) :: [T.building()]
  defp corner_adjacent_buildings(game, corner) do
    Graphs.corner_sides[corner]
    |> Enum.flat_map(fn {_, other_corner} ->
      case game.buildings[other_corner] do
        nil -> []
        building -> [building]
      end
    end)
  end

  @spec place_settlement_arbitrary(Game.t(), T.color(), T.corner()) :: T.result(Game.t())
  defp place_settlement_arbitrary(game, player, corner) do
    cond do
      game.buildings[corner] ->
        {:error, :occupied}
      corner_adjacent_buildings(game, corner) != [] ->
        {:error, :adjacent_building}
      true ->
        with {:ok, game} <- update_player_piece(game, player, :settlement, -1) do
          {:ok, put_in(game.buildings[corner], {:settlement, player})}
        end
    end
  end

  @spec place_road_arbitrary(Game.t(), T.color(), T.side()) :: T.result(Game.t())
  defp place_road_arbitrary(game, player, side) do
    if game.roads[side] do
      {:error, :occupied}
    else
      with {:ok, game} <- update_player_piece(game, player, :road, -1) do
        {:ok, put_in(game.roads[side], player)}
      end
    end
  end

  @spec update_player_resource(Game.t(), T.color(), T.resource(), integer()) :: T.result(Game.t())
  defp update_player_resource(game, player, resource, amount) do
    T.update_nonnegative(game.players[player].resources[resource], amount)
  end

  @spec update_player_resources(Game.t(), T.color(), [{T.resource(), integer()}]) :: T.result(Game.t())
  defp update_player_resources(game, player, resources) do
    resduce(game, resources, fn {resource, amount}, game ->
      update_player_resource(game, player, resource, amount)
    end)
  end

  @spec dice_roll() :: T.dice_roll()
  defp dice_roll() do
    :rand.uniform(6) + :rand.uniform(6)
  end

  @spec affected_tiles(Game.t(), T.dice_roll()) :: [T.tile()]
  defp affected_tiles(game, roll) do
    game.board.tokens
    |> Stream.filter(fn {_tile, token} -> token == roll end)
    |> Stream.reject(fn {tile, _token} -> tile == game.robber_tile end)
    |> Stream.map(fn {tile, _token} -> tile end)
  end

  @spec tile_resource_production(Game.t(), T.tile()) :: [{T.color(), T.resource(), integer()}]
  defp tile_resource_production(game, tile) do
    resource = T.terrain_resource(game.board.terrains[tile])
    Graphs.tile_corners[tile]
    |> Enum.flat_map(fn corner ->
      building = game.buildings[corner]
      case building do
        nil -> []
        {kind, player} -> [{player, resource, T.building_weight(kind)}]
      end
    end)
  end

  @spec distribute_resources(Game.t(), [{T.color(), T.resource(), integer()}]) :: Game.t()
  defp distribute_resources(game, resources) do
    {:ok, game} =
      resduce(game, resources, fn {player, resource, amount}, game ->
        update_player_resource(game, player, resource, amount)
      end)
    game
  end

  @spec finish_turn(Game.t()) :: Game.t()

  defp finish_turn(%Game{state: {:foundation, 1, [_last]}, player_order: player_order} = game) do
    %{game | state: {:foundation, 2, Enum.reverse(player_order)}}
  end

  defp finish_turn(%Game{state: {:foundation, 1, [_|rest]}} = game) do
    %{game | state: {:foundation, 1, rest}}
  end

  defp finish_turn(%Game{state: {:foundation, 2, [_last]}, player_order: player_order} = game) do
    ongoing_start_turn(game, player_order)
  end

  defp finish_turn(%Game{state: {:foundation, 2, [_ | rest]}} = game) do
    %{game | state: {:foundation, 2, rest}}
  end

  defp finish_turn(%Game{state: {:ongoing, stage, [prev_player | next_players]}} = game)
  when stage == :trading or stage == :building
  do
    # Update special card holders

    army_size_threshold =
      case game.largest_army_holder do
        nil -> 3
        player -> game.players[player].used_knight_cards + 1
      end

    largest_army_holder =
      game.players
      |> Enum.filter(fn {_, player} -> player.used_knight_cards >= army_size_threshold end)
      |> Enum.max_by(fn {_, player} -> player.used_knight_cards end, fn -> nil end)
      |> case do
        nil -> game.largest_army_holder
        {color, _} -> color
      end

    longest_road_per_player =
      for color <- game.player_order, into: %{} do
        {color, RoadGraph.longest_road_length(game, color)}
      end

    road_length_threshold =
      case game.longest_road_holder do
        nil -> 5
        player -> longest_road_per_player[player] + 1
      end

    longest_road_holder =
      longest_road_per_player
      |> Enum.filter(fn {_player, length} -> length >= road_length_threshold end)
      |> Enum.max_by(fn {_player, length} -> length end, fn -> nil end)
      |> case do
        nil -> game.longest_road_holder
        {player, _length} -> player
      end

    game = %{game |
      largest_army_holder: largest_army_holder,
      longest_road_holder: longest_road_holder,
    }

    # Consolidate development cards that were bought in this turn

    game =
      Enum.reduce(game.new_development_cards, game, fn card, game ->
        update_in(game.players[prev_player].development_cards[card], &(&1 = 1))
      end)
    game = %{game | new_development_cards: []}

    # Update victory points

    game =
      Enum.reduce(game.player_order, game, fn color, game ->
        put_in(game.players[color].victory_points, victory_points(game, color))
      end)

    # Check for winner

    game.players
    |> Enum.find(fn {_color, player} -> player.victory_points >= 10 end)
    |> case do
      nil ->
        ongoing_start_turn(game, next_players ++ [prev_player])
      {winner, _} ->
        %{game | state: {:won_by, winner}}
    end
  end

  @spec end_turn(Game.t()) :: Game.t()
  def end_turn(%Game{state: {:ongoing, stage, _}} = game)
  when stage == :trading or stage == :building do
    # Just because finish_turn is private
    finish_turn(game)
  end

  @spec victory_points(Game.t(), T.color()) :: integer()
  defp victory_points(game, player) do
    buildings_vp =
      game.buildings
      |> Enum.filter(fn
        {_corner, nil} -> false
        {_corner, {_kind, color}} -> color == player
      end)
      |> Enum.map(fn {_corner, {kind, _color}} -> T.building_weight(kind) end)
      |> Enum.sum()

    development_cards_vp =
      game.players[player].development_cards
      |> Enum.map(&T.card_victory_points/1)
      |> Enum.sum()

    buildings_vp +
    development_cards_vp +
    (if game.largest_army_holder == player, do: 2, else: 0) +
    (if game.longest_road_holder == player, do: 2, else: 0)
  end

  @spec ongoing_start_turn(Game.t(), [T.color()]) :: Game.t()
  defp ongoing_start_turn(game, player_queue) do
    case roll = dice_roll() do
      7 ->
        stolen_players =
          game.players
          |> Enum.filter(fn {_, player} -> Player.number_of_resource_cards(player) > 7 end)
          |> Enum.map(fn {color, _} -> color end)
        next_stage =
          if stolen_players == [] do
            :moving_robber
          else
            {:choosing_stolen_cards, stolen_players}
          end
        %{game |
          state: {:ongoing, next_stage, player_queue},
          dice_roll: roll,
        }
      _ ->
        resources =
          affected_tiles(game, roll)
          |> Enum.flat_map(&tile_resource_production(game, &1))
        game = distribute_resources(game, resources)
        %{game |
          state: {:ongoing, :trading, player_queue},
          dice_roll: roll,
        }
      end
  end

  @spec place_starting_pieces(Game.t(), T.corner(), T.side()) :: T.result(Game.t())

  def place_starting_pieces(
    %Game{state: {:foundation, 1, [player|_]}} = game,
    settlement_corner, road_side
  ) do
    with {:ok, game} <- add_starting_pieces(game, player, settlement_corner, road_side) do
      {:ok, finish_turn(game)}
    end
  end

  def place_starting_pieces(
    %Game{state: {:foundation, 2, [player|_]}} = game,
    settlement_corner, road_side
  ) do
    with {:ok, game} <- add_starting_pieces(game, player, settlement_corner, road_side),
         resources =
          Graphs.corner_tiles[settlement_corner]
          |> Stream.map(fn tile ->
            resource = T.terrain_resource(game.board.terrains[tile])
            {resource, 1}
          end),
         {:ok, game} <- update_player_resources(game, player, resources)
    do
      {:ok, finish_turn(game)}
    end
  end

  @spec add_starting_pieces(Game.t(), T.color(), T.corner(), T.side()) :: T.result(Game.t())
  defp add_starting_pieces(game, player, corner, side) do
    adjacent_sides =
      Graphs.corner_sides[corner]
      |> Enum.map(&elem(&1, 0))
    if side not in adjacent_sides do
      {:error, :side_not_adjacent}
    else
      with {:ok, game} <- place_road_arbitrary(game, player, side),
           {:ok, game} <- place_settlement_arbitrary(game, player, corner)
      do
        {:ok, game}
      end
    end
  end

  @spec _trade_with_bank(Game.t(), T.resource(), integer(), T.resource()) :: T.result(Game.t())
  defp _trade_with_bank(
    %Game{state: {:ongoing, :trading, [player|_]}} = game,
    player_resource, amount, bank_resource
  ) do
    if player_resource == bank_resource do
      {:error, :trading_same}
    else
      update_player_resources(game, player, [
        {player_resource, -amount},
        {bank_resource, 1}
      ])
    end
  end

  @spec trade_with_bank(Game.t(), T.resource(), integer(), T.resource()) :: T.result(Game.t())

  def trade_with_bank(
    %Game{state: {:ongoing, :trading, _}} = game,
    player_resource, amount, bank_resource
  ) when amount == 4 do
    _trade_with_bank(game, player_resource, amount, bank_resource)
  end

  # TODO: test the two function clauses below more thoroughly

  def trade_with_bank(
    %Game{state: {:ongoing, :trading, [player|_]}} = game,
    player_resource, amount, bank_resource
  ) when amount == 3 do

    has_three_for_one =
      game.board.harbors
      |> Enum.any?(fn
        {corner, :three_for_one} ->
          case game.buildings[corner] do
            nil -> false
            {_, color} -> color == player
          end
        _ -> false
      end)

    if not has_three_for_one do
      {:error, :no_harbor}
    else
      _trade_with_bank(game, player_resource, amount, bank_resource)
    end
  end

  def trade_with_bank(
    %Game{state: {:ongoing, :trading, [player|_]}} = game,
    player_resource, amount, bank_resource
  ) when amount == 2 do

    has_two_for_one =
      game.board.harbors
      |> Enum.any?(fn
        {_, :three_for_one} -> false
        {corner, {:two_for_one, ^player_resource}} ->
          case game.buildings[corner] do
            nil -> false
            {_, color} -> color == player
          end
        {_, {:two_for_one, _}} -> false
      end)

    if not has_two_for_one do
      {:error, :no_harbor}
    else
      _trade_with_bank(game, player_resource, amount, bank_resource)
    end
  end

  def trade_with_bank(%Game{state: {:ongoing, :trading, _}}, _player_resource, _amount, _bank_resource) do
    {:error, :invalid_amount}
  end

  def trade_with_bank(_, _, _, _) do
    {:error, :invalid_state}
  end

  @spec negate_resources([{T.resource(), integer()}]) :: [{T.resource(), integer()}]
  defp negate_resources(resources) do
    resources
    |> Enum.map(fn {res, amt} -> {res, -amt} end)
  end

  @spec transfer_resources(Game.t(), T.color(), T.color(), [{T.resource(), integer()}]) :: T.result(Game.t())
  defp transfer_resources(game, from_player, to_player, resources) do
    with {:ok, game} <- update_player_resources(game, from_player, negate_resources(resources)),
         {:ok, game} <- update_player_resources(game, to_player, resources)
    do
      {:ok, game}
    end
  end

  @spec trade_with_player(Game.t(), T.color(), [{T.resource(), integer()}], [{T.resource(), integer()}]) :: T.result(Game.t())
  def trade_with_player(
    %Game{state: {:ongoing, :trading, [player|_]}} = game,
    other_player, resources_given, resources_received
  ) do
    cond do
      player == other_player ->
        {:error, :trading_with_yourself}

      resources_given == [] or resources_received == [] ->
        {:error, :trading_for_free}

      not MapSet.disjoint?(
        resources_given |> MapSet.new(&elem(&1, 0)),
        resources_received |> MapSet.new(&elem(&1, 0))
      ) ->
        {:error, :trading_same}

      true ->
        with {:ok, game} <- transfer_resources(game, player, other_player, resources_given) do
          transfer_resources(game, other_player, player, resources_received)
        end
    end
  end

  @spec finish_trading(Game.t()) :: Game.t()
  def finish_trading(%Game{state: {:ongoing, :trading, queue}} = game) do
    %{game | state: {:ongoing, :building, queue}}
  end

  @spec choose_stolen_cards(Game.t(), T.color(), [{T.resource(), integer()}]) :: T.result(Game.t())
  def choose_stolen_cards(
    %Game{state: {:ongoing, {:choosing_stolen_cards, players_remaining}, queue}} = game,
    player, cards
  ) do
    num_given_cards =
      cards
      |> Enum.map(fn {_, amount} -> amount end)
      |> Enum.sum()
    num_want_cards =
      div(Player.number_of_resource_cards(game.players[player]), 2)

    cond do
      player not in players_remaining ->
        {:error, :no_stolen_cards}

      num_given_cards != num_want_cards ->
        {:error, :invalid_card_amount}

      true ->
        with {:ok, game} <- update_player_resources(game, player, negate_resources(cards)) do
          players_remaining = List.delete(players_remaining, player)
          next_stage =
            if players_remaining == [] do
              :moving_robber
            else
              {:choosing_stolen_cards, players_remaining}
            end
          {:ok, %{game | state: {:ongoing, next_stage, queue}}}
        end
    end
  end

  @spec move_robber(Game.t(), T.tile(), T.color() | nil) :: T.result(Game.t())
  def move_robber(
    %Game{state: {:ongoing, :moving_robber, queue}} = game,
    tile, player_to_steal
  ) do
    with {:ok, game} <- _move_robber(game, tile, player_to_steal) do
      {:ok, %{game | state: {:ongoing, :trading, queue}}}
    end
  end

  @spec _move_robber(Game.t(), T.tile(), T.color() | nil) :: T.result(Game.t())
  defp _move_robber(%Game{state: {:ongoing, _, [player|_]}}=game, tile, player_to_steal) do
    adjacent_building_colors =
      Graphs.tile_corners[tile]
      |> Stream.flat_map(fn corner ->
        case game.buildings[corner] do
          nil -> []
          {_kind, color} -> [color]
        end
      end)

    cond do
      tile == game.robber_tile ->
        {:error, :robber_unmoved}

      player == player_to_steal ->
        {:error, :stealing_yourself}

      player_to_steal && player_to_steal not in adjacent_building_colors ->
        {:error, :player_to_steal_not_adjacent}

      true ->
        game = %{game | robber_tile: tile}
        stealable_resources =
          if player_to_steal do
            game.players[player_to_steal].resources
            |> Enum.flat_map(fn {resource, amount} -> List.duplicate(resource, amount) end)
          else
            []
          end
        if stealable_resources == [] do
          {:ok, game}
        else
          # O(n) due to linked list
          stolen_resource = Enum.at(stealable_resources, :rand.uniform(length(stealable_resources)) - 1)
          transfer_resources(game, player_to_steal, player, [{stolen_resource, 1}])
        end
    end
  end

  @spec place_road_adjacent(Game.t(), T.color(), T.side()) :: T.result(Game.t())
  defp place_road_adjacent(game, player, side) do
    if player not in side_adjacent_roads(game, side) do
      {:error, :no_adjacent_roads}
    else
      place_road_arbitrary(game, player, side)
    end
  end

  @spec build_road(Game.t(), T.side()) :: T.result(Game.t())
  def build_road(
    %Game{state: {:ongoing, :building, [player|_]}} = game,
    side
  ) do
    with {:ok, game} = place_road_adjacent(game, player, side) do
      update_player_resources(game, player, T.cost(:road))
    end
  end

  @spec place_settlement_adjacent(Game.t(), T.color(), T.corner()) :: T.result(Game.t())
  defp place_settlement_adjacent(game, player, corner) do
    if player not in corner_adjacent_roads(game, corner) do
      {:error, :no_adjacent_roads}
    else
      place_settlement_arbitrary(game, player, corner)
    end
  end

  @spec build_settlement(Game.t(), T.corner()) :: T.result(Game.t())
  def build_settlement(
    %Game{state: {:ongoing, :building, [player|_]}} = game,
    corner
  ) do
    with {:ok, game} <- place_settlement_adjacent(game, player, corner) do
      update_player_resources(game, player, T.cost(:settlement))
    end
  end

  @spec build_city(Game.t(), T.corner()) :: T.result(Game.t())
  def build_city(
    %Game{state: {:ongoing, :building, [player|_]}} = game,
    corner
  ) do
    case game.buildings[corner] do
      nil ->
        {:error, :no_settlement}

      {:city, _} ->
        {:error, :occupied}

      {_, building_color} when building_color != player ->
        {:error, :settlement_not_yours}

      {:settlement, ^player} ->
        with {:ok, game} <- update_player_resources(game, player, T.cost(:city)),
             {:ok, game} <- update_player_piece(game, player, :city, -1)
        do
          {:ok, put_in(game.buildings[corner], {:city, player})}
        end
    end
  end

  @spec pop_development_card(Game.t()) :: T.result({T.development_card(), T.game()})
  defp pop_development_card(game) do
    case game.development_card_stack do
      [] ->
        {:error, :no_development_cards_left}
      [card | rest] ->
        {:ok, {card, %{game | development_card_stack: rest}}}
    end
  end

  @spec buy_development_card(Game.t()) :: T.result(Game.t())
  def buy_development_card(
    %Game{state: {:ongoing, :building, [player|_]}} = game
  ) do
    with {:ok, {card, game}} <- pop_development_card(game),
         {:ok, game} <- update_player_resources(game, player, T.cost(:development_card))
    do
      {:ok, update_in(game.new_development_cards, &[card | &1])}
    end
  end

  defguard allows_development_card(stage)
  when stage in [:trading, :building, :moving_robber]

  @spec remove_development_card(Game.t(), T.color(), T.development_card()) :: T.result(Game.t())
  defp remove_development_card(game, player, card) do
    T.update_nonnegative(game.players[player].development_cards[card], -1)
  end

  @spec use_knight_card(Game.t(), T.tile(), T.color()) :: T.result(Game.t())
  def use_knight_card(
    %Game{state: {:ongoing, stage, [player|_]}} = game,
    robber_tile, player_to_steal
  ) when allows_development_card(stage) do
    with {:ok, game} <- T.update_nonnegative(game.players[player].development_cards[:knight], -1) do
      game = update_in(game.players[player].used_knight_cards, &(&1 + 1))
      _move_robber(game, robber_tile, player_to_steal)
    end
  end

  @spec use_monopoly_card(Game.t(), T.resource()) :: T.result(Game.t())
  def use_monopoly_card(
    %Game{state: {:ongoing, stage, [thief|_]}} = game,
    resource
  ) when allows_development_card(stage) do
    with {:ok, game} <- remove_development_card(game, thief, :monopoly) do
      total =
        game.players
        |> Enum.map(fn {_, player} -> player.resources[resource] end)
        |> Enum.sum()
      game =
        Enum.reduce(game.player_order, game, fn color, game ->
          put_in(game.players[color].resources[resource], 0)
        end)
      {:ok, put_in(game.players[thief].resources[resource], total)}
    end
  end

  @spec use_road_building_card(Game.t(), T.side(), T.side()) :: T.result(Game.t())
  def use_road_building_card(
    %Game{state: {:ongoing, stage, [player|_]}} = game,
    side1, side2
  ) when allows_development_card(stage) do
    with {:ok, game} <- remove_development_card(game, player, :road_building) do
      # HACK: Currently we can't _just_ place side1 then side2, because while side2 may
      # be adjacent to some road, side1 may be adjacent only to side2 which doesn't exist yet,
      # so it fails. To bypass this, we attempt to put the roads in one order then the other.

      attempt =
        with {:ok, game} <- place_road_adjacent(game, player, side1) do
          place_road_adjacent(game, player, side2)
        end

      case attempt do
        {:error, :no_adjacent_roads} ->
          with {:ok, game} <- place_road_adjacent(game, player, side2) do
            place_road_adjacent(game, player, side1)
          end
        result ->
          result
      end
    end
  end

  @spec use_year_of_plenty_card(Game.t(), T.resource(), T.resource()) :: T.result(Game.t())
  def use_year_of_plenty_card(
    %Game{state: {:ongoing, stage, [player|_]}} = game,
    resource1, resource2
  ) when allows_development_card(stage) do
    with {:ok, game} <- remove_development_card(game, player, :year_of_plenty) do
      update_player_resources(game, player, [{resource1, 1}, {resource2, 1}])
    end
  end

end
