defmodule Catan.Model.Player do
  alias Catan.Model.T
  require T

  defstruct [
    :resources,
    :development_cards,
    :pieces,
    :victory_points,
    :used_knight_cards,
  ]

  @type t() :: %__MODULE__{
    resources:           %{T.resource() => integer()},
    development_cards:   %{T.development_card() => integer()},
    pieces:              %{T.piece() => integer()},
    victory_points:      integer(),
    used_knight_cards:   integer(),
  }

  def initial() do
    %__MODULE__{
      resources: T.resources() |> Map.new(&{&1, 0}),
      development_cards: T.development_cards() |> Map.new(&{&1, 0}),
      pieces: %{
        settlement: 5,
        road: 15,
        city: 4,
      },
      victory_points: 0,
      used_knight_cards: 0,
    }
  end

  def card_count(cards) do
    cards
    |> Map.values()
    |> Enum.sum()
  end



end
