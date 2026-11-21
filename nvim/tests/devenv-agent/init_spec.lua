describe("devenv-agent", function()
    it("module loads without error", function()
        local ok, mod = pcall(require, "devenv-agent")
        assert.is_true(ok, "devenv-agent module should load: " .. tostring(mod))
        assert.is_table(mod)
    end)

    it("exports expected functions", function()
        local mod = require("devenv-agent")
        assert.is_function(mod.setup)
        assert.is_function(mod.toggle)
        assert.is_function(mod.open)
        assert.is_function(mod.open_visual)
        assert.is_function(mod.set_provider)
    end)

    it("has default config values", function()
        local mod = require("devenv-agent")
        assert.is_table(mod.config)
        assert.is_string(mod.config.provider)
        assert.is_number(mod.config.float_width)
        assert.is_number(mod.config.float_height)
    end)
end)

describe("devenv-agent commands", function()
    local mod = require("devenv-agent")
    local notified

    before_each(function()
        mod.setup({})
        notified = {}
        mod._orig_notify = vim.notify
        vim.notify = function(msg, level)
            table.insert(notified, { msg = msg, level = level })
        end
    end)

    after_each(function()
        vim.notify = mod._orig_notify
    end)

    it("registers :DevenvAgent with the pane subcommands in completion", function()
        assert.equals(2, vim.fn.exists(":DevenvAgent"))
        local candidates = vim.fn.getcompletion("DevenvAgent ", "cmdline")
        for _, expected in ipairs({ "pane", "pane claude", "pane pi", "pane close", "send", "doctor" }) do
            assert.is_true(vim.tbl_contains(candidates, expected), "missing completion: " .. expected)
        end
    end)

    it("doctor reports every backend without printing secret values", function()
        vim.uv.os_setenv("OLLAMA_API_KEY", "super-secret-value")
        vim.cmd("DevenvAgent doctor")
        local out = notified[1].msg
        assert.is_truthy(out:find("claude", 1, true))
        assert.is_truthy(out:find("pi", 1, true))
        assert.is_truthy(out:find("OLLAMA_API_KEY set", 1, true))
        assert.is_nil(out:find("super-secret-value", 1, true))
    end)

    it("rejects unknown subcommands", function()
        vim.cmd("DevenvAgent nonsense")
        assert.equals(vim.log.levels.ERROR, notified[1].level)
    end)
end)
