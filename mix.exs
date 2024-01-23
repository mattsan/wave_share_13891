defmodule WaveShare13891.MixProject do
  use Mix.Project

  def project do
    [
      app: :wave_share_13891,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:circuits_gpio, "~> 2.0"},
      {:circuits_spi, "~> 2.0"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false}
    ]
  end

  def docs do
    [
      groups_for_functions: [
        Guards: & &1[:guard]
      ]
    ]
  end
end
