local api = {}

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

local function read_int_setting(key, default_value, min_value, max_value)
    local raw_value = tonumber(minetest.settings:get(key)) or default_value
    return clamp(raw_value, min_value, max_value)
end

local function read_bool_setting(key, default_value)
    local value = minetest.settings:get_bool(key)
    if value == nil then
        return default_value
    end
    return value
end

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function read_pattern_list_setting(key, default_values)
    local raw_value = minetest.settings:get(key)
    if raw_value == nil then
        return default_values
    end

    local values = {}
    for part in raw_value:gmatch("([^,]+)") do
        local pattern = trim(part)
        if pattern ~= "" then
            table.insert(values, pattern)
        end
    end

    return values
end

local default_harvest_cycle_allow_patterns = {
    "^farming:",
    "^x_farming:",
    "^better_farming:",
    "^default:papyrus$",
    "^default:cactus$",
}

local default_harvest_cycle_deny_patterns = {
    "_fruit$",
    "_fruit_mark$",
    "_seedling$",
}

api.config = {
    fertility_cycles = read_int_setting("volcanic_soil_fertility_cycles", 5, 1, 100),
    growth_boost_interval = read_int_setting("volcanic_soil_growth_boost_interval", 1, 1, 300),
    growth_boost_steps = read_int_setting("volcanic_soil_growth_boost_steps", 1, 1, 8),
    sapling_boost_interval = read_int_setting("volcanic_soil_sapling_boost_interval", 20, 1, 300),
    bypass_light_check = read_bool_setting("volcanic_soil_bypass_light_check", true),
    harvest_cycle_allow_patterns = read_pattern_list_setting(
        "volcanic_soil_harvest_cycle_allow_patterns",
        default_harvest_cycle_allow_patterns
    ),
    harvest_cycle_deny_patterns = read_pattern_list_setting(
        "volcanic_soil_harvest_cycle_deny_patterns",
        default_harvest_cycle_deny_patterns
    ),
}

-- Prefer farming:soil_wet so the plot remains tillable; fall back to dirt.
function api.degradation_target(registered_nodes)
    if registered_nodes["farming:soil_wet"] then
        return "farming:soil_wet"
    end
    if registered_nodes["default:dirt"] then
        return "default:dirt"
    end
    return nil
end

function api.dirt_sounds(default_mod)
    if default_mod and default_mod.node_sound_dirt_defaults then
        return default_mod.node_sound_dirt_defaults()
    end
    return {}
end

return api
