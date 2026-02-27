local providers = require("devenv-agent.providers")
local context = require("devenv-agent.context")
local Popup = require("nui.popup")
local Layout = require("nui.layout")
local event = require("nui.utils.autocmd").event

local M = {}

M.config = {
    provider = "ollama",
    float_width = 0.6,
    float_height = 0.7,
    context_max_lines = 200,
    context_max_line_length = 500,
}

-- State
local layout = nil
local history_popup = nil
local input_popup = nil
local conversation = {} ---@type table[] messages in {role, content} format
local current_mode = "explain" ---@type "explain"|"do"
local streaming = false
local buffer_context = nil ---@type table|nil gathered context for current session

--- Load the keybinding reference
local function get_keybinding_reference()
    local paths = {
        vim.fn.stdpath("config") .. "/docs/keybinding-reference.md",
        vim.fn.getcwd() .. "/docs/keybinding-reference.md",
    }
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            return content
        end
    end
    return "(keybinding reference not found)"
end

--- Build system prompt based on mode
---@param mode "explain"|"do"
---@return string
local function build_system_prompt(mode)
    local ctx = buffer_context or {}
    local cwd = vim.fn.getcwd()

    local env_context = string.format(
        "Current file: %s\nFiletype: %s\nCursor: line %s, col %s\nCWD: %s\nNvim version: %s\n",
        ctx.filename or "(no file)",
        ctx.filetype or "(none)",
        ctx.cursor_line or "?",
        ctx.cursor_col or "?",
        cwd,
        tostring(vim.version())
    )

    -- Build buffer content section
    local buffer_section = ""
    if ctx.content and ctx.content ~= "" then
        local header
        if ctx.content_type == "selection" then
            header = string.format(
                "## Selected Code (%s L%d-%d)\n\n",
                ctx.filename or "(no file)",
                ctx.selection_start or 0,
                ctx.selection_end or 0
            )
        elseif ctx.content_type == "cursor_window" then
            header = string.format("## Buffer Content (%s)\n\n", ctx.filename or "(no file)")
        else
            header = "## Buffer Content\n\n"
        end

        local ft = ctx.filetype or ""
        if ft == "(none)" then
            ft = ""
        end
        buffer_section = header .. "```" .. ft .. "\n" .. ctx.content .. "\n```\n"
    end

    local keybindings = get_keybinding_reference()

    local mode_instruction
    if mode == "explain" then
        mode_instruction = "You are an assistant for the nvim-agentic-devenv environment. "
            .. "When the user asks how to do something, explain step-by-step using "
            .. "the actual keybindings from this environment. Never execute commands — "
            .. "just explain clearly."
    else
        mode_instruction = "You are an assistant for the nvim-agentic-devenv environment. "
            .. "When the user asks you to do something, provide the nvim commands to execute. "
            .. "Wrap each command in a <nvim-cmd> block like:\n"
            .. "<nvim-cmd>:edit Makefile</nvim-cmd>\n\n"
            .. "The user will be shown each command for approval before execution. "
            .. "You may also explain what you're doing."
    end

    return mode_instruction
        .. "\n\n## Environment Context\n\n"
        .. env_context
        .. "\n"
        .. buffer_section
        .. "\n## Keybinding Reference\n\n"
        .. keybindings
end

--- Append text to the history buffer
---@param text string
local function append_to_buffer(text)
    if not history_popup or not vim.api.nvim_buf_is_valid(history_popup.bufnr) then
        return
    end
    local buf = history_popup.bufnr
    local lines = vim.api.nvim_buf_get_lines(buf, -2, -1, false)
    local last_line = lines[1] or ""

    -- Split text by newlines and append
    local parts = vim.split(text, "\n", { plain = true })
    parts[1] = last_line .. parts[1]

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, -2, -1, false, parts)
    vim.bo[buf].modifiable = false

    -- Scroll to bottom
    local win = history_popup.winid
    if win and vim.api.nvim_win_is_valid(win) then
        local line_count = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_win_set_cursor(win, { line_count, 0 })
    end
end

--- Parse and execute nvim commands from response (do mode)
---@param response string
local function handle_nvim_commands(response)
    for cmd in response:gmatch("<nvim%-cmd>(.-)</nvim%-cmd>") do
        local choice = vim.fn.confirm("Execute nvim command?\n\n" .. cmd, "&Yes\n&No\n&Cancel", 2)
        if choice == 1 then
            local ok, err = pcall(vim.cmd, cmd)
            if not ok then
                vim.notify("Command failed: " .. tostring(err), vim.log.levels.ERROR)
            end
        elseif choice == 3 then
            break
        end
    end
end

--- Send a message and stream the response
---@param user_input string
local function send_message(user_input)
    if streaming then
        vim.notify("DevenvAgent: already streaming a response", vim.log.levels.WARN)
        return
    end

    table.insert(conversation, { role = "user", content = user_input })

    -- Show user message in history buffer
    vim.bo[history_popup.bufnr].modifiable = true
    append_to_buffer("\n\n**You:** " .. user_input .. "\n\n**AI:** ")
    vim.bo[history_popup.bufnr].modifiable = false

    streaming = true
    local full_response = ""
    local system = build_system_prompt(current_mode)
    local provider = providers.get(M.config.provider)

    provider.send(conversation, system, function(chunk)
        full_response = full_response .. chunk
        append_to_buffer(chunk)
    end, function()
        streaming = false
        table.insert(conversation, { role = "assistant", content = full_response })
        append_to_buffer("\n")

        -- In "do" mode, parse and offer to execute commands
        if current_mode == "do" then
            handle_nvim_commands(full_response)
        end
    end)
end

--- Build the popup header text showing file context
---@return string
local function popup_header()
    local ctx = buffer_context or {}
    local base = " DevenvAgent [" .. current_mode .. "] (" .. M.config.provider .. ")"

    if ctx.content_type == "selection" and ctx.selection_start then
        local fname = vim.fn.fnamemodify(ctx.filename or "", ":t")
        if fname == "" then
            fname = "(no file)"
        end
        return base .. " -- " .. fname .. " L" .. ctx.selection_start .. "-" .. ctx.selection_end .. " "
    elseif ctx.content_type == "cursor_window" and ctx.cursor_line then
        local fname = vim.fn.fnamemodify(ctx.filename or "", ":t")
        if fname == "" then
            fname = "(no file)"
        end
        return base .. " -- " .. fname .. ":" .. ctx.cursor_line .. " "
    else
        return base .. " "
    end
end

--- Build initial popup content lines
---@return string[]
local function initial_content()
    local ctx = buffer_context or {}
    local summary
    if ctx.content_type == "selection" then
        summary = string.format("Context: selection L%d-%d", ctx.selection_start or 0, ctx.selection_end or 0)
    elseif ctx.content_type == "cursor_window" then
        summary = string.format("Context: buffer around line %d", ctx.cursor_line or 0)
    elseif ctx.content_type == "binary" then
        summary = "Context: (binary or non-text buffer skipped)"
    else
        summary = "Context: (empty buffer)"
    end

    return {
        "# DevenvAgent — " .. current_mode .. " mode",
        "",
        "Provider: " .. M.config.provider,
        summary,
        "",
        "Type below. **Ctrl-Enter** to send. **Tab** switch panes. **q** / **Ctrl-c** close.",
        "",
        "---",
    }
end

--- Close the layout and nil all state
local function close_layout()
    if layout then
        layout:unmount()
        layout = nil
        history_popup = nil
        input_popup = nil
    end
end

--- Focus the input pane and enter insert mode
local function focus_input()
    if input_popup and vim.api.nvim_win_is_valid(input_popup.winid) then
        vim.api.nvim_set_current_win(input_popup.winid)
        vim.cmd("startinsert")
    end
end

--- Focus the history pane and leave insert mode
local function focus_history()
    if history_popup and vim.api.nvim_win_is_valid(history_popup.winid) then
        vim.api.nvim_set_current_win(history_popup.winid)
        vim.cmd("stopinsert")
    end
end

--- Toggle between input and history panes
local function toggle_pane()
    local cur = vim.api.nvim_get_current_win()
    if input_popup and cur == input_popup.winid then
        focus_history()
    else
        focus_input()
    end
end

--- Read input buffer, send message, clear input buffer
local function send_from_input()
    if not input_popup or not vim.api.nvim_buf_is_valid(input_popup.bufnr) then
        return
    end
    local lines = vim.api.nvim_buf_get_lines(input_popup.bufnr, 0, -1, false)
    local text = vim.trim(table.concat(lines, "\n"))
    if text == "" then
        return
    end
    send_message(text)
    -- Clear input buffer
    vim.api.nvim_buf_set_lines(input_popup.bufnr, 0, -1, false, { "" })
    focus_input()
end

--- Set up keybindings on both panes
local function setup_keybindings()
    local map_opts = { noremap = true, silent = true }

    -- Both panes: q (normal) closes layout
    for _, pane in ipairs({ history_popup, input_popup }) do
        pane:map("n", "q", close_layout, map_opts)
        pane:map("n", "<C-c>", close_layout, map_opts)
        pane:map("i", "<C-c>", close_layout, map_opts)
        pane:map("n", "<Tab>", toggle_pane, map_opts)
        pane:map("i", "<Tab>", toggle_pane, map_opts)
    end

    -- Input pane: send keybindings
    input_popup:map("n", "<CR>", send_from_input, map_opts)
    input_popup:map("i", "<C-CR>", send_from_input, map_opts)
    input_popup:map("n", "<C-CR>", send_from_input, map_opts)
end

--- Set up BufLeave autocmds that close layout only when leaving both panes
local function setup_buf_leave()
    for _, pane in ipairs({ history_popup, input_popup }) do
        pane:on(event.BufLeave, function()
            vim.schedule(function()
                if not layout then
                    return
                end
                local cur = vim.api.nvim_get_current_win()
                -- If the current window is one of our panes, don't close
                if
                    (history_popup and vim.api.nvim_win_is_valid(history_popup.winid) and cur == history_popup.winid)
                    or (input_popup and vim.api.nvim_win_is_valid(input_popup.winid) and cur == input_popup.winid)
                then
                    return
                end
                close_layout()
            end)
        end)
    end
end

--- Create or toggle the chat layout
function M.toggle()
    if layout and history_popup and vim.api.nvim_win_is_valid(history_popup.winid) then
        close_layout()
        return
    end

    -- Gather context if not already set (e.g. opened via <leader>aa or :DevenvAgent toggle)
    if not buffer_context then
        buffer_context = context.gather({
            max_lines = M.config.context_max_lines,
            max_line_length = M.config.context_max_line_length,
        })
    end

    -- History pane (top, read-only)
    history_popup = Popup({
        enter = false,
        focusable = true,
        border = {
            style = "rounded",
            text = {
                top = popup_header(),
                top_align = "center",
            },
        },
        buf_options = {
            filetype = "markdown",
            modifiable = false,
        },
    })

    -- Input pane (bottom, editable)
    input_popup = Popup({
        enter = true,
        focusable = true,
        border = {
            style = "rounded",
            text = {
                top = " Input ",
                top_align = "left",
                bottom = " <C-CR> send | <Tab> pane | <C-c> close ",
                bottom_align = "center",
            },
        },
        buf_options = {
            modifiable = true,
        },
    })

    layout = Layout(
        {
            position = "50%",
            size = {
                width = M.config.float_width,
                height = M.config.float_height,
            },
        },
        Layout.Box({
            Layout.Box(history_popup, { size = "80%" }),
            Layout.Box(input_popup, { size = "20%" }),
        }, { dir = "col" })
    )

    layout:mount()
    setup_keybindings()
    setup_buf_leave()

    -- Show initial content in history buffer
    vim.bo[history_popup.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(history_popup.bufnr, 0, -1, false, initial_content())
    vim.bo[history_popup.bufnr].modifiable = false

    -- Start in insert mode in the input pane
    focus_input()
end

--- Open in a specific mode (normal mode — cursor-window context)
---@param mode "explain"|"do"
---@param ctx? table pre-gathered context
function M.open(mode, ctx)
    current_mode = mode
    conversation = {}

    -- Gather context if not provided
    buffer_context = ctx
        or context.gather({
            max_lines = M.config.context_max_lines,
            max_line_length = M.config.context_max_line_length,
        })

    -- Close existing layout if open
    if layout and history_popup and vim.api.nvim_win_is_valid(history_popup.winid) then
        close_layout()
    end
    M.toggle()
end

--- Open in a specific mode with visual selection context
---@param mode "explain"|"do"
function M.open_visual(mode)
    local ctx = context.gather({
        visual = true,
        max_lines = M.config.context_max_lines,
        max_line_length = M.config.context_max_line_length,
    })
    M.open(mode, ctx)
end

--- Set provider
---@param name string
function M.set_provider(name)
    if providers.providers[name] then
        M.config.provider = name
        vim.notify("DevenvAgent: provider set to " .. name, vim.log.levels.INFO)
    else
        vim.notify(
            "DevenvAgent: unknown provider '" .. name .. "'. Available: ollama, anthropic",
            vim.log.levels.ERROR
        )
    end
end

--- Setup function called by Lazy.nvim
---@param opts? table
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    -- Auto-select anthropic if ANTHROPIC_API_KEY is set and ollama isn't running
    if M.config.provider == "ollama" and os.getenv("ANTHROPIC_API_KEY") then
        -- Still default to ollama, but let user know anthropic is available
        vim.defer_fn(function()
            vim.notify("DevenvAgent: ANTHROPIC_API_KEY detected. Use :DevenvAgent provider anthropic to switch.", vim.log.levels.INFO)
        end, 1000)
    end

    -- Register commands
    vim.api.nvim_create_user_command("DevenvAgent", function(cmd_opts)
        local args = vim.split(cmd_opts.args, "%s+")
        local subcmd = args[1] or "toggle"

        if subcmd == "explain" then
            M.open("explain")
        elseif subcmd == "do" then
            M.open("do")
        elseif subcmd == "toggle" then
            M.toggle()
        elseif subcmd == "provider" then
            M.set_provider(args[2] or "")
        else
            vim.notify("DevenvAgent: unknown command '" .. subcmd .. "'", vim.log.levels.ERROR)
        end
    end, {
        nargs = "*",
        complete = function()
            return { "explain", "do", "toggle", "provider ollama", "provider anthropic" }
        end,
    })
end

return M
