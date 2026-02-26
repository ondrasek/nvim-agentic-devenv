local curl = require("plenary.curl")

local M = {}

---@class DevenvAgentProvider
---@field name string
---@field send fun(messages: table[], system: string, on_chunk: fun(text: string), on_done: fun())

---@type table<string, DevenvAgentProvider>
M.providers = {}

-- Ollama provider (local, default)
M.providers.ollama = {
    name = "ollama",
    send = function(messages, system, on_chunk, on_done)
        local body = vim.json.encode({
            model = "qwen3-coder",
            messages = vim.list_extend(
                { { role = "system", content = system } },
                messages
            ),
            stream = true,
        })

        curl.post("http://localhost:11434/api/chat", {
            body = body,
            headers = { ["Content-Type"] = "application/json" },
            stream = function(_, chunk)
                if not chunk or chunk == "" then
                    return
                end
                local ok, data = pcall(vim.json.decode, chunk)
                if ok and data.message and data.message.content then
                    vim.schedule(function()
                        on_chunk(data.message.content)
                    end)
                end
                if ok and data.done then
                    vim.schedule(on_done)
                end
            end,
        })
    end,
}

-- Anthropic provider (optional, via ANTHROPIC_API_KEY)
M.providers.anthropic = {
    name = "anthropic",
    send = function(messages, system, on_chunk, on_done)
        local api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key then
            vim.schedule(function()
                on_chunk("Error: ANTHROPIC_API_KEY not set")
                on_done()
            end)
            return
        end

        local body = vim.json.encode({
            model = "claude-sonnet-4-20250514",
            max_tokens = 4096,
            system = system,
            messages = messages,
            stream = true,
        })

        local buffer = ""

        curl.post("https://api.anthropic.com/v1/messages", {
            body = body,
            headers = {
                ["Content-Type"] = "application/json",
                ["x-api-key"] = api_key,
                ["anthropic-version"] = "2023-06-01",
            },
            stream = function(_, chunk)
                if not chunk or chunk == "" then
                    return
                end
                buffer = buffer .. chunk
                -- SSE format: lines starting with "data: "
                while true do
                    local newline = buffer:find("\n")
                    if not newline then
                        break
                    end
                    local line = buffer:sub(1, newline - 1)
                    buffer = buffer:sub(newline + 1)

                    if line:match("^data: ") then
                        local json_str = line:sub(7)
                        if json_str == "[DONE]" then
                            vim.schedule(on_done)
                            return
                        end
                        local ok, data = pcall(vim.json.decode, json_str)
                        if ok then
                            if data.type == "content_block_delta" and data.delta and data.delta.text then
                                vim.schedule(function()
                                    on_chunk(data.delta.text)
                                end)
                            elseif data.type == "message_stop" then
                                vim.schedule(on_done)
                                return
                            end
                        end
                    end
                end
            end,
        })
    end,
}

--- Get the current provider
---@param name? string Provider name ("ollama" or "anthropic")
---@return DevenvAgentProvider
function M.get(name)
    name = name or "ollama"
    return M.providers[name] or M.providers.ollama
end

return M
