defmodule WaveShare13891 do
  @moduledoc """
  Documentation for WaveShare13891.
  """

  use Supervisor

  @name __MODULE__

  def start_link(opts) do
    name = Keyword.get(opts, :name, @name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  defdelegate register(key_or_keys), to: WaveShare13891.KeyEvent
  defdelegate register(key_or_keys, subscriber), to: WaveShare13891.KeyEvent

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :duplicate, name: Registry.WaveShare13891},
      WaveShare13891.KeyEvent,
      {WaveShare13891.GPIO, event_listener: WaveShare13891.KeyEvent},
      WaveShare13891.SPI,
      WaveShare13891.LCD
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
