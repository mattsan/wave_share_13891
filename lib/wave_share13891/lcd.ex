defmodule WaveShare13891.LCD do
  use GenServer

  defstruct [:dis_column, :dis_page, :scan_dir, :x_adjust, :y_adjust]

  alias WaveShare13891.LCD
  alias WaveShare13891.LCD.Device

  require Bitwise
  import Bitwise

  @name __MODULE__

  def start_link(opts) do
    scan_dir = Keyword.get(opts, :scan_dir, :u2d_r2l)
    state = %{scan_dir: scan_dir}
    GenServer.start_link(__MODULE__, state, name: @name)
  end

  def set_windows(x_start, y_start, x_end, y_end) do
    GenServer.cast(@name, {:set_windows, x_start, y_start, x_end, y_end})
  end

  def set_color(data) do
    GenServer.cast(@name, {:set_color, data})
  end

  def init(state) do
    GenServer.cast(@name, :init_lcd)

    new_state =
      state
      |> Map.put(:lcd, %LCD{scan_dir: :d2u_l2r})

    {:ok, new_state}
  end

  def handle_cast(:init_lcd, state) do
    {dis_column, dis_page, x_adjust, y_adjust} = Device.initialize(state.scan_dir)

    lcd = %LCD{state.lcd |
      dis_column: dis_column,
      dis_page: dis_page,
      x_adjust: x_adjust,
      y_adjust: y_adjust
    }

    {:noreply, %{state | lcd: lcd}}
  end

  def handle_cast({:set_windows, x_start, y_start, x_end, y_end}, state) do
    x = <<
      0x00,
      (x_start &&& 0xff) + state.lcd.x_adjust,
      0x00,
      (x_end &&& 0xff) + state.lcd.x_adjust
    >>
    y = <<
      0x00,
      (y_start &&& 0xff) + state.lcd.y_adjust,
      0x00,
      (y_end &&& 0xff) + state.lcd.y_adjust
    >>

    Device.write_register(0x2a, x)
    Device.write_register(0x2b, y)
    Device.select_register(0x2c)

    {:noreply, state}
  end

  def handle_cast({:set_color, data}, state) do
    Device.write_data(data)

    {:noreply, state}
  end
end
