--- Contextual assistant: a chat made of two ordinary nvim buffers (transcript above, input below)
--- docked on the right or bottom. Because they are plain buffers, every nvim motion, operator,
--- search, yank and window command works. The agent (Claude Code, Pi, ...) runs headless behind it,
--- one process per turn, and receives the active file / selection as context.
---
--- Backends live in `devenv-agent.chat_backends`: each turns a request into a command line and
--- parses the agent's streamed stdout into events.
local pane = require("devenv-agent.pane")

local M = {}

M.config = {
    backend = "claude",
    mode = "edit", -- "edit": the agent may change files in the project | "ask": read-only (<leader>am toggles)
    auto_open = true, -- open the chat (cursor stays in your file) when nvim starts on a file; false disables
    -- After an auto-open, a file tree that (re)appears is closed again instead of hiding the chat: neo-tree
    -- finishes its own startup reveal asynchronously and would otherwise push the chat out.
    startup_grace_ms = 3000,
    input_height = 6,
    send_insert_key = "<C-s>", -- sends from insert mode (normal mode: <CR>)
    kill_after_ms = 3000, -- cancel sends SIGINT (clean stop, session stays resumable), then kills after this
}

local state = {
    tbuf = nil, ---@type integer|nil transcript buffer
    ibuf = nil, ---@type integer|nil input buffer
    twin = nil, ---@type integer|nil
    iwin = nil, ---@type integer|nil
    job = nil, ---@type integer|nil running turn
    turn = nil, ---@type table|nil bookkeeping of the running turn
    sessions = {}, ---@type table<string, string> backend name -> session id (conversation continuity)
    root = nil, ---@type string|nil project root the sessions belong to
    grace_until = 0, ---@type integer vim.uv.now() until which a reappearing tree must not hide the chat
}

local function backends()
    return require("devenv-agent.chat_backends").backends
end

local function notify(msg, level)
    vim.notify("DevenvAgent chat: " .. msg, level or vim.log.levels.INFO)
end

local function valid(buf)
    return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function win_valid(win)
    return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.is_visible()
    return win_valid(state.twin) and win_valid(state.iwin)
end

function M.is_running()
    return state.job ~= nil
end

-- ─── Transcript ─────────────────────────────────────────────────────────────

local function make_buffer(name, filetype)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].buflisted = false
    vim.bo[buf].filetype = filetype
    pcall(vim.api.nvim_buf_set_name, buf, name)
    vim.b[buf].devenv_agent_chat = true
    return buf
end

--- Append text (possibly a partial line) at the end of the transcript, following the output
--- only if the cursor was already at the end.
---@param text string
local function append(text)
    local buf = state.tbuf
    if not valid(buf) or text == "" then
        return
    end
    local count = vim.api.nvim_buf_line_count(buf)
    local following = not win_valid(state.twin) or vim.api.nvim_win_get_cursor(state.twin)[1] >= count
    local last = vim.api.nvim_buf_get_lines(buf, count - 1, count, false)[1] or ""
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_text(buf, count - 1, #last, count - 1, #last, vim.split(text, "\n", { plain = true }))
    vim.bo[buf].modifiable = false
    if following and win_valid(state.twin) then
        pcall(vim.api.nvim_win_set_cursor, state.twin, { vim.api.nvim_buf_line_count(buf), 0 })
    end
end

local function backend_label()
    local be = backends()[M.config.backend]
    return be and be.label or M.config.backend
end

local function set_winbar()
    if not win_valid(state.twin) then
        return
    end
    local status = state.job and "  working…  (<C-c> cancels)" or ""
    local mode = M.config.mode == "edit" and "edit: may change files" or "ASK: read-only, <leader>am allows edits"
    local text = (" %s · %s%s"):format(backend_label(), mode, status):gsub("%%", "%%%%")
    vim.wo[state.twin].winbar = text
end

-- ─── Turn execution ─────────────────────────────────────────────────────────

--- Apply one parsed backend event to the UI/state
---@param ev table
---@param turn table per-turn bookkeeping
local function handle_event(ev, turn)
    if ev.type == "text" then
        turn.got_text = true
        append(ev.text)
    elseif ev.type == "tool" then
        append(("\n`%s`\n"):format(ev.text))
    elseif ev.type == "session" then
        state.sessions[M.config.backend] = ev.id
    elseif ev.type == "error" then
        turn.error = ev.text
    end
end

local function feed_line(line, backend, turn)
    if line == "" then
        return
    end
    for _, ev in ipairs(backend.parse(line, turn.parser)) do
        handle_event(ev, turn)
    end
end

--- jobstart delivers `data` split on newlines; the first element continues the previous chunk
local function make_stdout_handler(backend, turn)
    return function(_, data)
        data[1] = turn.partial .. data[1]
        turn.partial = table.remove(data)
        for _, line in ipairs(data) do
            feed_line(line, backend, turn)
        end
    end
end

local function finish_turn(job, code, backend, turn)
    if state.job ~= job then
        return
    end
    feed_line(turn.partial, backend, turn)
    state.job = nil
    if turn.cancelled then
        append("\n_(cancelled)_\n\n")
    elseif turn.error or (code ~= 0 and not turn.got_text) then
        local err = turn.error or vim.trim(table.concat(turn.stderr, "\n"))
        append(("\n**Error** (exit %d): %s\n\n"):format(code, err ~= "" and err or "no output"))
        if turn.resumed then
            -- A session that cannot be resumed would fail every later turn: start fresh next time
            state.sessions[M.config.backend] = nil
            append("_The conversation could not be resumed; the next message starts a new one._\n\n")
        end
    else
        append("\n\n")
    end
    vim.cmd("silent! checktime") -- the agent may have edited files
    set_winbar()
end

---@param message string
local function start_turn(message)
    local name = M.config.backend
    local be = backends()[name]
    if not be then
        return notify("unknown backend '" .. name .. "'", vim.log.levels.ERROR)
    end
    if vim.fn.executable(be.cmd[1]) == 0 then
        return notify("'" .. be.cmd[1] .. "' is not on PATH (try :DevenvAgent doctor)", vim.log.levels.ERROR)
    end
    local root = pane.project_root()
    if state.root and state.root ~= root then
        -- Sessions belong to a project directory: another repo means another conversation
        state.sessions = {}
        append(("_Project changed to %s: new agent conversation._\n\n"):format(root))
    end
    state.root = root
    local session = state.sessions[name]
    local cmd, stdin = be.build({ prompt = message, session = session, mode = M.config.mode })
    local opts = { cwd = root, stdin = "pipe" }
    local env = pane.load_env(root, be.env_keys or {}, pane.config.env_file)
    if next(env) then
        opts.env = env
    end
    local turn = { partial = "", stderr = {}, parser = {}, got_text = false, resumed = session ~= nil }
    local on_stdout = make_stdout_handler(be, turn)
    opts.on_stdout = on_stdout
    opts.on_stderr = function(_, data)
        vim.list_extend(turn.stderr, data)
    end
    local job
    opts.on_exit = function(_, code)
        vim.schedule(function()
            finish_turn(job, code, be, turn)
        end)
    end
    job = vim.fn.jobstart(cmd, opts)
    if job <= 0 then
        return notify("failed to start '" .. cmd[1] .. "'", vim.log.levels.ERROR)
    end
    state.job = job
    state.turn = turn
    if stdin then
        vim.fn.chansend(job, stdin)
    end
    vim.fn.chanclose(job, "stdin")
    set_winbar()
end

--- Stop the running turn
function M.cancel()
    local job = state.job
    if not job then
        return
    end
    if state.turn then
        state.turn.cancelled = true
    end
    local ok, pid = pcall(vim.fn.jobpid, job)
    if ok and pid and pid > 0 then
        pcall(vim.uv.kill, pid, "sigint")
    end
    vim.defer_fn(function()
        pcall(vim.fn.jobstop, job) -- still alive (or already gone: harmless)
    end, M.config.kill_after_ms)
end

-- ─── Windows ────────────────────────────────────────────────────────────────

local function style(win)
    local wo = vim.wo[win]
    wo.winfixbuf = true -- hooks/:edit/--remote must not replace the chat buffers
    wo.number = false
    wo.relativenumber = false
    wo.signcolumn = "no"
    wo.wrap = true
    wo.linebreak = true
    wo.conceallevel = 2
end

local function set_keymaps()
    local function map(buf, mode, lhs, fn, desc)
        vim.keymap.set(mode, lhs, fn, { buffer = buf, desc = desc, nowait = true })
    end
    map(state.ibuf, "n", "<CR>", M.submit, "Send to agent")
    map(state.ibuf, "i", M.config.send_insert_key, M.submit, "Send to agent")
    for _, buf in ipairs({ state.ibuf, state.tbuf }) do
        map(buf, "n", "<C-c>", M.cancel, "Cancel the running turn")
    end
    map(state.tbuf, "n", "q", M.hide, "Hide the chat")
    -- The transcript is read-only: i/a jump to the input instead of failing with E21
    for _, key in ipairs({ "i", "a" }) do
        map(state.tbuf, "n", key, function()
            M.focus_input(true)
        end, "Type a message")
    end
end

local function ensure_buffers()
    if not valid(state.tbuf) then
        state.tbuf = make_buffer("devenv-agent://chat", "markdown")
        vim.bo[state.tbuf].modifiable = false
    end
    if not valid(state.ibuf) then
        state.ibuf = make_buffer("devenv-agent://input", "markdown")
    end
    set_keymaps()
end

local function show_windows()
    pane.dock_park()
    local side, size = pane.choose_layout(vim.o.columns, vim.o.lines, pane.config.layout)
    local split = side == "right" and { split = "right", win = -1, width = size }
        or { split = "below", win = -1, height = size }
    state.twin = vim.api.nvim_open_win(state.tbuf, true, split)
    style(state.twin)
    state.iwin =
        vim.api.nvim_open_win(state.ibuf, true, { split = "below", win = state.twin, height = M.config.input_height })
    style(state.iwin)
    vim.wo[state.iwin].winfixheight = true
    set_winbar()
end

--- Show the chat (creating it on first use) and focus the input
---@param insert? boolean start typing right away
function M.open(insert)
    ensure_buffers()
    if not M.is_visible() then
        show_windows()
    end
    M.focus_input(insert)
end

function M.focus_input(insert)
    if not M.is_visible() then
        return M.open(insert)
    end
    vim.api.nvim_set_current_win(state.iwin)
    if insert then
        vim.cmd("startinsert!")
    end
end

--- Hide the windows; the conversation (and a running turn) continue
function M.hide()
    for _, key in ipairs({ "iwin", "twin" }) do
        if win_valid(state[key]) then
            pcall(vim.api.nvim_win_close, state[key], true)
        end
        state[key] = nil
    end
    pane.dock_restore()
end

function M.toggle()
    if M.is_visible() then
        M.hide()
    else
        M.open(true)
    end
end

--- End the conversation: stop any turn, close the windows and drop the transcript and sessions
function M.close()
    M.cancel()
    state.job = nil -- the exit handler of the cancelled turn must not touch the next conversation
    M.hide()
    for _, key in ipairs({ "tbuf", "ibuf" }) do
        if valid(state[key]) then
            pcall(vim.api.nvim_buf_delete, state[key], { force = true })
        end
        state[key] = nil
    end
    state.sessions = {}
    state.root = nil
end

--- Start a fresh conversation (new agent session, empty transcript)
function M.new_session()
    M.cancel()
    state.job = nil
    state.sessions = {}
    state.root = nil
    set_winbar()
    if valid(state.tbuf) then
        vim.bo[state.tbuf].modifiable = true
        vim.api.nvim_buf_set_lines(state.tbuf, 0, -1, false, {})
        vim.bo[state.tbuf].modifiable = false
    end
end

-- ─── Sending ────────────────────────────────────────────────────────────────

--- Ask the agent. The active file (or selected range) is attached automatically.
---@param text string
---@param range? { first: integer, last: integer }
function M.send(text, range)
    if state.job then
        return notify("a turn is still running (<C-c> cancels it)", vim.log.levels.WARN)
    end
    local message, label = pane.context_message(text, range)
    if not message then
        return
    end
    if not M.is_visible() then
        M.open(false)
    end
    append(("## You\n%s\n\n_📎 %s_\n\n## %s\n"):format(text, label, backend_label()))
    start_turn(message)
end

--- Send what is typed in the input buffer, then clear it
function M.submit()
    if not valid(state.ibuf) then
        return
    end
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(state.ibuf, 0, -1, false), "\n"))
    if text == "" then
        return
    end
    if state.job then
        return notify("a turn is still running (<C-c> cancels it)", vim.log.levels.WARN)
    end
    vim.api.nvim_buf_set_lines(state.ibuf, 0, -1, false, {})
    vim.cmd("stopinsert")
    M.send(text)
end

--- Prompt for an instruction (a selection becomes its context), then send it
---@param range? { first: integer, last: integer }
function M.prompt(range)
    vim.ui.input({ prompt = "Agent: ", default = range and "Explain this code" or "Explain this file" }, function(input)
        if input and input ~= "" then
            M.send(input, range)
        end
    end)
end

-- ─── Settings ───────────────────────────────────────────────────────────────

function M.toggle_mode()
    M.config.mode = M.config.mode == "ask" and "edit" or "ask"
    set_winbar()
    notify("mode: " .. M.config.mode .. (M.config.mode == "edit" and " (the agent may change files)" or " (read-only)"))
end

function M.select_backend()
    local names = vim.tbl_keys(backends())
    table.sort(names)
    vim.ui.select(names, { prompt = "Agent backend" }, function(choice)
        if choice then
            M.config.backend = choice
            set_winbar()
        end
    end)
end

--- The file tree was opened by the user: if it cannot share the screen, hide the chat
function M.on_tree_opened()
    if not M.is_visible() or not pane.tree_driver.is_open() then
        return
    end
    if vim.uv.now() < state.grace_until then
        pane.dock_park() -- startup: the chat wins, the tree makes room again
        return
    end
    local width = pane.tree_driver.width() or pane.config.tree.default_width
    if pane.should_swap(vim.o.columns, vim.o.lines, pane.config.layout, pane.config.tree, width) then
        pane.dock_release()
        M.hide()
    end
end

--- Alternate between the chat and the file tree
function M.swap()
    if M.is_visible() then
        M.hide()
        if not pane.tree_driver.is_open() then
            pane.tree_driver.open()
        end
        return
    end
    pane.dock_park(true)
    M.open(true)
end

--- Should the chat open by itself? Only for an interactive nvim started with file arguments.
---@param enabled boolean
---@param argc integer number of file arguments nvim was started with
---@param ui_count integer number of attached UIs (0 when headless)
---@return boolean
function M.should_auto_open(enabled, argc, ui_count)
    return enabled and argc > 0 and ui_count > 0
end

--- Open the chat beside the file nvim started on, leaving the cursor in the file
---@param force? boolean skip the startup checks (tests)
function M.auto_open(force)
    if not force and not M.should_auto_open(M.config.auto_open, vim.fn.argc(), #vim.api.nvim_list_uis()) then
        return
    end
    local _, win = pane.target()
    if not win or M.is_visible() then
        return
    end
    state.grace_until = vim.uv.now() + M.config.startup_grace_ms
    M.open(false)
    vim.api.nvim_set_current_win(win)
end

---@param opts? table
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    local group = vim.api.nvim_create_augroup("DevenvAgentChat", { clear = true })
    if M.config.auto_open then
        if vim.v.vim_did_enter == 1 then
            vim.schedule(M.auto_open) -- the plugin loaded after startup (lazy.nvim VeryLazy)
        else
            vim.api.nvim_create_autocmd("VimEnter", {
                group = group,
                once = true,
                callback = function()
                    vim.schedule(M.auto_open) -- after other VimEnter handlers (file tree) have run
                end,
            })
        end
    end
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "neo-tree",
        callback = function()
            vim.schedule(M.on_tree_opened)
        end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.cancel })
    -- Closing either chat window by hand (:q, <C-w>c) closes the other too, so no orphan is left
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(args)
            local win = tonumber(args.match)
            if win and (win == state.twin or win == state.iwin) then
                vim.schedule(M.hide)
            end
        end,
    })
end

return M
