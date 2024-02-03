defmodule WaveShare13891.LCD do
  @moduledoc """
  Waveshare 13891 LCD server.
  """

  defmodule State do
    @moduledoc false

    defstruct width: nil,
              height: nil,
              scanning_direction: nil,
              x_adjust: nil,
              y_adjust: nil,
              lcd_cs: nil,
              lcd_rst: nil,
              lcd_dc: nil,
              lcd_bl: nil,
              spi_bus: nil

    def new(scanning_direction) do
      %__MODULE__{scanning_direction: scanning_direction}
    end

    def set_gram_scan_way(state, width, height, x_adjust, y_adjust) do
      %{state | width: width, height: height, x_adjust: x_adjust, y_adjust: y_adjust}
    end

    def set_lcd_cs(state, value) do
      %{state | lcd_cs: value}
    end

    def set_lcd_rst(state, value) do
      %{state | lcd_rst: value}
    end

    def set_lcd_dc(state, value) do
      %{state | lcd_dc: value}
    end

    def set_lcd_bl(state, value) do
      %{state | lcd_bl: value}
    end

    def set_spi_bus(state, value) do
      %{state | spi_bus: value}
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
  def set_backlight(condition) when is_boolean(condition) do
    GenServer.call(@name, {:set_backlight, condition})
  end

  @impl true
  def init(opts) do
    scanning_direction = Keyword.get(opts, :scanning_direction, :u2d_r2l)
    state = State.new(scanning_direction)

    send(self(), :init_lcd)

    {:ok, state}
  end

  @impl true
  def handle_info(:init_lcd, state) do
    [lcd_rst, lcd_dc, lcd_bl] = ST7735S.initialize_gpio()
    {:ok, spi_bus} = ST7735S.initialize_spi()

    state =
      state
      |> State.set_lcd_rst(lcd_rst)
      |> State.set_lcd_dc(lcd_dc)
      |> State.set_lcd_bl(lcd_bl)
      |> State.set_spi_bus(spi_bus)

    {width, height, x_adjust, y_adjust} = ST7735S.initialize(state, state.scanning_direction)

    {:noreply, State.set_gram_scan_way(state, width, height, x_adjust, y_adjust)}
  end

  @impl true
  def handle_cast({:set_window, x_start, y_start, x_end, y_end}, state) do
    ST7735S.set_window(state, x_start, y_start, x_end, y_end, state.x_adjust, state.y_adjust)

    {:noreply, state}
  end

  def handle_cast({:write_data, data}, state) do
    ST7735S.write_data(state, data)

    {:noreply, state}
  end

  @impl true
  def handle_call({:set_backlight, condition}, _from, state) do
    ST7735S.set_backlight(state, condition)

    {:reply, :ok, state}
  end
end
