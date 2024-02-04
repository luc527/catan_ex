defmodule Catan.Rooms do

  def create(num_players) do
    uuid = UUID.uuid4()
    child_spec = {Catan.Room, {num_players, uuid}}
    with {:ok, _pid} = DynamicSupervisor.start_child(Catan.RoomSupervisor, child_spec) do
      {:ok, uuid, Catan.Room.via_tuple(uuid)}
    end
  end

  def get(uuid) do
    if Registry.lookup(Catan.RoomRegistry, uuid) == [] do
      {:error, :not_found}
    else
      {:ok, Catan.Room.via_tuple(uuid)}
    end
  end

end
