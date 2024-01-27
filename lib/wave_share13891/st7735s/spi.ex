defmodule WaveShare13891.ST7735S.SPI do
  @moduledoc """
  Waveshare 13891 SPI server.
  """

  use GenServer

  @name __MODULE__
  @default_bus_name "spidev0.0"
  @speed_hz 20_000_000
  @delay_us 0

  @doc """
  Starts SPI server.

  - `:name` - Server name (default: `#{inspect(@name)}`)
  - `:bus_name` - SPI bus name (default: `#{inspect(@default_bus_name)}`)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) when is_list(opts) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Transfers binary data.

  - `data` - binary
  """
  @spec transfer(binary()) :: binary()
  def transfer(pid \\ @name, data) when is_binary(data) do
    GenServer.call(pid, {:transfer, data})
  end

  @impl true
  def init(opts) do
    bus_name = Keyword.get(opts, :bus_name, @default_bus_name)
    state = %{}

    send(self(), {:open_spi, bus_name})

    {:ok, state}
  end

  @impl true
  def handle_info({:open_spi, bus_name}, state) do
    {:ok, bus} = Circuits.SPI.open(bus_name, speed_hz: @speed_hz, delay_us: @delay_us)

    {:noreply, Map.put(state, :bus, bus)}
  end

  @impl true
  def handle_call({:transfer, data}, _from, state) do
    Circuits.SPI.transfer(state.bus, data)

    {:reply, data, state}
  end
end
