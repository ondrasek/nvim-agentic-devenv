--- Agent pane: a terminal split (right or bottom, depending on screen real estate) that hosts a
--- CLI coding agent (Claude Code, Pi, ...) next to the buffer you are working on.
---
--- Design notes
--- * Backends are plain config (command, args, env keys); nothing here is agent specific.
--- * Context is handed over as plain text (path, line range, selection) -- no dependence on any
---   agent's `@file` syntax. Agents read files from disk, so the target buffer is written first and
---   buffers are reloaded (`checktime`) while the pane is open.
--- * Secrets: only keys listed in a backend's `env_keys` are taken from the process environment or
---   the project's `.env` and injected into the agent process. Values are never printed or logged.
--- * The pane window is `winfixbuf`, so `:edit`/`--remote` from hooks cannot replace the agent.
local M = {}

M.config = {
    backend = "claude",
    backends = {
        -- hooks = false: the embedded Claude runs with ALL hooks disabled (your quality-gate / auto-commit
        -- hooks must not fire inside the editor); the chat shares this setting.
        -- active_file_hook = true: prefix every typed prompt with the active nvim file through a per-launch
        -- `--settings` hook. A hook cannot coexist with hooks = false (verified: disableAllHooks also
        -- silences hooks defined in the same --settings), so enabling it requires hooks = true.
        claude = {
            cmd = { "claude" },
            args = {},
            env_keys = {},
            ready_ms = 1500,
            hooks = false,
            active_file_hook = false,
        },
        -- Pi needs a provider entry in ~/.pi/agent/models.json (see README) and, for Ollama Cloud,
        -- OLLAMA_API_KEY. Add e.g. args = { "--model", "<provider>/<model-id>" } to pick a model.
        pi = { cmd = { "pi" }, args = {}, env_keys = { "OLLAMA_API_KEY" }, ready_ms = 1500 },
    },
    layout = {
        side = "auto", -- "auto" | "right" | "bottom"
        min_columns_for_right = 160, -- "auto" goes right only on screens at least this wide
        width = 0.4, -- fraction of columns for a right pane
        height = 0.4, -- fraction of lines for a bottom pane
        min_width = 60,
        min_height = 12,
    },
    -- Share the screen with the file tree (neo-tree): on small displays the tree and a right-hand pane
    -- take turns instead of squeezing the code window.
    tree = {
        swap = "auto", -- true: always alternate | false: never | "auto": alternate when the code would get too narrow
        min_code_columns = 100, -- "auto": swap when less than this many columns would be left for code
        default_width = 35, -- tree width assumed when the tree is not open (matches neo-tree's `window.width`)
    },
    -- Files searched (in order, first value wins) for allowlisted env_keys when the process env lacks them.
    -- Relative paths are relative to the project root; "~" is expanded.
    env_file = { ".env", "~/.local/_env" },
    -- Esc belongs to the agent. These keys work inside the pane (terminal mode):
    exit_terminal_key = "<C-q>", -- jump straight back to the code window
    -- Window navigation from inside the pane; false disables. <C-\> + h/j/k/l needs no Alt/Option key
    -- (macOS terminals often do not send Alt) and no Ctrl-h/j/k/l, which Claude Code itself uses.
    nav_keys = { h = "<C-\\>h", j = "<C-\\>j", k = "<C-\\>k", l = "<C-\\>l" },
    max_selection_lines = 300,
    reload_interval_ms = 2000,
}

local state = {
    win = nil, ---@type integer|nil
    buf = nil, ---@type integer|nil
    job = nil, ---@type integer|nil
    backend = nil, ---@type string|nil
    started_at = 0, ---@type integer ms (vim.uv.now) when the agent process was started
    target_win = nil, ---@type integer|nil
    target_buf = nil, ---@type integer|nil
    timer = nil,
    tree_parked = false, ---@type boolean the pane closed the file tree and owes it back when it goes away
}

-- ─── Pure helpers (unit tested) ─────────────────────────────────────────────

--- Decide pane side and size from the available screen space
---@param columns integer
---@param lines integer
---@param layout table
---@return "right"|"bottom" side, integer size columns (right) or lines (bottom)
function M.choose_layout(columns, lines, layout)
    local side = layout.side
    if side ~= "right" and side ~= "bottom" then
        side = columns >= layout.min_columns_for_right and "right" or "bottom"
    end
    if side == "right" then
        return side, math.max(layout.min_width, math.floor(columns * layout.width))
    end
    return side, math.max(layout.min_height, math.floor(lines * layout.height))
end

--- Should the file tree and the pane take turns instead of sharing the screen?
---@param columns integer
---@param lines integer
---@param layout table
---@param tree table `config.tree`
---@param tree_width integer current (or assumed) tree width
---@return boolean
function M.should_swap(columns, lines, layout, tree, tree_width)
    if tree.swap ~= "auto" then
        return tree.swap == true
    end
    local side, size = M.choose_layout(columns, lines, layout)
    if side ~= "right" then
        return false -- a bottom pane does not compete with the tree for columns
    end
    return columns - tree_width - size < tree.min_code_columns
end

--- Text a hook injects into the agent's context so "this file" means the active buffer
---@param target { path: string, filetype?: string, cursor?: integer }
---@return string
function M.build_hook_text(target)
    local ft = (target.filetype and target.filetype ~= "") and (" (" .. target.filetype .. ")") or ""
    local at = target.cursor and (", cursor at line " .. target.cursor) or ""
    return string.format(
        '[Neovim] Active buffer: %s%s%s. When the user says "this file", "the file" or "the buffer", they mean this file.',
        target.path,
        ft,
        at
    )
end

--- Command line for an agent backend, with the active-file hook attached when the backend wants it
---@param backend table
---@return string[]
function M.build_cmd(backend)
    local cmd = vim.list_extend(vim.deepcopy(backend.cmd), backend.args or {})
    if backend.hooks == false and not backend.active_file_hook then
        vim.list_extend(cmd, { "--settings", vim.json.encode({ disableAllHooks = true }) })
    elseif backend.active_file_hook then
        -- Runs inside the agent process; $NVIM is inherited from the :terminal job
        local remote = vim.fn.shellescape(vim.v.progpath)
            .. [[ --server "$NVIM" --remote-expr "v:lua.require'devenv-agent.pane'.hook_context()" 2>/dev/null; true]]
        local settings = {
            hooks = {
                UserPromptSubmit = {
                    { hooks = { { type = "command", command = '[ -n "$NVIM" ] && ' .. remote } } },
                },
            },
        }
        vim.list_extend(cmd, { "--settings", vim.json.encode(settings) })
    end
    return cmd
end

--- Strip one pair of matching quotes
---@param value string
---@return string
local function unquote(value)
    local q = value:sub(1, 1)
    if (q == '"' or q == "'") and value:sub(-1) == q and #value >= 2 then
        return value:sub(2, -2)
    end
    return (value:gsub("%s+#.*$", ""))
end

--- Parse KEY=VALUE lines (optionally `export KEY=VALUE`), keeping ONLY allowlisted keys
---@param text string contents of a dotenv file
---@param allow string[] keys to extract
---@return table<string, string>
function M.parse_env(text, allow)
    local wanted = {}
    for _, key in ipairs(allow) do
        wanted[key] = true
    end
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        local key, value = line:match("^%s*export%s+([%w_]+)%s*=%s*(.-)%s*$")
        if not key then
            key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        end
        if key and wanted[key] then
            out[key] = unquote(value)
        end
    end
    return out
end

--- Collect allowlisted env values: the process environment wins, then the project's env file
---@param root string project root
---@param keys string[]
---@param env_file string|string[]|nil file name(s), relative to root, absolute or "~"-prefixed
---@return table<string, string>
function M.load_env(root, keys, env_file)
    local out = {}
    local missing = {}
    for _, key in ipairs(keys) do
        local value = os.getenv(key)
        if value and value ~= "" then
            out[key] = value
        else
            table.insert(missing, key)
        end
    end
    local files = type(env_file) == "table" and env_file or { env_file }
    for _, name in ipairs(files) do
        if #missing == 0 then
            break
        end
        local path = name:sub(1, 1) == "~" and vim.fn.expand(name)
            or (name:sub(1, 1) == "/" and name or root .. "/" .. name)
        local f = io.open(path, "r") -- follows symlinks
        if f then
            local from_file = M.parse_env(f:read("*a") or "", missing)
            f:close()
            out = vim.tbl_extend("force", out, from_file)
            missing = vim.tbl_filter(function(key)
                return out[key] == nil
            end, missing)
        end
    end
    return out
end

--- Build the plain-text message handed to the agent
---@param target { path: string, filetype?: string, cursor?: integer }
---@param instruction string
---@param selection? { first: integer, last: integer, text: string }
---@return string
function M.build_message(target, instruction, selection)
    local ft = (target.filetype and target.filetype ~= "") and (" (" .. target.filetype .. ")") or ""
    if selection then
        return string.format(
            "%s\n\nFile: %s%s, lines %d-%d:\n```%s\n%s\n```",
            instruction,
            target.path,
            ft,
            selection.first,
            selection.last,
            target.filetype or "",
            selection.text
        )
    end
    local at = target.cursor and (", cursor at line " .. target.cursor) or ""
    return string.format("%s\n\nFile: %s%s%s", instruction, target.path, ft, at)
end

-- ─── Target buffer tracking ─────────────────────────────────────────────────

local function is_target_win(win)
    if not vim.api.nvim_win_is_valid(win) or win == state.win then
        return false
    end
    if vim.api.nvim_win_get_config(win).relative ~= "" then
        return false
    end
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function remember_target()
    local win = vim.api.nvim_get_current_win()
    if is_target_win(win) then
        state.target_win = win
        state.target_buf = vim.api.nvim_win_get_buf(win)
    end
end

--- The buffer the agent should work on: the last normal file window the user was in
---@return integer|nil bufnr, integer|nil winid
function M.target()
    if state.target_win and is_target_win(state.target_win) then
        return vim.api.nvim_win_get_buf(state.target_win), state.target_win
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_target_win(win) then
            return vim.api.nvim_win_get_buf(win), win
        end
    end
    return nil, nil
end

-- ─── Pane lifecycle ─────────────────────────────────────────────────────────

local function notify(msg, level)
    vim.notify("DevenvAgent pane: " .. msg, level or vim.log.levels.INFO)
end

function M.is_alive()
    return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf) and state.job ~= nil
end

function M.is_visible()
    return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- ─── File tree (neo-tree) cooperation ───────────────────────────────────────

local function neo_tree_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative == "" then
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
                return win
            end
        end
    end
end

--- How the pane drives the file tree. Replaceable, so tests (and other trees) can plug in.
M.tree_driver = {
    is_open = function()
        return neo_tree_win() ~= nil
    end,
    width = function()
        local win = neo_tree_win()
        return win and vim.api.nvim_win_get_width(win) or nil
    end,
    open = function()
        pcall(vim.cmd, "Neotree show") -- "show" keeps focus where it is
    end,
    close = function()
        pcall(vim.cmd, "Neotree close")
    end,
}

--- Close the file tree if it would crowd the pane (or unconditionally with `force`)
---@param force? boolean
local function park_tree(force)
    local tree = M.tree_driver
    if not tree.is_open() then
        return
    end
    local width = tree.width() or M.config.tree.default_width
    if force or M.should_swap(vim.o.columns, vim.o.lines, M.config.layout, M.config.tree, width) then
        tree.close()
        state.tree_parked = true
    end
end

--- Give the file tree back if the pane had taken its place
local function restore_tree()
    if state.tree_parked then
        state.tree_parked = false
        if not M.tree_driver.is_open() then
            M.tree_driver.open()
        end
    end
end

--- Shared with the chat window: make room for / give back the file tree
M.dock_park = park_tree
M.dock_restore = restore_tree

--- Forget that the tree was parked (the user chose the tree themselves)
function M.dock_release()
    state.tree_parked = false
end

--- The file tree was opened by the user: if it cannot share the screen with the pane, hide the pane
--- (its session keeps running).
function M.on_tree_opened()
    if not M.is_visible() or not M.tree_driver.is_open() then
        return
    end
    local width = M.tree_driver.width() or M.config.tree.default_width
    if M.should_swap(vim.o.columns, vim.o.lines, M.config.layout, M.config.tree, width) then
        state.tree_parked = false -- the user chose the tree; do not reopen it behind their back
        M.hide()
    end
end

local function stop_timer()
    if state.timer then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
    end
end

--- Reload buffers the agent changed on disk, periodically while the pane exists
local function start_timer()
    if state.timer then
        return
    end
    state.timer = vim.uv.new_timer()
    state.timer:start(
        M.config.reload_interval_ms,
        M.config.reload_interval_ms,
        vim.schedule_wrap(function()
            if vim.fn.mode() ~= "c" then
                vim.cmd("silent! checktime")
            end
        end)
    )
end

local function style_window(win, side)
    local wo = vim.wo[win]
    wo.winfixbuf = true -- hooks/:edit/--remote must not replace the agent terminal
    wo.number = false
    wo.relativenumber = false
    wo.signcolumn = "no"
    wo.winfixwidth = side == "right"
    wo.winfixheight = side == "bottom"
end

--- Leave the agent and go back to the code window being worked on
function M.focus_code()
    local _, win = M.target()
    vim.cmd("stopinsert")
    if win then
        vim.api.nvim_set_current_win(win)
    end
end

local function set_buffer_keymaps(buf)
    -- Esc belongs to the agent TUI (cancel/interrupt); the global terminal <Esc> map must not eat it
    vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = buf, nowait = true, desc = "Pass Esc to agent" })
    vim.keymap.set("t", M.config.exit_terminal_key, M.focus_code, { buffer = buf, desc = "Back to the code window" })
    for dir, key in pairs(M.config.nav_keys or {}) do
        vim.keymap.set("t", key, "<Cmd>wincmd " .. dir .. "<CR>", { buffer = buf, desc = "Window " .. dir })
    end
    -- Coming back to the pane (any window command, mouse, <leader>af) resumes typing to the agent
    vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
        buffer = buf,
        callback = function()
            vim.cmd("startinsert")
        end,
    })
end

--- Terminate the agent and remove the pane window and buffer
local function teardown()
    stop_timer()
    if state.job then
        pcall(vim.fn.jobstop, state.job)
    end
    if M.is_visible() then
        pcall(vim.api.nvim_win_close, state.win, true)
    end
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
    end
    state.win, state.buf, state.job, state.backend = nil, nil, nil, nil
end

--- Fully terminate the agent and remove the pane (the file tree comes back if the pane had replaced it)
function M.close()
    teardown()
    restore_tree()
end

--- Open a split for the pane and return its window
---@return integer win
local function open_split()
    park_tree()
    local side, size = M.choose_layout(vim.o.columns, vim.o.lines, M.config.layout)
    vim.cmd((side == "right" and "botright %dvnew" or "botright %dnew"):format(size))
    local win = vim.api.nvim_get_current_win()
    style_window(win, side)
    return win
end

local function resolve_root()
    local buf = M.target()
    local name = buf and vim.api.nvim_buf_get_name(buf) or ""
    local start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
    -- Outside any git repo the file's own directory is the project: the agent must be able to read the file
    return vim.fs.root(start, ".git") or start
end

M.project_root = resolve_root

--- Start the backend process in a fresh pane
---@param name string
local function spawn(name)
    local backend = M.config.backends[name]
    if not backend then
        return notify("unknown backend '" .. name .. "'", vim.log.levels.ERROR)
    end
    if vim.fn.executable(backend.cmd[1]) == 0 then
        return notify("'" .. backend.cmd[1] .. "' is not on PATH (try :DevenvAgent doctor)", vim.log.levels.ERROR)
    end
    local root = resolve_root()
    local env = M.load_env(root, backend.env_keys or {}, M.config.env_file)
    local cmd = M.build_cmd(backend)

    state.win = open_split() -- `vnew` gives an empty buffer that jobstart({term=true}) can take over
    state.buf = vim.api.nvim_win_get_buf(state.win)
    state.backend = name
    state.started_at = vim.uv.now()
    local job_opts = { term = true, cwd = root }
    if next(env) then
        job_opts.env = env -- an empty table is rejected by jobstart (E475), so only pass real entries
    end
    state.job = vim.fn.jobstart(cmd, job_opts)
    if state.job <= 0 then
        M.close()
        return notify("failed to start '" .. cmd[1] .. "'", vim.log.levels.ERROR)
    end
    vim.b[state.buf].devenv_agent_pane = true
    vim.bo[state.buf].buflisted = false -- keep the agent out of the bufferline
    set_buffer_keymaps(state.buf)
    local job = state.job
    vim.api.nvim_create_autocmd("TermClose", {
        buffer = state.buf,
        once = true,
        callback = function()
            vim.schedule(function()
                -- A stale handler (old session, e.g. after switching backend) must not kill a newer one
                if state.job == job then
                    M.close()
                end
            end)
        end,
    })
    start_timer()
    vim.cmd("startinsert")
end

--- Show the pane again after it was hidden (the agent session kept running)
local function reveal()
    local win = open_split()
    local placeholder = vim.api.nvim_win_get_buf(win) -- empty buffer created by `vnew`
    vim.wo[win].winfixbuf = false
    vim.api.nvim_win_set_buf(win, state.buf)
    vim.wo[win].winfixbuf = true
    if placeholder ~= state.buf then
        pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
    end
    state.win = win
    vim.cmd("startinsert")
end

--- Open (or focus) the pane. Switching backend restarts the agent.
---@param name? string backend name; defaults to config.backend
function M.open(name)
    name = name or state.backend or M.config.backend
    if M.is_alive() and state.backend ~= name then
        M.close()
    end
    if M.is_alive() then
        if M.is_visible() then
            vim.api.nvim_set_current_win(state.win)
            vim.cmd("startinsert")
        else
            reveal()
        end
        return
    end
    spawn(name)
end

--- Hide the pane window but keep the agent session alive
function M.hide()
    if M.is_visible() then
        vim.api.nvim_win_close(state.win, true)
    end
    state.win = nil
    restore_tree()
end

--- Alternate between the agent pane and the file tree: whichever is showing makes room for the other
function M.swap()
    if M.is_visible() then
        M.hide()
        if not M.tree_driver.is_open() then
            M.tree_driver.open()
        end
        return
    end
    park_tree(true)
    M.open()
    if not M.is_visible() then
        restore_tree() -- the pane could not start: do not leave the user without a tree
    end
end

function M.toggle()
    if M.is_visible() then
        M.hide()
    else
        M.open()
    end
end

-- ─── Sending context to the agent ───────────────────────────────────────────

--- Write text into the agent's terminal. Multi-line text is sent as a bracketed paste so the
--- first newline does not submit a half-written prompt.
---@param text string
---@param submit boolean press Enter afterwards
local function transmit(text, submit)
    if not M.is_alive() then
        return
    end
    local job = state.job
    local payload = text
    if text:find("\n", 1, true) then
        payload = "\27[200~" .. text .. "\27[201~"
    end
    vim.fn.chansend(job, payload)
    if submit then
        vim.defer_fn(function()
            if state.job == job then
                vim.fn.chansend(job, "\r")
            end
        end, 150)
    end
end

--- Send text to the agent, starting the pane first if necessary
---@param text string
---@param opts? { submit?: boolean }
function M.send(text, opts)
    local submit = not (opts and opts.submit == false)
    local fresh = not M.is_alive()
    M.open()
    if not M.is_alive() then
        return
    end
    local backend = M.config.backends[state.backend]
    local wait = 0
    if fresh then
        -- A TUI that just started has not enabled bracketed paste yet; give it time
        wait = math.max(0, (backend.ready_ms or 0) - (vim.uv.now() - state.started_at))
    end
    vim.defer_fn(function()
        transmit(text, submit)
    end, wait)
end

local flush

--- Called by the agent's prompt hook (through `nvim --server $NVIM --remote-expr`): describe the active file
---@return string text, empty when there is no file buffer
function M.hook_context()
    local buf, win = M.target()
    if not buf then
        return ""
    end
    local abs = vim.api.nvim_buf_get_name(buf)
    local root = resolve_root()
    return M.build_hook_text({
        path = (vim.fs.relpath and vim.fs.relpath(root, abs)) or abs,
        filetype = vim.bo[buf].filetype,
        cursor = win and vim.api.nvim_win_get_cursor(win)[1] or nil,
    })
end

--- Write the target buffer to disk so the agent sees the current content
---@param buf integer
function flush(buf)
    if vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function()
            vim.cmd("silent! update")
        end)
    end
end

--- Build the plain-text request about the active file (or a line range of it)
--- Saves the target buffer first so the agent reads current content.
---@param instruction string
---@param range? { first: integer, last: integer } restrict to these lines
---@return string|nil message, string|nil label short description of the attached context
function M.context_message(instruction, range)
    local buf, win = M.target()
    if not buf then
        notify("no file buffer to work on", vim.log.levels.WARN)
        return nil
    end
    flush(buf)
    local root = resolve_root()
    local abs = vim.api.nvim_buf_get_name(buf)
    local target = {
        path = (vim.fs.relpath and vim.fs.relpath(root, abs)) or abs,
        filetype = vim.bo[buf].filetype,
        cursor = win and vim.api.nvim_win_get_cursor(win)[1] or nil,
    }
    local selection
    if range and range.first > 0 then
        local last = math.min(range.last, range.first + M.config.max_selection_lines - 1)
        local lines = vim.api.nvim_buf_get_lines(buf, range.first - 1, last, false)
        selection = { first = range.first, last = last, text = table.concat(lines, "\n") }
    end
    local label = target.path .. (selection and (":" .. selection.first .. "-" .. selection.last) or "")
    return M.build_message(target, instruction, selection), label
end

--- Send a request about the active file (or a line range of it) to the agent
---@param instruction string
---@param range? { first: integer, last: integer } restrict to these lines
function M.ask(instruction, range)
    local message = M.context_message(instruction, range)
    if message then
        M.send(message)
    end
end

--- Prompt for an instruction, then send it with the active file / selection as context
---@param range? { first: integer, last: integer }
function M.prompt(range)
    local default = range and "Explain this code" or "Explain this file"
    vim.ui.input({ prompt = "Agent: ", default = default }, function(input)
        if input and input ~= "" then
            M.ask(input, range)
        end
    end)
end

--- Pick the backend interactively
function M.select_backend()
    local names = vim.tbl_keys(M.config.backends)
    table.sort(names)
    vim.ui.select(names, { prompt = "Agent backend" }, function(choice)
        if choice then
            M.config.backend = choice
            M.open(choice)
        end
    end)
end

-- ─── Diagnostics ────────────────────────────────────────────────────────────

--- Report backend readiness. Never prints secret values.
---@return string[]
function M.doctor()
    local root = resolve_root()
    local lines = { "layout: " .. table.concat({ M.choose_layout(vim.o.columns, vim.o.lines, M.config.layout) }, " ") }
    local names = vim.tbl_keys(M.config.backends)
    table.sort(names)
    for _, name in ipairs(names) do
        local b = M.config.backends[name]
        local exe = vim.fn.exepath(b.cmd[1])
        local parts = { name .. ": " .. (exe ~= "" and exe or "NOT FOUND on PATH") }
        local env = M.load_env(root, b.env_keys or {}, M.config.env_file)
        for _, key in ipairs(b.env_keys or {}) do
            table.insert(parts, key .. (env[key] and " set" or " MISSING"))
        end
        table.insert(lines, table.concat(parts, "; "))
    end
    return lines
end

-- ─── Setup ──────────────────────────────────────────────────────────────────

---@param opts? table
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    local group = vim.api.nvim_create_augroup("DevenvAgentPane", { clear = true })

    vim.o.autoread = true
    vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, { group = group, callback = remember_target })
    vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave", "CursorHold" }, {
        group = group,
        callback = function()
            if vim.fn.mode() ~= "c" then
                vim.cmd("silent! checktime")
            end
        end,
    })
    -- Entering the pane to type a prompt: save the active file first so the agent reads current content
    vim.api.nvim_create_autocmd("TermEnter", {
        group = group,
        callback = function(args)
            if vim.b[args.buf].devenv_agent_pane then
                local buf = M.target()
                if buf then
                    flush(buf)
                end
            end
        end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = teardown })
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "neo-tree",
        callback = function()
            vim.schedule(M.on_tree_opened) -- the window is fully set up on the next tick
        end,
    })
    remember_target()
end

return M
