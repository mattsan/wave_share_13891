defmodule WaveShare13891.KeyEvent do
  @moduledoc """
  Waveshare 13891 Key event dispatche server.
  """

  use GenServer

  @name __MODULE__

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
    state = %{}

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
  def handle_info({:key_event, key, timestamp, condition}, state) do
    Registry.dispatch(Registry.WaveShare13891, key, fn entries ->
      for {_pid, subscriber} <- entries do
        send(subscriber, {:key_event, key, timestamp, condition})
      end
    end)

    {:noreply, state}
  end

  defp registered?(key, subscriber) do
    Registry.lookup(Registry.WaveShare13891, key)
    |> Enum.any?(fn
      {_, ^subscriber} -> true
      _ -> false
    end)
  end
end
