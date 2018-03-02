defmodule Etcd.Watcher do
  use GenServer

  require Logger

  def start_link(conn, key, opts) do
    GenServer.start_link(__MODULE__, %{
          conn: conn,
          key: key,
          opts: opts,
          id: nil,
          index: nil,
          notify: self()
                         })
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def init(ctx) do
    ctx = init_request(ctx)
    {:ok, ctx}
  end

  def handle_call(:stop, _, ctx) do
    {:stop, :normal, :ok, ctx}
  end

  def handle_info(%Etcd.AsyncReply{id: _id, reply: reply}, ctx) do
    case reply do
      {:ok, obj, _resp} ->
        Logger.debug(inspect(obj))
        node = obj["node"]
        index = node["modifiedIndex"]
        ctx = %{ctx | index: index}
        # :timer.sleep(1000)
        ctx = init_request(ctx)
        send(ctx.notify, {:watcher_notify, obj})
        {:noreply, ctx}

      {:error, {:closed, _}} ->
        Logger.debug("Connection closed, retry...")
        ctx = init_request(ctx)
        {:noreply, ctx}

      {:error, err} ->
        Logger.warn("Watcher error: #{inspect(err)}")
        send(ctx.notify, {:watcher_error, err})
        {:stop, err}
    end
  end

  defp init_request(ctx) do
    opts = if ctx.index do
      Map.merge(ctx.opts, :waitIndex, ctx.index + 1)
    else
      Map.merge(ctx.opts, :wait, true)
    end

    id = Etcd.Connection.request(ctx.conn, :async, :get, ctx.key, opts, [])
    %{ctx | id: id, opts: opts}
  end
end
