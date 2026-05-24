describe("volcanic_soil api", function()
    local reset_settings = _G.reset_mock_settings
    local reset_nodes = _G.reset_mock_nodes

    local function load_api()
        package.loaded.api = nil
        return dofile("api.lua")
    end

    before_each(function()
        reset_settings({})
        reset_nodes({})
    end)

    describe("degradation_target", function()
        it("returns farming:soil_wet when available", function()
            local api = load_api()
            reset_nodes({
                ["farming:soil_wet"] = {},
                ["default:dirt"] = {},
            })

            assert.equals("farming:soil_wet", api.degradation_target(minetest.registered_nodes))
        end)

        it("falls back to default:dirt", function()
            local api = load_api()
            reset_nodes({
                ["default:dirt"] = {},
            })

            assert.equals("default:dirt", api.degradation_target(minetest.registered_nodes))
        end)

        it("returns nil when no fallback nodes exist", function()
            local api = load_api()

            assert.is_nil(api.degradation_target(minetest.registered_nodes))
        end)
    end)

    describe("config", function()
        it("uses defaults when settings are unset", function()
            local api = load_api()

            assert.equals(5, api.config.fertility_cycles)
            assert.equals(1, api.config.growth_boost_interval)
            assert.equals(1, api.config.growth_boost_steps)
            assert.equals(20, api.config.sapling_boost_interval)
            assert.equals(true, api.config.bypass_light_check)
            assert.same({
                "^farming:",
                "^x_farming:",
                "^better_farming:",
                "^default:papyrus$",
                "^default:cactus$",
            }, api.config.harvest_cycle_allow_patterns)
            assert.same({
                "_fruit$",
                "_fruit_mark$",
                "_seedling$",
            }, api.config.harvest_cycle_deny_patterns)
        end)

        it("reads configured values", function()
            reset_settings({
                volcanic_soil_fertility_cycles = "9",
                volcanic_soil_growth_boost_interval = "45",
                volcanic_soil_growth_boost_steps = "4",
                volcanic_soil_sapling_boost_interval = "50",
                volcanic_soil_bypass_light_check = true,
                volcanic_soil_harvest_cycle_allow_patterns =
                    "^farming:, ^x_farming:, ^default:cactus$",
                volcanic_soil_harvest_cycle_deny_patterns = "_fruit$, _seedling$",
            })

            local api = load_api()
            assert.equals(9, api.config.fertility_cycles)
            assert.equals(45, api.config.growth_boost_interval)
            assert.equals(4, api.config.growth_boost_steps)
            assert.equals(50, api.config.sapling_boost_interval)
            assert.equals(true, api.config.bypass_light_check)
            assert.same({
                "^farming:",
                "^x_farming:",
                "^default:cactus$",
            }, api.config.harvest_cycle_allow_patterns)
            assert.same({
                "_fruit$",
                "_seedling$",
            }, api.config.harvest_cycle_deny_patterns)
        end)

        it("clamps values to configured bounds", function()
            reset_settings({
                volcanic_soil_fertility_cycles = "0",
                volcanic_soil_growth_boost_interval = "0",
                volcanic_soil_growth_boost_steps = "99",
                volcanic_soil_sapling_boost_interval = "0",
            })

            local api = load_api()
            assert.equals(1, api.config.fertility_cycles)
            assert.equals(1, api.config.growth_boost_interval)
            assert.equals(8, api.config.growth_boost_steps)
            assert.equals(1, api.config.sapling_boost_interval)
        end)
    end)
end)
