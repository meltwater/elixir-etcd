# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# You can configure for your application as:
#
#     config :etcd, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:etcd, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

config :etcd, :connection,
  schema: "http",
  hosts: ["127.0.0.1:2379"],
  prefix: "/v2/keys",
  ssl_options: []
