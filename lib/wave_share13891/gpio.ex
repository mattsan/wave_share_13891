defmodule WaveShare13891.GPIO do
  use GenServer

  alias Circuits.GPIO

  @name __MODULE__

  @lcd_cs 8
  @lcd_rst 27
  @lcd_dc 25
  @lcd_bl 24

  @up 6
  @down 19
  @left 5
  @right 26
  @press 13
  @key1 21
  @key2 20
  @key3 16

  defguard is_pin_level(value) when value in [0, 1]

  def start_link(_opts) do
    state = %{}
    GenServer.start_link(__MODULE__, state, name: @name)
  end

  def set_lcd_cs(value) when is_pin_level(value), do: GenServer.call(@name, {:set, :lcd_cs, value})
  def set_lcd_rst(value) when is_pin_level(value), do: GenServer.call(@name, {:set, :lcd_rst, value})
  def set_lcd_dc(value) when is_pin_level(value), do: GenServer.call(@name, {:set, :lcd_dc, value})
  def set_lcd_bl(value) when is_pin_level(value), do: GenServer.call(@name, {:set, :lcd_bl, value})

  def init(state) do
    {:ok, lcd_cs} = GPIO.open(@lcd_cs, :output)
    {:ok, lcd_rst} = GPIO.open(@lcd_rst, :output)
    {:ok, lcd_dc} = GPIO.open(@lcd_dc, :output)
    {:ok, lcd_bl} = GPIO.open(@lcd_bl, :output)

    {:ok, up} = GPIO.open(@up, :input, pull_mode: :pullup)
    {:ok, down} = GPIO.open(@down, :input, pull_mode: :pullup)
    {:ok, left} = GPIO.open(@left, :input, pull_mode: :pullup)
    {:ok, right} = GPIO.open(@right, :input, pull_mode: :pullup)
    {:ok, press} = GPIO.open(@press, :input, pull_mode: :pullup)
    {:ok, key1} = GPIO.open(@key1, :input, pull_mode: :pullup)
    {:ok, key2} = GPIO.open(@key2, :input, pull_mode: :pullup)
    {:ok, key3} = GPIO.open(@key3, :input, pull_mode: :pullup)

    GPIO.set_interrupts(up, :both)
    GPIO.set_interrupts(down, :both)
    GPIO.set_interrupts(left, :both)
    GPIO.set_interrupts(right, :both)
    GPIO.set_interrupts(press, :both)
    GPIO.set_interrupts(key1, :both)
    GPIO.set_interrupts(key2, :both)
    GPIO.set_interrupts(key3, :both)

    gpio = %{
      lcd_cs: lcd_cs,
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

    {:ok, Map.put(state, :gpio, gpio)}
  end

  def handle_call({:set, port, value}, _from, state) do
    resp =
      case port do
        :lcd_cs -> state.gpio.lcd_cs
        :lcd_rst -> state.gpio.lcd_rst
        :lcd_dc -> state.gpio.lcd_dc
        :lcd_bl -> state.gpio.lcd_bl
      end
      |> GPIO.write(value)

    {:reply, resp, state}
  end

  def handle_info({:circuits_gpio, pin_number, timestamp, value}, state) do
    key =
      case pin_number do
        @up -> :up
        @down -> :down
        @left -> :left
        @right -> :right
        @press -> :press
        @key1  -> :key1
        @key2  -> :key2
        @key3  -> :key3
      end

    condition =
      case value do
        0 -> :pressed
        1 -> :released
      end

    GenServer.cast(WaveShare13891.KeyEvent, {:key_event, key, timestamp, condition})

    {:noreply, state}
  end
end
