local M = {}

--- Check if buffer content looks like binary data
---@param bufnr integer
---@param lines string[]
---@return boolean
local function is_binary(bufnr, lines)
    if vim.bo[bufnr].binary then
        return true
    end
    local check_lines = math.min(#lines, 10)
    for i = 1, check_lines do
        if lines[i]:find("%z") then
            return true
        end
    end
    return false
end

--- Add line number prefixes and truncate long lines
---@param lines string[]
---@param start_lnum integer 1-based starting line number
---@param max_line_length integer
---@return string[]
local function format_lines(lines, start_lnum, max_line_length)
    local width = #tostring(start_lnum + #lines - 1)
    local formatted = {}
    for i, line in ipairs(lines) do
        local lnum = start_lnum + i - 1
        local prefix = string.format("%" .. width .. "d| ", lnum)
        if #line > max_line_length then
            line = line:sub(1, max_line_length) .. " …"
        end
        formatted[i] = prefix .. line
    end
    return formatted
end

--- Gather buffer context for AI prompts
---@param opts? { visual?: boolean, bufnr?: integer, winid?: integer, max_lines?: integer, max_line_length?: integer }
---@return table context
function M.gather(opts)
    opts = opts or {}
    local max_lines = opts.max_lines or 200
    local max_line_length = opts.max_line_length or 500

    -- Resolve buffer and window, defaulting to current
    local bufnr = opts.bufnr or 0
    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
        -- No changedtick available for invalid buffers; use -1 so callers
        -- always see a mismatch and re-gather when the buffer becomes valid.
        return {
            filename = "(invalid buffer)",
            filetype = "(none)",
            content = "",
            content_type = "empty",
            changedtick = -1,
        }
    end

    local winid = opts.winid or 0
    if winid == 0 then
        winid = vim.api.nvim_get_current_win()
    end

    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    local filetype = vim.bo[bufnr].filetype

    -- Resolve cursor: use window if valid, otherwise default to line 1
    local cursor_line, cursor_col
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
        local cursor = vim.api.nvim_win_get_cursor(winid)
        cursor_line = cursor[1]
        cursor_col = cursor[2] + 1 -- convert 0-based col to 1-based
    else
        cursor_line = 1
        cursor_col = 1
    end

    local ctx = {
        filename = buf_name ~= "" and buf_name or "(no file)",
        filetype = filetype ~= "" and filetype or "(none)",
        cursor_line = cursor_line,
        cursor_col = cursor_col,
        content = "",
        content_type = "empty",
    }

    local total_lines = vim.api.nvim_buf_line_count(bufnr)

    -- Empty buffer
    if total_lines == 0 or (total_lines == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == "") then
        ctx.content = "(empty buffer)"
        ctx.content_type = "empty"
        ctx.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
        return ctx
    end

    -- Binary detection: only fetch first 10 lines
    local prefix = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(10, total_lines), false)
    if is_binary(bufnr, prefix) then
        ctx.content = "(binary or non-text buffer skipped)"
        ctx.content_type = "binary"
        ctx.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
        return ctx
    end

    if opts.visual and bufnr == vim.api.nvim_get_current_buf() then
        -- Visual selection: read marks and normalize direction
        -- Marks are global, so only use them when bufnr is the current buffer
        local mark_start = vim.fn.line("'<")
        local mark_end = vim.fn.line("'>")
        local sel_start = math.min(mark_start, mark_end)
        local sel_end = math.max(mark_start, mark_end)
        if sel_start > 0 and sel_end > 0 and sel_start <= total_lines then
            sel_end = math.min(sel_end, total_lines)
            -- Cap to max_lines
            local truncated = false
            if sel_end - sel_start + 1 > max_lines then
                sel_end = sel_start + max_lines - 1
                truncated = true
            end
            local lines = vim.api.nvim_buf_get_lines(bufnr, sel_start - 1, sel_end, false)
            ctx.selection_start = sel_start
            ctx.selection_end = sel_end
            local content = table.concat(format_lines(lines, sel_start, max_line_length), "\n")
            if truncated then
                content = content .. "\n(truncated to " .. max_lines .. " lines)"
            end
            ctx.content = content
            ctx.content_type = "selection"
        else
            -- Invalid marks — fall back to cursor-window
            opts.visual = false
        end
    end

    if not opts.visual then
        -- Cursor-centered window
        local half = math.floor(max_lines / 2)
        local win_start = math.max(1, cursor_line - half)
        local win_end = math.min(total_lines, win_start + max_lines - 1)
        -- Adjust start if we hit the end
        win_start = math.max(1, win_end - max_lines + 1)

        local lines = vim.api.nvim_buf_get_lines(bufnr, win_start - 1, win_end, false)
        ctx.content = table.concat(format_lines(lines, win_start, max_line_length), "\n")
        ctx.content_type = "cursor_window"
    end

    ctx.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
    return ctx
end

return M
