# Volcanic Soil — User's Guide

## What it does

Volcanic Soil is a super-fertile ground block with an animated lava-touched texture. It exists in two states:

| State | Node | Description |
|---|---|---|
| **Natural** | `volcanic_soil:volcanic_soil` | Untilled; shovel-mined; can be tilled by a hoe |
| **Tilled** | `volcanic_soil:volcanic_soil_tilled` | Fertilized; crops grow faster here; degrades after use |

Obtaining volcanic soil from a recipe always produces the **natural** form. Till it with a hoe to unlock its full farming power.

---

## Getting volcanic soil

### Method 1: Cooking compressed cobble (with moreblocks)

If `moreblocks` is installed:

1. Obtain **compressed cobble** from moreblocks (8× regular cobblestone → 1× compressed)
2. Smelt in a furnace with any fuel (1 second cook time)
3. Receive **8× Volcanic Soil** (natural form)

**Recipe:**
```
Furnace input: Moreblocks Compressed Cobble
Fuel: Any fuel
Cook time: 1 second
Output: 8× Volcanic Soil
```

Compressed cobble variants also work (desert cobble compressed, etc.). If `moreblocks` is not installed, this acquisition path is unavailable.

### Method 2: Processing stone in a Lava Crucible (advanced)

If `lava_crucible` is installed, place a crucible over lava:

1. **Single Crucible:** Add 1× stone → receive **1× Volcanic Soil** (+ bonus dust)
2. **Double Crucible:** Add up to 2× stone → receive **up to 2× Volcanic Soil** (+ bonus dusts)
3. **Quad Crucible:** Add up to 4× stone → receive **up to 4× Volcanic Soil** (+ bonus dusts)

See the Lava Crucible documentation for full details.

---

## Farming modes

Volcanic Soil supports two different farming modes:

### Mode 1: Convenient (default — `volcanic_soil_require_tilling = false`)

In this mode, tilling is **optional**:

- **Plant directly** on natural volcanic soil without using a hoe
- Crops grow with the same speed boost as tilled soil
- Natural soil provides unlimited crops
- **Tilling is optional** — if you till, fertility cycles are tracked (5 harvests by default)

**Best for:** Casual farming, experimentation, and early-game setup.

**Workflow:**
1. Place volcanic soil
2. Plant crops directly
3. Crops grow fast without any extra setup
4. (Optional) Till with hoe to enable fertility tracking and get harvest limits

### Mode 2: Strict (optional — `volcanic_soil_require_tilling = true`)

In this mode, tilling is **required**:

- Crops **cannot** be planted on natural volcanic soil
- Must till with a hoe first to create tilled soil
- Only tilled soil provides growth boost
- Tilled soil tracks fertility cycles (default 5 harvests)

**Best for:** Resource management, performance-sensitive servers, and long-term survival gameplay.

**Workflow:**
1. Place volcanic soil
2. Till with hoe to create tilled soil
3. Plant crops (must be on tilled soil)
4. Crops grow fast on tilled soil only
5. After 5 harvests, soil degrades to regular dirt/soil

---

## Farming workflow (default mode)

### 1. Till the soil (optional)

Right-click `volcanic_soil:volcanic_soil` with any hoe. It converts to
`volcanic_soil:volcanic_soil_tilled` and starts with a full fertility counter
(default: 5 cycles, configurable — see *Configuration* below).

This step is **optional** in default mode. Crops will grow on untilled soil with
the same speed boost. Tilling is only needed if you want to track fertility cycles
and have soil degrade after repeated harvests.

### 2. Plant and harvest normally

Tilled volcanic soil acts as `soil=3` (wet tilled soil) and includes all
x_farming fertility groups (`grassland`, `desert`, `underground`, `ice_fishing`).
**Any crop from any farming mod can grow on it**, including crops with strict
fertility requirements like obsidian wart.

Crops also grow **faster** than on normal soil: an ABM fires periodically and
advances each growing crop by one extra stage, on top of the crop's own timer.
The boost interval is configurable (default every 30 seconds).

Saplings also get an extra growth boost when planted on volcanic soil (natural
or tilled). This boost triggers additional growth attempts, so tree growth is
typically faster than on ordinary dirt.

### 3. Fertility degrades with each harvest

Each time a **mature (fully-grown) crop** is harvested above tilled volcanic
soil, one fertility cycle is consumed. The remaining count is shown in the
block's tooltip when you hover over it with a pointing device, or displayed
on items you pick up (see below).

When the counter reaches zero the soil converts automatically to
`farming:soil_wet` when available, or `default:dirt` if that node exists.
If neither fallback node is present in the current game, the tilled volcanic
soil remains in place with its fertility exhausted instead of swapping to an
invalid node.

Harvesting an **immature** crop (breaking a growing-stage plant before it
matures) does **not** consume a cycle.

### 4. Picking up tilled soil

If you dig `volcanic_soil:volcanic_soil_tilled` directly, you receive a **tilled
item** that remembers the remaining cycles — e.g.
*"Volcanic Soil (Tilled, 3 cycles remaining)"*. Re-placing it restores that
count; no progress is lost.

Tilling a natural volcanic soil block with a hoe always starts the counter at the
configured maximum, regardless of any previously-placed tilled blocks.

---

## Properties

### Natural form (`volcanic_soil:volcanic_soil`)

- **Mining tool:** Shovel (crumbly=3)
- **Stack size:** 99
- **Soil group:** `soil=1` (tillable by hoe, not a planting surface by itself)
- **Spreading:** Spreads like dirt (`spreading_dirt_type=1`)
- **Visual:** Animated glowing lava texture

### Tilled form (`volcanic_soil:volcanic_soil_tilled`)

- **Mining tool:** Shovel (crumbly=3)
- **Stack size:** 1 per slot (carries metadata)
- **Soil group:** `soil=3` (acts as wet tilled soil)
- **Fertility groups:** `grassland`, `desert`, `underground`, `ice_fishing`, `field`, `wet`
- **Visual:** Warmer-toned animated texture

---

## Configuration

Add these settings to `minetest.conf`:

| Setting | Default | Description |
|---|---|---|
| `volcanic_soil_require_tilling` | `false` | If false (default), crops can grow on natural volcanic soil and tilling is optional. If true, crops require tilled soil (strict mode, original behavior) |
| `volcanic_soil_fertility_cycles` | `5` | Full harvests before tilled soil degrades (min 1, max 100) |
| `volcanic_soil_growth_boost_interval` | `1` | Seconds between extra growth ticks (min 1, max 300; lower values can increase server load on large farms) |
| `volcanic_soil_growth_boost_steps` | `1` | Growth stages advanced per boost tick (min 1, max 8) |
| `volcanic_soil_sapling_boost_interval` | `20` | Seconds between extra sapling growth attempts (min 1, max 300; lower values can increase server load with many saplings) |
| `volcanic_soil_bypass_light_check` | `true` | If true, volcanic-soil boosts can progress crops (and large cactus seedlings from default/x_farming) without normal sunlight checks |
| `volcanic_soil_harvest_cycle_allow_patterns` | `^farming:,^x_farming:,^better_farming:,^default:papyrus$,^default:cactus$` | Comma-separated Lua patterns for node names that can consume fertility cycles on player harvest |
| `volcanic_soil_harvest_cycle_deny_patterns` | `_fruit$,_fruit_mark$,_seedling$` | Comma-separated Lua patterns that always block cycle consumption (applied before allow patterns) |

**Example:**
```
volcanic_soil_require_tilling = false
volcanic_soil_fertility_cycles = 8
volcanic_soil_growth_boost_interval = 1
volcanic_soil_growth_boost_steps = 1
volcanic_soil_sapling_boost_interval = 15
volcanic_soil_bypass_light_check = true
volcanic_soil_harvest_cycle_allow_patterns = ^farming:,^x_farming:,^better_farming:,^default:papyrus$,^default:cactus$
volcanic_soil_harvest_cycle_deny_patterns = _fruit$,_fruit_mark$,_seedling$
```

These settings are also exposed in the in-game settings editor under *Volcanic Soil*.

---

## Upgrade path and breaking change note

> **If you have an existing world with placed `volcanic_soil:volcanic_soil` blocks:**
> After updating the mod, those blocks become soil=1 (untilled, not a planting
> surface). Crops currently planted on them will lose their soil support.
> Till the blocks again with a hoe to restore full fertility.

---

## Progression

**Easier path:** Cooking compressed cobble is available early and always produces 8× soil per block.

**Advanced path:** Lava Crucible processing offers variable yields (1–9 per block) and bonus mineral dusts, rewarding more complex setup.

Both recipes are kept available so players can choose their preferred method.

## Future enhancement notes

One possible future upgrade is an instant-grow mode that triggers as soon as a
seed or sapling is planted on volcanic soil. That would make the mod feel more
like a high-speed fertile substrate, but it would also change balance more
dramatically than the current faster-growth approach.

Another future enhancement idea is random crop multiplication on harvest while
using tilled volcanic soil (for example, occasional bonus yield drops). This
would add a luck/progression layer but should be configurable so servers can
tune economy impact.

Because most node names are lowercase in practice, harvest pattern matching is
currently case-sensitive. If mixed-case node names become common in modpacks,
an optional case-insensitive matching mode could be added as a configuration
toggle.

Add a toggle for disabling tilled state and simply growing crops on untilled volcanic soil