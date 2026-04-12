-- ─────────────────────────────────────────────────────────────────────────────
-- Configuration
-- ─────────────────────────────────────────────────────────────────────────────

volcanic_soil = volcanic_soil or {}

volcanic_soil.config = {
    fertility_cycles        = tonumber(minetest.settings:get("volcanic_soil_fertility_cycles"))        or 5,
    growth_boost_interval   = tonumber(minetest.settings:get("volcanic_soil_growth_boost_interval"))   or 30,
    sapling_boost_interval  = tonumber(minetest.settings:get("volcanic_soil_sapling_boost_interval"))  or 20,
}

-- Node to convert to when fertility is exhausted.
-- Prefer farming:soil_wet so the plot remains tillable; fall back to dirt.
local function degradation_target()
    if minetest.registered_nodes["farming:soil_wet"] then
        return "farming:soil_wet"
    end
    return "default:dirt"
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Node: volcanic_soil:volcanic_soil  (natural / untilled)
-- soil=1 so a hoe can till it.  The .soil table tells the asuna farming hoe
-- what node to convert to (it checks ndef.soil.dry).
-- ─────────────────────────────────────────────────────────────────────────────

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
        crumbly=3, soil=3, spreading_dirt_type=1, wet=1,
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
    sounds = default.node_sound_dirt_defaults(),

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
    after_place_node = function(pos, placer, itemstack)
        if not itemstack then return end
        local saved = itemstack:get_meta():get_int("volcanic_soil_cycles")
        if saved and saved > 0 then
            minetest.get_meta(pos):set_int("volcanic_soil_cycles", saved)
        end
    end,

    -- Issue a tilled-form item carrying the current cycle count so the player
    -- does not lose progress when moving or reorganising soil.
    after_dig_node = function(pos, oldnode, oldmetadata, digger)
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
        -- Confirm the soil directly below this crop is tilled volcanic soil.
        local below = {x=pos.x, y=pos.y-1, z=pos.z}
        if minetest.get_node(below).name ~= "volcanic_soil:volcanic_soil_tilled" then
            return
        end

        -- Parse the crop node name: "mod:cropname_N" → base="mod:cropname_", stage=N
        local node = minetest.get_node(pos)
        local base, stage_str = node.name:match("^(.-)(%d+)$")
        if not base or not stage_str then return end

        local next_name = base .. tostring(tonumber(stage_str) + 1)
        if minetest.registered_nodes[next_name] then
            minetest.set_node(pos, {name = next_name})
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
-- Harvest cycle counter
-- Fires on every node dig.  When a *mature* crop (plant group present,
-- growing group absent) is dug above tilled volcanic soil, one fertility
-- cycle is consumed.  At zero the soil degrades to normal soil.
-- ─────────────────────────────────────────────────────────────────────────────

minetest.register_on_dignode(function(pos, oldnode)
    -- Only mature plants (plant=1, growing=0) count as a completed harvest.
    if minetest.get_item_group(oldnode.name, "plant")   == 0 then return end
    if minetest.get_item_group(oldnode.name, "growing") ~= 0 then return end

    local below = {x=pos.x, y=pos.y-1, z=pos.z}
    if minetest.get_node(below).name ~= "volcanic_soil:volcanic_soil_tilled" then
        return
    end

    local meta   = minetest.get_meta(below)
    local cycles = meta:get_int("volcanic_soil_cycles") - 1

    if cycles <= 0 then
        minetest.set_node(below, {name = degradation_target()})
    else
        meta:set_int("volcanic_soil_cycles", cycles)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Recipes (unchanged — produce the natural/untilled form)
-- ─────────────────────────────────────────────────────────────────────────────

local craft = minetest.register_craft

-- NOTE: This wrapper was present in the original file and is preserved as-is.
function minetest.register_craft(a)
    return craft(a)
end

minetest.register_craft({
    type     = "cooking",
    output   = "volcanic_soil:volcanic_soil 8",
    recipe   = "moreblocks:cobble_compressed",
    cooktime = 1,
})
