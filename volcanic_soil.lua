-- ─────────────────────────────────────────────────────────────────────────────
-- Configuration
-- ─────────────────────────────────────────────────────────────────────────────

local modpath = minetest.get_modpath("volcanic_soil")
local volcanic_soil = dofile(modpath .. "/api.lua")
local default = rawget(_G, "default")
local ethereal = rawget(_G, "ethereal")
local x_farming = rawget(_G, "x_farming")

local function is_tilled_volcanic_soil(pos)
    local below = {x = pos.x, y = pos.y - 1, z = pos.z}
    return minetest.get_node(below).name == "volcanic_soil:volcanic_soil_tilled"
end

local function advance_growth_stage(pos, node, ndef)
    if ndef and ndef.next_plant and minetest.registered_nodes[ndef.next_plant] then
        minetest.swap_node(pos, {name = ndef.next_plant})
        return true
    end

    local base, stage_str = node.name:match("^(.-)(%d+)$")
    if not base or not stage_str then
        return false
    end

    local next_name = base .. tostring(tonumber(stage_str) + 1)
    if minetest.registered_nodes[next_name] then
        minetest.set_node(pos, {name = next_name})
        return true
    end

    return false
end

local function advance_growth_steps(pos, steps)
    local advances = 0

    for _ = 1, steps do
        local node = minetest.get_node(pos)
        local ndef = minetest.registered_nodes[node.name]
        if not ndef then
            break
        end

        if not advance_growth_stage(pos, node, ndef) then
            break
        end

        advances = advances + 1
    end

    return advances
end

-- Pattern-based harvest filter for fertility cycle consumption.
-- Lua patterns keep this extensible without hard-coding every crop node.
local function harvest_counts_for_cycles(node_name)
    for _, pattern in ipairs(volcanic_soil.config.harvest_cycle_deny_patterns) do
        if node_name:match(pattern) then
            return false
        end
    end

    for _, pattern in ipairs(volcanic_soil.config.harvest_cycle_allow_patterns) do
        if node_name:match(pattern) then
            return true
        end
    end

    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Node: volcanic_soil:volcanic_soil  (natural / untilled)
-- soil=1 so a hoe can till it.  The .soil table tells the asuna farming hoe
-- what node to convert to (it checks ndef.soil.dry).
-- ─────────────────────────────────────────────────────────────────────────────

minetest.register_node("volcanic_soil:volcanic_soil", {
    description = "Volcanic Soil",
    is_ground_content = true,
    groups = {crumbly=3, soil=1, sand=1, spreading_dirt_type=1},
    stack_max = 99,
    soil = {
        base = "volcanic_soil:volcanic_soil",
        dry  = "volcanic_soil:volcanic_soil_tilled",
        wet  = "volcanic_soil:volcanic_soil_tilled",
    },
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
    sounds = volcanic_soil.dirt_sounds(default),
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Node: volcanic_soil:volcanic_soil_tilled  (fertilized / tilled)
-- soil=3 acts as wet tilled soil.  Extra fertility groups cover all known
-- x_farming crop fertility requirements so any crop can grow here.
-- The self-referential .soil table prevents the asuna farming wet/dry ABM
-- from converting this node into farming:soil variants.
-- ─────────────────────────────────────────────────────────────────────────────

minetest.register_node("volcanic_soil:volcanic_soil_tilled", {
    description = "Volcanic Soil (Tilled)",
    is_ground_content = true,
    groups = {
        crumbly=3, soil=3, sand=1, spreading_dirt_type=1, wet=1,
        -- x_farming fertility groups (covers grassland, desert, underground, ice_fishing crops)
        field=1, grassland=1, desert=1, underground=1, ice_fishing=1,
    },
    soil = {
        base = "volcanic_soil:volcanic_soil",
        dry  = "volcanic_soil:volcanic_soil_tilled",
        wet  = "volcanic_soil:volcanic_soil_tilled",
    },
    -- Suppress default drop so after_dig_node can issue a tilled item that
    -- carries the remaining cycle count in its metadata.
    drop = "",
    -- Top face shows furrows; bottom and sides keep the natural texture.
    tiles = {
        {
            name = "lava_soil_tilled.png",
            backface_culling = false,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 6.0,
            },
        },
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
    sounds = volcanic_soil.dirt_sounds(default),

    -- Initialise the cycle counter when a node is placed.
    -- When tilled via hoe the hoe calls core.set_node (no item consumed), so
    -- on_construct always fires with no placed-item context — correct to start
    -- at the configured maximum.
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("volcanic_soil_cycles", volcanic_soil.config.fertility_cycles)
    end,

    -- If the item being placed carries a saved cycle count (from a previous
    -- dig), restore it, overriding the on_construct default.
    after_place_node = function(pos, _placer, itemstack)
        if not itemstack then return end
        local saved = itemstack:get_meta():get_int("volcanic_soil_cycles")
        if saved and saved > 0 then
            minetest.get_meta(pos):set_int("volcanic_soil_cycles", saved)
        end
    end,

    -- Issue a tilled-form item carrying the current cycle count so the player
    -- does not lose progress when moving or reorganising soil.
    after_dig_node = function(pos, _oldnode, oldmetadata, digger)
        local fields = oldmetadata.fields or {}
        local cycles = tonumber(fields["volcanic_soil_cycles"]) or 0
        -- Guard: always give at least 1 cycle so the item is usable.
        if cycles < 1 then cycles = 1 end

        local stack = ItemStack("volcanic_soil:volcanic_soil_tilled")
        local item_meta = stack:get_meta()
        item_meta:set_int("volcanic_soil_cycles", cycles)
        item_meta:set_string("description",
            "Volcanic Soil (Tilled, " .. cycles ..
            " cycle" .. (cycles == 1 and "" or "s") .. " remaining)")

        if digger and digger:is_player() then
            local inv = digger:get_inventory()
            if inv:room_for_item("main", stack) then
                inv:add_item("main", stack)
                return
            end
        end
        minetest.add_item(pos, stack)
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- ABM: growth boost
-- Gives crops rooted on tilled volcanic soil an extra growth stage tick,
-- making them grow faster than on ordinary soil.
-- ─────────────────────────────────────────────────────────────────────────────

minetest.register_abm({
    label    = "Volcanic soil growth boost",
    nodenames = {"group:growing"},
    neighbors = {"volcanic_soil:volcanic_soil_tilled"},
    interval = volcanic_soil.config.growth_boost_interval,
    chance   = 1,
    action   = function(pos)
        if not is_tilled_volcanic_soil(pos) then
            return
        end

        advance_growth_steps(pos, volcanic_soil.config.growth_boost_steps)
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- ABM: timer-based crop boost
-- Supports seed/plant based farming mods (including vanilla farming cotton)
-- by forcing immediate timer ticks, or direct stage advances when configured
-- to bypass sunlight checks.
-- ─────────────────────────────────────────────────────────────────────────────

minetest.register_abm({
    label = "Volcanic soil timer crop boost",
    nodenames = {"group:seed", "group:plant"},
    neighbors = {"volcanic_soil:volcanic_soil_tilled"},
    interval = volcanic_soil.config.growth_boost_interval,
    chance = 1,
    action = function(pos)
        if not is_tilled_volcanic_soil(pos) then
            return
        end

        local node = minetest.get_node(pos)
        local ndef = minetest.registered_nodes[node.name]
        if not ndef then
            return
        end

        if volcanic_soil.config.bypass_light_check then
            advance_growth_steps(pos, volcanic_soil.config.growth_boost_steps)
            return
        end

        if ndef.on_timer then
            minetest.get_node_timer(pos):start(0)
        end
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- ABM: sapling growth boost
-- Accelerates saplings planted directly on tilled volcanic soil.
-- For timer-based saplings (default, moretrees) the node timer is restarted
-- with a zero timeout so it fires on the next server step.
-- For ABM-based saplings (ethereal) the mod's own grow function is called
-- directly; ethereal's substrate checks still apply, so its biome-specific
-- saplings will only grow if volcanic soil qualifies (it has soil=3).
-- ─────────────────────────────────────────────────────────────────────────────

minetest.register_abm({
    label     = "Volcanic soil sapling boost",
    nodenames = {"group:sapling"},
    neighbors = {
        "volcanic_soil:volcanic_soil",
        "volcanic_soil:volcanic_soil_tilled",
    },
    interval  = volcanic_soil.config.sapling_boost_interval,
    chance    = 2,
    catch_up  = false,
    action    = function(pos)
        -- Only act when the sapling is directly on volcanic soil.
        local below = {x=pos.x, y=pos.y-1, z=pos.z}
        local below_name = minetest.get_node(below).name
        if below_name ~= "volcanic_soil:volcanic_soil"
        and below_name ~= "volcanic_soil:volcanic_soil_tilled" then
            return
        end

        local node = minetest.get_node(pos)
        local ndef = minetest.registered_nodes[node.name]
        if not ndef then return end

        if ndef.on_timer then
            -- Timer-based sapling: restart with 0 timeout to fire immediately.
            minetest.get_node_timer(pos):start(0)
        elseif ethereal and ethereal.grow_sapling then
            -- Ethereal ABM-based saplings: delegate to ethereal's own grow fn.
            ethereal.grow_sapling(pos, node)
        end
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Compatibility: x_farming large cactus seedling
-- The seedling has no seed/sapling/growing groups so it is not caught by any
-- of the generic boost ABMs above. Its on_construct timer fires after 31-62
-- minutes by design. Restart it with 0 to fire on the next server step so it
-- benefits from the same fast growth as other crops on volcanic soil.
-- ─────────────────────────────────────────────────────────────────────────────

minetest.register_abm({
    label = "Volcanic soil x_farming cactus seedling boost",
    nodenames = {
        "x_farming:large_cactus_with_fruit_seedling",
        "default:large_cactus_seedling",
    },
    neighbors = {"volcanic_soil:volcanic_soil_tilled"},
    interval = volcanic_soil.config.sapling_boost_interval,
    chance = 2,
    catch_up = false,
    action = function(pos)
        if not is_tilled_volcanic_soil(pos) then
            return
        end

        local node = minetest.get_node(pos)

        if volcanic_soil.config.bypass_light_check then
            if node.name == "x_farming:large_cactus_with_fruit_seedling"
            and x_farming and x_farming.grow_large_cactus then
                x_farming.grow_large_cactus(pos)
                return
            end

            if node.name == "default:large_cactus_seedling"
            and default and default.grow_large_cactus then
                default.grow_large_cactus(pos)
                return
            end
        end

        local ndef = minetest.registered_nodes[node.name]
        if not ndef or not ndef.on_timer then
            return
        end

        minetest.get_node_timer(pos):start(0)
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Harvest cycle counter
-- Fires on every node dig.  When a *mature* crop (plant group present,
-- growing group absent) is dug above tilled volcanic soil, one fertility
-- cycle is consumed.  At zero the soil degrades to normal soil.
-- ─────────────────────────────────────────────────────────────────────────────

minetest.register_on_dignode(function(pos, oldnode, digger)
    -- Only player harvests should consume fertility cycles.
    if not digger or not digger:is_player() then return end

    -- Only mature plants (plant=1, growing=0) count as a completed harvest.
    if minetest.get_item_group(oldnode.name, "plant")   == 0 then return end
    if minetest.get_item_group(oldnode.name, "growing") ~= 0 then return end

    if not harvest_counts_for_cycles(oldnode.name) then return end

    local below = {x=pos.x, y=pos.y-1, z=pos.z}
    if minetest.get_node(below).name ~= "volcanic_soil:volcanic_soil_tilled" then
        return
    end

    local meta   = minetest.get_meta(below)
    local cycles = meta:get_int("volcanic_soil_cycles") - 1

    if cycles <= 0 then
        local target = volcanic_soil.degradation_target(minetest.registered_nodes)
        if target then
            minetest.set_node(below, {name = target})
        else
            meta:set_int("volcanic_soil_cycles", 0)
        end
    else
        meta:set_int("volcanic_soil_cycles", cycles)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Recipes (unchanged — produce the natural/untilled form)
-- ─────────────────────────────────────────────────────────────────────────────

if minetest.get_modpath("moreblocks") then
    minetest.register_craft({
        type     = "cooking",
        output   = "volcanic_soil:volcanic_soil 8",
        recipe   = "moreblocks:cobble_compressed",
        cooktime = 1,
    })
end

