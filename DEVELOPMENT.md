# Volcanic Soil — Developer's Guide

## File structure

| File | Purpose |
|---|---|
| `init.lua` | Entry point — loads `volcanic_soil.lua` |
| `volcanic_soil.lua` | Node definition and cooking recipe |
| `mod.conf` | Mod name, display name, description, `depends`, `optional_depends` |
| `textures/` | Animated lava soil texture (`lava_soil.png`) |
| `LICENSE` | MIT license |

---

## Node definition

```lua
minetest.register_node("volcanic_soil:volcanic_soil", {
    description = "Volcanic Soil",
    is_ground_content = true,
    groups = {crumbly=3, soil=3, spreading_dirt_type=1},
    stack_max = 99,
    tiles = {
        {
            name = "lava_soil.png",
            backface_culling = false,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 6.0,
            },
        },
    },
    sounds = default.node_sound_dirt_defaults()
})
```

### Properties explained

| Property | Value | Purpose |
|----------|-------|---------|
| `description` | "Volcanic Soil" | Display name in inventory |
| `is_ground_content` | `true` | Caves generate through it; can be compacted by mods |
| `groups.crumbly` | 3 | Shovel-minable (crumbly=1 is easiest, hardness scales) |
| `groups.soil` | 3 | Compatible with farming and soil-type recipes |
| `groups.spreading_dirt_type` | 1 | Participates in dirt spreading (if enabled nearby) |
| `stack_max` | 99 | 99 blocks per inventory stack |
| `tiles[1].animation` | Vertical frames, 6s loop | Animates the lava texture (6 frames, 1s each) |
| `sounds` | Default dirt | Uses standard dirt break/place sounds |

---

## Texture and animation

**Texture file:** `textures/lava_soil.png`

The texture is 96 pixels tall (16 wide × 6 frames high), displaying 6 sequential animation frames in a vertical strip. The animation plays at 1 second per frame (6s total loop).

Animation definition:
```lua
animation = {
    type = "vertical_frames",      -- Frames stacked vertically
    aspect_w = 16,                 -- Frame width in pixels
    aspect_h = 16,                 -- Frame height in pixels
    length = 6.0,                  -- Total animation duration (seconds)
}
```

---

## Recipes

### Cooking recipe (compressed cobble)

```lua
minetest.register_craft({
    type = "cooking",
    output = "volcanic_soil:volcanic_soil 8",
    recipe = "moreblocks:cobble_compressed",
    cooktime = 1
})
```

- **Input:** Any compressed cobble variant (e.g., `moreblocks:cobble_compressed`)
- **Output:** 8× Volcanic Soil per compressed block
- **Cook time:** 1 second (very fast)
- **Furnace:** Works in any standard furnace

### Crucible output (stone input)

When `lava_crucible` is installed, the crucible outputs `volcanic_soil:volcanic_soil` when processing stone:

- **Input:** Stone-group items (varies with crucible tier)
- **Output:** 1–9× Volcanic Soil (varies with crucible tier and processing stage)
- **Bonus:** Random mineral dust (from ore_dust pool)

The crucible directly calls `volcanic_soil` as its soil output node via the `volcanic_soil:volcanic_soil` node name.

---

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
