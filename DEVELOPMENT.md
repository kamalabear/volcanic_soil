# Volcanic Soil — Developer's Guide

## File structure

| File | Purpose |
|---|---|
| `init.lua` | Entry point — loads `volcanic_soil.lua` |
| `volcanic_soil.lua` | Node definitions, ABM, on_dignode callback, config |
| `mod.conf` | Mod name, display name, description, `depends`, `optional_depends` |
| `settingtypes.txt` | In-game settings editor entries |
| `textures/lava_soil.png` | Animated lava soil texture (natural form) |
| `textures/lava_soil_tilled.png` | Animated top texture for tilled form (furrowed) |
| `LICENSE` | MIT license |

---

## Node state diagram

```
[recipe / crucible output]
         │
         ▼
volcanic_soil:volcanic_soil      (natural, soil=1)
         │
         │  hoe right-click (farming hoe reads ndef.soil.dry)
         ▼
volcanic_soil:volcanic_soil_tilled   (fertilized, soil=3)
         │
         │  N mature crop harvests (on_dignode counter)
         ▼
 farming:soil_wet  (or default:dirt if farming mod absent)
```

Digging `volcanic_soil:volcanic_soil_tilled` directly drops a tilled-form item
that carries the remaining cycle count in item metadata, so no progress is lost
when a player moves the block.

---

## Node definitions

### `volcanic_soil:volcanic_soil` (natural / untilled)

```lua
minetest.register_node("volcanic_soil:volcanic_soil", {
    description = "Volcanic Soil",
    is_ground_content = true,
    groups = {crumbly=3, soil=1, spreading_dirt_type=1},
    stack_max = 99,
    soil = {
        base = "volcanic_soil:volcanic_soil",
        dry  = "volcanic_soil:volcanic_soil_tilled",
        wet  = "volcanic_soil:volcanic_soil_tilled",
    },
    tiles = { { name="lava_soil.png", animation={...} } },
    sounds = default.node_sound_dirt_defaults()
})
```

**Key points:**
- `soil=1` signals that a hoe can till this node.
- The `soil` property table is read by the asuna farming hoe (`hoes.lua`): it checks `group:soil == 1` and then converts the node to `ndef.soil.dry`. No `on_rightclick` handler is needed on the soil node itself.
- The `soil.wet` entry is also set (same destination) to prevent the farming ABM treating this as a dry-soil candidate for wetting/drying cycles.

### `volcanic_soil:volcanic_soil_tilled` (fertilized / tilled)

```lua
minetest.register_node("volcanic_soil:volcanic_soil_tilled", {
    description = "Volcanic Soil (Tilled)",
    is_ground_content = true,
    groups = {
        crumbly=3, soil=3, spreading_dirt_type=1, wet=1,
        field=1, grassland=1, desert=1, underground=1, ice_fishing=1,
    },
    soil = {
        base = "volcanic_soil:volcanic_soil",
        dry  = "volcanic_soil:volcanic_soil_tilled",
        wet  = "volcanic_soil:volcanic_soil_tilled",
    },
    drop = "",   -- managed by after_dig_node
    tiles = {
        { name="lava_soil_tilled.png", animation={...} }, -- top
        { name="lava_soil.png", animation={...} },        -- bottom
        { name="lava_soil.png", animation={...} },        -- sides
    },
    sounds = default.node_sound_dirt_defaults(),
    on_construct    = function(pos) ... end,
    after_place_node = function(pos, placer, itemstack) ... end,
    after_dig_node  = function(pos, oldnode, oldmetadata, digger) ... end,
})
```

**Key points:**
- `soil=3` makes it equivalent to wet tilled soil for all farming mods.
- Extra groups (`grassland`, `desert`, `underground`, `ice_fishing`, `field`) cover all x_farming fertility requirements so any crop can grow here.
- Self-referential `soil` table (`dry` and `wet` both point back to itself) prevents the asuna farming wet/dry ABM from ever converting this node away.
- `drop = ""` suppresses the default item drop. `after_dig_node` issues the item manually (see *Cycle count persistence* below).

---

## Cycle count persistence

The tilled node stores `volcanic_soil_cycles` (int) in its node metadata.

**Flow:**

1. **Tilling (hoe):** `on_construct` fires, sets `volcanic_soil_cycles` to `volcanic_soil.config.fertility_cycles`. The hoe uses `core.set_node` — no item is consumed — so `after_place_node` is not called; the value always starts at the configured maximum.

2. **Placing from inventory:** `on_construct` fires first (sets default), then `after_place_node` fires and overwrites with the value stored in the item's metadata (if positive). This restores progress from a previously-dug tilled block.

3. **Digging:** `after_dig_node(pos, oldnode, oldmetadata, digger)` is called.
   - `oldmetadata` is a plain table (`{fields={...}, inventory={...}}`), the format returned by `MetaDataRef:to_table()`.
   - Reads `tonumber(oldmetadata.fields["volcanic_soil_cycles"])`.
   - Creates an `ItemStack("volcanic_soil:volcanic_soil_tilled")`, stores the cycle count and a human-readable description in the item's metadata.
   - Gives the stack to the digger's inventory (or drops at position if full).

---

## Growth boost ABM

```lua
minetest.register_abm({
    label     = "Volcanic soil growth boost",
    nodenames = {"group:growing"},
    neighbors = {"volcanic_soil:volcanic_soil_tilled"},
    interval  = volcanic_soil.config.growth_boost_interval,  -- default 30 s
    chance    = 1,
    action    = function(pos) ... end,
})
```

The action:
1. Verifies `minetest.get_node({pos.x, pos.y-1, pos.z}).name == "volcanic_soil:volcanic_soil_tilled"`.
2. Parses the crop node name with `node.name:match("^(.-)(%d+)$")` to extract base and stage number.
3. If `minetest.registered_nodes[base .. (stage+1)]` exists, calls `minetest.set_node` to advance the crop one stage.

This works for all mods that follow the `modname:cropname_N` naming convention (asuna farming, x_farming, better_farming). Seeds (which typically don't have the `growing` group) are unaffected.

---

## Harvest cycle counter

```lua
minetest.register_on_dignode(function(pos, oldnode) ... end)
```

Fires on every node dig worldwide. The checks are fast and return early for non-matching nodes:

1. `minetest.get_item_group(oldnode.name, "plant") == 0` → return (not a plant)
2. `minetest.get_item_group(oldnode.name, "growing") ~= 0` → return (still growing, not mature)
3. Node at `{pos.x, pos.y-1, pos.z}` ≠ `"volcanic_soil:volcanic_soil_tilled"` → return

When all checks pass, decrements `volcanic_soil_cycles` in node metadata. If the result ≤ 0, replaces the node with `farming:soil_wet` (or `default:dirt` as fallback).

---

## Sapling growth boost ABM

```lua
minetest.register_abm({
    label     = "Volcanic soil sapling boost",
    nodenames = {"group:sapling"},
    neighbors = {
        "volcanic_soil:volcanic_soil",
        "volcanic_soil:volcanic_soil_tilled",
    },
    interval  = volcanic_soil.config.sapling_boost_interval, -- default 20 s
    chance    = 2,
    catch_up  = false,
    action    = function(pos) ... end,
})
```

Behavior:
1. Runs only when the sapling is directly above natural or tilled volcanic soil.
2. For timer-based saplings, starts the node timer with `start(0)` to trigger an immediate growth attempt.
3. For ABM-based saplings (e.g. ethereal), calls that mod's growth function when available.
4. Uses `catch_up = false` to avoid large growth bursts after server downtime.

---

## Configuration

Loaded at mod startup in `volcanic_soil.lua`:

```lua
volcanic_soil.config = {
    fertility_cycles      = tonumber(minetest.settings:get("volcanic_soil_fertility_cycles"))      or 5,
    growth_boost_interval = tonumber(minetest.settings:get("volcanic_soil_growth_boost_interval")) or 30,
    sapling_boost_interval = tonumber(minetest.settings:get("volcanic_soil_sapling_boost_interval")) or 20,
}
```

Settings are also declared in `settingtypes.txt` for the in-game editor.

---

## Texture and animation

Both textures are animated vertical strips (16 px wide, 16 px per frame):

| Texture | Description |
|---|---|
| `lava_soil.png` | Natural form — original lava-touched palette |
| `lava_soil_tilled.png` | Tilled form — warmer-toned variant (boosted green, reduced blue channels) |

Animation definition used by both:
```lua
animation = {
    type     = "vertical_frames",
    aspect_w = 16,
    aspect_h = 16,
    length   = 6.0,
}
```

---

## Recipes

Both recipes produce the **natural** form (`volcanic_soil:volcanic_soil`). Players till it to unlock fertilized behaviour.

### Cooking recipe (compressed cobble)

```lua
minetest.register_craft({
    type     = "cooking",
    output   = "volcanic_soil:volcanic_soil 8",
    recipe   = "moreblocks:cobble_compressed",
    cooktime = 1,
})
```

### Crucible output (stone input)

When `lava_crucible` is installed the crucible outputs `volcanic_soil:volcanic_soil`
when processing stone. See the Lava Crucible mod for registration details.

---

## Integration notes

- **Any mod** referencing `group:soil` ≥ 3 will recognise the tilled form as a valid planting surface.
- **x_farming** bonemeal checks `ndef.groups` for fertility group membership; the tilled node's groups cover all known x_farming fertility values.
- **bonemeal mod** checks `group:soil`, `group:sand`, or `group:can_bonemeal` — the tilled node satisfies `group:soil`.
- **Auto-harvesters** (e.g. pipeworks-based machines) that dig crops via the normal dig path will also trigger `on_dignode`, consuming fertility cycles. This is intentional.


## Dependencies and integration

### Required dependencies

- **moreblocks:** Provides `cobble_compressed` for the cooking recipe
- **ore_dust:** Provides dust items that may drop from crucibles that output this soil

### Optional dependencies

- **lava_crucible:** If installed, crucibles will process stone into volcanic_soil:volcanic_soil with bonus dust. If not installed, only the cooking recipe is available.

### Integration points

Any mod can incorporate volcanic_soil by:

1. Referencing the node by name: `volcanic_soil:volcanic_soil`
2. Using the soil group: `minetest.get_item_group(nodename, "soil") > 0`
3. Using the crumbly group for tool recipes: `minetest.get_item_group(nodename, "crumbly") > 0`

For example, farming mods can place crops on volcanic soil by checking the `soil` group.

---

## Extending volcanic_soil

### Adding new recipes

To add a new recipe producing volcanic soil, register a craft:

```lua
minetest.register_craft({
    type = "cooking",
    output = "volcanic_soil:volcanic_soil 4",
    recipe = "mymod:lava_stone",
    cooktime = 2
})
```

Or shapeless:

```lua
minetest.register_craft({
    type = "shapeless",
    output = "volcanic_soil:volcanic_soil",
    recipe = {"mymod:lava_fragment", "default:stone"},
})
```

### Visual customization

To replace the animated texture, simply overwrite `textures/lava_soil.png` with your own texture (must be 16×96 pixels for the 6-frame animation).

To disable animation, modify the node definition to remove the animation table:

```lua
tiles = { "lava_soil.png" }  -- Static texture instead
```

---

## Notes

- **is_ground_content:** Set to `true` to allow cave generation and compaction by other mods
- **Spreading dirt:** The `spreading_dirt_type=1` group enables dirt-spreading mechanics if nearby mods implement it (e.g., grass spreading)
- **Node ID unified:** Both cooking and crucible paths output the same `volcanic_soil:volcanic_soil` node to consolidate two soil-generation paths into one

## License

See [LICENSE](LICENSE).
