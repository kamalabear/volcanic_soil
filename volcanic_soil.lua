local craft = minetest.register_craft
local dusts = {
    "volcanic_soil:diamond_dust",
    "volcanic_soil:gold_dust",
    "volcanic_soil:copper_dust",
    "volcanic_soil:iron_dust",
    "volcanic_soil:coal_dust",
    "volcanic_soil:silver_dust"
}

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

-- Register cooking recipe for compressed cobble
function minetest.register_craft(a)
    -- -- 20% chance to get a random dust
	-- if math.random(1, 5) == 1 then
    --     replacements = {{
    --             "moreblocks:cobble_compressed",
    --             dusts[math.random(#dusts)] .. " 1"
    --         },
    --         {"moreblocks:cobble_compressed", "volcanic_soil:volcanic_ash 1"},
    --         {"moreblocks:cobble_compressed", "volcanic_soil:volcanic_ash 1"},
    --         {"moreblocks:cobble_compressed", "volcanic_soil:volcanic_ash 1"},
    --         {"moreblocks:cobble_compressed", "volcanic_soil:volcanic_ash 1"},
    --         {"moreblocks:cobble_compressed", "volcanic_soil:volcanic_ash 1"},
    --         {"moreblocks:cobble_compressed", "volcanic_soil:volcanic_ash 1"},
    --         {"moreblocks:cobble_compressed", "volcanic_soil:volcanic_ash 1"},
    --         {"moreblocks:cobble_compressed", "volcanic_soil:volcanic_ash 1"}}
    -- else
    --     replacements = {}
	-- end
    
    return craft(a)
end

minetest.register_craft({
        type = "cooking",
        output = "volcanic_soil:volcanic_soil 8",
        recipe = "moreblocks:cobble_compressed",
        cooktime = 1})
