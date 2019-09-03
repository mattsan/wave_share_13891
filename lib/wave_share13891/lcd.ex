defmodule WaveShare13891.LCD do
  @moduledoc """
  WaveShare 13891 LCD interface.
  """

  use GenServer

  defstruct [:width, :height, :scanning_direction, :x_adjust, :y_adjust]

  alias WaveShare13891.LCD
  alias WaveShare13891.LCD.Device

  @name __MODULE__

  @doc """
  Starts LCD server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    scanning_direction = Keyword.get(opts, :scanning_direction, :u2d_r2l)
    state = %{scanning_direction: scanning_direction}
    GenServer.start_link(__MODULE__, state, name: @name)
  end

  @doc """
  Sets window area.
  """
  @spec set_window(non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: :ok
  def set_window(x_start, y_start, x_end, y_end) do
    GenServer.cast(@name, {:set_window, x_start, y_start, x_end, y_end})
  end

  @doc """
  Writes image data.

  The length of the binary is determined by the size of the window area specified with `set_window/4`.

  ```
  binary_length = (x_end - x_start + 1) * (y_end - y_start + 1) * 2 
  ```

  (Because of 16 bit color (2 bytes per dot))
  """
  @spec write_data(binary()) :: :ok
  def write_data(data) do
    GenServer.cast(@name, {:write_data, data})
  end

  @doc """
  Sets LCD backlight.

  If `condition` is `true`, it's turned on; if `false`, it's turned off.
  """
  @spec set_backlight(boolean()) :: :ok
  defdelegate set_backlight(condition), to: Device

  @impl true
  def init(state) do
    send(self(), :init_lcd)

    new_state =
      state
      |> Map.put(:lcd, %LCD{scanning_direction: :d2u_l2r})

    {:ok, new_state}
  end

  @impl true
  def handle_info(:init_lcd, state) do
    {width, height, x_adjust, y_adjust} = Device.initialize(state.scanning_direction)

    lcd = %LCD{state.lcd | width: width, height: height, x_adjust: x_adjust, y_adjust: y_adjust}

    {:noreply, %{state | lcd: lcd}}
  end

  @impl true
  def handle_cast({:set_window, x_start, y_start, x_end, y_end}, state) do
    Device.set_window(x_start, y_start, x_end, y_end, state.lcd.x_adjust, state.lcd.y_adjust)

    {:noreply, state}
  end

  def handle_cast({:write_data, data}, state) do
    Device.write_data(data)

    {:noreply, state}
  end
end
