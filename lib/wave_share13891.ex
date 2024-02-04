defmodule WaveShare13891 do
  @moduledoc """
  Waveshare 13891 interface module.

  ```
  +--------------------------------------------------+
  |                  WaveShare13891                  |
  +-------------------------+------------------------+
  |                         |   WaveShare13891.LCD   |
  | WaveShare13891.KeyEvent +------------------------+
  |                         | WaveShare13891.ST7735S |
  +-------------------------+---------+--------------+
  |           Cirsuits.GPIO           | Cirsuits.SPI |
  +-----------------------------------+--------------+
  ```

  ## LCD

  ### Turns backlight on or off

  ```elixir
  WaveShare13891.set_backlight(true)  # on
  WaveShare13891.set_backlight(false) # off
  ```

  ### Writes image

  ```elixir
  WaveShare13891.set_window(0, 0, 7, 7)
  WaveShare13891.write_data(<<0::unit(16)-size(8 * 8)>>)
  ```

  ## Key events

  ### Register subscribing keys

  ```elixir
  WaveShare13891.subscribe(:key1)          # single key
  # or
  WaveShare13891.subscribe([:key2, :key3]) # multiple keys
  ```

  ### Recieve key event message

  ```elixir
  {:key_event, key, timestamp, condition}
  ```

  - `key` - type of key (see [`WaveShare13891.KeyEvent.key`](WaveShare13891.KeyEvent.html#t:key/0)())
  - `timestamp` - monotonic timestamp (see `Circuits.GPIO.set_interrupts/3`)
  - `condition` - key condition (`:pressed` or `:released`)
  """

  use Supervisor

  @name __MODULE__

  @doc """
  Starts servers.

  ## Options

  - `:name` - supervisor's name (default: `#{inspect(@name)}`)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, @name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a process subscribing key events.

  - `key_or_keys` - subscribing key(s)
  - `subscriber` - process id (default `self()`)
  """
  @spec subscribe(WaveShare13891.KeyEvent.key() | [WaveShare13891.KeyEvent.key()], pid()) :: :ok
  defdelegate subscribe(key_or_keys, subscriber \\ self()), to: WaveShare13891.KeyEvent

  @doc """
  Draws image.

  The length of the binary is determined by the size of the window area.

  ```
  binary_length = width * height * 2
  ```

  (Because of 16 bit color (2 bytes per dot))
  """
  @spec draw(binary(), WaveShare13891.LCD.rect()) :: :ok
  defdelegate draw(data, rect), to: WaveShare13891.LCD

  @doc """
  Sets LCD backlight.

  If `condition` is `true`, it's turned on; if `false`, it's turned off.
  """
  @spec set_backlight(boolean()) :: :ok
  defdelegate set_backlight(condition), to: WaveShare13891.LCD

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :duplicate, name: Registry.WaveShare13891},
      WaveShare13891.KeyEvent,
      WaveShare13891.LCD
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
