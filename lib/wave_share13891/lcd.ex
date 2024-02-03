defmodule WaveShare13891.LCD do
  @moduledoc """
  Waveshare 13891 LCD server.
  """

  use GenServer

  alias WaveShare13891.ST7735S
  alias WaveShare13891.ST7735S.Handles

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
    state = Handles.new()

    send(self(), {:init_lcd, scanning_direction})

    {:ok, state}
  end

  @impl true
  def handle_info({:init_lcd, scanning_direction}, state) do
    state =
      state
      |> ST7735S.initialize(scanning_direction)

    {:noreply, state}
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
