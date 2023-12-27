defmodule Catan.Model.Board do
  defstruct terrains: %{}, pieces: %{}, buildings: %{}, roads: %{}

  alias Catan.Model.{Board, T}

  @spec available_terrains() :: [T.terrain()]
  defp available_terrains() do
    Enum.concat([
      [:desert],
      List.duplicate(:hills, 3),
      List.duplicate(:mountains, 3),
      List.duplicate(:forest, 4),
      List.duplicate(:fields, 4),
      List.duplicate(:pasture, 4),
    ])
  end

  @spec beginner_terrains() :: T.board_terrains()
  def beginner_terrains() do
    %{
      1 => :mountains,
      2 => :pasture,
      3 => :forest,
      4 => :fields,
      5 => :hills,
      6 => :pasture,
      7 => :hills,
      8 => :fields,
      9 => :forest,
      10 => :desert,
      11 => :forest,
      12 => :mountains,
      13 => :forest,
      14 => :mountains,
      15 => :fields,
      16 => :pasture,
      17 => :hills,
      18 => :fields,
      19 => :pasture,
    }
  end

  @spec beginner_pieces() :: T.board_pieces()
  def beginner_pieces() do
    %{
      1 => 10,
      2 => 2,
      3 => 9,
      4 => 12,
      5 => 6,
      6 => 4,
      7 => 10,
      8 => 9,
      9 => 11,
      # 10 is desert
      11 => 3,
      12 => 8,
      13 => 8,
      14 => 3,
      15 => 4,
      16 => 5,
      17 => 5,
      18 => 6,
      19 => 11,
    }
  end

  @spec beginner_buildings() :: T.board_buildings()
  def beginner_buildings() do
    %{
      9 => %{kind: :settlement, color: :red},
      15 => %{kind: :settlement, color: :orange},
      18 => %{kind: :settlement, color: :white},
      29 => %{kind: :settlement, color: :red},
      32 => %{kind: :settlement, color: :white},
      40 => %{kind: :settlement, color: :blue},
      41 => %{kind: :settlement, color: :orange},
      42 => %{kind: :settlement, color: :blue},
    }
  end

  @spec beginner_roads() :: T.board_roads()
  def beginner_roads() do
    %{
      14 => :red,
      16 => :orange,
      26 => :white,
      38 => :white,
      42 => :red,
      53 => :blue,
      57 => :blue,
      59 => :orange,
    }
  end

  @spec random_terrains() :: T.board_terrains()
  def random_terrains() do
    T.tiles()
    |> Stream.zip(Enum.shuffle(available_terrains()))
    |> Enum.into(%{})
  end

  @spec default_pieces_for(T.board_terrains()) :: T.board_pieces()
  def default_pieces_for(terrains) do
    tile_spiral    = [1, 4, 8, 13, 17, 18, 19, 16, 12, 7, 3, 2, 5, 9, 14, 15, 11, 6, 10]
    default_pieces = [5, 2, 6, 3, 8, 10, 9, 12, 11, 4, 8, 10, 9, 4, 5, 6, 3, 11]

    tile_spiral
    |> Stream.reject(fn tile -> terrains[tile] == :desert end)
    |> Stream.zip(default_pieces)
    |> Enum.into(%{})
  end

  @spec beginner() :: %Board{}
  def beginner() do
    %Board{
      terrains: beginner_terrains(),
      pieces: beginner_pieces(),
      buildings: beginner_buildings(),
      roads: beginner_roads(),
    }
  end

  @spec random_empty() :: %Board{}
  def random_empty() do
    terrains = random_terrains()
    pieces   = default_pieces_for(terrains)
    %Board{
      terrains: terrains,
      pieces: pieces,
      buildings: %{},
      roads: %{},
    }
  end

  # TODO: random_pieces, but it would require that red pieces (8, 6) never be next to each other, so it's a little more difficult

  @spec add_building(%Board{}, T.corner(), T.color(), T.building_kind()) :: %Board{}
  def add_building(board, corner, color, kind) do
    put_in(board.buildings[corner], %{color: color, kind: kind})
  end

  @spec add_road(%Board{}, T.road(), T.color()) :: %Board{}
  def add_road(board, road, color) do
    put_in(board.roads[road], color)
  end

  @spec building_weight(T.building_kind()) :: integer()
  def building_weight(:settlement), do: 1
  def building_weight(:city), do: 2

  @spec terrain_resource(T.terrain()) :: T.resource()
  def terrain_resource(:hills), do: :brick
  def terrain_resource(:forest), do: :lumber
  def terrain_resource(:mountains), do: :ore
  def terrain_resource(:fields), do: :grain
  def terrain_resource(:pasture), do: :wool

end
