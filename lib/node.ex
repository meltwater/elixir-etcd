defmodule Etcd.Node do
  defstruct dir: false,
            key: nil,
            nodes: [],
            createdIndex: nil,
            modifiedIndex: nil,
            ttl: nil,
            expiration: nil

  def from_map(map) do
    load_nodes(Enum.into(map, %Etcd.Node{}, fn {k, v} -> {String.to_existing_atom(k), v} end))
  end

  defp load_nodes(%{dir: false} = node), do: node
  defp load_nodes(%{dir: true} = node), do: %{node | nodes: load_nodes(node.nodes)}
  defp load_nodes(nil), do: nil
  defp load_nodes(lst) when is_list(lst), do: Enum.map(lst, &from_map/1)
end

defimpl Collectable, for: Etcd.Node do
  def into(original) do
    {original,
     fn
       node, {:cont, {k, v}} -> :maps.put(k, v, node)
       node, :done -> node
       _, :halt -> :ok
     end}
  end
end
