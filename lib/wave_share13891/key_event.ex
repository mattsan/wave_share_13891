defmodule WaveShare13891.KeyEvent do
  @moduledoc """
  Waveshare 13891 Key event dispatche server.
  """

  use GenServer

  alias Circuits.GPIO

  @name __MODULE__
  @gpio_up 6
  @gpio_down 19
  @gpio_left 5
  @gpio_right 26
  @gpio_press 13
  @gpio_key1 21
  @gpio_key2 20
  @gpio_key3 16

  @type key() :: :up | :down | :left | :right | :press | :key1 | :key2 | :key3

  @doc """
  Returns true if `value` is a key, otherwise returns `false`.
  """
  defguard is_key(value) when value in [:up, :down, :left, :right, :press, :key1, :key2, :key3]

  @doc """
  Starts key event dispatche server.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Registers the process subscribing key events.

  - `key_or_keys` - subscribing key(s)
  """
  @spec register(key() | [key()]) :: :ok
  def register(key_or_keys) when is_list(key_or_keys) or is_key(key_or_keys) do
    register(key_or_keys, self())
  end

  @doc """
  Registers a process subscribing key events.

  - `key_or_keys` - subscribing key(s)
  - `subscriber` - process id
  """
  @spec register(key() | [key()], pid()) :: :ok
  def register(key_or_keys, subscriber)

  def register(keys, subscriber) when is_list(keys) and is_pid(subscriber) do
    keys
    |> Enum.each(&register(&1, subscriber))
  end

  def register(key, subscriber) when is_key(key) and is_pid(subscriber) do
    GenServer.cast(@name, {:register, key, subscriber})
  end

  @impl true
  def init(_opts) do
    state = initialize_gpio()

    {:ok, state}
  end

  @impl true
  def handle_cast({:register, key, subscriber}, state) do
    unless registered?(key, subscriber) do
      {:ok, _pid} = Registry.register(Registry.WaveShare13891, key, subscriber)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, pin_number, timestamp, value}, state) do
    broadcast(pin_number_to_key(pin_number), timestamp, kind(value))

    {:noreply, state}
  end

  defp initialize_gpio do
    {:ok, up} = GPIO.open(@gpio_up, :input, pull_mode: :pullup)
    {:ok, down} = GPIO.open(@gpio_down, :input, pull_mode: :pullup)
    {:ok, left} = GPIO.open(@gpio_left, :input, pull_mode: :pullup)
    {:ok, right} = GPIO.open(@gpio_right, :input, pull_mode: :pullup)
    {:ok, press} = GPIO.open(@gpio_press, :input, pull_mode: :pullup)
    {:ok, key1} = GPIO.open(@gpio_key1, :input, pull_mode: :pullup)
    {:ok, key2} = GPIO.open(@gpio_key2, :input, pull_mode: :pullup)
    {:ok, key3} = GPIO.open(@gpio_key3, :input, pull_mode: :pullup)

    GPIO.set_interrupts(up, :both)
    GPIO.set_interrupts(down, :both)
    GPIO.set_interrupts(left, :both)
    GPIO.set_interrupts(right, :both)
    GPIO.set_interrupts(press, :both)
    GPIO.set_interrupts(key1, :both)
    GPIO.set_interrupts(key2, :both)
    GPIO.set_interrupts(key3, :both)

    %{
      up: up,
      down: down,
      left: left,
      right: right,
      press: press,
      key1: key1,
      key2: key2,
      key3: key3
    }
  end

  defp registered?(key, subscriber) do
    Registry.lookup(Registry.WaveShare13891, key)
    |> Enum.any?(fn
      {_, ^subscriber} -> true
      _ -> false
    end)
  end

  defp pin_number_to_key(pin_number) do
    case pin_number do
      @gpio_up -> :up
      @gpio_down -> :down
      @gpio_left -> :left
      @gpio_right -> :right
      @gpio_press -> :press
      @gpio_key1 -> :key1
      @gpio_key2 -> :key2
      @gpio_key3 -> :key3
    end
  end

  defp kind(0), do: :pressed
  defp kind(1), do: :released

  defp broadcast(key, timestamp, kind) do
    Registry.dispatch(Registry.WaveShare13891, key, fn entries ->
      for {_pid, subscriber} <- entries do
        send(subscriber, {:key_event, key, timestamp, kind})
      end
    end)
  end
end
