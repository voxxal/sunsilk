defmodule Veloren.Helper do
  def load_asset(id) do
    {:ok, res} = File.read("./veloren/assets/" <> String.replace(id, ".", "/") <> ".ron")

    Ron.decode(res)
  end
end

defmodule Veloren.Loot do
  def normalize(loot_table) do
    total = Enum.reduce(loot_table, 0, fn {chance, _}, acc -> acc + chance end)

    Enum.reduce(loot_table, [], fn {chance, entry}, acc ->
      acc ++
        case entry do
          {:LootTable, {id}} ->
            Enum.map(normalize(Veloren.Helper.load_asset(id)), fn {c, x} ->
              {c * chance / total, x}
            end)

          e ->
            [{chance / total, e}]
        end
    end)
  end

  def item_to_name(spec) do
    case spec do
      {:Item, {id}} ->
        {:ItemDef, %{name: name}} = Veloren.Helper.load_asset(id)
        name

      {:ModularWeapon, %{material: material, tool: tool}} -> Atom.to_string(material) <> " " <> Atom.to_string(tool)
    end
  end

  # Enum.map(Veloren.Loot.normalize(Veloren.Helper.load_asset("common.loot_tables.dungeon.tier-1.boss")), fn {chance, x} -> {chance, Veloren.Loot.item_to_name(x)} end)
end
