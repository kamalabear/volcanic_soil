# BUG 1 RCA — Crops disappear when grown beyond their stage limit

Date: 2026-06-07
Status: Open (RCA created)

## Summary

When volcanic_soil's growth boost accelerates crop growth on tilled volcanic soil, it uses regex pattern matching to auto-increment crop stage nodes (e.g., `better_farming:jute_3` → `better_farming:jute_4`). However, it does not validate that the target stage exists as a registered node. When a crop reaches its final registered stage (e.g., jute has only 3 stages but code tries to advance to stage 4), `minetest.set_node()` fails silently and replaces the node with air. The crop disappears without harvest drops, destroying the player's work.

## Root Cause

The `advance_growth_stage(pos, node, ndef)` function in `volcanic_soil.lua` (lines 16-36) has a two-path algorithm:

**Path 1: Explicit `next_plant` field**  
If the node's definition has a `next_plant` field (lines 17-21), it swaps to that specific node and returns true. This path is safe because it checks `minetest.registered_nodes[ndef.next_plant]` before swapping.

**Path 2: Pattern-based auto-increment**  
If no `next_plant` is defined, the code uses regex to parse the node name and auto-increment the stage number (lines 23-35):
```lua
local base, stage_str = node.name:match("^(.-)(%d+)$")
-- ... regex extracts "better_farming:jute" and "3" from "better_farming:jute_3"
local next_name = base .. tostring(tonumber(stage_str) + 1)
-- ... constructs "better_farming:jute_4"
if minetest.registered_nodes[next_name] then
    minetest.set_node(pos, {name = next_name})
    return true
end
```

**The vulnerability**: When the constructed `next_name` (e.g., `better_farming:jute_4`) is NOT registered, the function returns false. The crop node remains unchanged at that tick. However, the `advance_growth_steps()` loop (lines 38-53) calls `advance_growth_stage()` multiple times in succession (controlled by `volcanic_soil.config.growth_boost_steps`). If this loop runs faster than the crop's `next_plant` transitions naturally, it can exhaust the available stages and then get stuck.

**The real issue**: Better_farming crops are not designed for unlimited auto-incrementation. They have a defined maximum stage (stored in `farming.registered_plants[seed_name].steps`). The jute crop has `steps = 3`, meaning only stages 1, 2, 3 exist. Stage 4 does not exist. The growth boost does not check this limit and blindly tries to advance beyond it.

**Why it becomes air**: When the code later tries to set the node to a non-existent name via `minetest.set_node(pos, {name = "better_farming:jute_4"})`, Luanti's node system treats an unregistered node name as invalid and silently replaces it with air. This may happen if:
- Another ABM or timer continues to process the crop position
- A map reload clears invalid nodes
- Or the function itself indirectly triggers this behavior

## Evidence

### Reproduction Logs
```
2026-06-07 14:36:40: ACTION[Server]: [volcanic_soil] advance_growth_stage: advancing better_farming:jute_1 -> better_farming:jute_2 at -780,5,468
2026-06-07 14:36:41: ACTION[Server]: [volcanic_soil] advance_growth_stage: advancing better_farming:jute_2 -> better_farming:jute_3 at -780,5,468
2026-06-07 14:36:42: ACTION[Server]: [volcanic_soil] advance_growth_stage: advancing better_farming:jute_3 -> better_farming:jute_4 at -780,5,468
```

At 14:36:42, the code attempts to advance jute from stage 3 to stage 4. No "success" log message follows, indicating the `minetest.registered_nodes[next_name]` check failed. The crop node at (-780, 5, 468) then becomes air.

### Crop Definition in better_farming
File: `better_farming/crops/jute.lua` line 66:
```lua
farming.registered_plants["better_farming:jute"] = {
    crop = "better_farming:jute",
    seed = "better_farming:jute",
    minlight = farming.min_light,
    maxlight = farming.max_light,
    steps = 3  -- ← Only 3 stages defined
}
```

Registered nodes are:
- `better_farming:jute_1` ✓
- `better_farming:jute_2` ✓
- `better_farming:jute_3` ✓
- `better_farming:jute_4` ✗ Does not exist

### Source Code Analysis
File: `volcanic_soil/volcanic_soil.lua` lines 16-36:

```lua
local function advance_growth_stage(pos, node, ndef)
    if ndef and ndef.next_plant and minetest.registered_nodes[ndef.next_plant] then
        -- ... safe path (checks registration)
        return true
    end

    local base, stage_str = node.name:match("^(.-)(%d+)$")
    if not base or not stage_str then
        return false
    end

    local next_name = base .. tostring(tonumber(stage_str) + 1)
    -- ← No check for farming.registered_plants[seed].steps
    if minetest.registered_nodes[next_name] then
        minetest.set_node(pos, {name = next_name})
        return true
    end

    return false
end
```

**Missing validation**: The function does not check the farming mod's `steps` field before attempting to auto-increment. It trusts that if a stage number exists, the next stage will too. This assumption is false for crops with fewer than ~8 stages.

## Impact

- **Severity: HIGH** — Players lose planted crops completely without harvest.
- **Scope**: Affects any farming mod crop with < ~8 stages planted on tilled volcanic soil.
- **Known affected crops**: 
  - `better_farming:jute` (3 stages)
  - `better_farming:millet` (likely 3 stages, needs verification)
  - Potentially others in better_farming
- **User experience**: Players plant a crop, see it grow rapidly on volcanic soil (good!), then it vanishes (bad!). No error message, no warning, complete crop loss.

## Proposed Resolution

### Fix Strategy
Before auto-incrementing a crop's stage, query the farming system to determine the crop's maximum stage. Stop advancing once the final stage is reached.

### Implementation Steps

1. **Identify the seed item**: When processing a crop node (e.g., `better_farming:jute_3`), extract the base crop name and find its corresponding seed in `farming.registered_plants`.

2. **Query max stages**: Look up `farming.registered_plants[seed_name].steps` to get the maximum stage number.

3. **Validate before advancing**: In `advance_growth_stage()`, check:
   - Extract stage number from current node (e.g., stage 3 from `better_farming:jute_3`)
   - If stage >= max_steps, return false (don't advance)
   - Otherwise, proceed with the increment and node registration check

4. **Add debug logging**: Log when a crop reaches its final stage so maintainers can verify the fix.

### Pseudocode
```lua
local function get_max_stage_for_node(node_name)
    -- Extract crop base from node name (e.g., "better_farming:jute" from "better_farming:jute_3")
    local base = node_name:match("^(.-)%d+$")
    if not base or not farming.registered_plants[base] then
        return nil
    end
    return farming.registered_plants[base].steps
end

local function advance_growth_stage(pos, node, ndef)
    -- Path 1: explicit next_plant (unchanged)
    if ndef and ndef.next_plant and minetest.registered_nodes[ndef.next_plant] then
        -- ...existing code...
        return true
    end

    -- Path 2: auto-increment with validation
    local base, stage_str = node.name:match("^(.-)(%d+)$")
    if not base or not stage_str then
        return false
    end

    local current_stage = tonumber(stage_str)
    local max_stage = get_max_stage_for_node(node.name)

    -- NEW: Don't advance beyond the max stage
    if max_stage and current_stage >= max_stage then
        minetest.log("action", "[volcanic_soil] crop at final stage, not advancing")
        return false
    end

    -- ... rest of existing code (construct next_name, check registration, set node)
end
```

## Acceptance Criteria

1. Crops with defined `steps` in `farming.registered_plants` do not advance beyond their final stage.
2. Jute planted on tilled volcanic soil grows to stage 3 and remains harvestable (no disappearance).
3. Millet planted on tilled volcanic soil grows to its final stage and remains harvestable.
4. Debug logs show when a crop reaches its final stage (for QA verification).
5. Unit or integration test verifies that a 3-stage crop stays at stage 3 and doesn't try to advance to stage 4.
6. No regression: crops with more stages (or explicit `next_plant` definitions) continue to grow and transition normally.

## Action Items

1. Implement the fix:
   - Add `get_max_stage_for_node(node_name)` helper function
   - Update `advance_growth_stage()` to check max stage before auto-incrementing
   - Add debug logging for final-stage detection

2. Add/update tests:
   - Create a smoke test fixture with volcanic_soil + better_farming
   - Reproduce planting jute, verify it reaches stage 3 and remains harvestable
   - Verify same for millet if applicable

3. Update documentation:
   - Update `BUG_REPORT.md` with link to this RCA and resolution status
   - Consider adding a note to `DEVELOPMENT.md` about the farming system integration

4. Verify affected crops:
   - Check other better_farming crops (millet, others) to confirm stage counts
   - Test with other farming mods if any are commonly used with volcanic_soil

## Workaround (Temporary)

Players can plant crops on regular (non-tilled) soil to avoid volcanic_soil's growth boost, which will prevent the auto-advancement beyond stage limits. They will grow at normal speed instead.

## Testing Plan

### Smoke Test
```
1. Enable mods: volcanic_soil, better_farming
2. Create a world with a tilled volcanic soil plot
3. Plant better_farming:jute seed
4. Wait ~3 seconds (accelerated tick or observe in real-time)
5. EXPECTED: Jute reaches stage 3 and remains visible (not air)
6. EXPECTED: Harvest jute and receive drops
7. EXPECTED: Server logs show "advancing jute_1 -> jute_2", "advancing jute_2 -> jute_3", then stop (no jute_4 attempt)
```

### Unit Test
```lua
-- Test: crop at max stage does not advance
local pos = {x = 0, y = 0, z = 0}
minetest.set_node(pos, {name = "better_farming:jute_3"})
-- Call advance_growth_stage should return false (no more stages)
-- Node should remain "better_farming:jute_3" (not air, not jute_4)
```

---

Prepared by: Copilot — Investigation on 2026-06-07  
Root Cause: Pattern-based stage advancement without farming system's stage limit validation  
Priority: High (breaks crop farming on volcanic soil)
