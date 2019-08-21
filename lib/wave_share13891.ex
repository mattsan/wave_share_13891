defmodule WaveShare13891 do
  @moduledoc """
  Documentation for WaveShare13891.
  """

  defdelegate register(key_or_keys), to: WaveShare13891.KeyEvent
  defdelegate register(key_or_keys, subscriber), to: WaveShare13891.KeyEvent
end
