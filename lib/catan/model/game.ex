defmodule Catan.Model.Game do
  alias Catan.Model.{Player, T, Board}

  defstruct [
    :state,
    :board,
    :players,
    :buildings,
    :roads,
    :player_order,
    :longest_road_card_holder,
    :largest_army_card_holder,
    :development_card_stack,
  ]

  @type t() :: %__MODULE__{
    state:                    T.game_state(),
    board:                    Board.t(),
    players:                  %{T.color() => Player.t()},
    buildings:                %{T.corner() => T.building()},
    roads:                    %{T.path() => T.color()},
    player_order:             [T.color()],
    longest_road_card_holder: T.color() | nil,
    largest_army_card_holder: T.color() | nil,
    development_card_stack:   [T.development_card()],
  }

  def update_player_resource(game, player, resource, amount) do
    update_in(game.players[player], &Player.update_resource(&1, resource, amount))
  end

  def update_player_piece(game, player, piece, amount) do
    update_in(game.players[player], &Player.update_piece(&1, piece, amount))
  end

  def update_player_development_card(game, player, card, amount) do
    update_in(game.players[player], &Player.update_development_card(&1, card, amount))
  end

  def add_building(game, corner, building) do
    game
    |> update_player_piece(building.color, building.kind, -1)
    |> put_building(corner, building)
  end

  def put_building(game, corner, building) do
    put_in(game.buildings[corner], building)
  end

  def add_road(game, path, color) do
    game
    |> update_player_piece(color, :road, -1)
    |> put_road(path, color)
  end

  def put_road(game, path, color) do
    put_in(game.roads[path], color)
  end

  def initial(board, player_order) do
    %__MODULE__{
      state: {:foundation, 1, hd(player_order), player_order},
      board: board,
      players:
        player_order
        |> Stream.map(&{&1, Player.initial()})
        |> Enum.into(%{}),
      buildings: %{},
      roads: %{},
      player_order: player_order,
      longest_road_card_holder: nil,
      largest_army_card_holder: nil,
      development_card_stack:
        Enum.shuffle(
          Enum.concat([
            T.victory_point_cards(),
            List.duplicate(:knight_card, 14),
            T.progress_cards() |> Enum.flat_map(&List.duplicate(&1, 2))
          ])
        )
    }
  end

  def beginner_buildings() do
    [
      {9, %{kind: :settlement, color: :red}},
      {15, %{kind: :settlement, color: :orange}},
      {18, %{kind: :settlement, color: :white}},
      {29, %{kind: :settlement, color: :red}},
      {32, %{kind: :settlement, color: :white}},
      {40, %{kind: :settlement, color: :blue}},
      {41, %{kind: :settlement, color: :orange}},
      {42, %{kind: :settlement, color: :blue}},
    ]
  end

  def beginner_buildings_for(players) do
    beginner_buildings()
    |> Enum.filter(fn {_, %{color: color}} -> color in players end)
  end

  def beginner_roads() do
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

  def beginner_roads_for(players) do
    beginner_roads()
    |> Enum.filter(fn {_, color} -> color in players end)
  end

  def set_state(game, state) do
    %{game | state: state}
  end

  def add_buildings(game, buildings) do
    buildings
    |> Enum.reduce(game, fn {corner, building}, game ->
      add_building(game, corner, building)
    end)
  end

  def add_roads(game, roads) do
    roads
    |> Enum.reduce(game, fn {path, color}, game ->
      add_road(game, path, color)
    end)
  end

  def beginner(player_order) do
    initial(Board.beginner(), player_order)
    |> set_state({:ongoing, hd(player_order)})
    |> add_buildings(beginner_buildings_for(player_order))
    |> add_roads(beginner_roads_for(player_order))
  end
end
