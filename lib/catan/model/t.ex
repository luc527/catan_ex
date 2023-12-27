defmodule Catan.Model.T do
  @moduledoc """
  Roads, corners and tiles are numbered in reading order (top-to-bottom, left-to-right).
  """

  @type road() :: 1..72
  @type corner() :: 1..54
  @type tile() :: 1..19

  @type terrain() :: :hills | :forest | :mountains | :fields | :pasture | :desert
  @type resource() :: :brick | :lumber | :ore | :grain | :wool

  @type dice_roll() :: 2..12

  @type piece() :: 2|3|4|5|6|8|9|10|11|12

  @type color() :: :red | :blue | :orange | :white

  @type building_kind() :: :settlement | :city
  @type building() :: %{kind: building_kind(), color: color()}

  @type board_terrains() :: %{tile() => terrain()}
  @type board_pieces() :: %{tile() => piece()}
  @type board_buildings() :: %{corner() => building()}
  @type board_roads() :: %{road() => color()}

  @spec tiles() :: T.tile()
  def tiles(), do: 1..19

  @spec corners() :: T.corner()
  def corners(), do: 1..54

  @spec roads() :: T.road()
  def roads(), do: 1..72
end
