local quit = require("config.quit")

local function panel(kind)
    vim.cmd("botright vnew")
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buftype = "nofile"
    if kind == "tree" then
        vim.bo[buf].filetype = "neo-tree"
    else
        vim.b[buf].devenv_agent_chat = true
    end
    return vim.api.nvim_get_current_win()
end

describe("config.quit", function()
    local file_win

    before_each(function()
        vim.cmd("silent! only!")
        vim.cmd("enew!")
        file_win = vim.api.nvim_get_current_win()
    end)

    after_each(function()
        pcall(vim.api.nvim_set_current_win, file_win)
        vim.cmd("silent! only!")
    end)

    it("closes tree and chat panels when quitting from the last file window", function()
        panel("tree")
        panel("chat")
        panel("chat")
        vim.api.nvim_set_current_win(file_win)
        quit.before_quit()
        assert.same({ file_win }, vim.api.nvim_list_wins())
    end)

    it("does nothing when another file window is open", function()
        vim.cmd("split")
        panel("tree")
        vim.api.nvim_set_current_win(file_win)
        quit.before_quit()
        assert.equals(3, #vim.api.nvim_list_wins())
    end)

    it("does nothing when quitting from inside a panel", function()
        local tree = panel("tree")
        quit.before_quit()
        assert.equals(2, #vim.api.nvim_list_wins())
        assert.equals(tree, vim.api.nvim_get_current_win())
    end)

    describe("in a real child nvim", function()
        local file

        before_each(function()
            file = vim.fn.tempname() .. ".md"
            local f = assert(io.open(file, "w"))
            f:write("hello\n")
            f:close()
        end)

        --- Open the file with two side panels, run `command`; STILL-RUNNING is printed if nvim did not exit
        local function run(command, setup)
            local args = { vim.v.progpath, "--headless", "-u", "tests/minimal_init.lua", file }
            local steps = {
                "lua require('config.quit').setup()",
                "botright vnew | setlocal buftype=nofile filetype=neo-tree",
                "botright vnew | setlocal buftype=nofile | let b:devenv_agent_chat = v:true",
                "wincmd t",
                setup or "echo",
                command,
                "lua io.stdout:write('STILL-RUNNING wins=' .. #vim.api.nvim_list_wins())",
                "qa!",
            }
            for _, step in ipairs(steps) do
                vim.list_extend(args, { "-c", step })
            end
            local res = vim.system(args, { text = true }):wait(20000)
            return (res.stdout or "") .. (res.stderr or "")
        end

        local function contents()
            local f = assert(io.open(file))
            local text = f:read("*a")
            f:close()
            return text
        end

        it("one :q exits", function()
            assert.is_nil(run("q"):find("STILL-RUNNING", 1, true))
        end)

        it(":wq writes the change and exits", function()
            assert.is_nil(run("wq", "call setline(1, 'changed')"):find("STILL-RUNNING", 1, true))
            assert.equals("changed\n", contents())
        end)

        it(":q with unsaved changes still refuses and keeps the change", function()
            local out = run("silent! q", "call setline(1, 'unsaved')")
            assert.is_truthy(out:find("STILL-RUNNING", 1, true))
            assert.equals("hello\n", contents())
        end)

        it(":q! discards and exits", function()
            assert.is_nil(run("q!", "call setline(1, 'unsaved')"):find("STILL-RUNNING", 1, true))
            assert.equals("hello\n", contents())
        end)
    end)
end)
