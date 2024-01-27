defmodule WaveShare13891.KeyEvent do
  @moduledoc """
  Waveshare 13891 Key event dispatche server.
  """

  use GenServer

  alias Circuits.GPIO

  @name __MODULE__
  # input pins
  @pin_in_up 6
  @pin_in_down 19
  @pin_in_left 5
  @pin_in_right 26
  @pin_in_press 13
  @pin_in_key1 21
  @pin_in_key2 20
  @pin_in_key3 16

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
    state = initialize_input()

    {:ok, state}
  end

  defp initialize_input do
    {:ok, up} = GPIO.open(@pin_in_up, :input, pull_mode: :pullup)
    {:ok, down} = GPIO.open(@pin_in_down, :input, pull_mode: :pullup)
    {:ok, left} = GPIO.open(@pin_in_left, :input, pull_mode: :pullup)
    {:ok, right} = GPIO.open(@pin_in_right, :input, pull_mode: :pullup)
    {:ok, press} = GPIO.open(@pin_in_press, :input, pull_mode: :pullup)
    {:ok, key1} = GPIO.open(@pin_in_key1, :input, pull_mode: :pullup)
    {:ok, key2} = GPIO.open(@pin_in_key2, :input, pull_mode: :pullup)
    {:ok, key3} = GPIO.open(@pin_in_key3, :input, pull_mode: :pullup)

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

  @impl true
  def handle_cast({:register, key, subscriber}, state) do
    unless registered?(key, subscriber) do
      {:ok, _pid} = Registry.register(Registry.WaveShare13891, key, subscriber)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_gpio, pin_number, timestamp, value}, state) do
    key = pin_number_to_key(pin_number)

    kind =
      case value do
        0 -> :pressed
        1 -> :released
      end

    Registry.dispatch(Registry.WaveShare13891, key, fn entries ->
      for {_pid, subscriber} <- entries do
        send(subscriber, {:key_event, key, timestamp, kind})
      end
    end)

    {:noreply, state}
  end

  defp pin_number_to_key(pin_number) do
    case pin_number do
      @pin_in_up -> :up
      @pin_in_down -> :down
      @pin_in_left -> :left
      @pin_in_right -> :right
      @pin_in_press -> :press
      @pin_in_key1 -> :key1
      @pin_in_key2 -> :key2
      @pin_in_key3 -> :key3
    end
  end

  defp registered?(key, subscriber) do
    Registry.lookup(Registry.WaveShare13891, key)
    |> Enum.any?(fn
      {_, ^subscriber} -> true
      _ -> false
    end)
  end
end
