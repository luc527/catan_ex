defmodule Catan.Model.Board do
  alias Catan.Model.{Board, T}

  # TODO: harbors

  defstruct [
    terrains: %{},
    tokens: %{},
  ]

  @type t() :: %__MODULE__{
    terrains: %{T.tile() => T.terrain()},
    tokens:   %{T.tile() => T.token()},
  }

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

  @spec beginner_board_terrains() :: %{T.tile() => T.terrain()}
  defp beginner_board_terrains() do
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

  @spec beginner_board_tokens() :: %{T.tile() => T.token()}
  defp beginner_board_tokens() do
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

  @spec random_terrains() :: %{T.tile() => T.terrain()}
  def random_terrains() do
    Stream.zip(T.tiles(), Enum.shuffle(available_terrains()))
    |> Map.new()
  end

  @spec default_tokens_for(%{T.tile() => T.terrain()}) :: %{T.tile() => T.token()}
  def default_tokens_for(terrains) do
    tile_spiral    = [1, 4, 8, 13, 17, 18, 19, 16, 12, 7, 3, 2, 5, 9, 14, 15, 11, 6, 10]
    default_tokens = [5, 2, 6, 3, 8, 10, 9, 12, 11, 4, 8, 10, 9, 4, 5, 6, 3, 11]

    tile_spiral
    |> Stream.reject(fn tile -> terrains[tile] == :desert end)
    |> Stream.zip(default_tokens)
    |> Map.new()
  end

  @spec beginner_board() :: %Board{}
  def beginner_board() do
    %Board{
      terrains: beginner_board_terrains(),
      tokens: beginner_board_tokens(),
    }
  end

  @spec random_board_but_default_tokens() :: %Board{}
  def random_board_but_default_tokens() do
    terrains = random_terrains()
    tokens = default_tokens_for(terrains)
    %Board{
      terrains: terrains,
      tokens: tokens,
    }
  end

  # TODO: random_tokens, but it would require that red tokens (8, 6) never be next to each other, so it's a little more difficult
  # TODO: then Board.random_full or something

end
