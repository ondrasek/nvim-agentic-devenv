--- Sample Lua file for testing lua_ls and stylua formatting.

-- TODO: Add more table manipulation examples

local M = {}

--- Greet a user by name.
---@param name string
---@return string
function M.greet(name)
    return "Hello, " .. name .. "!"
end

--- Sum all numbers in a table.
---@param numbers number[]
---@return number
function M.sum(numbers)
    local total = 0
    for _, n in ipairs(numbers) do
        total = total + n
    end
    return total
end

--- Create a new key-value store.
---@return table
function M.create_store()
    local store = {}

    return {
        set = function(key, value)
            store[key] = value
        end,
        get = function(key)
            return store[key]
        end,
        keys = function()
            local result = {}
            for k, _ in pairs(store) do
                table.insert(result, k)
            end
            return result
        end,
    }
end

-- Main execution
local greeting = M.greet("World")
print(greeting)

local nums = { 1, 2, 3, 4, 5 }
print("Sum: " .. M.sum(nums))

local store = M.create_store()
store.set("language", "Lua")
store.set("version", "5.1")
print("Language: " .. store.get("language"))

return M
