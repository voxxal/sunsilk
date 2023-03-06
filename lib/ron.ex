defmodule Ron.Parser do
  import NimbleParsec

  @moduledoc """
  Ron Parsing lib.
  """
  ws_single = choice([utf8_char([?\n]), utf8_char([?\t]), utf8_char([?\r]), utf8_char([?\s])])

  comment =
    choice([
      string("//")
      |> repeat(
        lookahead_not(choice([utf8_char([?\n]), eos()]))
        |> utf8_char([])
      )
      |> tag(:line_comment),
      string("/*")
      |> repeat(
        lookahead_not(string("*/"))
        |> utf8_char([])
      )
      |> string("*/")
      |> tag(:block_comment)
    ])

  ws = optional(repeat(choice([ws_single, comment])))

  comma = ignore(ws) |> string(",") |> ignore(ws)

  digit = utf8_char([?0..?9])

  unsigned =
    choice([
      ignore(string("0b"))
      |> utf8_char([?0..?1])
      |> repeat(choice([utf8_char([?0..?1]), ignore(utf8_char([?_]))]))
      |> reduce({List, :to_integer, [2]}),
      ignore(string("0o"))
      |> utf8_char([?0..?7])
      |> repeat(choice([utf8_char([?0..?7]), ignore(utf8_char([?_]))]))
      |> reduce({List, :to_integer, [8]}),
      ignore(string("0x"))
      |> utf8_char([?0..?9, ?a..?f, ?A..?F])
      |> repeat(choice([utf8_char([?0..?9, ?a..?f, ?A..?F]), ignore(utf8_char([?_]))]))
      |> reduce({List, :to_integer, [16]}),
      digit
      |> repeat(choice([digit, ignore(utf8_char([?_]))]))
      |> reduce({List, :to_integer, [10]})
    ])
    |> unwrap_and_tag(:num)

  signed = optional(utf8_char([?+, ?-])) |> concat(unsigned) |> tag(:signed)

  float_std = digit |> repeat(digit) |> utf8_char([?.]) |> repeat(digit)

  float_frac = utf8_char([?.]) |> concat(digit) |> repeat(digit)

  float_exp =
    utf8_char([?e, ?E]) |> optional(utf8_char([?+, ?-])) |> concat(digit) |> repeat(digit)

  float_num = choice([float_std, float_frac]) |> optional(float_exp)

  float =
    optional(utf8_char([?+, ?-]))
    |> choice([string("inf"), string("NaN"), float_num])
    |> reduce({List, :to_float, []})
    |> unwrap_and_tag(:float)

  # TODO support unicode hexs (also actually fix string_escape sequences)
  string_escape = utf8_char([?\\]) |> utf8_char([?", ?\\, ?b, ?f, ?n, ?r, ?t])

  string_std =
    ignore(utf8_char([?"]))
    |> repeat(
      lookahead_not(choice([utf8_char([?"]), eos()]))
      |> choice([string_escape, utf8_char([])])
    )
    |> ignore(utf8_char([?"]))
    |> reduce({List, :to_string, []})

  # TODO support raw (harder to do than expected)

  # defcombinatorp(
  #   :string_raw_content,
  #   choice([utf8_char([?#]) |> concat(parsec(:string_raw_content)) |> utf8_char([?#]), utf8_char([?"]) |> ])
  # )

  # string_raw = utf8_char([?r]) |> parsec(:string_raw_content)

  string = string_std |> unwrap_and_tag(:string)

  char =
    ignore(utf8_char([?']))
    |> choice([string("\\'"), string("\\\\"), utf8_char(not: ?')])
    |> ignore(utf8_char([?']))
    |> tag(:char)

  bool =
    choice([string("true"), string("false")])
    |> map({String, :to_atom, []})
    |> unwrap_and_tag(:bool)

  option_some =
    ignore(string("Some"))
    |> ignore(ws)
    |> ignore(string("("))
    |> ignore(ws)
    |> parsec(:value)
    |> ignore(ws)
    |> ignore(string(")"))
    |> unwrap_and_tag(:option_some)

  option = choice([ignore(string("None")) |> tag(:option_none), option_some])

  list =
    ignore(utf8_char([?[]))
    |> ignore(ws)
    |> optional(
      parsec(:value)
      |> repeat(ignore(comma) |> parsec(:value))
      |> ignore(optional(comma))
    )
    |> ignore(ws)
    |> ignore(utf8_char([?]]))
    |> tag(:list)

  map_entry =
    parsec(:value)
    |> ignore(ws)
    |> ignore(utf8_char([?:]))
    |> ignore(ws)
    |> parsec(:value)
    |> tag(:map_entry)

  map =
    ignore(utf8_char([?{]))
    |> ignore(ws)
    |> optional(
      map_entry
      |> repeat(ignore(comma) |> concat(map_entry))
      |> ignore(optional(comma))
    )
    |> ignore(ws)
    |> ignore(utf8_char([?}]))
    |> tag(:map)

  tuple =
    ignore(utf8_char([?(]))
    |> optional(
      parsec(:value)
      |> repeat(ignore(comma) |> parsec(:value))
      |> ignore(optional(comma))
    )
    |> ignore(utf8_char([?)]))
    |> tag(:tuple)

  ident_std_first = utf8_char([?A..?Z, ?a..?z, ?_])
  ident_std_rest = utf8_char([?A..?Z, ?a..?z, ?0..?9, ?_])
  ident_std = ident_std_first |> repeat(ident_std_rest)
  ident_raw_rest = utf8_char([?A..?Z, ?a..?z, ?0..?9, ?_, ?., ?+, ?-])
  ident_raw = ignore(string("r#")) |> concat(ident_raw_rest) |> repeat(ident_raw_rest)

  ident = choice([ident_std, ident_raw]) |> reduce({List, :to_atom, []}) |> unwrap_and_tag(:ident)
  unit_struct = ident |> ignore(string("()")) |> tag(:unit_struct)
  tuple_struct = ident |> ignore(ws) |> concat(tuple) |> tag(:tuple_struct)

  named_field =
    ident
    |> ignore(ws)
    |> ignore(utf8_char([?:]))
    |> ignore(ws)
    |> parsec(:value)
    |> tag(:named_field)

  named_struct =
    optional(ident)
    |> ignore(ws)
    |> ignore(utf8_char([?(]))
    |> ignore(ws)
    |> optional(
      named_field
      |> repeat(ignore(comma) |> concat(named_field))
      |> ignore(optional(comma))
      |> ignore(ws)
    )
    |> ignore(utf8_char([?)]))
    |> tag(:named_struct)

  struct = choice([unit_struct, tuple_struct, named_struct])

  enum_variant_unit = ident |> tag(:enum_variant_unit)
  enum_variant_tuple = ident |> ignore(ws) |> concat(tuple) |> tag(:enum_variant_tuple)

  enum_variant_named =
    ident
    |> ignore(ws)
    |> ignore(utf8_char([?(]))
    |> optional(
      named_field
      |> repeat(ignore(comma) |> concat(named_field))
      |> ignore(optional(comma))
    )
    |> ignore(utf8_char([?)]))
    |> tag(:enum_variant_named)

  enum_variant = choice([enum_variant_unit, enum_variant_tuple, enum_variant_named])

  value =
    choice([
      float,
      unsigned,
      signed,
      string,
      option,
      char,
      bool,
      list,
      map,
      tuple,
      struct,
      enum_variant
    ])

  defparsecp(:value, value)

  ron = ignore(ws) |> parsec(:value) |> ignore(ws) |> eos()

  defparsec(:parse, ron)
end

defmodule Ron do
  defp traverse_named_struct({:named_struct, [{:ident, ident} | fields]}) do
    fields_parsed = for field <- fields, into: %{}, do: traverse([field])
    {ident, fields_parsed}
  end

  defp traverse_named_struct({:named_struct, fields}) do
    for field <- fields, into: %{}, do: traverse([field])
  end

  defp traverse_map_entry({:map_entry, [key, value]}) do
    {traverse([key]), traverse([value])}
  end

  defp traverse_map({:map, fields}) do
    for field <- fields, into: %{}, do: traverse_map_entry(field)
  end

  defp traverse_tuple({:tuple, tuple}) do
    List.to_tuple(Enum.map(tuple, fn v -> traverse([v]) end))
  end

  defp traverse(node) do
    node = hd(node)

    # TODO missing a couple things here
    case node do
      {:named_struct, _} -> traverse_named_struct(node)
      {:named_field, [{:ident, ident}, value]} -> {ident, traverse([value])}
      {:tuple_struct, [{:ident, ident}, tuple]} -> {ident, traverse_tuple(tuple)}
      {:map, _} -> traverse_map(node)
      {:map_entry, _} -> traverse_map_entry(node)
      {:tuple, _} -> traverse_tuple(node)
      {:enum_variant_unit, [{:ident, ident}]} -> ident
      {:list, list} -> Enum.map(list, fn v -> traverse([v]) end)
      {:char, char} -> hd(char)
      {:bool, bool} -> bool
      {:num, num} -> num
      {:signed, [?-, {:num, num}]} -> -num
      {:signed, [?+, {:num, num}]} -> num
      {:float, float} -> float
      {:string, string} -> string
      {:option_none, []} -> nil
      {:option_some, value} -> traverse([value])
    end
  end

  def decode(str) do
    case Ron.Parser.parse(str) do
      {:ok, res, _, _, _, _} -> traverse(res)
      {:error, _, _, _, _, _} -> raise "Failed to parse ron."
    end
  end
end
