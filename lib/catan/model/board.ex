defmodule Catan.Model.Board do
  alias Catan.Model.{Board, T}

  defstruct [
    :terrains,
    :tokens,
    :harbors,
  ]

  @type t() :: %__MODULE__{
    terrains: %{T.tile() => T.terrain()},
    tokens:   %{T.tile() => T.token()},
    harbors:  %{T.corner() => T.harbor()}
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
      harbors: beginner_board_harbors(),
    }
  end

  @spec random_board_but_default_tokens() :: %Board{}
  def random_board_but_default_tokens() do
    terrains = random_terrains()
    tokens = default_tokens_for(terrains)
    %Board{
      terrains: terrains,
      tokens: tokens,
      harbors: random_harbors(),
    }
  end

  @spec available_harbors() :: [T.harbor()]
  def available_harbors() do
    Enum.concat([
      T.resources() |> Enum.map(&{:two_for_one, &1}),
      List.duplicate(:three_for_one, 4)
    ])
  end

  @spec harbor_corner_pairs() :: [{T.corner(), T.corner()}]
  def harbor_corner_pairs() do
    [
      {1, 4},
      {2, 6},
      {11, 16},
      {27, 33},
      {43, 47},
      {50, 53},
      {48, 52},
      {34, 39},
      {12, 17},
    ]
  end

  @spec random_harbors() :: %{T.corner() => T.harbor()}
  def random_harbors() do
    available_harbors()
    |> Enum.shuffle()
    |> Enum.zip(harbor_corner_pairs())
    |> Enum.flat_map(fn {harbor, {c1, c2}} -> [{c1, harbor}, {c2, harbor}] end)
    |> Map.new()
  end

  @spec beginner_board_harbors() :: %{T.corner() => T.harbor()}
  def beginner_board_harbors() do
    %{
      1 => :three_for_one,
      4 => :three_for_one,
      2 => {:two_for_one, :grain},
      6 => {:two_for_one, :grain},
      11 => {:two_for_one, :ore},
      16 => {:two_for_one, :ore},
      27 => :three_for_one,
      33 => :three_for_one,
      43 => {:two_for_one, :wool},
      47 => {:two_for_one, :wool},
      50 => :three_for_one,
      53 => :three_for_one,
      48 => :three_for_one,
      52 => :three_for_one,
      34 => {:two_for_one, :brick},
      39 => {:two_for_one, :brick},
      12 => {:two_for_one, :lumber},
      17 => {:two_for_one, :lumber},
    }
  end


  # TODO: random_tokens, but it would require that red tokens (8, 6) never be next to each other, so it's a little more difficult
  # TODO: then Board.random_full or something

end
