defmodule Etcd do
  require Logger

  alias Etcd.Connection
  alias Etcd.Node
  alias Etcd.ServerError

  def dir(srv, _root, recursive \\ false) do
    ls!(srv, false, true, recursive)
  end

  def keys(srv, _root, recursive \\ false) do
    ls!(srv, true, false, recursive)
  end

  def ls!(srv, root, allow_leaf \\ true, allow_node \\ true, recursive \\ false) do
    case get!(srv, root, recursive: recursive) do
      %Node{dir: true, nodes: nodes} ->
        nodes
        |> Enum.flat_map(&flat_node/1)
        |> Enum.filter(fn
          %Node{dir: true} -> allow_node
          %Node{dir: false} -> allow_leaf
        end)

      node ->
        [node]
    end
  end

  defp flat_node(%Node{dir: false} = leaf), do: [leaf]
  defp flat_node(%Node{dir: true} = node), do: [node | Enum.flat_map(node.nodes, &flat_node/1)]

  def get?(srv, key, opts \\ []) do
    try do
      get!(srv, key, opts)
    rescue
      ServerError -> nil
    end
  end

  def get!(srv, key, query \\ []) do
    Node.from_map(raw_get!(srv, key, query))
  end

  def getAll!(srv, key \\ "/") do
    get!(srv, key, recursive: true)
  end

  defp raw_get!(srv, key, query) do
    %{"node" => node} = request!(srv, :get, key, query, [])
    node
  end

  def put!(srv, key, value, body \\ []) do
    body = Map.merge(body, :value, value)
    request!(srv, :put, key, [], body)
  end

  # for attomically assigning key values in a directory
  def put_in!(srv, folder, value, body \\ []) do
    body = Map.merge(body, :value, value)
    request!(srv, :post, folder, [], body)
  end

  # directories can have a ttl
  def mkdir!(srv, name, opts \\ []) do
    opts = Map.merge(opts, :dir, true)
    request!(srv, :put, name, opts, [])
  end

  def delete!(srv, key, body \\ []) do
    request!(srv, :delete, key, [], body)
  end

  def rmdir!(srv, key) do
    request!(srv, :delete, key, [recursive: true], [])
  end

  def wait!(srv, key, query \\ [], timeout \\ 10000) do
    query = Map.merge(query, :wait, true)
    request!(srv, :get, key, query, [], timeout)
  end

  def watch(_srv, _key, _opts) do
  end

  defp request!(srv, verb, key, query \\ [], body \\ [], timeout \\ 5000) do
    case Connection.request(srv, :sync, verb, key, query, body, timeout) do
      {:ok, %{"action" => _action} = reply, _} ->
        reply

      {:ok, %{"errorCode" => errCode, "message" => errMsg}, _} ->
        raise ServerError, code: errCode, message: errMsg

      {:error, e} ->
        raise e
    end
  end
end
