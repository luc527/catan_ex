defmodule Catan.Model.RoadGraph do
  alias Catan.Model.Graphs
  alias Catan.Model.T
  alias Catan.Model.Game

  @type road_graph() :: %{T.side() => MapSet.t(T.side())}

  @spec new(Game.t(), T.color()) :: road_graph()
  def new(game, player) do
    for {side0, color} <- game.roads, color == player, into: %{} do
      adjacent_sides =
        for corner <- Graphs.side_corners[side0],
            {side1, _} <- Graphs.corner_sides[corner],
            side1 != side0,
            game.roads[side1] == player,
            into: MapSet.new() do
          side1
        end
      {side0, adjacent_sides}
    end
  end

  defp sinks_step(_graph, _stack=[], _visited, sinks), do: sinks
  defp sinks_step(graph, [side | rest], visited, sinks) do
    if side in visited do
      sinks_step(graph, rest, visited, sinks)
    else
      next_visited = MapSet.put(visited, side)
      graph[side]
      |> MapSet.difference(visited)
      |> MapSet.to_list()
      |> case do
        [] ->
          # This is a sink
          sinks_step(graph, rest, next_visited, [side | sinks])
        children ->
          sinks_step(graph, children ++ rest, next_visited, sinks)
      end
    end
  end

  @doc """
  If you have A <--> B <--> C <--> D,
  where A, B, C and D are corners and <--> are roads built between them,
  you can't start the search for road sequences on BC, because it's in the middle:
  the search would yield the sequences [BC, AB] and [BC, CD] and not [AB, BC, CD],
  which is the expected result. Therefore, you have to start either on AB or CD.
  This function returns roads that are appropriate for the beginning of a search.
  """
  @spec sinks(road_graph()) :: [T.side()]
  def sinks(graph) when map_size(graph) == 0, do: []
  def sinks(graph) do
    stack   = Map.keys(graph)
    visited = MapSet.new()
    sinks_step(graph, stack, visited, [])
  end

  defp paths_from(graph, side, visited, ignore) do
    if side in visited do
      {[], visited}
    else
      visited = MapSet.put(visited, side)
      graph[side]
      |> MapSet.difference(visited)
      |> MapSet.difference(ignore)  # To avoid backtracking
      |> Enum.map(&paths_from(graph, &1, visited, graph[side]))
      |> case do
        [] ->
          {[[side]], visited}
        results ->
          paths =
            for {subpaths, _} <- results, subpath <- subpaths do
              [side | subpath]
            end
          visited =
            results
            |> Enum.map(fn {_, visited} -> visited end)
            |> Enum.reduce(MapSet.new(), &MapSet.union/2)
          {paths, visited}
      end
    end
  end

  defp paths_step(_graph, []=_to_visit, _visited, acc), do: acc
  defp paths_step(graph, [side | to_visit], visited, acc) do
    {paths, visited} = paths_from(graph, side, visited, MapSet.new())
    paths_step(graph, to_visit, visited, paths ++ acc)
  end

  def paths(graph) do
    paths_step(graph, sinks(graph), MapSet.new(), [])
  end

  @spec longest_road_length(Game.t(), T.color()) :: integer()
  def longest_road_length(game, player) do
    new(game, player)
    |> paths()
    |> Enum.map(&length(&1))
    |> Enum.max()
  end

end
