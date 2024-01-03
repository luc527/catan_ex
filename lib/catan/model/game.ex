defmodule Catan.Model.Game do
  require Catan.Model.T
  alias Catan.Model.Graphs
  alias Catan.Model.Game
  alias Catan.Model.Player
  alias Catan.Model.Board
  alias Catan.Model.T

  defstruct [
    :board,
    :buildings,
    :roads,
    :player_order,

    :players,
    :state,
    :dice_roll,
  ]

  @type t() :: %__MODULE__ {
    board: %Board{},
    buildings: %{T.corner() => T.building()},
    roads: %{T.path() => T.color()},
    player_order: [T.color()],

    players: %{T.color() => %Player{}},
    state: T.game_state(),
    dice_roll: T.dice_roll()|nil,
  }

  defp as_result(game) do
    {:ok, game}
  end

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
         {:ok, game} <- add_roads(game, beginner_game_roads_for(players)),
         {:ok, game} <- add_settlements(game, beginner_game_settlements_for(players))
    do
      resources =
        beginner_game_producing_settlements_for(players)
        |> Stream.flat_map(fn {corner, player} ->
          Graphs.corner_tiles[corner]
          |> Stream.map(fn tile ->
            resource = T.terrain_resource(game.board.terrains[tile])
            {player, resource, 1}
          end)
        end)
      game
      |> distribute_resources(resources)
      |> ongoing_start_turn(players)
      |> as_result()
    end
  end

  @spec initial_game([T.color()], Board.t()) :: T.result(Game.t())
  def initial_game([_|_] = player_order, %Board{} = board) do
    cond do
      length(player_order) != length(Enum.uniq(player_order)) ->
        {:error, :repeated_players}
      Enum.any?(player_order, &(&1 not in T.colors())) ->
        {:error, :invalid_players}
      true ->
        {:ok, %Game{
          state: {:foundation, 1, player_order},
          board: board,
          player_order: player_order,
          players: player_order |> Map.new(&{&1, Player.initial()}),
          buildings: %{},
          roads: %{},
          dice_roll: nil,
        }}
    end
  end

  @spec add_roads(Game.t(), [{T.path(), T.color()}]) :: T.result(Game.t())
  defp add_roads(game, roads) do
    resduce(game, roads, fn {path, color}, game ->
      add_road(game, color, path)
    end)
  end

  @spec add_settlements(Game.t(), [{T.corner(), T.color()}]) :: T.result(Game.t())
  defp add_settlements(game, settlements) do
    resduce(game, settlements, fn {corner, color}, game ->
      add_settlement(game, color, corner)
    end)
  end

  @spec beginner_game_roads() :: [{T.path(), T.color()}]
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

  @spec beginner_game_roads_for([T.color()]) :: [{T.path(), T.color()}]
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

  @spec beginner_game_settlements_for([T.color()]) :: [{T.path(), T.color()}]
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

  @spec beginner_game_producing_settlements_for([T.color()]) :: [{T.path(), T.color()}]
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
    Graphs.corner_paths[corner]
    |> Enum.flat_map(fn {path, _} ->
      case game.roads[path] do
        nil -> []
        color -> [color]
      end
    end)
  end

  @spec path_adjacent_roads(Game.t(), T.path()) :: [T.color()]
  defp path_adjacent_roads(game, path) do
    Graphs.path_corners[path]
    |> Enum.flat_map(fn corner -> Graphs.corner_paths[corner] end)
    |> Enum.flat_map(fn {other_path, _} ->
      if other_path == path do
        []
      else
        case game.roads[other_path] do
          nil -> []
          road -> [road]
        end
      end
    end)
  end

  @spec adjacent_buildings(Game.t(), T.corner()) :: [T.building()]
  defp adjacent_buildings(game, corner) do
    Graphs.corner_paths[corner]
    |> Enum.flat_map(fn {_, other_corner} ->
      case game.buildings[other_corner] do
        nil -> []
        building -> [building]
      end
    end)
  end

  @spec add_settlement(Game.t(), T.color(), T.corner()) :: T.result(Game.t())
  defp add_settlement(game, player, corner) do
    cond do
      game.buildings[corner] ->
        {:error, :occupied}
      adjacent_buildings(game, corner) != [] ->
        {:error, :adjacent_building}
      true ->
        with {:ok, game} <- update_player_piece(game, player, :settlement, -1) do
          {:ok, put_in(game.buildings[corner], {:settlement, player})}
        end
    end
  end

  @spec add_road(Game.t(), T.color(), T.path()) :: T.result(Game.t())
  defp add_road(game, player, path) do
    if game.roads[path] do
      {:error, :occupied}
    else
      with {:ok, game} <- update_player_piece(game, player, :road, -1) do
        {:ok, put_in(game.roads[path], player)}
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
    |> Stream.map(fn {tile, _token} -> tile end)
  end

  @spec tile_resource_production(Game.t(), T.tile()) :: [{T.color(), T.resource(), integer()}]
  defp tile_resource_production(game, tile) do
    resource = T.terrain_resource(game.board.terrains[tile])
    Graphs.tile_corners[tile]
    |> Stream.flat_map(fn corner ->
      building = game.buildings[corner]
      case building do
        nil            -> []
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
    # TODO:
    # - consolidate new development cards
    # - update special card holders
    # - update victory points
    # - check for winner
    # if no winner, then start a new turn like below
    ongoing_start_turn(game, next_players ++ [prev_player])
  end

  @spec end_turn(Game.t()) :: Game.t()
  def end_turn(%Game{state: {:ongoing, stage, _}} = game)
  when stage == :trading or stage == :building
  do
    # Because finish_turn is private
    finish_turn(game)
  end


  @spec ongoing_start_turn(Game.t(), [T.color()]) :: Game.t()
  defp ongoing_start_turn(game, player_queue) do
    case roll = dice_roll() do
      7 ->
        %{game |
          state: {:ongoing, :moving_robber, player_queue},
          dice_roll: roll,
        }
      _ ->
        resources =
          affected_tiles(game, roll)
          |> Stream.flat_map(&tile_resource_production(game, &1))
        game = distribute_resources(game, resources)
        %{game |
          state: {:ongoing, :trading, player_queue},
          dice_roll: roll,
        }
      end
  end


  @spec place_starting_pieces(Game.t(), T.corner(), T.path()) :: T.result(Game.t())

  def place_starting_pieces(
    %Game{state: {:foundation, 1, [player|_]}} = game,
    settlement_corner, road_path
  ) do
    with {:ok, game} <- add_starting_pieces(game, player, settlement_corner, road_path) do
      {:ok, finish_turn(game)}
    end
  end

  def place_starting_pieces(
    %Game{state: {:foundation, 2, [player|_]}} = game,
    settlement_corner, road_path
  ) do
    with {:ok, game} <- add_starting_pieces(game, player, settlement_corner, road_path),
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


  @spec add_starting_pieces(Game.t(), T.color(), T.corner(), T.path()) :: T.result(Game.t())
  defp add_starting_pieces(game, player, corner, path) do
    adjacent_paths =
      Graphs.corner_paths[corner]
      |> Enum.map(&elem(&1, 0))
    if path not in adjacent_paths do
      {:error, :path_not_adjacent}
    else
      with {:ok, game} <- add_road(game, player, path),
           {:ok, game} <- add_settlement(game, player, corner)
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

  #amount==3: player needs 3:1 harbour
  #amount==2: player needs 2:1 harbour of the specific resource being traded

  def trade_with_bank(%Game{state: {:ongoing, :trading, _}}, _player_resource, _amount, _bank_resource) do
    {:error, :invalid_amount}
  end

  def trade_with_bank(_, _, _, _) do
    {:error, :invalid_state}
  end


  @spec transfer_resources(Game.t(), T.color(), T.color(), [{T.resource(), integer()}]) :: T.result(Game.t())
  defp transfer_resources(game, from_player, to_player, resources) do
    with {:ok, game} <- update_player_resources(
                          game,
                          from_player,
                          Stream.map(resources, fn {resource, amount} -> {resource, -amount} end))
    do
      update_player_resources(game, to_player, resources)
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

  # TODO deal with :moving_robber state

  @spec build_road(Game.t(), T.path()) :: T.result(Game.t())
  def build_road(
    %Game{state: {:ongoing, :building, [player|_]}} = game,
    path
  ) do
    if player not in path_adjacent_roads(game, path) do
      {:error, :no_adjacent_roads}
    else
      with {:ok, game} <- add_road(game, player, path) do
        update_player_resources(game, player, T.cost(:road))
      end
    end
  end

  @spec build_settlement(Game.t(), T.corner()) :: T.result(Game.t())
  def build_settlement(
    %Game{state: {:ongoing, :building, [player|_]}} = game,
    corner
  ) do
    if player not in corner_adjacent_roads(game, corner) do
      {:error, :no_adjacent_roads}
    else
      with {:ok, game} <- add_settlement(game, player, corner) do
        update_player_resources(game, player, T.cost(:settlement))
      end
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

end
