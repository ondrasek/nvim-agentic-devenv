local context = require("devenv-agent.context")

local function scratch_buffer(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(buf)
    return buf
end

describe("devenv-agent.context", function()
    local lines = {}
    for i = 1, 10 do
        lines[i] = "line " .. i
    end

    it("falls back to the cursor window when there is no selection", function()
        scratch_buffer(lines)
        local ctx = context.gather({ visual = true })
        assert.equals("cursor_window", ctx.content_type)
    end)

    it("uses the live selection, not stale '< '> marks, while visual mode is active", function()
        scratch_buffer(lines)
        -- Previous selection: L2-3 (sets the '< and '> marks)
        vim.cmd("normal! 2GVj\27")
        -- Current selection: L5-6, still in visual mode
        vim.cmd("normal! 5GVj")
        assert.is_truthy(vim.fn.mode():match("^[vV]"), "test setup: visual mode should be active")
        local ctx = context.gather({ visual = true })
        vim.cmd("normal! \27")
        assert.equals("selection", ctx.content_type)
        assert.equals(5, ctx.selection_start)
        assert.equals(6, ctx.selection_end)
    end)

    it("uses the marks after visual mode has exited", function()
        scratch_buffer(lines)
        vim.cmd("normal! 3GVjj\27")
        local ctx = context.gather({ visual = true })
        assert.equals("selection", ctx.content_type)
        assert.equals(3, ctx.selection_start)
        assert.equals(5, ctx.selection_end)
    end)

    it("truncates long lines on character boundaries without splitting multibyte characters", function()
        scratch_buffer({ string.rep("ě", 20) })
        local ctx = context.gather({ max_line_length = 5 })
        assert.equals("1| " .. string.rep("ě", 5) .. " …", ctx.content)
    end)

    it("reports empty buffers", function()
        scratch_buffer({ "" })
        local ctx = context.gather()
        assert.equals("empty", ctx.content_type)
    end)

    it("caps selections at max_lines", function()
        scratch_buffer(lines)
        vim.cmd("normal! 1GVG\27")
        local ctx = context.gather({ visual = true, max_lines = 3 })
        assert.equals(1, ctx.selection_start)
        assert.equals(3, ctx.selection_end)
        assert.is_truthy(ctx.content:find("truncated to 3 lines", 1, true))
    end)
end)
