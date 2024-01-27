defmodule WaveShare13891 do
  @moduledoc """
  Waveshare 13891 interface module.
  """

  use Supervisor

  @name __MODULE__

  @doc """
  Starts servers.

  ## Options

  - `:name` - supervisor's name (default: `WaveShare13891`)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, @name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  defdelegate register(key_or_keys), to: WaveShare13891.KeyEvent
  defdelegate register(key_or_keys, subscriber), to: WaveShare13891.KeyEvent
  defdelegate set_backlight(condition), to: WaveShare13891.LCD
  defdelegate set_window(x_start, y_start, x_end, y_end), to: WaveShare13891.LCD
  defdelegate write_data(data), to: WaveShare13891.LCD

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :duplicate, name: Registry.WaveShare13891},
      WaveShare13891.KeyEvent,
      WaveShare13891.ST7735S.GPIO,
      WaveShare13891.ST7735S.SPI,
      WaveShare13891.LCD
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
