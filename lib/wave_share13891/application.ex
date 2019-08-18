defmodule WaveShare13891.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: WaveShare13891.Worker.start_link(arg)
      # {WaveShare13891.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WaveShare13891.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
