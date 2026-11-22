--- OS-level containment for headless agents (macOS Seatbelt via `sandbox-exec`).
---
--- Tool allowlists do not limit *paths*, and Pi neither asks for approval nor sandboxes itself. This module
--- wraps the agent command in a Seatbelt profile so a prompt-injected or confused agent cannot touch files
--- outside its scope, whatever its tools try:
---   scope "file"    -- write only the active file; read only that file (+ what the agent needs to run)
---   scope "project" -- read/write the project root; `.env*` stay unreadable
---   scope "none"    -- no sandbox
--- In every scope the rest of the user's home (ssh keys, `~/.local/_env`, the agent's own auth file, ...)
--- is unreadable and unwritable.
---
--- Caveats: `sandbox-exec` is DEPRECATED by Apple (works today, may disappear), so containment fails
--- CLOSED: when it is requested and unavailable the agent is not started. Network is not restricted
--- (Seatbelt cannot filter by host name).
local M = {}

--- Quote a path for an SBPL string literal
---@param s string
---@return string
local function q(s)
    return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

--- Is sandboxing possible on this machine?
---@return boolean
function M.available()
    return vim.uv.os_uname().sysname == "Darwin" and vim.fn.executable("sandbox-exec") == 1
end

---@param path string
---@return string
local function real(path)
    return vim.uv.fs_realpath(path) or path
end

---@class DevenvContainOpts
---@field scope "file"|"project"
---@field file string absolute path of the active file
---@field root string project root
---@field home string user home
---@field temp string the user temp directory (user data lives there too)
---@field scratch string private temp dir the agent may write to
---@field agent_dir string agent state dir (e.g. ~/.pi); only `agent_writable` inside it is writable
---@field agent_writable string[] paths inside agent_dir the agent must be able to write
---@field agent_secret string[] files inside agent_dir the agent must NOT read (credentials)
---@field extra_read? string[] additional readable paths
---@field env? table<string,string> environment additions for the agent process

--- Build the Seatbelt profile
---@param o DevenvContainOpts
---@return string
function M.profile(o)
    local out = {
        "(version 1)",
        "(allow default)",
        -- Writes: nothing, except the allowances below (later rules win)
        "(deny file-write*)",
        '(allow file-write* (literal "/dev/null") (literal "/dev/tty") (literal "/dev/dtracehelper")'
            .. ' (regex #"^/dev/tty"))',
        "(allow file-write* (subpath " .. q(o.scratch) .. "))",
    }
    for _, path in ipairs(o.agent_writable or {}) do
        table.insert(out, "(allow file-write* (subpath " .. q(path) .. "))")
    end
    -- Reads: file contents where user data lives are denied (system and Homebrew paths stay readable so the
    -- agent can run), then the needed paths are re-allowed
    local seen = {}
    for _, root in ipairs({ "/Users", "/Volumes", "/private/tmp", o.home, o.temp }) do
        if not seen[root] then
            seen[root] = true
            table.insert(out, "(deny file-read-data (subpath " .. q(root) .. "))")
        end
    end
    table.insert(out, "(allow file-read-data (subpath " .. q(o.agent_dir) .. "))")
    table.insert(out, "(allow file-read-data (subpath " .. q(o.scratch) .. "))")
    for _, path in ipairs(o.extra_read or {}) do
        table.insert(out, "(allow file-read-data (subpath " .. q(path) .. "))")
    end
    if o.scope == "project" then
        table.insert(out, "(allow file-write* (subpath " .. q(o.root) .. "))")
        table.insert(out, "(allow file-read-data (subpath " .. q(o.root) .. "))")
        table.insert(out, '(deny file-read-data (regex #"/\\.env(\\..*)?$"))')
    else
        table.insert(out, "(allow file-write* (literal " .. q(o.file) .. "))")
        table.insert(out, "(allow file-read-data (literal " .. q(o.file) .. "))")
        -- Node cannot start without reading its working directory (process.cwd -> EPERM). Only the directory
        -- entry itself: the agent sees file names there, never their contents.
        table.insert(out, "(allow file-read-data (literal " .. q(o.root) .. "))")
    end
    for _, path in ipairs(o.agent_secret or {}) do
        table.insert(out, "(deny file-read-data (literal " .. q(path) .. "))")
    end
    return table.concat(out, "\n")
end

--- Wrap an agent command line in the sandbox
---@param cmd string[]
---@param ctx { scope: string, file: string, root: string, agent_dir: string, agent_writable?: string[], agent_secret?: string[], extra_read?: string[], env?: table<string,string> }
---@return string[]|nil wrapped command, table<string,string>|nil env additions, string|nil error
function M.wrap(cmd, ctx)
    if ctx.scope == "none" then
        return cmd, {}
    end
    if not M.available() then
        return nil,
            nil,
            "containment '"
                .. ctx.scope
                .. "' needs macOS sandbox-exec; set chat.containment = 'none' to run uncontained"
    end
    local scratch = real(vim.fn.tempname())
    vim.fn.mkdir(scratch, "p")
    scratch = real(scratch)
    local profile = M.profile({
        scope = ctx.scope,
        file = real(ctx.file),
        root = real(ctx.root),
        home = real(vim.uv.os_homedir()),
        temp = real(vim.uv.os_tmpdir()),
        scratch = scratch,
        agent_dir = real(ctx.agent_dir),
        agent_writable = ctx.agent_writable,
        agent_secret = ctx.agent_secret,
        extra_read = ctx.extra_read,
    })
    local wrapped = { "sandbox-exec", "-p", profile }
    vim.list_extend(wrapped, cmd)
    return wrapped, vim.tbl_extend("force", ctx.env or {}, { TMPDIR = scratch })
end

return M
