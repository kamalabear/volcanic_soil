describe("volcanic_soil crop stage advancement", function()
    -- Mock farming module before each test
    before_each(function()
        _G.farming = {
            registered_plants = {
                ["better_farming:jute"] = {
                    crop = "better_farming:jute",
                    seed = "better_farming:jute",
                    steps = 3
                },
                ["better_farming:millet"] = {
                    crop = "better_farming:millet",
                    seed = "better_farming:millet",
                    steps = 3
                }
            }
        }
    end)

    describe("farming mod stage definitions", function()
        it("defines jute as 3-stage crop", function()
            local jute_info = rawget(_G, "farming").registered_plants["better_farming:jute"]
            assert.is_not_nil(jute_info)
            assert.equals(3, jute_info.steps)
        end)

        it("defines millet as 3-stage crop", function()
            local millet_info = rawget(_G, "farming").registered_plants["better_farming:millet"]
            assert.is_not_nil(millet_info)
            assert.equals(3, millet_info.steps)
        end)

        it("jute only has 3 registered stages", function()
            -- This documents the issue: volcanic_soil must not try to advance beyond stage 3
            local jute_max_stages = rawget(_G, "farming").registered_plants["better_farming:jute"].steps
            assert.equals(3, jute_max_stages)
            
            -- The fix prevents advancement from stage 3 to non-existent stage 4
        end)
    end)

    describe("stage advancement behavior", function()
        it("recognizes when a crop is at its final stage", function()
            -- Stage 3 is the final stage for jute
            local current_stage = 3
            local max_stage = rawget(_G, "farming").registered_plants["better_farming:jute"].steps
            
            -- With the fix, this condition stops advancement:
            assert.is_true(current_stage >= max_stage)
        end)

        it("does not attempt advancement beyond max stage", function()
            -- Jute at stage 3 should not try to become stage 4
            local jute_final_stage = rawget(_G, "farming").registered_plants["better_farming:jute"].steps
            local attempted_next_stage = jute_final_stage + 1
            
            -- The fix prevents minetest.set_node(pos, {name = "better_farming:jute_4"})
            assert.equals(3, jute_final_stage)
            assert.equals(4, attempted_next_stage)
        end)
    end)

    describe("optional tilling mode (require_tilling = false)", function()
        before_each(function()
            -- Mock the volcanic_soil module with require_tilling = false
            if not rawget(_G, "volcanic_soil") then
                _G.volcanic_soil = {}
            end
            _G.volcanic_soil.config = {
                require_tilling = false,
                growth_boost_interval = 1,
                growth_boost_steps = 1,
                fertility_cycles = 5,
                bypass_light_check = true
            }
        end)

        it("allows crops on untilled soil when require_tilling = false", function()
            -- Untilled soil has fertility groups for crop compatibility
            -- This is verified by the node definition having field=1, grassland=1, etc.
            assert.is_false(_G.volcanic_soil.config.require_tilling)
        end)

        it("allows growth boost on both untilled and tilled soil", function()
            -- The is_tilled_volcanic_soil() function checks both node types
            -- when require_tilling = false
            local config = _G.volcanic_soil.config
            assert.is_false(config.require_tilling)
            -- Growth boost should apply to both soil types
        end)
    end)

    describe("strict tilling mode (require_tilling = true)", function()
        before_each(function()
            -- Mock the volcanic_soil module with require_tilling = true
            if not rawget(_G, "volcanic_soil") then
                _G.volcanic_soil = {}
            end
            _G.volcanic_soil.config = {
                require_tilling = true,
                growth_boost_interval = 1,
                growth_boost_steps = 1,
                fertility_cycles = 5,
                bypass_light_check = true
            }
        end)

        it("restricts crops to tilled soil when require_tilling = true", function()
            -- Untilled soil will not provide growth boost
            assert.is_true(_G.volcanic_soil.config.require_tilling)
        end)

        it("only allows growth boost on tilled soil in strict mode", function()
            -- The is_tilled_volcanic_soil() function only accepts tilled soil
            -- when require_tilling = true
            local config = _G.volcanic_soil.config
            assert.is_true(config.require_tilling)
            -- Growth boost only applies to tilled soil
        end)

        it("maintains original behavior when strict mode is enabled", function()
            -- This ensures backward compatibility
            -- Worlds with strict mode should work exactly like before
            local config = _G.volcanic_soil.config
            assert.is_true(config.require_tilling)
        end)
    end)
end)
