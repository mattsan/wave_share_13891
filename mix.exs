defmodule WaveShare13891.MixProject do
  use Mix.Project

  def project do
    [
      app: :wave_share_13891,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {WaveShare13891.Application, []}
    ]
  end

  defp deps do
    [
      {:circuits_gpio, "~> 0.4.1"},
      {:circuits_spi, "~> 0.1.3"}
    ]
  end
end
