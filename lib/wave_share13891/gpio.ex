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

  # input pins
  @pin_in_up 6
  @pin_in_down 19
  @pin_in_left 5
  @pin_in_right 26
  @pin_in_press 13
  @pin_in_key1 21
  @pin_in_key2 20
  @pin_in_key3 16

  @type pin_level() :: 0 | 1

  defguard is_pin_level(value) when value in [0, 1]

  @doc """
  Starts GPIO server.

  ## Options

  - `:event_listener` - A listner process receiving key events (type: [`Proces.dist()`](https://hexdocs.pm/elixir/Process.html#t:dest/0))
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
  def init(opts) do
    event_listener = Keyword.get(opts, :event_listener)
    state = %{event_listener: event_listener}

    send(self(), :initialize_gpio)

    {:ok, state}
  end

  @impl true
  def handle_call({:set, port, value}, _from, state) do
    case port do
      :lcd_cs -> state.gpio.lcd_cs
      :lcd_rst -> state.gpio.lcd_rst
      :lcd_dc -> state.gpio.lcd_dc
      :lcd_bl -> state.gpio.lcd_bl
    end
    |> GPIO.write(value)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:initialize_gpio, state) do
    gpio = initialize_gpio()

    {:noreply, Map.put(state, :gpio, gpio)}
  end

  def handle_info({:circuits_gpio, pin_number, timestamp, value}, state) do
    if state.event_listener do
      key = pin_number_to_key(pin_number)

      kind =
        case value do
          0 -> :pressed
          1 -> :released
        end

      send(state.event_listener, {:key_event, key, timestamp, kind})
    end

    {:noreply, state}
  end

  defp initialize_gpio do
    # {:ok, lcd_cs} = GPIO.open(@pin_out_lcd_cs, :output)
    {:ok, lcd_rst} = GPIO.open(@pin_out_lcd_rst, :output)
    {:ok, lcd_dc} = GPIO.open(@pin_out_lcd_dc, :output)
    {:ok, lcd_bl} = GPIO.open(@pin_out_lcd_bl, :output)

    {:ok, up} = GPIO.open(@pin_in_up, :input, pull_mode: :pullup)
    {:ok, down} = GPIO.open(@pin_in_down, :input, pull_mode: :pullup)
    {:ok, left} = GPIO.open(@pin_in_left, :input, pull_mode: :pullup)
    {:ok, right} = GPIO.open(@pin_in_right, :input, pull_mode: :pullup)
    {:ok, press} = GPIO.open(@pin_in_press, :input, pull_mode: :pullup)
    {:ok, key1} = GPIO.open(@pin_in_key1, :input, pull_mode: :pullup)
    {:ok, key2} = GPIO.open(@pin_in_key2, :input, pull_mode: :pullup)
    {:ok, key3} = GPIO.open(@pin_in_key3, :input, pull_mode: :pullup)

    GPIO.set_interrupts(up, :both)
    GPIO.set_interrupts(down, :both)
    GPIO.set_interrupts(left, :both)
    GPIO.set_interrupts(right, :both)
    GPIO.set_interrupts(press, :both)
    GPIO.set_interrupts(key1, :both)
    GPIO.set_interrupts(key2, :both)
    GPIO.set_interrupts(key3, :both)

    %{
      # lcd_cs: lcd_cs,
      lcd_rst: lcd_rst,
      lcd_dc: lcd_dc,
      lcd_bl: lcd_bl,
      up: up,
      down: down,
      left: left,
      right: right,
      press: press,
      key1: key1,
      key2: key2,
      key3: key3
    }
  end

  defp pin_number_to_key(pin_number) do
    case pin_number do
      @pin_in_up -> :up
      @pin_in_down -> :down
      @pin_in_left -> :left
      @pin_in_right -> :right
      @pin_in_press -> :press
      @pin_in_key1 -> :key1
      @pin_in_key2 -> :key2
      @pin_in_key3 -> :key3
    end
  end
end
