defmodule CxLeaderboard.RedisStore do
  @moduledoc """
  Use this storage engine to get efficient leaderboards powered by Redis.
  """

  @behaviour CxLeaderboard.Storage

  @redis_stream_buffer_size 10
  ## Writers

  @doc false
  def create(kwargs) do
    name = Keyword.get(kwargs, :name)
    {:ok, name}
  end

  @doc false
  def clear(name) do
    case redis_command(["DEL", name]) do
      {:ok, _} -> {:ok, name}
      error -> error
    end
  end

  @doc false
  def populate(name, data, _ \\ %{}) do
    entries = Enum.flat_map(data, fn {{score, id}, _} -> [score, id] end)

    case redis_command(["ZADD", name | entries]) do
      {:ok, _} -> {:ok, name}
      error -> error
    end
  end

  @doc false
  def async_populate(name, data, _ \\ %{}) do
    commands =
      Enum.map(data, fn {{score, id}, _} -> ["ZADD", name, score, id] end)

    case redis_pipeline(commands) do
      {:ok, _} -> {:ok, name}
      error -> error
    end
  end

  @doc false
  def add(name, entry, indexer \\ %{}) do
    add_or_update(name, entry, indexer)
  end

  @doc false
  def remove(name, id, _ \\ %{}) do
    case redis_command(["ZREM", name, id]) do
      {:ok, _} -> {:ok, name}
      error -> error
    end
  end

  @doc false
  def update(name, entry, indexer \\ %{}) do
    add_or_update(name, entry, indexer)
  end

  @doc false
  def add_or_update(name, entry, _ \\ %{}) do
    {{score, id}, _} = entry

    case redis_command(["ZADD", name, score, id]) do
      {:ok, _} -> {:ok, name}
      error -> error
    end
  end

  ## Readers

  @doc false
  def get(name, id) do
    get(name, id, 0..0)
  end

  @doc false
  def get(name, id, range) do
    {:ok, rank} = redis_command(["ZRANK", name, id])

    if rank != nil do
      {:ok, entries} =
        redis_command([
          "ZRANGE",
          name,
          (rank + Enum.at(range, 0)) |> max(0),
          (rank + Enum.at(range, -1)) |> max(0),
          "WITHSCORES"
        ])

      entries
      |> map_entries_to_records(name)
    else
      []
    end
  end

  @doc false
  def top(name) do
    redis_stream_generator("ZRANGE", name)
  end

  @doc false
  def bottom(name) do
    redis_stream_generator("ZREVRANGE", name)
  end

  @doc false
  def count(name) do
    case redis_command(["ZCARD", name]) do
      {:ok, count} -> count
      error -> error
    end
  end

  defp redis_stream_generator(command, name) do
    Stream.resource(
      fn -> {0, @redis_stream_buffer_size} end,
      fn {start_idx, end_idx} ->
        {status, entries} =
          redis_command([
            command,
            name,
            start_idx,
            end_idx,
            "WITHSCORES"
          ])

        if status == :ok && !Enum.empty?(entries) do
          records = map_entries_to_records(entries, name, start_idx)
          {records, {start_idx + end_idx + 1, end_idx + end_idx + 1}}
        else
          {:halt, {start_idx, end_idx}}
        end
      end,
      fn {_, end_idx} ->
        end_idx
      end
    )
  end

  defp map_entries_to_records(entries, name, index \\ 0) do
    entries
    |> Enum.chunk_every(2)
    |> Enum.with_index(index)
    |> Enum.map(&map_entry_to_record/1)
    |> Enum.map(&join_rank_on_record(&1, name))
  end

  defp map_entry_to_record(entry) do
    {[entry_id, entry_score], index} = entry

    {
      {String.to_integer(entry_score), String.to_atom(entry_id)},
      String.to_atom(entry_id),
      {index, {index + 1, nil}}
    }
  end

  defp join_rank_on_record(entry, name) do
    {{score, id}, payload, {_, {_, percentile}}} = entry
    {:ok, rank} = redis_command(["ZRANK", name, id])
    {{score, id}, payload, {rank, {rank + 1, percentile}}}
  end

  defp redis_command(command) do
    Redix.command(:redix, command)
  end

  defp redis_pipeline(commands) do
    Redix.pipeline(:redix, commands)
  end
end
