defmodule Catan.Application do
  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Catan.RoomSupervisor},
      {Registry, keys: :unique, name: Catan.RoomRegistry},
    ]
    Supervisor.start_link(children, strategy: :one_for_all, name: __MODULE__)
  end
end
