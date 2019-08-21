defmodule WaveShare13891.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: Registry.WaveShare13891},
      WaveShare13891.KeyEvent,
      WaveShare13891.GPIO
    ]

    opts = [strategy: :one_for_one, name: WaveShare13891.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
