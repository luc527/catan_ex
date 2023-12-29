defmodule Catan.Model.Player do
  alias Catan.Model.T

  defstruct [
    :resources,
    :development_cards,
    :pieces,
  ]

  @type t() :: %__MODULE__{
    resources:           %{T.resource() => integer()},
    development_cards:   %{T.development_card() => integer()},
    pieces:              %{T.piece() => integer()}
  }

  def initial() do
    %__MODULE__{
      resources:
        T.resources()
        |> Enum.map(&{&1, 0})
        |> Enum.into(%{}),
      development_cards:
        T.development_cards()
        |> Enum.map(&{&1, 0})
        |> Enum.into(%{}),
      pieces: %{
        road: 15,
        settlement: 5,
        city: 4,
      }
    }
  end

  def update_resource(player, resource, amount) do
    update_in(player.resources[resource], &(&1 + amount))
  end

  def update_piece(player, piece, amount) do
    update_in(player.pieces[piece], &(&1 + amount))
  end

  def update_development_card(player, card, amount) do
    update_in(player.development_cards[card], &(&1 + amount))
  end

end
