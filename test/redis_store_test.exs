defmodule RedisStoreTest do
  use CxLeaderboard.RedisStorageCase
  alias CxLeaderboard.{Leaderboard, RedisStore}

  setup do
    board = Leaderboard.create!(name: :test1, store: RedisStore, indexer: %{})
    Leaderboard.clear(board)
    {:ok, board: board}
  end
end
