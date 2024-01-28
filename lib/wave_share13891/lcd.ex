defmodule WaveShare13891.LCD do
  @moduledoc """
  Waveshare 13891 LCD server.
  """

  defmodule State do
    @moduledoc false

    defstruct [:width, :height, :scanning_direction, :x_adjust, :y_adjust]

    def new(scanning_direction) do
      %__MODULE__{scanning_direction: scanning_direction}
    end

    def set_gram_scan_way(state, width, height, x_adjust, y_adjust) do
      %{state | width: width, height: height, x_adjust: x_adjust, y_adjust: y_adjust}
    end
  end

  use GenServer

  alias WaveShare13891.ST7735S

  @name __MODULE__

  @doc """
  Starts LCD server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @spec set_window(non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: :ok
  def set_window(x_start, y_start, x_end, y_end) do
    GenServer.cast(@name, {:set_window, x_start, y_start, x_end, y_end})
  end

  @spec write_data(binary()) :: :ok
  def write_data(data) do
    GenServer.cast(@name, {:write_data, data})
  end

  @spec set_backlight(boolean()) :: :ok
  defdelegate set_backlight(condition), to: ST7735S

  @impl true
  def init(opts) do
    scanning_direction = Keyword.get(opts, :scanning_direction, :u2d_r2l)
    state = State.new(scanning_direction)

    send(self(), :init_lcd)

    {:ok, state}
  end

  @impl true
  def handle_info(:init_lcd, state) do
    {width, height, x_adjust, y_adjust} = ST7735S.initialize(state.scanning_direction)

    {:noreply, State.set_gram_scan_way(state, width, height, x_adjust, y_adjust)}
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
end
