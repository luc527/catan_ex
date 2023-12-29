defmodule Catan.Model.T do
  @moduledoc """
  Paths, corners and tiles are numbered in reading order (top-to-bottom, left-to-right).
  """

  @type path()   :: 1..72
  @type corner() :: 1..54
  @type tile()   :: 1..19

  @type terrain()  :: :hills | :forest | :mountains | :fields | :pasture | :desert
  @type resource() :: :brick | :lumber | :ore       | :grain  | :wool

  @type dice_roll() :: 2..12
  @type token()     :: 2|3|4|5|6|8|9|10|11|12

  @type color() :: :red | :blue | :orange | :white

  @type building_kind() :: :settlement | :city
  @type building()      :: %{kind: building_kind(), color: color()}
  # TODO: eventually check if building() couldn't be just a tuple

  @type board_terrains()  :: %{tile() => terrain()}
  @type board_tokens()    :: %{tile() => token()}
  @type board_buildings() :: %{corner() => building()}
  @type board_roads()     :: %{path() => color()}

  @type victory_point_card() :: :library | :market | :chapel | :great_hall | :university
  @type progress_card()      :: :monopoly | :year_of_plenty | :road_building
  @type development_card()   :: victory_point_card() | progress_card() | :knight_card

  @type piece() :: :settlement | :city | :road

  @type game_state() ::
    {:foundation, round :: 1|2, player :: T.color(), queue :: [T.color()]}
    | {:ongoing, current_player :: T.color()}
    | {:won_by, winner :: T.color()}

  @spec tiles() :: T.tile()
  def tiles(), do: 1..19

  @spec corners() :: T.corner()
  def corners(), do: 1..54

  @spec paths() :: T.path()
  def paths(), do: 1..72

  @spec victory_point_cards() :: [T.victory_point_card()]
  def victory_point_cards(), do: [:library, :market, :chapel, :great_hall, :university]

  @spec progress_cards() :: [T.progress_card()]
  def progress_cards(), do: [:monopoly, :year_of_plenty, :road_building]

  @spec development_cards() :: [T.development_card()]
  def development_cards() do
    [:knight_card | (victory_point_cards() ++ progress_cards())]
  end

  @spec resources() :: [T.resource()]
  def resources(), do: [:brick, :lumber, :ore, :grain, :wool]

  @spec building_weight(T.building_kind()) :: integer()
  def building_weight(:settlement), do: 1
  def building_weight(:city), do: 2

  @spec terrain_resource(T.terrain()) :: T.resource()
  def terrain_resource(:hills), do: :brick
  def terrain_resource(:forest), do: :lumber
  def terrain_resource(:mountains), do: :ore
  def terrain_resource(:fields), do: :grain
  def terrain_resource(:pasture), do: :wool
  def terrain_resource(:desert), do: :nil


end
