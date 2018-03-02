defmodule Etcd.Request do
  defstruct mode: :sync,
    method: :get,
    path: nil,
    query: nil,
    body: nil,
    headers: [],
    opts: [],
    id: nil,
    from: nil,
    stream_to: nil
end
