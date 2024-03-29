defmodule Catan.Model.Graphs do
  alias Catan.Model.T

  @spec corner_sides() :: %{T.corner() => [{T.side(), T.corner()}]}
  def corner_sides() do
    %{
      1 => [{1, 4}, {2, 5}],
      2 => [{3, 5}, {4, 6}],
      3 => [{5, 6}, {6, 7}],

      4 => [{1, 1}, {7, 8}],
      5 => [{2, 1}, {3, 2}, {8, 9}],
      6 => [{4, 2}, {5, 3}, {9, 10}],
      7 => [{6, 3}, {10, 11}],

      8 => [{7, 4}, {11, 12}, {12, 13}],
      9 => [{8, 5}, {13, 13}, {14, 14}],
      10 => [{9, 6}, {15, 14}, {16, 15}],
      11 => [{10, 7}, {17, 15}, {18, 16}],

      12 => [{11, 8}, {19, 17}],
      13 => [{12, 8}, {13, 9}, {20, 18}],
      14 => [{14, 9}, {15, 10}, {21, 19}],
      15 => [{16, 10}, {17, 11}, {22, 20}],
      16 => [{18, 11}, {23, 21}],

      17 => [{19, 12}, {24, 22}, {25, 23}],
      18 => [{20, 13}, {26, 23}, {27, 24}],
      19 => [{21, 14}, {28, 24}, {29, 25}],
      20 => [{22, 15}, {30, 25}, {31, 26}],
      21 => [{23, 16}, {32, 26}, {33, 27}],

      22 => [{24, 17}, {34, 28}],
      23 => [{25, 17}, {26, 18}, {35, 29}],
      24 => [{27, 18}, {28, 19}, {36, 30}],
      25 => [{29, 19}, {30, 20}, {37, 31}],
      26 => [{31, 20}, {32, 21}, {38, 32}],
      27 => [{33, 21}, {39, 33}],

      28 => [{34, 22}, {40, 34}],
      29 => [{35, 23}, {41, 34}, {42, 35}],
      30 => [{36, 24}, {43, 35}, {44, 36}],
      31 => [{37, 25}, {45, 36}, {46, 37}],
      32 => [{38, 26}, {47, 37}, {48, 38}],
      33 => [{39, 27}, {49, 38}],

      34 => [{40, 28}, {41, 29}, {50, 39}],
      35 => [{42, 29}, {43, 30}, {51, 40}],
      36 => [{44, 30}, {45, 31}, {52, 41}],
      37 => [{46, 31}, {47, 32}, {53, 42}],
      38 => [{48, 32}, {49, 33}, {54, 43}],

      39 => [{50, 34}, {55, 44}],
      40 => [{51, 35}, {56, 44}, {57, 45}],
      41 => [{52, 36}, {58, 45}, {59, 46}],
      42 => [{53, 37}, {60, 46}, {61, 47}],
      43 => [{54, 38}, {62, 47}],

      44 => [{55, 39}, {56, 40}, {63, 48}],
      45 => [{57, 40}, {58, 41}, {64, 49}],
      46 => [{59, 41}, {60, 42}, {65, 50}],
      47 => [{61, 42}, {62, 43}, {66, 51}],

      48 => [{63, 44}, {67, 52}],
      49 => [{64, 45}, {68, 52}, {69, 53}],
      50 => [{65, 46}, {70, 53}, {71, 54}],
      51 => [{66, 47}, {72, 54}],

      52 => [{67, 48}, {68, 49}],
      53 => [{69, 49}, {70, 50}],
      54 => [{71, 50}, {72, 51}],
    }
  end

  @spec tile_corners() :: %{T.tile() => [T.corner()]}
  def tile_corners() do
    %{
      1 => [1, 4, 5, 8, 9, 12],
      2 => [2, 5, 6, 9, 10, 14],
      3 => [3, 6, 7, 10, 11, 15],
      4 => [8, 12, 13, 17, 18, 23],
      5 => [9, 12, 14, 18, 19, 24],
      6 => [10, 14, 15, 19, 20, 25],
      7 => [11, 15, 16, 20, 21, 26],
      8 => [17, 22, 23, 28, 29, 34],
      9 => [18, 23, 24, 29, 30, 35],
      10 => [19, 24, 25, 30, 31, 36],
      11 => [20, 25, 26, 31, 32, 37],
      12 => [21, 26, 27, 32, 33, 38],
      13 => [29, 34, 35, 39, 40, 44],
      14 => [30, 35, 36, 40, 41, 45],
      15 => [31, 36, 37, 41, 42, 46],
      16 => [32, 37, 38, 42, 43, 47],
      17 => [40, 44, 45, 48, 49, 52],
      18 => [41, 45, 46, 49, 50, 53],
      19 => [42, 46, 47, 50, 51, 54],
    }
  end

  @spec corner_tiles() :: %{T.corner() => [T.tile()]}
  def corner_tiles() do
    %{
      1 => [1],
      2 => [2],
      3 => [3],
      4 => [1],
      5 => [1, 2],
      6 => [2, 3],
      7 => [3],
      8 => [1, 4],
      9 => [1, 2, 5],
      10 => [2, 3, 6],
      11 => [3, 7],
      12 => [1, 4, 5],
      13 => [4],
      14 => [2, 5, 6],
      15 => [3, 6, 7],
      16 => [7],
      17 => [4, 8],
      18 => [4, 5, 9],
      19 => [5, 6, 10],
      20 => [6, 7, 11],
      21 => [7, 12],
      22 => [8],
      23 => [4, 8, 9],
      24 => [5, 9, 10],
      25 => [6, 10, 11],
      26 => [7, 11, 12],
      27 => [12],
      28 => [8],
      29 => [8, 9, 13],
      30 => [9, 10, 14],
      31 => [10, 11, 15],
      32 => [11, 12, 16],
      33 => [12],
      34 => [8, 13],
      35 => [9, 13, 14],
      36 => [10, 14, 15],
      37 => [11, 15, 16],
      38 => [12, 16],
      39 => [13],
      40 => [13, 14, 17],
      41 => [14, 15, 18],
      42 => [15, 16, 19],
      43 => [16],
      44 => [13, 17],
      45 => [14, 17, 18],
      46 => [15, 18, 19],
      47 => [16, 19],
      48 => [17],
      49 => [17, 18],
      50 => [18, 19],
      51 => [19],
      52 => [17],
      53 => [18],
      54 => [19],
    }
  end

  def side_corners() do
    %{
      1 => [4, 1],
      2 => [5, 1],
      3 => [5, 2],
      4 => [2, 6],
      5 => [3, 6],
      6 => [3, 7],
      7 => [4, 8],
      8 => [5, 9],
      9 => [10, 6],
      10 => [7, 11],
      11 => [8, 12],
      12 => [8, 13],
      13 => [13, 9],
      14 => [14, 9],
      15 => [10, 14],
      16 => [10, 15],
      17 => [15, 11],
      18 => [16, 11],
      19 => [17, 12],
      20 => [18, 13],
      21 => [19, 14],
      22 => [15, 20],
      23 => [16, 21],
      24 => [22, 17],
      25 => [17, 23],
      26 => [18, 23],
      27 => [18, 24],
      28 => [19, 24],
      29 => [19, 25],
      30 => [20, 25],
      31 => [20, 26],
      32 => [21, 26],
      33 => [27, 21],
      34 => [22, 28],
      35 => [29, 23],
      36 => [24, 30],
      37 => [25, 31],
      38 => [32, 26],
      39 => [27, 33],
      40 => [28, 34],
      41 => [34, 29],
      42 => [35, 29],
      43 => [35, 30],
      44 => [36, 30],
      45 => [36, 31],
      46 => [37, 31],
      47 => [32, 37],
      48 => [38, 32],
      49 => [38, 33],
      50 => [34, 39],
      51 => [35, 40],
      52 => [36, 41],
      53 => [42, 37],
      54 => [38, 43],
      55 => [39, 44],
      56 => [40, 44],
      57 => [40, 45],
      58 => [41, 45],
      59 => [41, 46],
      60 => [42, 46],
      61 => [42, 47],
      62 => [43, 47],
      63 => [48, 44],
      64 => [49, 45],
      65 => [50, 46],
      66 => [51, 47],
      67 => [52, 48],
      68 => [49, 52],
      69 => [49, 53],
      70 => [50, 53],
      71 => [54, 50],
      72 => [54, 51],
    }
  end
end
