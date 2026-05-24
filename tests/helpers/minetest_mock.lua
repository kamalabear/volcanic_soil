-- Minimal minetest API mock for busted tests.
_G.minetest = {
    settings = {
        _data = {},
        get = function(self, key)
            return self._data[key]
        end,
        get_bool = function(self, key)
            local value = self._data[key]
            if value == nil then
                return nil
            end
            if type(value) == "boolean" then
                return value
            end
            if type(value) == "string" then
                value = value:lower()
                return value == "true" or value == "1" or value == "yes"
            end
            return value ~= 0
        end,
        set = function(self, key, value)
            self._data[key] = value
        end,
    },

    registered_nodes = {},
}

_G.reset_mock_settings = function(data)
    minetest.settings._data = data or {}
end

_G.reset_mock_nodes = function(data)
    minetest.registered_nodes = data or {}
end
