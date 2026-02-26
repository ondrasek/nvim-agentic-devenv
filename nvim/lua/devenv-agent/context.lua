local M = {}

--- Check if buffer content looks like binary data
---@param lines string[]
---@return boolean
local function is_binary(lines)
    if vim.bo.binary then
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
---@param opts? { visual?: boolean, max_lines?: integer, max_line_length?: integer }
---@return table context
function M.gather(opts)
    opts = opts or {}
    local max_lines = opts.max_lines or 200
    local max_line_length = opts.max_line_length or 500

    local buf_name = vim.api.nvim_buf_get_name(0)
    local filetype = vim.bo.filetype
    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor[1]
    local cursor_col = cursor[2] + 1 -- convert 0-based col to 1-based

    local ctx = {
        filename = buf_name ~= "" and buf_name or "(no file)",
        filetype = filetype ~= "" and filetype or "(none)",
        cursor_line = cursor_line,
        cursor_col = cursor_col,
        content = "",
        content_type = "empty",
    }

    local total_lines = vim.api.nvim_buf_line_count(0)

    -- Empty buffer
    if total_lines == 0 or (total_lines == 1 and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "") then
        ctx.content = "(empty buffer)"
        ctx.content_type = "empty"
        return ctx
    end

    local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- Binary detection
    if is_binary(all_lines) then
        ctx.content = "(binary or non-text buffer skipped)"
        ctx.content_type = "binary"
        return ctx
    end

    if opts.visual then
        -- Visual selection: read marks
        local sel_start = vim.fn.line("'<")
        local sel_end = vim.fn.line("'>")
        if sel_start > 0 and sel_end > 0 and sel_start <= total_lines then
            sel_end = math.min(sel_end, total_lines)
            local lines = vim.api.nvim_buf_get_lines(0, sel_start - 1, sel_end, false)
            ctx.selection_start = sel_start
            ctx.selection_end = sel_end
            ctx.content = table.concat(format_lines(lines, sel_start, max_line_length), "\n")
            ctx.content_type = "selection"
        end
    else
        -- Cursor-centered window
        local half = math.floor(max_lines / 2)
        local win_start = math.max(1, cursor_line - half)
        local win_end = math.min(total_lines, win_start + max_lines - 1)
        -- Adjust start if we hit the end
        win_start = math.max(1, win_end - max_lines + 1)

        local lines = vim.api.nvim_buf_get_lines(0, win_start - 1, win_end, false)
        ctx.content = table.concat(format_lines(lines, win_start, max_line_length), "\n")
        ctx.content_type = "cursor_window"
    end

    return ctx
end

return M
