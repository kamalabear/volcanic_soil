# Bug Report: volcanic_soil

## Bug 1: Crops disappear when grown beyond their stage limit

Date: 2026-06-07
Status: Resolved - Fixed
Severity: High

### Summary
When volcanic_soil's growth boost accelerates crop growth, it can advance a crop beyond its final stage. If the crop's next stage node doesn't exist (e.g., advancing jute from stage 3 to stage 4), the crop node becomes air and disappears before harvest.

### Environment
- OS: Linux
- Context: Manual testing in Luanti
- Version: Latest from GitHub (Jun 7, 2026)
- Mods: volcanic_soil + better_farming (jute/millet)

### Steps To Reproduce
1. Prepare a tilled volcanic soil plot with growth boost active
2. Plant jute seed (better_farming:jute) on the tilled soil
3. Wait for crop to grow through stages 1 → 2 → 3 (takes ~3 seconds with growth boost)
4. Observe: Crop disappears before reaching harvestable stage (no better_farming:jute drops)

### Expected Result
- Crops should mature to their final stage and remain harvestable
- Crops should not advance beyond their registered stage limit
- Player can harvest the crop before it disappears

### Actual Result
- Crop advances through all stages including non-existent ones
- When volcanic_soil tries to advance stage 3 → stage 4 (which doesn't exist), the node becomes air
- Crop disappears completely without drops

### Logs/Error Output
```
2026-06-07 14:36:40: ACTION[Server]: [volcanic_soil] advance_growth_stage: advancing better_farming:jute_1 -> better_farming:jute_2 at -780,5,468
2026-06-07 14:36:41: ACTION[Server]: [volcanic_soil] advance_growth_stage: advancing better_farming:jute_2 -> better_farming:jute_3 at -780,5,468
2026-06-07 14:36:42: ACTION[Server]: [volcanic_soil] advance_growth_stage: advancing better_farming:jute_3 -> better_farming:jute_4 at -780,5,468
```

Note: No error when trying to set node to non-existent `better_farming:jute_4` — it silently becomes air.

### Likely Cause
The `advance_growth_stage()` function in `volcanic_soil.lua` uses pattern matching (`(.-)(%d+)$`) to parse crop node names and increment the stage number, without checking if:
1. The crop has a registered `steps` field from `farming.registered_plants[seed_name]`
2. The calculated next stage actually exists as a registered node

When the next stage doesn't exist and the function returns `false`, the crop node remains but should be checked before trying the increment. More critically, if a stage node somehow gets set to a non-existent name, Luanti replaces it with air.

### Impact
- **HIGH:** Blocks farming of better_farming crops (jute, millet, others with < 8 stages)
- Players lose planted crops without harvest
- Affects all users trying to use volcanic_soil with farming mods

### Acceptance Criteria
1. Crops planted on volcanic_soil should not advance beyond their final registered stage
2. Volcanic_soil should query `farming.registered_plants` to determine max stage for each crop
3. Growth boost should stop advancing once the final stage is reached
4. Crops should remain at their final stage and be harvestable
5. No nodes set to non-existent names

### Notes
- Related crops affected: jute (3 stages), millet (suspected 3 stages)
- Issue does NOT occur with standard/regular furnace smelting — only with volcanic_soil growth boost
- Root cause: pattern-based stage advancement doesn't respect farming system's `steps` field
- The fix should check `farming.registered_plants[seed_name].steps` before trying to advance beyond it

### Investigation Findings

**Root Cause Identified**: The `advance_growth_stage()` function in `volcanic_soil.lua` uses regex pattern matching to auto-increment crop stage numbers (e.g., `jute_3` → `jute_4`), but it doesn't validate:
1. That the crop has a maximum stage defined in `farming.registered_plants`
2. That the next stage node is actually registered

**Evidence**:
- better_farming:jute is registered with `steps = 3` (only stages 1, 2, 3 exist)
- Volcanic soil attempts to advance 3 → 4 when growth boost runs
- Node `better_farming:jute_4` doesn't exist, so minetest.set_node defaults to air
- Crop disappears without drops

**Solution**: Before incrementing stage, check the farming mod's stage limit for that crop and stop at the final stage.

## Resolution

**Fixed in commit**: 7d327c3
**Date Fixed**: 2026-06-07

### Changes Made

1. **New function `get_max_stage_for_node(node_name)`** (volcanic_soil.lua:16-69)
   - Extracts crop base name from node (handles both `jute_3` and `cotton3` formats)
   - Primary path: Queries `farming.registered_plants[base].steps` for authoritative max stage
   - Fallback: Directly counts registered stage nodes (handles crops that don't populate farming API)
   - Returns nil if unable to determine (triggers safe failure mode)

2. **Enhanced `advance_growth_stage()` logic** (volcanic_soil.lua:71-103)
   - Now calls `get_max_stage_for_node()` to determine maximum stage
   - **Critical safeguard**: Refuses to advance if max stage cannot be determined
   - Checks `if current_stage >= max_stage` before attempting increment
   - Logs when crop reaches final stage: "crop X at final stage Y, not advancing"

3. **Test coverage** (tests/crop_stage_advancement_spec.lua)
   - 11 unit tests covering jute (3 stages), millet (3 stages), and edge cases
   - All tests passing

### Validation

✅ Unit tests: 11 successes / 0 failures / 0 errors
✅ Manual testing: Crops stop at stage 3, remain harvestable
✅ Log shows: "crop at final stage 3, not advancing" when limit reached
✅ No more "jute_3 → jute_4" advancement attempts
✅ Crops remain visible and harvestable at final stage

---
