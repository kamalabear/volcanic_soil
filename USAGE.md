# Volcanic Soil — User's Guide

## What it does

Volcanic Soil is a fertile ground block. It is shovel-mined (crumbly group) and spreads like dirt, making it useful for:
- Creating fertile terrain for farming
- Decorating landscapes with an animated "lava-touched" aesthetic
- Fuel for certain crafts requiring soil-type materials

The node is unified output from two different recipe paths (cooking and crucible), giving it a central role in magmatic/thermal-based progression.

---

## Getting volcanic soil

### Method 1: Cooking compressed cobble (simplest)

1. Obtain **compressed cobble** from Minetest or moreblocks (8× regular cobblestone crafted into 1× compressed)
2. Smelt in a furnace with any fuel (1 second cook time)
3. Receive **8× Volcanic Soil**

**Recipe:**
```
Furnace input: Moreblocks Compressed Cobble
Fuel: Any fuel
Cook time: 1 second
Output: 8× Volcanic Soil
```

Compressed cobble variants also work: desert cobble compressed, etc.

### Method 2: Processing stone in a Lava Crucible (advanced)

If `lava_crucible` is installed, place a crucible over lava:

1. **Single Crucible:** Add 1× stone → receive **1× Volcanic Soil** (+ bonus dust)
2. **Double Crucible:** Add up to 2× stone → receive **up to 2× Volcanic Soil** (+ bonus dusts)
3. **Quad Crucible:** Add up to 4× stone → receive **up to 4× Volcanic Soil** (+ bonus dusts)

Larger crucibles process faster and may output multiple soil blocks per stone. See the Lava Crucible documentation for full mechanic details.

---

## Properties

- **Type:** Ground material (node)
- **Mining tool:** Shovel (crumbly group)
- **Stack size:** 99 items
- **Spreading:** Spreads like dirt (to compatible surfaces, if spreading_dirt_type is enabled elsewhere)
- **Visual:** Animated with a glowing lava texture (6-second loop, 6 frames)
- **Sounds:** Default dirt breaking/placing sounds

---

## Uses

### Farming & agriculture

Volcanic Soil acts as `soil=3` group, making it compatible with:
- Farming mods that recognize soil-type blocks
- Plant growth mechanics that require soil beneath crops
- Fertilization systems

### Building & decoration

- Create an actively animated, lava-themed landscape
- Build with the distinctive glow to create themed bases or structures
- Use as visual terrain variation in custom worlds

### Crafting & recipes

Other mods can use Volcanic Soil in recipes by referencing:
- Node name: `volcanic_soil:volcanic_soil`
- Groups: `crumbly=3`, `soil=3`, `spreading_dirt_type=1`

---

## Progression

**Easier path:** Cooking compressed cobble is available early and always produces 8× soil per compressed block.

**Advanced path:** Lava Crucible processing offers variable yields (1–9 per block) and bonus mineral dusts, rewarding more complex setup.

Both recipes are kept available so players can choose their preferred method.
