local curl = require("plenary.curl")

local M = {}

---@class DevenvAgentProvider
---@field name string
---@field send fun(messages: table[], system: string, on_chunk: fun(text: string), on_done: fun(), on_error: fun(err: string)): table|nil

---@type table<string, DevenvAgentProvider>
M.providers = {}

--- Per-provider settings; override via `require("devenv-agent").setup({ providers = { ... } })`
M.settings = {
    ollama = { model = "qwen3-coder", url = "http://localhost:11434/api/chat" },
    anthropic = { model = "claude-sonnet-5-5", max_tokens = 4096 },
}

-- Ollama provider (local, default)
M.providers.ollama = {
    name = "ollama",
    send = function(messages, system, on_chunk, on_done, on_error)
        local body = vim.json.encode({
            model = M.settings.ollama.model,
            messages = vim.list_extend({ { role = "system", content = system } }, messages),
            stream = true,
        })

        local job = curl.post(M.settings.ollama.url, {
            body = body,
            headers = { ["Content-Type"] = "application/json" },
            stream = function(_, chunk)
                if not chunk or chunk == "" then
                    return
                end
                local ok, data = pcall(vim.json.decode, chunk)
                if ok and data.error then
                    vim.schedule(function()
                        on_error("Ollama error: " .. data.error)
                        on_done()
                    end)
                    return
                end
                if ok and data.message and data.message.content then
                    vim.schedule(function()
                        on_chunk(data.message.content)
                    end)
                end
                if ok and data.done then
                    vim.schedule(on_done)
                end
            end,
            on_error = function(err)
                vim.schedule(function()
                    local msg = type(err) == "table" and (err.message or vim.inspect(err)) or tostring(err)
                    if msg:match("Connection refused") or msg:match("curl exit code 7") then
                        on_error("Connection refused — is Ollama running?")
                    else
                        on_error("Ollama request failed: " .. msg)
                    end
                    on_done()
                end)
            end,
        })
        return job
    end,
}

--- Try to decode a non-SSE JSON error body from Anthropic (4xx/5xx responses)
---@param raw string raw response buffer
---@return string|nil error message, or nil if not an error
local function detect_anthropic_json_error(raw)
    local ok, data = pcall(vim.json.decode, raw)
    if ok and data.type == "error" then
        return data.error and data.error.message or "Unknown API error"
    end
    return nil
end

--- Process a single SSE data line from Anthropic's streaming API
---@param json_str string the JSON payload after "data: "
---@param on_chunk fun(text: string)
---@param on_error fun(err: string)
---@param on_done fun()
---@return boolean should_stop whether the caller should stop processing
local function process_anthropic_sse(json_str, on_chunk, on_error, on_done)
    if json_str == "[DONE]" then
        vim.schedule(on_done)
        return true
    end
    local ok, data = pcall(vim.json.decode, json_str)
    if not ok then
        return false
    end
    if data.type == "error" then
        local msg = data.error and data.error.message or "Unknown API error"
        vim.schedule(function()
            on_error("Anthropic API error: " .. msg)
            on_done()
        end)
        return true
    elseif data.type == "content_block_delta" and data.delta and data.delta.text then
        vim.schedule(function()
            on_chunk(data.delta.text)
        end)
    elseif data.type == "message_stop" then
        vim.schedule(on_done)
        return true
    end
    return false
end

--- Handle one line of the Anthropic response stream (SSE `data:` line or a plain JSON error body)
---@param line string|nil
---@param on_chunk fun(text: string)
---@param on_error fun(err: string)
---@param on_done fun()
---@return boolean should_stop whether the stream is finished
function M.handle_anthropic_line(line, on_chunk, on_error, on_done)
    if not line or line == "" then
        return false
    end
    if line:match("^data: ") then
        return process_anthropic_sse(line:sub(7), on_chunk, on_error, on_done)
    end
    -- Non-SSE JSON error body (4xx/5xx)
    if line:sub(1, 1) == "{" then
        local err_msg = detect_anthropic_json_error(line)
        if err_msg then
            vim.schedule(function()
                on_error("Anthropic API error: " .. err_msg)
                on_done()
            end)
            return true
        end
    end
    return false
end

-- Anthropic provider (optional, via ANTHROPIC_API_KEY)
M.providers.anthropic = {
    name = "anthropic",
    send = function(messages, system, on_chunk, on_done, on_error)
        local api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key then
            vim.schedule(function()
                on_error("ANTHROPIC_API_KEY not set")
                on_done()
            end)
            return nil
        end

        local body = vim.json.encode({
            model = M.settings.anthropic.model,
            max_tokens = M.settings.anthropic.max_tokens,
            system = system,
            messages = messages,
            stream = true,
        })

        local stopped = false

        local job = curl.post("https://api.anthropic.com/v1/messages", {
            body = body,
            headers = {
                ["Content-Type"] = "application/json",
                ["x-api-key"] = api_key,
                ["anthropic-version"] = "2023-06-01",
            },
            -- plenary delivers stdout one complete line per callback (newline stripped)
            stream = function(_, line)
                if stopped then
                    return
                end
                if M.handle_anthropic_line(line, on_chunk, on_error, on_done) then
                    stopped = true
                end
            end,
            -- Backstop: the stream may end without message_stop; on_done is idempotent in the caller
            callback = function()
                if not stopped then
                    stopped = true
                    vim.schedule(on_done)
                end
            end,
            on_error = function(err)
                vim.schedule(function()
                    local msg = type(err) == "table" and (err.message or vim.inspect(err)) or tostring(err)
                    on_error("Anthropic request failed: " .. msg)
                    on_done()
                end)
            end,
        })
        return job
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
