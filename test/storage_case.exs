defmodule CxLeaderboard.StorageCase do
  use ExUnit.CaseTemplate
  alias CxLeaderboard.Leaderboard

  using do
    quote location: :keep do
      test "keeps entry count", %{board: board} do
        board =
          board
          |> Leaderboard.populate!([
            {-20, :id1},
            {-30, :id2}
          ])

        assert 2 == Leaderboard.count(board)
      end

      test "returns top entries", %{board: board} do
        top =
          board
          |> Leaderboard.populate!([
            {-20, :id1},
            {-30, :id2}
          ])
          |> Leaderboard.top()
          |> Enum.take(2)

        assert [
                 {{-30, :id2}, :id2, {0, 1, 75.0, 1, 1}},
                 {{-20, :id1}, :id1, {1, 2, 25.0, 0, 1}}
               ] == top
      end

      test "returns bottom entries", %{board: board} do
        bottom =
          board
          |> Leaderboard.populate!([
            {-20, :id1},
            {-30, :id2}
          ])
          |> Leaderboard.bottom()
          |> Enum.take(2)

        assert [
                 {{-20, :id1}, :id1, {1, 2, 25.0, 0, 1}},
                 {{-30, :id2}, :id2, {0, 1, 75.0, 1, 1}}
               ] == bottom
      end

      test "supports payloads in each entry", %{board: board} do
        top =
          board
          |> Leaderboard.populate!([
            {{-20, :id1}, %{foo: "foo"}},
            {{-30, :id2}, %{bar: "bar"}}
          ])
          |> Leaderboard.top()
          |> Enum.take(2)

        assert [
                 {{-30, :id2}, %{bar: "bar"}, {0, 1, 75.0, 1, 1}},
                 {{-20, :id1}, %{foo: "foo"}, {1, 2, 25.0, 0, 1}}
               ] == top
      end

      test "supports tiebreaks in each entry", %{board: board} do
        top =
          board
          |> Leaderboard.populate!([
            {-20, 2, :id1},
            {-20, 1, :id2},
            {-30, 3, :id3},
            {-30, 4, :id4}
          ])
          |> Leaderboard.top()
          |> Enum.take(4)

        assert [
                 {{-30, 3, :id3}, :id3, {0, 1, 75.0, 2, 2}},
                 {{-30, 4, :id4}, :id4, {1, 1, 75.0, 2, 2}},
                 {{-20, 1, :id2}, :id2, {2, 3, 25.0, 0, 2}},
                 {{-20, 2, :id1}, :id1, {3, 3, 25.0, 0, 2}}
               ] == top
      end

      test "supports adding individual entries", %{board: board} do
        top =
          board
          |> Leaderboard.populate!([{-20, :id1}, {-30, :id2}])
          |> Leaderboard.add!({-40, :id3})
          |> Leaderboard.add!({-40, :id4})
          |> Leaderboard.top()
          |> Enum.take(4)

        assert [
                 {{-40, :id3}, :id3, {0, 1, 75.0, 2, 2}},
                 {{-40, :id4}, :id4, {1, 1, 75.0, 2, 2}},
                 {{-30, :id2}, :id2, {2, 3, 37.5, 1, 1}},
                 {{-20, :id1}, :id1, {3, 4, 12.5, 0, 1}}
               ] == top
      end

      test "errors on adding a duplicate id", %{board: board} do
        assert {:error, :entry_already_exists} ==
                 board
                 |> Leaderboard.add!({1, :id1})
                 |> Leaderboard.add({1, :id1})
      end

      test "supports adding individual entries when empty", %{board: board} do
        top =
          board
          |> Leaderboard.add!({-20, :id1})
          |> Leaderboard.top()
          |> Enum.take(1)

        assert [
                 {{-20, :id1}, :id1, {0, 1, 50.0, 0, 1}}
               ] == top
      end

      test "supports updating individual entries", %{board: board} do
        board =
          board
          |> Leaderboard.populate!([
            {-20, :id1},
            {-30, :id2}
          ])

        top =
          board
          |> Leaderboard.top()
          |> Enum.take(2)

        assert [
                 {{-30, :id2}, :id2, {0, 1, 75.0, 1, 1}},
                 {{-20, :id1}, :id1, {1, 2, 25.0, 0, 1}}
               ] == top

        top =
          board
          |> Leaderboard.update!({-10, :id2})
          |> Leaderboard.top()
          |> Enum.take(3)

        assert [
                 {{-20, :id1}, :id1, {0, 1, 75.0, 1, 1}},
                 {{-10, :id2}, :id2, {1, 2, 25.0, 0, 1}}
               ] == top
      end

      test "errors on updating a missing id", %{board: board} do
        assert {:error, :entry_not_found} ==
                 Leaderboard.update(board, {1, :id1})
      end

      test "supports removing individual entries", %{board: board} do
        top =
          board
          |> Leaderboard.populate!([{-20, :id1}, {-30, :id2}])
          |> Leaderboard.remove!(:id1)
          |> Leaderboard.top()
          |> Enum.take(2)

        assert [
                 {{-30, :id2}, :id2, {0, 1, 50.0, 0, 1}}
               ] == top
      end

      test "errors on removing a missing id", %{board: board} do
        assert {:error, :entry_not_found} ==
                 Leaderboard.remove(board, :missing_id)
      end

      test "supports atomic add via add_or_update", %{board: board} do
        top =
          board
          |> Leaderboard.add_or_update!({-10, :id1})
          |> Leaderboard.top()
          |> Enum.take(1)

        assert [
                 {{-10, :id1}, :id1, {0, 1, 50.0, 0, 1}}
               ] == top
      end

      test "supports atomic update via add_or_update", %{board: board} do
        top =
          board
          |> Leaderboard.add!({-10, :id1})
          |> Leaderboard.add_or_update!({-20, :id1})
          |> Leaderboard.top()
          |> Enum.take(2)

        assert [
                 {{-20, :id1}, :id1, {0, 1, 50.0, 0, 1}}
               ] == top
      end

      test "gracefully handles invalid entries", %{board: board} do
        assert {:error, :bad_entry} =
                 Leaderboard.add(board, {-20, :tiebreak, :id1, :oops})
      end

      test "ignores invalid entries when populating", %{board: board} do
        top =
          board
          |> Leaderboard.populate!([
            {-20, :tiebreak, :id1, :oops},
            {-30, :tiebreak, :id2}
          ])
          |> Leaderboard.top()
          |> Enum.take(2)

        assert [
                 {{-30, :tiebreak, :id2}, :id2, {0, 1, 50.0, 0, 1}}
               ] == top
      end

      test "anything can be a score", %{board: board} do
        top =
          board
          |> Leaderboard.populate!([
            {"a", :id1},
            {"b", :id2}
          ])
          |> Leaderboard.top()
          |> Enum.take(2)

        assert [
                 {{"a", :id1}, :id1, {0, 1, 75.0, 1, 1}},
                 {{"b", :id2}, :id2, {1, 2, 25.0, 0, 1}}
               ] == top
      end

      test "retrieves records via get", %{board: board} do
        board =
          board
          |> Leaderboard.populate!([{-20, :id1}, {-30, :id2}])

        assert {{-20, :id1}, :id1, {1, 2, 25.0, 0, 1}} ==
                 Leaderboard.get(board, :id1)
      end

      test "retrieves next adjacent records", %{board: board} do
        records =
          board
          |> Leaderboard.populate!([
            {-40, :id1},
            {-30, :id2},
            {-20, :id3},
            {-10, :id4}
          ])
          |> Leaderboard.range(:id2, 0..1)

        assert [
                 {{-30, :id2}, :id2, {1, 2, 62.5, 2, 1}},
                 {{-20, :id3}, :id3, {2, 3, 37.5, 1, 1}}
               ] == records
      end

      test "retrieves previous adjacent records", %{board: board} do
        records =
          board
          |> Leaderboard.populate!([
            {-40, :id1},
            {-30, :id2},
            {-20, :id3},
            {-10, :id4}
          ])
          |> Leaderboard.range(:id2, -1..0)

        assert [
                 {{-40, :id1}, :id1, {0, 1, 87.5, 3, 1}},
                 {{-30, :id2}, :id2, {1, 2, 62.5, 2, 1}}
               ] == records
      end

      test "retrieves an adjacent range of records", %{board: board} do
        records =
          board
          |> Leaderboard.populate!([
            {-40, :id1},
            {-30, :id2},
            {-20, :id3},
            {-10, :id4}
          ])
          |> Leaderboard.range(:id2, -2..1)

        assert [
                 {{-40, :id1}, :id1, {0, 1, 87.5, 3, 1}},
                 {{-30, :id2}, :id2, {1, 2, 62.5, 2, 1}},
                 {{-20, :id3}, :id3, {2, 3, 37.5, 1, 1}}
               ] == records
      end

      test "retrieves a range of records in reverse order", %{board: board} do
        records =
          board
          |> Leaderboard.populate!([
            {-40, :id1},
            {-30, :id2},
            {-20, :id3},
            {-10, :id4}
          ])
          |> Leaderboard.range(:id2, 2..-1)

        assert [
                 {{-10, :id4}, :id4, {3, 4, 12.5, 0, 1}},
                 {{-20, :id3}, :id3, {2, 3, 37.5, 1, 1}},
                 {{-30, :id2}, :id2, {1, 2, 62.5, 2, 1}},
                 {{-40, :id1}, :id1, {0, 1, 87.5, 3, 1}}
               ] == records
      end

      test "retrieves an empty list if id is not found", %{board: board} do
        records =
          board
          |> Leaderboard.populate!([
            {-40, :id1},
            {-30, :id2}
          ])
          |> Leaderboard.range(:id3, -2..1)

        assert [] == records
      end
    end
  end
end
