defmodule RonParserTest do
  use ExUnit.Case
  doctest Ron.Parser

  test "numbers" do
    # valid decimal
    assert Ron.Parser.parse("123") == {:ok, [decimal_num: 123], "", %{}, {1, 0}, 3}
    # invalid decimal
    assert Ron.Parser.parse("123abc") == {:ok, [decimal_num: 123], "abc", %{}, {1, 0}, 3}

    # valid binary
    assert Ron.Parser.parse("0b1011") == {:ok, [binary_num: '1011'], "", %{}, {1, 0}, 6}
  end

  test "example.ron" do
    Ron.Parser.parse(~s<(
      boolean: true,
      float: 8.2,
      map: {
          1: '1',
          2: '4',
          3: '9',
          4: '1',
          5: '2',
          6: '3',
      },
      nested: Nested(
          a: "Decode me!",
          b: 'z',
      ),
      tuple: (3, 7),
      vec: [
          (a: "Nested 1", b: 'x'),
          (a: "Nested 2", b: 'y'),
          (a: "Nested 3", b: 'z'),
      ],
    )>) |> IO.inspect
  end
end
