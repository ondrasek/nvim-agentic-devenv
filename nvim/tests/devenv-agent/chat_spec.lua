local pane = require("devenv-agent.pane")
local chat = require("devenv-agent.chat")
local default_mode = chat.config.mode
local default_auto_open = chat.config.auto_open

-- A scripted agent: its "stdout" is whatever the shell script prints
local script = ""
package.loaded["devenv-agent.chat_backends"] = {
    backends = {
        fake = {
            label = "Fake",
            cmd = { "sh" },
            env_keys = {},
            build = function(ctx)
                chat._last_ctx = ctx
                return { "sh", "-c", script }
            end,
            parse = function(line)
                if line:sub(1, 8) == "SESSION " then
                    return { { type = "session", id = line:sub(9) } }
                end
                if line == "FAIL" then
                    return { { type = "error", text = "boom" } }
                end
                return { { type = "text", text = line .. "\n" } }
            end,
        },
    },
}

local function transcript()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.b[b].devenv_agent_chat and vim.bo[b].modifiable == false then
            return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
        end
    end
    return ""
end

local function wait_done()
    assert.is_true(vim.wait(5000, function()
        return not chat.is_running()
    end, 20))
end

local function chat_wins()
    local out = {}
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.b[vim.api.nvim_win_get_buf(w)].devenv_agent_chat then
            table.insert(out, w)
        end
    end
    return out
end

describe("devenv-agent.chat", function()
    local file

    before_each(function()
        vim.o.swapfile = false
        vim.o.updatecount = 0
        pane.setup({ layout = { side = "right", min_width = 30 }, tree = { swap = false } })
        chat.setup({ backend = "fake", mode = "ask", kill_after_ms = 200 })
        file = vim.fn.tempname() .. ".lua"
        local f = assert(io.open(file, "w"))
        f:write("local a = 1\nlocal b = 2\n")
        f:close()
        vim.cmd("edit " .. file)
    end)

    after_each(function()
        chat.close()
    end)

    it("defaults to edit mode so a requested change is applied, and says so in the winbar", function()
        assert.equals("edit", default_mode)
        chat.setup({ mode = default_mode })
        chat.open()
        local twin = chat_wins()[1]
        assert.is_truthy(vim.wo[twin].winbar:find("edit: may change files", 1, true))
        chat.toggle_mode()
        assert.is_truthy(vim.wo[twin].winbar:find("read-only", 1, true))
    end)

    it("auto_open: decides from the option, file arguments and an attached UI", function()
        assert.is_true(chat.should_auto_open(true, 1, 1))
        assert.is_false(chat.should_auto_open(false, 1, 1))
        assert.is_false(chat.should_auto_open(true, 0, 1)) -- started without a file
        assert.is_false(chat.should_auto_open(true, 1, 0)) -- headless
    end)

    it("auto_open opens the chat but leaves the cursor in the file window", function()
        local file_win = vim.api.nvim_get_current_win()
        chat.auto_open(true)
        assert.is_true(chat.is_visible())
        assert.equals(file_win, vim.api.nvim_get_current_win())
        chat.auto_open(true) -- already visible: no duplicate windows
        assert.equals(2, #chat_wins())
    end)

    it("auto_open is on by default, but a headless start without a file never opens the chat", function()
        assert.is_true(default_auto_open)
        chat.auto_open()
        assert.is_false(chat.is_visible())
    end)

    it("auto_open = false is honoured", function()
        chat.setup({ auto_open = false })
        chat.auto_open()
        assert.is_false(chat.is_visible())
    end)

    it("opens a transcript and an input window, both pinned and focused on the input", function()
        chat.open()
        local wins = chat_wins()
        assert.equals(2, #wins)
        for _, w in ipairs(wins) do
            assert.is_true(vim.wo[w].winfixbuf)
        end
        assert.is_true(vim.b[vim.api.nvim_get_current_buf()].devenv_agent_chat)
        assert.equals("markdown", vim.bo.filetype)
        assert.is_true(vim.bo.modifiable) -- the input buffer is a normal editable buffer
    end)

    it("streams output into the transcript, handling lines split across chunks", function()
        script = "printf 'par'; sleep 0.1; printf 'tial\\nsecond\\n'"
        chat.send("Explain")
        wait_done()
        local text = transcript()
        assert.is_truthy(text:find("## You\nExplain", 1, true))
        assert.is_truthy(text:find("## Fake", 1, true))
        assert.is_truthy(text:find("partial\nsecond", 1, true))
    end)

    it("attaches the active file as context, not to the visible text", function()
        script = "true"
        chat.send("Fix it", { first = 2, last = 2 })
        wait_done()
        assert.is_truthy(chat._last_ctx.prompt:find("lines 2-2", 1, true))
        assert.is_truthy(chat._last_ctx.prompt:find("local b = 2", 1, true))
        assert.is_truthy(transcript():find(vim.fn.fnamemodify(file, ":t") .. ":2-2", 1, true))
    end)

    it("keeps the session id and hands it to the next turn", function()
        script = "echo 'SESSION abc'; echo hi"
        chat.send("one")
        wait_done()
        script = "echo again"
        chat.send("two")
        wait_done()
        assert.equals("abc", chat._last_ctx.session)
    end)

    it("passes the mode and toggles it", function()
        script = "true"
        chat.send("x")
        wait_done()
        assert.equals("ask", chat._last_ctx.mode)
        chat.toggle_mode()
        chat.send("y")
        wait_done()
        assert.equals("edit", chat._last_ctx.mode)
    end)

    it("reports a backend error in the transcript", function()
        script = "echo FAIL; exit 3"
        chat.send("x")
        wait_done()
        assert.is_truthy(transcript():find("**Error** (exit 3): boom", 1, true))
    end)

    it("cancel stops a running turn", function()
        script = "sleep 30"
        chat.send("x")
        assert.is_true(chat.is_running())
        chat.cancel()
        wait_done()
        assert.is_truthy(transcript():find("(cancelled)", 1, true))
    end)

    it("refuses a second turn while one is running", function()
        script = "sleep 30"
        chat.send("first")
        local warned
        local orig = vim.notify
        vim.notify = function(msg)
            warned = msg
        end
        chat.send("second")
        vim.notify = orig
        assert.is_truthy(warned and warned:find("still running", 1, true))
        chat.cancel()
        wait_done()
    end)

    it("submit sends the input buffer text and clears it", function()
        script = "echo ok"
        chat.open()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line one", "line two" })
        chat.submit()
        wait_done()
        assert.is_truthy(transcript():find("line one\nline two", 1, true))
        assert.same({ "" }, vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false))
    end)

    it("hide keeps the conversation, toggle shows it again", function()
        script = "echo remembered"
        chat.send("hello")
        wait_done()
        chat.hide()
        assert.is_false(chat.is_visible())
        assert.equals(0, #chat_wins())
        chat.toggle()
        assert.is_true(chat.is_visible())
        assert.is_truthy(transcript():find("remembered", 1, true))
    end)

    it("close wipes the conversation", function()
        script = "echo gone"
        chat.send("hello")
        wait_done()
        chat.close()
        assert.equals("", transcript())
        assert.equals(0, #chat_wins())
    end)

    it("closing one chat window by hand closes the other and keeps the conversation", function()
        script = "echo kept"
        chat.send("hello")
        wait_done()
        local input_win = chat_wins()[2]
        vim.api.nvim_win_close(input_win, true)
        assert.is_true(vim.wait(1000, function()
            return #chat_wins() == 0
        end, 20))
        assert.is_false(chat.is_visible())
        chat.focus_input() -- must reopen cleanly, not error on a dead window
        assert.equals(2, #chat_wins())
        assert.is_truthy(transcript():find("kept", 1, true))
    end)

    it("a failed resume drops the session so the next turn can start fresh", function()
        script = "echo 'SESSION s1'; echo ok"
        chat.send("one")
        wait_done()
        script = "echo FAIL; exit 1"
        chat.send("two") -- resumes s1 and fails
        wait_done()
        assert.equals("s1", chat._last_ctx.session)
        script = "echo recovered"
        chat.send("three")
        wait_done()
        assert.is_nil(chat._last_ctx.session)
        assert.is_truthy(transcript():find("recovered", 1, true))
    end)

    it("new_session ignores the late exit of the cancelled turn", function()
        script = "sleep 30"
        chat.send("x")
        chat.new_session()
        vim.wait(300)
        assert.is_nil(transcript():find("(cancelled)", 1, true))
        assert.is_false(chat.is_running())
    end)

    it("takes turns with the file tree when swapping", function()
        local orig_driver = pane.tree_driver
        local open = true
        pane.tree_driver = {
            is_open = function()
                return open
            end,
            width = function()
                return 35
            end,
            open = function()
                open = true
            end,
            close = function()
                open = false
            end,
        }
        chat.swap() -- tree -> chat
        assert.is_true(chat.is_visible())
        assert.is_false(open)
        chat.swap() -- chat -> tree
        assert.is_false(chat.is_visible())
        assert.is_true(open)
        pane.tree_driver = orig_driver
    end)
end)
