defmodule PotatoExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :potato_example,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :potato]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:observables, git: "https://github.com/macoene/observables", branch: "master"},
      {:potato, path: "/home/teamx11/potato_thesis/potato_runtime/examples/deps/potato"}
    ]
  end
end
