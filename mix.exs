defmodule ElixirEtcd.Mixfile do
  use Mix.Project

  def project do
    [
      app: :etcd,
      version: "0.1.0",
      elixir: "~> 1.5",
      description: desc(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :exjsx, :httpoison],
      env: [
        url: "http://127.0.0.1:2379",
        crt: "./etcd.crt",
        key: "./etcd.key",
        ca: "./ca.crt"
      ]
    ]
  end

  defp deps do
    [
      {:exjsx, "~> 4.0"},
      {:httpoison, "~> 1.0"},
      {:credo, "~> 0.8", only: :dev}
    ]
  end

  defp desc do
    """
    Etcd APIv2 Client for Elixir
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      contributors: ["Bearice Ren", "Jake Wilkins", "Yuan Yang", "Hans-Gunther Schmidt"],
      links: %{"Github" => "https://github.com/meltwater/elixir-etcd"}
    ]
  end
end
