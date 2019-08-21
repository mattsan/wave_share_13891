defmodule WaveShare13891.KeyEvent do
  use GenServer

  @name __MODULE__

  defguard is_key(key) when key in [:up, :down, :left, :right, :press, :key1, :key2, :key3]

  def start_link(_opts) do
    state = %{}
    GenServer.start_link(__MODULE__, state, name: @name)
  end

  def register(key_or_keys) when is_list(key_or_keys) or is_key(key_or_keys) do
    register(key_or_keys, self())
  end

  def register(keys, subscriber) when is_list(keys) do
    keys
    |> Enum.each(&register(&1, subscriber))
  end

  def register(key, subscriber) when is_key(key) do
    GenServer.cast(@name, {:register, key, subscriber})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:register, key, subscriber}, state) do
    registered =
      Registry.lookup(Registry.WaveShare13891, key)
      |> Enum.any?(fn
        {_, ^subscriber} -> true
        _ -> false
      end)

    unless registered do
      {:ok, _pid} = Registry.register(Registry.WaveShare13891, key, subscriber)
    end

    {:noreply, state}
  end

  def handle_cast({:key_event, key, timestamp, condition}, state) do
    Registry.dispatch(Registry.WaveShare13891, key, fn entries ->
      for {_pid, subscriber} <- entries do
        send(subscriber, {:key_event, key, timestamp, condition})
      end
    end)
    {:noreply, state}
  end
end
