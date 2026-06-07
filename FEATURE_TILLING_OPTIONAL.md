# Feature Implementation Plan: Optional Tilling Requirement

**Objective**: Change default behavior to allow crop growth on non-tilled volcanic soil, with optional configuration to require tilling.

**Status**: Planning
**Priority**: Medium
**Complexity**: Medium

---

## 1. Current Behavior Analysis

### Current Implementation
- Growth boost only works on **tilled** volcanic soil (`volcanic_soil:volcanic_soil_tilled`)
- Untilled volcanic soil (`volcanic_soil:volcanic_soil`) has `soil=1` but no growth boost or fertility groups
- Function `is_tilled_volcanic_soil(pos)` checks if below node is tilled
- Tilled soil has fertility groups: `field=1, grassland=1, desert=1, underground=1, ice_fishing=1`
- Tilled soil tracks fertility cycles (default 5 harvests per tilled block)

### Current Limitations
- Players must hoe/till volcanic soil before planting
- Untilled soil provides no benefits
- Two soil nodes manage single farming system

---

## 2. Desired Behavior

### New Default Behavior (Config Off - tilling optional)
✅ Crops can be planted directly on untilled `volcanic_soil:volcanic_soil`
✅ Growth boost ABM works on both tilled AND untilled volcanic soil
✅ Untilled soil gets fertility groups for crop compatibility
✅ Untilled soil has growth boost (same as tilled)
❌ No fertility cycle tracking on untilled soil (optional: crops always grow)
❌ Tilling converts untilled → tilled (but optional)

### Optional Strict Mode (Config On - tilling required)
✅ Crops **cannot** be planted on untilled volcanic soil
✅ Only tilled soil provides growth boost
✅ Requires player to explicitly till before farming
✅ Maintains current behavior if user prefers it

---

## 3. Configuration Design

### New Setting
```
volcanic_soil_require_tilling (Require tilling before crop growth) bool false
```

**Behavior**:
- `false` (default): Crops can grow on untilled soil; tilling is optional for convenience
- `true` (strict mode): Crops only grow on tilled soil; matches current behavior

---

## 4. Implementation Plan

### Phase 1: Update Node Definitions

**File**: `volcanic_soil.lua` (lines 152-186)

**Changes to untilled node**:
```lua
-- Add fertility groups to untilled soil
groups = {
    crumbly=3, soil=1, sand=1, spreading_dirt_type=1,
    -- Add these to allow crops:
    field=1, grassland=1, desert=1, underground=1, ice_fishing=1,
}
```

**No changes to tilled node** — already has all groups.

**Impact**: Crops can be planted on untilled soil (vanilla farming compatibility).

### Phase 2: Update Growth Boost Logic

**File**: `volcanic_soil.lua` (lines 240-280, ABM registration)

**Current ABM**:
- Registers on `volcanic_soil:volcanic_soil_tilled` only
- Calls `advance_growth_steps()`

**Changes needed**:
1. If `require_tilling = false`: ABM registers on BOTH untilled and tilled nodes
2. If `require_tilling = true`: ABM registers on tilled only (current behavior)

**Implementation approach**:
```lua
local node_list = {"volcanic_soil:volcanic_soil_tilled"}
if not volcanic_soil.config.require_tilling then
    table.insert(node_list, "volcanic_soil:volcanic_soil")
end

minetest.register_abm({
    label = "Crop boost on volcanic soil",
    nodenames = node_list,
    ...
})
```

**Impact**: Growth boost works on both soil types when tilling is optional.

### Phase 3: Update Fertility Cycle Logic

**File**: `volcanic_soil.lua` (lines 350-380, harvest handling)

**Current behavior**:
- Only tilled soil consumes fertility cycles on harvest
- Untilled soil doesn't track cycles

**Changes needed** (if enabling cycles on untilled):
- Make untilled soil also track cycles (optional B path)
- OR: Leave untilled soil with unlimited crops (simpler, recommended)

**Recommendation**: Keep untilled soil as "infinite" (no cycle tracking).
- Advantage: Untilled acts as "lite" mode, tilled as "limited resource" mode
- Trade-off: More natural farming vs. resource management

**No code changes needed** if untilled soil gets no cycle system.

### Phase 4: Configuration Loading

**File**: `api.lua` (lines 5-30, config initialization)

**Add new setting**:
```lua
require_tilling = minetest.settings:get_bool("volcanic_soil_require_tilling", false)
```

### Phase 5: Fallback Compatibility Check

**File**: `volcanic_soil.lua` (add near growth boost ABM)

**Add safety check**:
```lua
local function should_apply_growth_boost(node_name)
    if node_name == "volcanic_soil:volcanic_soil_tilled" then
        return true
    end
    if node_name == "volcanic_soil:volcanic_soil" then
        return not volcanic_soil.config.require_tilling
    end
    return false
end
```

**Impact**: Guards against unexpected nodes while ABM registers.

---

## 5. Updated settingtypes.txt

**Add**:
```
volcanic_soil_require_tilling (Require tilling before crop growth) bool false
```

**Rationale**: Clear toggle, defaults to convenience mode.

---

## 6. Documentation Updates

### Update README.md
**Current section**: "Tilling Requirement"
**New content**:
```
Crops can be planted directly on volcanic soil without tilling (default behavior).
Tilling is optional and provides no additional benefit unless strict mode is enabled.

To require tilling before crops grow, enable the setting:
  volcanic_soil_require_tilling = true
```

### Update USAGE.md
**Add section**: "Default vs. Strict Mode"
```
Default Mode (tilling optional):
- Plant seeds directly on volcanic soil
- Crops grow with the boost
- No fertility management needed

Strict Mode (tilling required, enable in settings):
- Till soil first with hoe
- Tilled soil provides growth boost
- Fertility cycles limit harvests
- Better for server performance/resource management
```

### Update DEVELOPMENT.md
**Add section**: "Configuration Options"
- Document `require_tilling` behavior
- Explain interaction with ABM registration

---

## 7. Testing Plan

### Unit Tests (tests/crop_stage_advancement_spec.lua)

**Add test suite**: `untilled_soil_growth`
```
✓ Crops can be planted on untilled soil (default)
✓ Crops advance growth stages on untilled soil
✓ Growth boost works on untilled soil
✓ require_tilling=true prevents growth on untilled soil
✓ Tilled soil always allows growth (regardless of setting)
✓ Fertility cycles still work on tilled soil
```

**Estimated new tests**: 6-8 tests

### Manual/Smoke Tests

**Test 1**: Default behavior
```
1. Plant seed on untilled volcanic soil (no hoe first)
2. Wait 3-4 seconds
3. Confirm: Crop advances to stage 2+
```

**Test 2**: Strict mode
```
1. Set require_tilling = true
2. Plant seed on untilled soil
3. Confirm: Seed doesn't plant OR crop doesn't grow
4. Till soil with hoe
5. Plant same seed
6. Confirm: Crop grows normally
```

**Test 3**: Fertility cycles still work
```
1. Plant/harvest on tilled soil 5+ times
2. Confirm: Soil degrades to normal after cycle limit
```

---

## 8. Code Changes Summary

| File | Lines | Change | Impact |
|------|-------|--------|--------|
| `volcanic_soil.lua` | 152-186 | Add fertility groups to untilled node | Crops plantable on untilled soil |
| `volcanic_soil.lua` | 240-280 | Conditional ABM registration | Growth boost on both soil types (if enabled) |
| `api.lua` | 5-30 | Add `require_tilling` config | Read user setting |
| `settingtypes.txt` | end | Add new setting | User-configurable toggle |
| `README.md` | — | Update usage docs | Explain new default behavior |
| `USAGE.md` | — | Add mode comparison section | Document both modes |
| `DEVELOPMENT.md` | — | Document config option | Technical reference |
| `tests/crop_stage_advancement_spec.lua` | — | Add 6-8 new tests | Validate both modes |

---

## 9. Rollout Strategy

### Phase 1: Code Implementation (1 session)
- ✏️ Update node definitions
- ✏️ Update ABM registration logic
- ✏️ Add config loading
- ✏️ Write unit tests

### Phase 2: Testing & Documentation (1 session)
- 🧪 Run all unit tests (target: 17-19 passing)
- 🧪 Manual smoke tests (both modes)
- 📝 Update README, USAGE, DEVELOPMENT
- 📝 Update BUG_REPORT if applicable

### Phase 3: Deployment (1 session)
- ✅ Lint & final validation
- ✅ Commit with clear message
- ✅ Push to GitHub
- ✅ Deploy to servers

---

## 10. Backward Compatibility

### Impact on Existing Setups

**Old worlds** (before this change):
- Tilled soil continues to work exactly as before
- Untilled soil remains untilled (no change)
- Setting defaults to `false` (optional tilling) — non-breaking

**New worlds**:
- Can use either mode
- Default mode (optional) is more beginner-friendly
- Strict mode available for experienced players

**Migration**:
- No data migration needed
- No breaking changes

---

## 11. Success Criteria

- ✅ Crops grow on untilled soil by default
- ✅ `require_tilling = true` mode works (crops only on tilled)
- ✅ All existing tests pass
- ✅ 6+ new tests added and passing
- ✅ Documentation updated
- ✅ No regression in fertility cycle tracking
- ✅ Growth boost works on both soil types (default) or tilled only (strict)

---

## 12. Open Questions / Decisions

1. **Fertility cycles on untilled soil?**
   - Decision: NO (untilled = infinite crops, tilled = limited resource)
   - Alternative: Could add separate fertility tracking for untilled

2. **Should there be an ABM fallback check?**
   - Decision: YES (for safety/future-proofing)
   - Adds minimal overhead

3. **Should tilling provide ANY benefit?**
   - Decision: Keep as-is (tilling still possible, just optional)
   - Alternative: Could make tilled soil grow faster than untilled

---

## Estimated Effort

| Task | Effort |
|------|--------|
| Code changes | 1-2 hours |
| Unit tests | 1 hour |
| Manual testing | 30 min |
| Documentation | 30 min |
| **Total** | **3-4 hours** |

