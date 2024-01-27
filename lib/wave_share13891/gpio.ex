defmodule WaveShare13891.GPIO do
  @moduledoc """
  Waveshare 13891 GPIO interface module.

  ## Input

  | Symbol         | Raspberry Pi pin | Description          | Event symbol |
  |----------------|------------------|----------------------|--------------|
  | KEY1           | P21              | Button 1/GPIO        | `key1`       |
  | KEY2           | P20              | Button 2/GPIO        | `key2`       |
  | KEY3           | P16              | Button 3/GPIO        | `key3`       |
  | Joystick Up    | P6               | Joystick Up          | `up`         |
  | Joystick Down  | P19              | Joystick Down        | `down`       |
  | Joystick Left  | P5               | Joystick Left        | `left`       |
  | Joystick Right | P26              | Joystick Right       | `right`      |
  | Joystick Press | P13              | Joystick Press       | `press`      |

  ### Events

  These events are sent to the listener specified by the option `:event_listener` of `start_link/1`.

  ```elixir
  {:key_event, key, timestamp, kind}
  ```

  - `key` - See event symbols in table.
  - `timestamp` - The time the event occurred. See [circuit_gpio document](https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html#set_interrupts/3).
  - `kind` - `:pressed` or `:released`

  ## Output

  | Symbol         | Raspberry Pi pin | Description          | Function        |
  |----------------|------------------|----------------------|-----------------|
  | DC             | P25              | Data/Command control | `set_lcd_dc/1`  |
  | RST            | P27              | Reset                | `set_lcd_rst/1` |
  | BL             | P24              | Backlight            | `set_lcd_bl/1`  |
  """

  use GenServer

  alias Circuits.GPIO

  @name __MODULE__

  # output pins
  # @pin_out_lcd_cs 8
  @pin_out_lcd_rst 27
  @pin_out_lcd_dc 25
  @pin_out_lcd_bl 24

  @type pin_level() :: 0 | 1

  defguard is_pin_level(value) when value in [0, 1]

  @doc """
  Starts GPIO server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @spec set_lcd_cs(pin_level()) :: :ok
  def set_lcd_cs(value) when is_pin_level(value) do
    GenServer.call(@name, {:set, :lcd_cs, value})
  end

  @spec set_lcd_rst(pin_level()) :: :ok
  def set_lcd_rst(value) when is_pin_level(value) do
    GenServer.call(@name, {:set, :lcd_rst, value})
  end

  @spec set_lcd_dc(pin_level()) :: :ok
  def set_lcd_dc(value) when is_pin_level(value) do
    GenServer.call(@name, {:set, :lcd_dc, value})
  end

  @spec set_lcd_bl(pin_level()) :: :ok
  def set_lcd_bl(value) when is_pin_level(value) do
    GenServer.call(@name, {:set, :lcd_bl, value})
  end

  @impl true
  def init(_opts) do
    state = %{}

    send(self(), :initialize_pins)

    {:ok, state}
  end

  @impl true
  def handle_call({:set, port, value}, _from, state) do
    case port do
      :lcd_cs -> state.lcd_cs
      :lcd_rst -> state.lcd_rst
      :lcd_dc -> state.lcd_dc
      :lcd_bl -> state.lcd_bl
    end
    |> GPIO.write(value)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:initialize_pins, _state) do
    # {:ok, lcd_cs} = GPIO.open(@pin_out_lcd_cs, :output)
    {:ok, lcd_rst} = GPIO.open(@pin_out_lcd_rst, :output)
    {:ok, lcd_dc} = GPIO.open(@pin_out_lcd_dc, :output)
    {:ok, lcd_bl} = GPIO.open(@pin_out_lcd_bl, :output)

    state = %{
      # lcd_cs: lcd_cs,
      lcd_rst: lcd_rst,
      lcd_dc: lcd_dc,
      lcd_bl: lcd_bl
    }

    {:noreply, state}
  end
end
