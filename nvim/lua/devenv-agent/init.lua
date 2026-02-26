local providers = require("devenv-agent.providers")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

M.config = {
    provider = "ollama",
    float_width = 0.6,
    float_height = 0.7,
}

-- State
local popup = nil
local conversation = {} ---@type table[] messages in {role, content} format
local current_mode = "explain" ---@type "explain"|"do"
local streaming = false

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
    local buf_name = vim.api.nvim_buf_get_name(0)
    local filetype = vim.bo.filetype
    local cwd = vim.fn.getcwd()

    local context = string.format(
        "Current file: %s\nFiletype: %s\nCWD: %s\nNvim version: %s\n",
        buf_name ~= "" and buf_name or "(no file)",
        filetype ~= "" and filetype or "(none)",
        cwd,
        tostring(vim.version())
    )

    local keybindings = get_keybinding_reference()

    if mode == "explain" then
        return "You are an assistant for the nvim-agentic-devenv environment. "
            .. "When the user asks how to do something, explain step-by-step using "
            .. "the actual keybindings from this environment. Never execute commands — "
            .. "just explain clearly.\n\n"
            .. "## Environment Context\n\n"
            .. context
            .. "\n## Keybinding Reference\n\n"
            .. keybindings
    else
        return "You are an assistant for the nvim-agentic-devenv environment. "
            .. "When the user asks you to do something, provide the nvim commands to execute. "
            .. "Wrap each command in a <nvim-cmd> block like:\n"
            .. "<nvim-cmd>:edit Makefile</nvim-cmd>\n\n"
            .. "The user will be shown each command for approval before execution. "
            .. "You may also explain what you're doing.\n\n"
            .. "## Environment Context\n\n"
            .. context
            .. "\n## Keybinding Reference\n\n"
            .. keybindings
    end
end

--- Append text to the popup buffer
---@param text string
local function append_to_buffer(text)
    if not popup or not vim.api.nvim_buf_is_valid(popup.bufnr) then
        return
    end
    local buf = popup.bufnr
    local lines = vim.api.nvim_buf_get_lines(buf, -2, -1, false)
    local last_line = lines[1] or ""

    -- Split text by newlines and append
    local parts = vim.split(text, "\n", { plain = true })
    parts[1] = last_line .. parts[1]

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, -2, -1, false, parts)
    vim.bo[buf].modifiable = false

    -- Scroll to bottom
    local win = popup.winid
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

    -- Show user message in buffer
    vim.bo[popup.bufnr].modifiable = true
    append_to_buffer("\n\n**You:** " .. user_input .. "\n\n**AI:** ")
    vim.bo[popup.bufnr].modifiable = false

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

--- Create or toggle the chat popup
function M.toggle()
    if popup and vim.api.nvim_win_is_valid(popup.winid) then
        popup:unmount()
        popup = nil
        return
    end

    popup = Popup({
        enter = true,
        focusable = true,
        border = {
            style = "rounded",
            text = {
                top = " DevenvAgent [" .. current_mode .. "] (" .. M.config.provider .. ") ",
                top_align = "center",
                bottom = " <Enter> send | <C-c> close | :DevenvAgent provider <name> ",
                bottom_align = "center",
            },
        },
        position = "50%",
        size = {
            width = M.config.float_width,
            height = M.config.float_height,
        },
        buf_options = {
            filetype = "markdown",
            modifiable = false,
        },
    })

    popup:mount()

    -- Close on C-c or q
    popup:map("n", "<C-c>", function()
        popup:unmount()
        popup = nil
    end, { noremap = true })

    popup:map("n", "q", function()
        popup:unmount()
        popup = nil
    end, { noremap = true })

    -- Enter to type a message
    popup:map("n", "<CR>", function()
        vim.ui.input({ prompt = "DevenvAgent [" .. current_mode .. "]: " }, function(input)
            if input and input ~= "" then
                send_message(input)
            end
        end)
    end, { noremap = true })

    -- Close when leaving the buffer
    popup:on(event.BufLeave, function()
        if popup then
            popup:unmount()
            popup = nil
        end
    end)

    -- Show initial content
    vim.bo[popup.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, {
        "# DevenvAgent — " .. current_mode .. " mode",
        "",
        "Provider: " .. M.config.provider,
        "",
        "Press **Enter** to type a message. Press **q** or **Ctrl-c** to close.",
        "",
        "---",
    })
    vim.bo[popup.bufnr].modifiable = false
end

--- Open in a specific mode
---@param mode "explain"|"do"
function M.open(mode)
    current_mode = mode
    conversation = {}
    -- Close existing popup if open
    if popup and vim.api.nvim_win_is_valid(popup.winid) then
        popup:unmount()
        popup = nil
    end
    M.toggle()
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
