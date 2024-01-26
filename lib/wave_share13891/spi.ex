defmodule WaveShare13891.SPI do
  @moduledoc """
  Waveshare 13891 SPI server.
  """

  defmodule State do
    @moduledoc false

    defstruct [:bus_name, :bus]

    def new(bus_name) do
      %__MODULE__{bus_name: bus_name, bus: nil}
    end

    def put_bus(%__MODULE__{} = state, bus) do
      %{state | bus: bus}
    end
  end

  use GenServer

  @name __MODULE__
  @speed_hz 20_000_000
  @delay_us 0

  @doc """
  Starts SPI server.

  - `:name` - Server name (default: `WaveShare13891.SPI`)
  - `:bus_name` - SPI bus name (default: `"spidev0.0"`)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) when is_list(opts) do
    name = Keyword.get(opts, :name, @name)
    bus_name = Keyword.get(opts, :bus_name, "spidev0.0")
    GenServer.start_link(__MODULE__, bus_name, name: name)
  end

  @doc """
  Transfers binary data.

  - `data` - binary
  """
  @spec transfer(binary()) :: binary()
  def transfer(data) when is_binary(data) do
    GenServer.call(@name, {:transfer, data})
  end

  @impl true
  def init(bus_name) do
    send(self(), :open_spi)
    state = State.new(bus_name)

    {:ok, state}
  end

  @impl true
  def handle_info(:open_spi, state) do
    {:ok, bus} = Circuits.SPI.open(state.bus_name, speed_hz: @speed_hz, delay_us: @delay_us)

    {:noreply, State.put_bus(state, bus)}
  end

  @impl true
  def handle_call({:transfer, data}, _from, state) do
    Circuits.SPI.transfer(state.bus, data)

    {:reply, data, state}
  end
end
