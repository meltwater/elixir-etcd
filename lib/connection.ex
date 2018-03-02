defmodule Etcd.Connection do
  use GenServer

  require Logger

  alias Etcd.AsyncReply
  alias Etcd.Request

  @config Application.get_env(:etcd, :connection)

  defstruct schema: @config[:schema],
    hosts: @config[:hosts],
    prefix: @config[:prefix],
    ssl_options: @config[:ssl_options]

  def request(conn, mode, method, path, query, body, timeout \\ 5000) do
    GenServer.call(
      conn,
      %Request{mode: mode, method: method, path: path, query: query, body: body},
      timeout
    )
  end

  def request(conn, %Request{} = req, timeout \\ 5000) do
    GenServer.call(conn, req, timeout)
  end

  def start_link(uri) do
    GenServer.start_link(__MODULE__, uri)
  end

  def init(srv) do
    table = :ets.new(:requests, [:set, :private])
    {:ok, %{:server => srv, :table => table}}
  end

  def handle_call(req, from, ctx) do
    reply = mkreq(ctx, req, from)

    if req.mode == :async do
      {:reply, reply, ctx}
    else
      {:noreply, ctx}
    end
  rescue
    err ->
      Logger.error(
        "#{Exception.message(err)}\n#{Exception.format_stacktrace(System.stacktrace())}"
      )

      {:reply, {:error, err}, ctx}
  end

  def handle_info({:hackney_response, id, {:status, code, _reason}}, ctx) do
    update_resp(ctx, id, :status_code, code)
    {:noreply, ctx}
  end

  def handle_info({:hackney_response, id, {:headers, hdr}}, ctx) do
    update_resp(ctx, id, :headers, hdr)
    {:noreply, ctx}
  end

  def handle_info({:hackney_response, id, chunk}, ctx) when is_binary(chunk) do
    update_resp(ctx, id, :body, chunk, fn parts -> parts <> chunk end)
    {:noreply, ctx}
  end

  def handle_info({:hackney_response, id, :done}, ctx) do
    finish_resp(ctx, id, &process_response(ctx, &1, &2))
    {:noreply, ctx}
  end

  def handle_info({:hackney_response, id, {:redirect, to, _hdrs}}, ctx) do
    Logger.debug(fn ->
      "Redirecting #{inspect(id)} to #{to}"
    end)

    {:noreply, ctx}
  end

  def handle_info({:hackney_response, id, {:error, reason}}, ctx) do
    finish_resp(ctx, id, fn req, _resp ->
      reply(req, {:error, reason})
    end)

    {:noreply, ctx}
  end

  defp reply(req, reply) do
    case req.mode do
      :async ->
        pid =
          if req.stream_to do
            req.stream_to
          else
            elem(req.from, 0)
          end

        send(pid, %AsyncReply{id: req.id, reply: reply})

      :sync ->
        GenServer.reply(req.from, reply)
    end
  end

  defp finish_resp(ctx, id, cb) do
    case :ets.lookup(ctx.table, id) do
      [{^id, req, resp}] ->
        :ets.delete(ctx.table, id)
        cb.(req, resp)

      _ ->
        Logger.warn("Not found: #{inspect(id)}")
        :error
    end
  end

  defp update_resp(ctx, id, field, value, fun \\ nil) do
    fun = case fun do
            nil -> fn _any -> value end
            _ -> fun
          end

    case :ets.lookup(ctx.table, id) do
      [{^id, from, resp}] ->
        resp = Map.update(resp, field, value, fun)
        :ets.insert(ctx.table, {id, from, resp})

      _ ->
        Logger.warn("Not found: #{inspect(id)}")
        :error
    end
  end

  defp mkurl(ctx, req) do
    uri = ctx.server
    ret = uri.schema <> "://" <> hd(uri.hosts) <> uri.prefix <> req.path

    if req.query do
      ret <> "?" <> URI.encode_query(req.query)
    else
      ret
    end
  end

  defp mkhdrs(_ctx, req) do
    if req.body do
      Enum.into(req.headers, [{"Content-Type", "application/x-www-form-urlencoded"}])
    else
      req.headers
    end
  end

  defp mkbody(_ctx, req) do
    if req.body do
      URI.encode_query(req.body)
    else
      ""
    end
  end

  defp mkopts(ctx, opts) do
    uri = ctx.server

    opts
    |> Map.merge(:ssl_options, uri.ssl_options)
    |> Map.merge(:stream_to, self())
    |> Map.merge(:follow_redirect, true)
    |> Map.merge(:force_redirect, true)
    |> Map.merge(:async, true)
  end

  defp mkreq(ctx, req, from) do
    method = req.method
    url = mkurl(ctx, req)
    headers = mkhdrs(ctx, req)
    body = mkbody(ctx, req)
    options = mkopts(ctx, req.opts)

    Logger.debug("#{method} #{url} #{inspect(headers)} #{inspect(body)} #{inspect(options)}")

    case :hackney.request(method, url, headers, body, options) do
      {:ok, id} ->
        req = %{req | from: from, id: id}
        :ets.insert(ctx.table, {id, req, %{body: ""}})
        {:ok, id}

      {:error, e} ->
        raise e
    end
  end

  defp process_response(_ctx, req, resp) do
    Logger.debug("get #{resp.status_code}")
    body = JSX.decode!(resp.body)
    reply(req, {:ok, body, resp})
  rescue
    err ->
      Logger.error(
        "Bad response: #{inspect(resp)}\n#{Exception.message(err)}\n#{
          Exception.format_stacktrace(System.stacktrace())
        }"
      )

      reply(req, {:error, err})
  end
end
