defmodule WaveShare13891.LCD do
  @moduledoc """
  Waveshare 13891 LCD server.
  """

  use GenServer

  alias WaveShare13891.ST7735S

  @type rect() :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer()
        }

  @name __MODULE__

  @doc """
  Starts LCD server.

  ## Options

  - `:scanning_direction` - scanning direction (default `:u2d_r2l`)
      - see [`WaveShare13891.ST7735S.scanning_direction()`](WaveShare13891.ST7735S.html#t:scanning_direction/0)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @spec set_backlight(boolean()) :: :ok
  def set_backlight(condition) when is_boolean(condition) do
    GenServer.cast(@name, {:set_backlight, condition})
  end

  @spec draw(binary(), rect()) :: :ok
  def draw(data, %{x: _, y: _, width: _, height: _} = rect) when is_binary(data) do
    GenServer.cast(@name, {:draw, data, rect})
  end

  @impl true
  def init(opts) do
    scanning_direction = Keyword.get(opts, :scanning_direction, :u2d_r2l)
    handles = ST7735S.initialize(scanning_direction)

    {:ok, %{handles: handles}}
  end

  @impl true
  def handle_cast({:draw, data, rect}, state) do
    ST7735S.draw(state.handles, data, rect)

    {:noreply, state}
  end

  def handle_cast({:set_backlight, condition}, state) do
    ST7735S.set_backlight(state.handles, condition)

    {:noreply, state}
  end
end
