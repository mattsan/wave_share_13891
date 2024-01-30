defmodule WaveShare13891.KeyEvent do
  @moduledoc """
  Waveshare 13891 Key event dispatche server.
  """

  use GenServer

  alias Circuits.GPIO

  @name __MODULE__

  @gpio_key_pairs %{
    6 => :up,
    19 => :down,
    5 => :left,
    26 => :right,
    13 => :press,
    21 => :key1,
    20 => :key2,
    16 => :key3
  }

  @type key() :: :up | :down | :left | :right | :press | :key1 | :key2 | :key3

  @doc """
  Returns true if `value` is a key, otherwise returns `false`.
  """
  defguard is_key(value) when value in [:up, :down, :left, :right, :press, :key1, :key2, :key3]

  @doc """
  Starts key event dispatche server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @spec register(key() | [key()], pid()) :: :ok
  def register(key_or_keys, subscriber)

  def register(keys, subscriber) when is_list(keys) and is_pid(subscriber) do
    Enum.each(keys, &register(&1, subscriber))
  end

  def register(key, subscriber) when is_key(key) and is_pid(subscriber) do
    Registry.register(Registry.WaveShare13891, key, subscriber)
  end

  @impl true
  def init(_opts) do
    state = initialize_gpio()

    {:ok, state}
  end

  # about message, see https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html#set_interrupts/3
  @impl true
  def handle_info({:circuits_gpio, gpio_number, timestamp, value}, state) do
    broadcast(@gpio_key_pairs[gpio_number], timestamp, condition(value))

    {:noreply, state}
  end

  defp initialize_gpio do
    @gpio_key_pairs
    |> Enum.map(fn {gpio, key} ->
      {:ok, handle} = GPIO.open(gpio, :input, pull_mode: :pullup)
      GPIO.set_interrupts(handle, :both)
      {key, handle}
    end)
  end

  defp broadcast(key, timestamp, condition) do
    Registry.dispatch(Registry.WaveShare13891, key, fn entries ->
      for {_pid, subscriber} <- entries do
        send(subscriber, {:key_event, key, timestamp, condition})
      end
    end)
  end

  defp condition(0), do: :pressed
  defp condition(1), do: :released
end
