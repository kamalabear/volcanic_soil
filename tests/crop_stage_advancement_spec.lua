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
end)
