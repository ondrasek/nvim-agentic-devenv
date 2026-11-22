local backends = require("devenv-agent.chat_backends")

--- Parse every line of a fixture, returning all events in order
local function parse_fixture(name, backend)
    local path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures/" .. name
    local events, state = {}, {}
    for line in io.lines(path) do
        vim.list_extend(events, backend.parse(line, state))
    end
    return events
end

local function types(events)
    return vim.tbl_map(function(e)
        return e.type
    end, events)
end

describe("devenv-agent.chat_backends claude (real-run fixture)", function()
    local claude = backends.backends.claude

    it("extracts the session id, streams the text and does not repeat it from the result", function()
        local events = parse_fixture("claude-pong.jsonl", claude)
        assert.same({ "session", "text", "session" }, types(events))
        assert.equals("00000000-0000-0000-0000-00000000fix1", events[1].id)
        assert.equals("pong", events[2].text)
    end)

    it("falls back to the final result text when nothing was streamed", function()
        local events =
            claude.parse('{"type":"result","subtype":"success","is_error":false,"result":"final","session_id":"s"}', {})
        assert.same({ "session", "text" }, types(events))
        assert.equals("final", events[2].text)
    end)

    it("reports tool use and blocked tools", function()
        local use = claude.parse(
            '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"a.lua"}}]}}',
            {}
        )
        assert.same({ { type = "tool", text = "Read: a.lua" } }, use)
        local denied = claude.parse(
            '{"type":"result","subtype":"success","is_error":false,"result":"x","permission_denials":[{"tool_name":"Edit"}]}',
            { streamed = true }
        )
        assert.is_truthy(denied[1].text:find("Edit was denied by the permission mode", 1, true))
    end)

    it("turns an error result into an error event and ignores junk lines", function()
        local events =
            claude.parse('{"type":"result","subtype":"error_during_execution","is_error":true,"errors":["boom"]}', {})
        assert.same({ { type = "error", text = "boom" } }, events)
        assert.same({}, claude.parse("not json at all", {}))
    end)

    it("builds a read-only command for ask mode, with hooks disabled", function()
        local cmd = claude.build({ prompt = "hi", mode = "ask" })
        local joined = " " .. table.concat(cmd, " ") .. " "
        assert.equals("claude", cmd[1])
        assert.is_truthy(joined:find(" --tools Read,Grep,Glob ", 1, true))
        assert.is_truthy(joined:find(" --permission-mode dontAsk ", 1, true))
        assert.is_truthy(joined:find("disableAllHooks", 1, true))
        assert.is_nil(joined:find("--resume", 1, true))
        assert.is_nil(joined:find("Edit", 1, true))
    end)

    it("builds an edit command without any shell tool, and resumes a session", function()
        local cmd = claude.build({ prompt = "hi", mode = "edit", session = "abc" })
        local joined = " " .. table.concat(cmd, " ") .. " "
        assert.is_truthy(joined:find(" --permission-mode acceptEdits ", 1, true))
        assert.is_truthy(joined:find(" --tools Read,Grep,Glob,Edit,Write ", 1, true))
        assert.is_nil(joined:find("Bash", 1, true))
        assert.is_truthy(joined:find(" --resume abc ", 1, true))
    end)

    it("protects a prompt that starts with a dash or @", function()
        assert.equals(" -rf", claude.build({ prompt = "-rf", mode = "ask" })[3])
        assert.equals(" @file", claude.build({ prompt = "@file", mode = "ask" })[3])
    end)
end)

describe("devenv-agent.chat_backends pi", function()
    local pi = backends.backends.pi

    it("surfaces a failed turn from the real-run fixture (exit code is 0 there)", function()
        local events = parse_fixture("pi-error.jsonl", pi)
        assert.same({ "session", "error", "error" }, types(events))
        assert.equals("Connection error.", events[2].text)
    end)

    it("streams a successful turn from the real-run fixture: session, tool use, text", function()
        local events = parse_fixture("pi-success.jsonl", pi)
        assert.equals("session", events[1].type)
        assert.equals("00000000-0000-0000-0000-00000000fix3", events[1].id)
        local text, tools = "", {}
        for _, ev in ipairs(events) do
            assert.is_not.equals("error", ev.type)
            if ev.type == "text" then
                text = text .. ev.text
            elseif ev.type == "tool" then
                table.insert(tools, ev.text)
            end
        end
        assert.equals("noted.", text)
        assert.same({ "read: note.txt" }, tools)
    end)

    it("contained runs use a private state dir with env-referenced providers only", function()
        local home = vim.fn.tempname()
        vim.fn.mkdir(home .. "/.pi/agent", "p")
        local f = assert(io.open(home .. "/.pi/agent/models.json", "w"))
        f:write(vim.json.encode({
            providers = {
                cloud = { baseUrl = "https://x", apiKey = "${OLLAMA_API_KEY}", models = { { id = "m" } } },
                local_ = { baseUrl = "http://127.0.0.1", apiKey = "LITERAL-KEY-VALUE", models = { { id = "n" } } },
            },
        }))
        f:close()
        local old_home, old_state = vim.env.HOME, vim.env.XDG_STATE_HOME
        vim.env.HOME = home
        vim.env.XDG_STATE_HOME = home .. "/state"
        local c = pi.contain()
        vim.env.HOME, vim.env.XDG_STATE_HOME = old_home, old_state

        assert.equals(c.agent_dir, c.env.PI_CODING_AGENT_DIR)
        assert.is_truthy(c.agent_dir:find("devenv-agent/pi", 1, true))
        local gen = assert(io.open(c.agent_dir .. "/models.json")):read("*a")
        assert.is_truthy(gen:find("${OLLAMA_API_KEY}", 1, true))
        assert.is_nil(gen:find("LITERAL-KEY-VALUE", 1, true))
        for _, path in ipairs(c.agent_writable) do
            assert.is_nil(path:find("models.json", 1, true))
            assert.is_nil(path:find("extensions", 1, true))
        end
    end)

    it("ignores reasoning deltas", function()
        local events = pi.parse(
            '{"type":"message_update","assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":"Hello "}}',
            {}
        )
        assert.same({ { type = "text", text = "Hello " } }, events)
        assert.same({}, pi.parse('{"type":"message_update","assistantMessageEvent":{"type":"thinking_delta"}}', {}))
    end)

    it("builds a read-only JSON-mode command and continues with --session-id", function()
        local first = pi.build({ prompt = "hi", mode = "ask" })
        assert.same({ "pi", "--mode", "json", "--tools", "read" }, vim.list_slice(first, 1, 5))
        assert.equals("hi", first[#first])
        local next_turn = " " .. table.concat(pi.build({ prompt = "hi", mode = "edit", session = "sid" }), " ") .. " "
        assert.is_truthy(next_turn:find(" --session-id sid ", 1, true))
        assert.is_truthy(next_turn:find(" --tools read,edit,write ", 1, true))
        assert.is_nil(next_turn:find("bash", 1, true))
    end)
end)
