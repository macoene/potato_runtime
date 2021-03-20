defmodule Potato.MixProject do
  use Mix.Project

  def project do
    [
      app: :potato,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Potato.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:observables, git: "https://github.com/macoene/observables", branch: "master"}
    ]
  end
end
