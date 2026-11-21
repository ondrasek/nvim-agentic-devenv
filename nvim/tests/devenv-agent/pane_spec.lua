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
        local expected = squash("File: " .. vim.api.nvim_buf_get_name(0)) -- before the pane takes focus
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
