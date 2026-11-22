--- Headless agent backends for the chat buffers.
---
--- A backend is { label, cmd, env_keys, build(ctx) -> cmd[, stdin], parse(line, state) -> events }.
--- `parse` turns one line of the agent's stdout into events:
---   { type = "text", text }  { type = "tool", text }  { type = "session", id }  { type = "error", text }
---
--- Evidence for the event shapes:
--- * Claude Code: a real `claude -p --output-format stream-json --verbose --include-partial-messages`
---   run (v2.1.330), trimmed in tests/devenv-agent/fixtures/claude-pong.jsonl.
--- * Pi, failed turn: a real `pi --mode json` run (v0.84.3), fixtures/pi-error.jsonl.
--- * Pi, successful turn (text, tool use, session): a real `pi --mode json --model ollama-cloud/kimi-k3`
---   run, trimmed in fixtures/pi-success.jsonl.
local M = {}

M.options = {
    -- Hooks for the embedded Claude (chat and terminal) are controlled by
    -- `pane.config.backends.claude.hooks` (default false = all hooks disabled).
    -- Tools per mode. No shell tool in either: the chat is a contextual assistant, not an autonomous agent.
    claude_tools = { ask = "Read,Grep,Glob", edit = "Read,Grep,Glob,Edit,Write" },
    pi_tools = { ask = "read", edit = "read,edit,write" },
}

local function extra_backend(name)
    local ok, pane = pcall(require, "devenv-agent.pane")
    return ok and pane.config.backends[name] or {}
end

local function extra_args(name)
    return extra_backend(name).args or {}
end

local function system_prompt(mode)
    local rules = mode == "edit" and "You may edit files on disk when asked; say which files you changed."
        or "You are read-only: you cannot change files. Show proposed changes as code the user can apply."
    return "You are a contextual coding assistant inside Neovim. Each message names the user's active file "
        .. "(and possibly a selection): read it from disk. Be concise, answer in Markdown, refer to code as "
        .. "file:line. "
        .. rules
end

--- A prompt starting with '-' would be parsed as an option by the agent CLIs
---@param prompt string
local function safe_prompt(prompt)
    return (prompt:gsub("^[%-@]", " %0"))
end

local function decode(line)
    local ok, obj = pcall(vim.json.decode, line)
    if ok and type(obj) == "table" then
        return obj
    end
end

local function tool_label(name, input)
    input = type(input) == "table" and input or {}
    local detail = input.file_path or input.path or input.pattern or input.command or ""
    return detail ~= "" and (name .. ": " .. detail) or name
end

-- ─── Claude Code ────────────────────────────────────────────────────────────

local function claude_result(obj, streamed)
    local events = {}
    if obj.session_id then
        table.insert(events, { type = "session", id = obj.session_id })
    end
    for _, denial in ipairs(obj.permission_denials or {}) do
        local detail = type(denial) == "table" and tool_label(denial.tool_name or "a tool", denial.tool_input)
            or "a tool"
        table.insert(events, { type = "tool", text = detail .. " was denied by the permission mode" })
    end
    if obj.is_error or obj.subtype ~= "success" then
        local detail = obj.result or table.concat(obj.errors or {}, "; ")
        table.insert(events, { type = "error", text = detail ~= "" and detail or tostring(obj.subtype) })
    elseif not streamed and obj.result then
        table.insert(events, { type = "text", text = obj.result }) -- nothing was streamed: use the final text
    end
    return events
end

local function claude_parse(line, state)
    local obj = decode(line)
    if not obj then
        return {}
    end
    if obj.type == "system" and obj.subtype == "init" then
        return { { type = "session", id = obj.session_id } }
    end
    local event = obj.type == "stream_event" and obj.event or nil
    if event and event.type == "content_block_delta" and event.delta and event.delta.type == "text_delta" then
        state.streamed = true
        return { { type = "text", text = event.delta.text } }
    end
    if obj.type == "assistant" and obj.message then
        local events = {}
        for _, item in ipairs(obj.message.content or {}) do
            if item.type == "tool_use" then
                table.insert(events, { type = "tool", text = tool_label(item.name, item.input) })
            end
        end
        return events
    end
    if obj.type == "result" then
        return claude_result(obj, state.streamed)
    end
    return {}
end

local function claude_build(ctx)
    local cmd = {
        "claude",
        "-p",
        safe_prompt(ctx.prompt),
        "--output-format",
        "stream-json",
        "--verbose",
        "--include-partial-messages",
        "--tools",
        M.options.claude_tools[ctx.mode] or M.options.claude_tools.ask,
        "--permission-mode",
        ctx.mode == "edit" and "acceptEdits" or "dontAsk",
        "--append-system-prompt",
        system_prompt(ctx.mode),
    }
    if extra_backend("claude").hooks == false then
        vim.list_extend(cmd, { "--settings", vim.json.encode({ disableAllHooks = true }) })
    end
    if ctx.session then
        vim.list_extend(cmd, { "--resume", ctx.session })
    end
    return vim.list_extend(cmd, extra_args("claude"))
end

-- ─── Pi ─────────────────────────────────────────────────────────────────────

local function pi_message_error(obj)
    local msg = obj.message
    if type(msg) == "table" and msg.role == "assistant" and msg.stopReason == "error" then
        return { { type = "error", text = msg.errorMessage or "the model request failed" } }
    end
    return {}
end

local function pi_parse(line, state)
    local obj = decode(line)
    if not obj then
        return {}
    end
    if obj.type == "session" and obj.id then
        return { { type = "session", id = obj.id } }
    end
    if obj.type == "message_update" and type(obj.assistantMessageEvent) == "table" then
        local ame = obj.assistantMessageEvent
        if ame.type == "text_delta" and ame.delta then
            state.streamed = true
            return { { type = "text", text = ame.delta } }
        end
        return {}
    end
    if obj.type == "tool_execution_start" then
        return { { type = "tool", text = tool_label(obj.toolName or obj.name or "tool", obj.args or obj.input) } }
    end
    if obj.type == "message_end" then
        return pi_message_error(obj)
    end
    if obj.type == "auto_retry_end" and obj.success == false then
        return { { type = "error", text = obj.finalError or "the model request failed" } }
    end
    return {}
end

local function pi_build(ctx)
    local cmd = { "pi", "--mode", "json" }
    if ctx.session then
        vim.list_extend(cmd, { "--session-id", ctx.session })
    end
    vim.list_extend(cmd, {
        "--tools",
        M.options.pi_tools[ctx.mode] or M.options.pi_tools.ask,
        "--append-system-prompt",
        system_prompt(ctx.mode),
    })
    vim.list_extend(cmd, extra_args("pi"))
    return vim.list_extend(cmd, { safe_prompt(ctx.prompt) })
end

M.backends = {
    claude = { label = "Claude", cmd = { "claude" }, env_keys = {}, build = claude_build, parse = claude_parse },
    pi = { label = "Pi", cmd = { "pi" }, env_keys = { "OLLAMA_API_KEY" }, build = pi_build, parse = pi_parse },
}

return M
