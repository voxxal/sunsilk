defmodule Veloren.Helper do
  def load_asset(spec) do
    {:ok, res} = File.read("./veloren/assets/" <> String.replace(spec, ".", "/") <> ".ron")

    Ron.decode(res)
  end
end

defmodule Veloren.Loot do
  def normalize(loot_table) do
    total = Enum.reduce(loot_table, 0, fn {chance, _}, acc -> acc + chance end)

    Enum.reduce(loot_table, [], fn {chance, entry}, acc ->
      acc ++
        case entry do
          {:LootTable, {spec}} ->
            Enum.map(normalize(Veloren.Helper.load_asset(spec)), fn {c, x} ->
              {c * chance / total, x}
            end)

          e ->
            [{chance / total, e}]
        end
    end)
  end
end
