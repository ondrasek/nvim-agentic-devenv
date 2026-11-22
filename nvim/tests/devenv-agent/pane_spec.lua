local pane = require("devenv-agent.pane")

local layout = pane.config.layout

describe("devenv-agent.pane choose_layout", function()
    it("goes right on wide screens, sized by fraction", function()
        local side, size = pane.choose_layout(240, 60, layout)
        assert.equals("right", side)
        assert.equals(96, size) -- floor(240 * 0.4)
    end)

    it("goes to the bottom on narrow screens", function()
        local side, size = pane.choose_layout(120, 50, layout)
        assert.equals("bottom", side)
        assert.equals(20, size) -- floor(50 * 0.4)
    end)

    it("clamps to minimum sizes", function()
        local _, w = pane.choose_layout(170, 50, vim.tbl_extend("force", layout, { width = 0.1 }))
        assert.equals(layout.min_width, w)
        local _, h = pane.choose_layout(100, 20, layout)
        assert.equals(layout.min_height, h)
    end)

    it("honours an explicit side", function()
        assert.equals("bottom", (pane.choose_layout(300, 80, vim.tbl_extend("force", layout, { side = "bottom" }))))
        assert.equals("right", (pane.choose_layout(80, 24, vim.tbl_extend("force", layout, { side = "right" }))))
    end)
end)

describe("devenv-agent.pane should_swap", function()
    local tree = pane.config.tree

    it("auto: swaps when a right pane would leave too little room for code", function()
        -- 170 cols: right pane = 68, tree = 35 -> 67 left for code (< 100)
        assert.is_true(pane.should_swap(170, 50, layout, tree, 35))
        -- 300 cols: pane 120, tree 35 -> 145 left
        assert.is_false(pane.should_swap(300, 60, layout, tree, 35))
    end)

    it("auto: never swaps for a bottom pane", function()
        assert.is_false(pane.should_swap(120, 40, layout, tree, 35))
    end)

    it("honours explicit true/false", function()
        assert.is_true(pane.should_swap(400, 80, layout, vim.tbl_extend("force", tree, { swap = true }), 35))
        assert.is_false(pane.should_swap(170, 50, layout, vim.tbl_extend("force", tree, { swap = false }), 35))
    end)
end)

describe("devenv-agent.pane env handling", function()
    local text = table.concat({
        "# comment",
        "OLLAMA_API_KEY=abc123",
        "export OTHER_SECRET='must-not-leak'",
        'QUOTED="with spaces"',
        "TRAILING=value # trailing comment",
        "",
    }, "\r\n")

    it("extracts only allowlisted keys", function()
        local env = pane.parse_env(text, { "OLLAMA_API_KEY", "QUOTED", "TRAILING" })
        assert.same({ OLLAMA_API_KEY = "abc123", QUOTED = "with spaces", TRAILING = "value" }, env)
        assert.is_nil(env.OTHER_SECRET)
    end)

    it("understands export prefixes and quotes", function()
        assert.same({ OTHER_SECRET = "must-not-leak" }, pane.parse_env(text, { "OTHER_SECRET" }))
    end)

    it("reads the env file through a symlink, and the process env wins", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        local real = dir .. "/_env"
        local f = assert(io.open(real, "w"))
        f:write("DEVENV_TEST_FROM_FILE=file-value\nDEVENV_TEST_BOTH=file-value\n")
        f:close()
        assert(vim.uv.fs_symlink(real, dir .. "/.env"))
        vim.uv.os_setenv("DEVENV_TEST_BOTH", "process-value")

        local env = pane.load_env(dir, { "DEVENV_TEST_FROM_FILE", "DEVENV_TEST_BOTH", "DEVENV_TEST_ABSENT" }, ".env")
        assert.equals("file-value", env.DEVENV_TEST_FROM_FILE)
        assert.equals("process-value", env.DEVENV_TEST_BOTH)
        assert.is_nil(env.DEVENV_TEST_ABSENT)
    end)

    it("falls back to later env files, the project file wins, and only allowlisted keys load", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        local function write(path, text)
            local f = assert(io.open(path, "w"))
            f:write(text)
            f:close()
        end
        write(dir .. "/.env", "DEVENV_T_A=project\n")
        write(dir .. "/global", "DEVENV_T_A=global\nDEVENV_T_B=global-b\nDEVENV_T_SECRET=nope\n")
        local env = pane.load_env(dir, { "DEVENV_T_A", "DEVENV_T_B", "DEVENV_T_NONE" }, { ".env", dir .. "/global" })
        assert.same({ DEVENV_T_A = "project", DEVENV_T_B = "global-b" }, env)
    end)

    it("works without an env file", function()
        assert.same({}, pane.load_env(vim.fn.tempname(), { "DEVENV_TEST_NOPE" }, ".env"))
    end)
end)

describe("devenv-agent.pane build_message", function()
    it("references the file when there is no selection", function()
        local msg = pane.build_message({ path = "src/a.lua", filetype = "lua", cursor = 7 }, "Explain")
        assert.equals("Explain\n\nFile: src/a.lua (lua), cursor at line 7", msg)
    end)

    it("embeds the selection with its line range", function()
        local msg = pane.build_message(
            { path = "a.py", filetype = "python" },
            "Refactor",
            { first = 3, last = 4, text = "x = 1\ny = 2" }
        )
        assert.equals("Refactor\n\nFile: a.py (python), lines 3-4:\n```python\nx = 1\ny = 2\n```", msg)
    end)
end)

describe("devenv-agent.pane active-file hook", function()
    it("describes the active buffer for the agent's context", function()
        local text = pane.build_hook_text({ path = "CLAUDE.md", filetype = "markdown", cursor = 12 })
        assert.is_truthy(text:find("Active buffer: CLAUDE.md (markdown), cursor at line 12", 1, true))
        assert.is_truthy(text:find("this file", 1, true))
    end)

    it("attaches a UserPromptSubmit hook through --settings for backends that ask for it", function()
        local cmd = pane.build_cmd({ cmd = { "claude" }, args = { "--foo" }, active_file_hook = true })
        assert.equals("claude", cmd[1])
        assert.equals("--foo", cmd[2])
        assert.equals("--settings", cmd[3])
        local settings = vim.json.decode(cmd[4])
        local hook = settings.hooks.UserPromptSubmit[1].hooks[1]
        assert.equals("command", hook.type)
        assert.is_truthy(hook.command:find('--server "$NVIM"', 1, true))
        assert.is_truthy(hook.command:find("hook_context", 1, true))
    end)

    it("disables all hooks for a backend with hooks = false, without injecting the file hook", function()
        local cmd = pane.build_cmd({ cmd = { "claude" }, args = {}, hooks = false })
        assert.same({ "claude", "--settings", '{"disableAllHooks":true}' }, cmd)
    end)

    it("ships the embedded Claude with hooks off and the file hook opt-in", function()
        local claude = pane.config.backends.claude
        assert.is_false(claude.hooks)
        assert.is_false(claude.active_file_hook)
        assert.is_truthy(table.concat(pane.build_cmd(claude), " "):find("disableAllHooks", 1, true))
    end)

    it("leaves other backends' command lines alone", function()
        assert.same({ "pi", "--x" }, pane.build_cmd({ cmd = { "pi" }, args = { "--x" } }))
    end)

    it("hook_context is empty without a file buffer and names the file otherwise", function()
        vim.cmd("enew")
        assert.equals("", pane.hook_context())
        local file = vim.fn.tempname() .. ".lua"
        local f = assert(io.open(file, "w"))
        f:write("x = 1\n")
        f:close()
        vim.cmd("edit " .. file)
        assert.is_truthy(pane.hook_context():find(vim.fn.fnamemodify(file, ":t"), 1, true))
    end)
end)

--- Whitespace-free text of the agent pane: the terminal wraps long lines at its width
local function squash(text)
    return (text:gsub("%s+", ""))
end

--- Text of the (single) agent pane buffer
local function pane_text()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.b[b].devenv_agent_pane then
            return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
        end
    end
    return ""
end

local function pane_win()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.b[vim.api.nvim_win_get_buf(w)].devenv_agent_pane then
            return w
        end
    end
end

describe("devenv-agent.pane integration (cat backend)", function()
    local file

    before_each(function()
        vim.o.swapfile = false
        vim.o.updatecount = 0
        pane.setup({
            backend = "fake",
            backends = { fake = { cmd = { "cat" }, args = {}, env_keys = {}, ready_ms = 0 } },
            layout = { side = "right", min_width = 30 },
        })
        file = vim.fn.tempname() .. ".lua"
        local f = assert(io.open(file, "w"))
        f:write("local a = 1\nlocal b = 2\nlocal c = 3\n")
        f:close()
        vim.cmd("edit " .. file)
    end)

    after_each(function()
        pane.close()
    end)

    it("opens a pinned terminal window and keeps tracking the file buffer as target", function()
        pane.open("fake")
        local win = pane_win()
        assert.is_truthy(win)
        assert.is_true(pane.is_alive() and pane.is_visible())
        assert.is_true(vim.wo[win].winfixbuf)

        -- Focus is inside the pane, but the target stays the file window
        vim.api.nvim_set_current_win(win)
        local buf = pane.target()
        -- macOS tmp dirs are symlinked (/var -> /private/var): compare real paths
        assert.equals(vim.uv.fs_realpath(file), vim.uv.fs_realpath(vim.api.nvim_buf_get_name(buf)))

        -- :edit inside the pane window must fail instead of replacing the agent terminal
        local ok = pcall(vim.api.nvim_win_call, win, function()
            vim.cmd("edit " .. vim.fn.tempname())
        end)
        assert.is_false(ok)
        assert.is_truthy(pane_win())
    end)

    it("delivers text and file context to the agent process", function()
        -- Outside a git repo the file's own directory is the project root, so the path is just the file name
        local expected = squash("File: " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t"))
        pane.ask("Please explain")
        local got = vim.wait(3000, function()
            return squash(pane_text()):find(expected, 1, true) ~= nil
        end, 50)
        assert.is_true(got, "expected " .. expected .. " in: " .. squash(pane_text()))
        assert.is_truthy(squash(pane_text()):find("Pleaseexplain", 1, true))
        assert.is_truthy(squash(pane_text()):find("(lua)", 1, true))
    end)

    it("includes the selection when a range is given", function()
        pane.ask("Fix this", { first = 2, last = 3 })
        assert.is_true(vim.wait(3000, function()
            return squash(pane_text()):find("lines2-3", 1, true) ~= nil
        end, 50))
        local text = squash(pane_text())
        assert.is_truthy(text:find("localb=2", 1, true))
        assert.is_truthy(text:find("localc=3", 1, true))
        assert.is_nil(text:find("locala=1", 1, true))
    end)

    it("writes a modified target buffer to disk before sending", function()
        vim.api.nvim_buf_set_lines(0, 0, 1, false, { "local a = 'edited'" })
        assert.is_true(vim.bo.modified)
        pane.ask("Check")
        local f = assert(io.open(file, "r"))
        local disk = f:read("*a")
        f:close()
        assert.is_truthy(disk:find("edited", 1, true))
    end)

    it("hide keeps the agent session alive and toggle brings it back", function()
        pane.open("fake")
        pane.hide()
        assert.is_false(pane.is_visible())
        assert.is_true(pane.is_alive())
        pane.toggle()
        assert.is_true(pane.is_visible())
        assert.is_true(vim.wo[pane_win()].winfixbuf)
    end)

    it("Ctrl-q jumps back to the code window, and navigation keys exist in the pane", function()
        local code_win = vim.api.nvim_get_current_win()
        pane.open("fake")
        local win = pane_win()
        vim.api.nvim_set_current_win(win)
        local buf = vim.api.nvim_win_get_buf(win)
        for _, key in ipairs({ "<C-q>", "<C-\\>h", "<C-\\>j", "<C-\\>k", "<C-\\>l" }) do
            local map = vim.api.nvim_buf_call(buf, function()
                return vim.fn.maparg(key, "t", false, true)
            end)
            assert.is_truthy(map.buffer == 1 and map.lhs, key .. " not mapped in the pane")
        end
        pane.focus_code()
        assert.equals(code_win, vim.api.nvim_get_current_win())
        -- returning resumes typing: the pane registers an autocmd for it
        local acs = vim.api.nvim_get_autocmds({ buffer = buf, event = "WinEnter" })
        assert.is_true(#acs > 0)
    end)

    it("switching backend does not let the old session's TermClose kill the new one", function()
        pane.config.backends.fake2 = { cmd = { "cat" }, args = {}, env_keys = {}, ready_ms = 0 }
        pane.open("fake")
        pane.open("fake2") -- restarts: old job is stopped, its TermClose fires later
        vim.wait(500) -- let any stale scheduled handlers run
        assert.is_true(pane.is_alive())
        assert.is_true(pane.is_visible())
    end)

    it("close ends the session and removes the window", function()
        pane.open("fake")
        pane.close()
        assert.is_false(pane.is_alive())
        assert.is_nil(pane_win())
    end)

    it("reports a missing backend executable instead of erroring", function()
        pane.config.backends.ghost = { cmd = { "definitely-not-installed-xyz" }, args = {}, env_keys = {} }
        local notified
        local orig = vim.notify
        vim.notify = function(msg)
            notified = msg
        end
        pane.open("ghost")
        vim.notify = orig
        assert.is_truthy(notified and notified:find("not on PATH", 1, true))
        assert.is_false(pane.is_alive())
    end)
end)

describe("devenv-agent.pane file tree swapping (fake tree)", function()
    local fake, orig_driver, file

    local function setup_pane(tree)
        pane.setup({
            backend = "fake",
            backends = { fake = { cmd = { "cat" }, args = {}, env_keys = {}, ready_ms = 0 } },
            layout = { side = "right", min_width = 30 },
            tree = tree,
        })
    end

    before_each(function()
        vim.o.swapfile = false
        vim.o.updatecount = 0
        orig_driver = pane.tree_driver
        fake = { open = true, opens = 0, closes = 0 }
        pane.tree_driver = {
            is_open = function()
                return fake.open
            end,
            width = function()
                return fake.open and 35 or nil
            end,
            open = function()
                fake.open = true
                fake.opens = fake.opens + 1
            end,
            close = function()
                fake.open = false
                fake.closes = fake.closes + 1
            end,
        }
        file = vim.fn.tempname() .. ".lua"
        local f = assert(io.open(file, "w"))
        f:write("local a = 1\n")
        f:close()
        vim.cmd("edit " .. file)
    end)

    after_each(function()
        pane.close()
        pane.tree_driver = orig_driver
    end)

    it("swap = true: opening the pane parks the tree and hiding the pane brings it back", function()
        setup_pane({ swap = true })
        pane.open("fake")
        assert.is_false(fake.open)
        pane.hide()
        assert.is_true(fake.open)
        pane.toggle()
        assert.is_false(fake.open)
        pane.close()
        assert.is_true(fake.open)
    end)

    it("swap = false: the tree is never touched", function()
        setup_pane({ swap = false })
        pane.open("fake")
        pane.hide()
        assert.equals(0, fake.closes)
        assert.equals(0, fake.opens)
    end)

    it("swap() alternates regardless of the auto rule, in both directions", function()
        setup_pane({ swap = false })
        pane.swap() -- tree -> pane
        assert.is_true(pane.is_visible())
        assert.is_false(fake.open)
        pane.swap() -- pane -> tree (session survives)
        assert.is_false(pane.is_visible())
        assert.is_true(pane.is_alive())
        assert.is_true(fake.open)
    end)

    it("swap() gives the tree back when the pane cannot start", function()
        setup_pane({ swap = false })
        pane.config.backends.ghost = { cmd = { "definitely-not-installed-xyz" }, args = {}, env_keys = {} }
        pane.config.backend = "ghost"
        local orig = vim.notify
        vim.notify = function() end
        pane.swap()
        vim.notify = orig
        assert.is_false(pane.is_visible())
        assert.is_true(fake.open)
    end)

    it("opening the tree while the pane shows hides the pane when they cannot share", function()
        setup_pane({ swap = true })
        pane.open("fake")
        fake.open = true -- the user opens the tree (e.g. <leader>e)
        pane.on_tree_opened()
        assert.is_false(pane.is_visible())
        assert.is_true(pane.is_alive())
        assert.is_true(fake.open) -- the tree the user asked for stays
    end)
end)
