defmodule WaveShare13891.LCD do
  @moduledoc """
  Waveshare 13891 LCD server.
  """

  use GenServer

  alias WaveShare13891.ST7735S

  defstruct [:width, :height, :scanning_direction, :x_adjust, :y_adjust]

  @name __MODULE__

  @doc """
  Starts LCD server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Sets window area.

  ```
  width = x_end - x_start + 1
  ```

  ```
  height = y_end - y_start + 1
  ```
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
  defdelegate set_backlight(condition), to: ST7735S

  @impl true
  def init(opts) do
    scanning_direction = Keyword.get(opts, :scanning_direction, :u2d_r2l)
    state = new_state(scanning_direction)

    send(self(), :init_lcd)

    {:ok, state}
  end

  @impl true
  def handle_info(:init_lcd, state) do
    {width, height, x_adjust, y_adjust} = ST7735S.initialize(state.scanning_direction)

    {:noreply, set_gram_scan_way(state, width, height, x_adjust, y_adjust)}
  end

  @impl true
  def handle_cast({:set_window, x_start, y_start, x_end, y_end}, state) do
    ST7735S.set_window(x_start, y_start, x_end, y_end, state.x_adjust, state.y_adjust)

    {:noreply, state}
  end

  def handle_cast({:write_data, data}, state) do
    ST7735S.write_data(data)

    {:noreply, state}
  end

  defp new_state(scanning_direction) do
    %__MODULE__{scanning_direction: scanning_direction}
  end

  defp set_gram_scan_way(state, width, height, x_adjust, y_adjust) do
    %{state | width: width, height: height, x_adjust: x_adjust, y_adjust: y_adjust}
  end
end
