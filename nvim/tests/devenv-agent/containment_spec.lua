local containment = require("devenv-agent.containment")

local function opts(over)
    return vim.tbl_extend("force", {
        scope = "file",
        file = "/work/proj/docs/NOTES.md",
        root = "/work/proj",
        home = "/Users/me",
        temp = "/var/tmp-user",
        scratch = "/var/tmp-user/scratch",
        agent_dir = "/Users/me/state/pi",
        agent_writable = { "/Users/me/state/pi/sessions" },
        agent_secret = { "/Users/me/state/pi/auth.json" },
    }, over or {})
end

describe("devenv-agent.containment profile", function()
    it("file scope: writes and reads only the active file, with the cwd entry for node", function()
        local p = containment.profile(opts())
        assert.is_truthy(p:find('(allow file-write* (literal "/work/proj/docs/NOTES.md"))', 1, true))
        assert.is_truthy(p:find('(allow file-read-data (literal "/work/proj/docs/NOTES.md"))', 1, true))
        assert.is_truthy(p:find('(allow file-read-data (literal "/work/proj"))', 1, true))
        assert.is_nil(p:find('(allow file-write* (subpath "/work/proj"))', 1, true))
    end)

    it("project scope: the project tree, but .env files stay unreadable", function()
        local p = containment.profile(opts({ scope = "project" }))
        assert.is_truthy(p:find('(allow file-write* (subpath "/work/proj"))', 1, true))
        assert.is_truthy(p:find("(deny file-read-data (regex", 1, true))
        assert.is_truthy(p:find("\\.env", 1, true))
    end)

    it("denies user-data roots before re-allowing, and never lets the agent write its own config", function()
        local p = containment.profile(opts())
        for _, root in ipairs({ "/Users", "/Volumes", "/private/tmp", "/Users/me", "/var/tmp-user" }) do
            assert.is_truthy(p:find('(deny file-read-data (subpath "' .. root .. '"))', 1, true), root)
        end
        assert.is_truthy(p:find('(allow file-write* (subpath "/Users/me/state/pi/sessions"))', 1, true))
        assert.is_nil(p:find('(allow file-write* (subpath "/Users/me/state/pi"))', 1, true))
        assert.is_truthy(p:find('(deny file-read-data (literal "/Users/me/state/pi/auth.json"))', 1, true))
    end)

    it("escapes quotes and backslashes in paths", function()
        local p = containment.profile(opts({ file = '/work/we"ird\\name.md' }))
        assert.is_truthy(p:find('(literal "/work/we\\"ird\\\\name.md")', 1, true))
    end)
end)

describe("devenv-agent.containment wrap", function()
    local real_available = containment.available
    after_each(function()
        containment.available = real_available
    end)

    local ctx = { scope = "file", file = "/work/a.md", root = "/work", agent_dir = "/tmp" }

    it("leaves the command alone for scope none", function()
        local cmd, env = containment.wrap({ "pi", "x" }, vim.tbl_extend("force", ctx, { scope = "none" }))
        assert.same({ "pi", "x" }, cmd)
        assert.same({}, env)
    end)

    it("fails closed when sandboxing is unavailable", function()
        containment.available = function()
            return false
        end
        local cmd, env, err = containment.wrap({ "pi" }, ctx)
        assert.is_nil(cmd)
        assert.is_nil(env)
        assert.is_truthy(err:find("sandbox-exec", 1, true))
    end)

    it("prefixes sandbox-exec, keeps the agent's env additions and gives it a private TMPDIR", function()
        containment.available = function()
            return true
        end
        local cmd, env =
            containment.wrap({ "pi", "x" }, vim.tbl_extend("force", ctx, { env = { PI_CODING_AGENT_DIR = "/d" } }))
        assert.same({ "sandbox-exec", "-p" }, vim.list_slice(cmd, 1, 2))
        assert.same({ "pi", "x" }, vim.list_slice(cmd, #cmd - 1, #cmd))
        assert.equals("/d", env.PI_CODING_AGENT_DIR)
        assert.is_truthy(env.TMPDIR)
    end)
end)

describe("devenv-agent.containment real sandbox-exec", function()
    if not containment.available() then
        pending("needs macOS sandbox-exec")
        return
    end

    local base, o
    local function w(path, text)
        vim.fn.mkdir(vim.fs.dirname(path), "p")
        local f = assert(io.open(path, "w"))
        f:write(text)
        f:close()
    end

    local function run(scope, shell)
        local profile = containment.profile(vim.tbl_extend("force", o, { scope = scope }))
        return vim.system({ "sandbox-exec", "-p", profile, "sh", "-c", shell }, { text = true }):wait().code
    end

    before_each(function()
        base = vim.uv.fs_realpath(vim.fn.tempname() .. "-contain") or (vim.fn.tempname() .. "-contain")
        vim.fn.mkdir(base, "p")
        base = vim.uv.fs_realpath(base)
        local home = base .. "/home"
        w(home .. "/proj/docs/NOTES.md", "mine\n")
        w(home .. "/proj/docs/OTHER.md", "sibling\n")
        w(home .. "/proj/.env", "SECRET=1\n")
        w(home .. "/.ssh/id", "key\n")
        w(home .. "/state/pi/auth.json", "{}\n")
        vim.fn.mkdir(base .. "/scratch", "p")
        o = {
            file = home .. "/proj/docs/NOTES.md",
            root = home .. "/proj",
            home = home,
            temp = base,
            scratch = base .. "/scratch",
            agent_dir = home .. "/state/pi",
            agent_writable = { home .. "/state/pi/sessions" },
            agent_secret = { home .. "/state/pi/auth.json" },
        }
    end)

    it("file scope: only the active file can be written or read", function()
        assert.equals(0, run("file", "echo edit >> " .. o.file))
        assert.equals(0, run("file", "cat " .. o.file))
        assert.is_not.equals(0, run("file", "echo x >> " .. o.root .. "/docs/OTHER.md"))
        assert.is_not.equals(0, run("file", "echo x > " .. o.root .. "/docs/new.md"))
        assert.is_not.equals(0, run("file", "cat " .. o.root .. "/docs/OTHER.md"))
        assert.is_not.equals(0, run("file", "echo x > " .. base .. "/outside.txt"))
    end)

    it("never exposes secrets, in any scope", function()
        for _, scope in ipairs({ "file", "project" }) do
            assert.is_not.equals(0, run(scope, "cat " .. o.home .. "/.ssh/id"), scope)
            assert.is_not.equals(0, run(scope, "cat " .. o.root .. "/.env"), scope)
            assert.is_not.equals(0, run(scope, "cat " .. o.agent_dir .. "/auth.json"), scope)
            assert.is_not.equals(0, run(scope, "echo x > " .. o.home .. "/.ssh/new"), scope)
        end
    end)

    it("project scope reaches the whole project but nothing outside it", function()
        assert.equals(0, run("project", "echo x >> " .. o.root .. "/docs/OTHER.md"))
        assert.equals(0, run("project", "cat " .. o.root .. "/docs/OTHER.md"))
        assert.is_not.equals(0, run("project", "echo x > " .. base .. "/outside.txt"))
    end)

    it("lets the agent write its sessions and scratch dir, and read system files", function()
        assert.equals(
            0,
            run("file", "mkdir -p " .. o.agent_dir .. "/sessions && echo s > " .. o.agent_dir .. "/sessions/s.jsonl")
        )
        assert.equals(0, run("file", "echo t > " .. o.scratch .. "/t"))
        assert.equals(0, run("file", "cat /etc/hosts"))
        assert.is_not.equals(0, run("file", "echo x > " .. o.agent_dir .. "/models.json"))
    end)
end)
