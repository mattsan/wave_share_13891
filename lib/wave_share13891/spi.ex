defmodule WaveShare13891.SPI do
  use GenServer

  defstruct [:ref, :bus_name]

  @name __MODULE__
  @speed_hz 20_000_000
  @delay_us 0

  def start_link(opts) do
    bus_name = Keyword.get(opts, :bus_name, "spidev0.0")
    state = %WaveShare13891.SPI{bus_name: bus_name}
    GenServer.start_link(__MODULE__, state, name: @name)
  end

  def transfer(data) do
    GenServer.call(@name, {:transfer, data})
  end

  def init(state) do
    GenServer.cast(@name, :open_spi)
    {:ok, state}
  end

  def handle_cast(:open_spi, state) do
    {:ok, ref} = Circuits.SPI.open(state.bus_name, speed_hz: @speed_hz, delay_us: @delay_us)

    {:noreply, %{state | ref: ref}}
  end

  def handle_call({:transfer, data}, _from, state) do
    Circuits.SPI.transfer(state.ref, data)

    {:reply, data, state}
  end
end
