local providers = require("devenv-agent.providers")

--- Feed lines to the Anthropic handler the way plenary does (one complete line per call)
local function run(lines)
    local out = { chunks = {}, errors = {}, done = 0, stopped = false }
    for _, line in ipairs(lines) do
        local stop = providers.handle_anthropic_line(line, function(c)
            table.insert(out.chunks, c)
        end, function(e)
            table.insert(out.errors, e)
        end, function()
            out.done = out.done + 1
        end)
        if stop then
            out.stopped = true
            break
        end
    end
    -- handlers dispatch through vim.schedule
    vim.wait(200, function()
        return out.done > 0 or (#out.chunks > 0 and not out.stopped)
    end)
    vim.wait(20)
    return out
end

describe("devenv-agent.providers anthropic stream", function()
    it("streams text deltas delivered one line per callback and finishes on message_stop", function()
        local out = run({
            "event: message_start",
            'data: {"type":"message_start","message":{"id":"x"}}',
            "",
            'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}',
            'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}',
            'data: {"type":"message_stop"}',
        })
        assert.same({ "Hel", "lo" }, out.chunks)
        assert.equals(1, out.done)
        assert.same({}, out.errors)
    end)

    it("reports a plain JSON error body (e.g. 401)", function()
        local out = run({
            '{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}',
        })
        assert.equals(1, #out.errors)
        assert.is_truthy(out.errors[1]:find("invalid x-api-key", 1, true))
        assert.equals(1, out.done)
    end)

    it("reports an in-stream error event", function()
        local out = run({ 'data: {"type":"error","error":{"message":"overloaded"}}' })
        assert.is_truthy(out.errors[1]:find("overloaded", 1, true))
        assert.equals(1, out.done)
    end)

    it("ignores blank lines, comments and event lines", function()
        local out = run({ "", ": ping", "event: ping" })
        assert.same({}, out.chunks)
        assert.is_false(out.stopped)
    end)
end)

describe("devenv-agent.providers registry", function()
    it("exposes configurable settings with a current Anthropic model", function()
        assert.is_string(providers.settings.anthropic.model)
        assert.is_string(providers.settings.ollama.model)
        assert.is_truthy(providers.settings.anthropic.model:find("claude", 1, true))
    end)

    it("falls back to ollama for unknown provider names", function()
        assert.equals("ollama", providers.get("nope").name)
    end)
end)
