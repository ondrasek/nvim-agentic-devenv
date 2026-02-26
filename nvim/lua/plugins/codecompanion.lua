local keybinding_ref = nil

--- Load the keybinding reference from docs/keybinding-reference.md at runtime
local function get_keybinding_reference()
    if keybinding_ref then
        return keybinding_ref
    end
    local paths = {
        vim.fn.stdpath("config") .. "/docs/keybinding-reference.md",
        vim.fn.getcwd() .. "/docs/keybinding-reference.md",
    }
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            keybinding_ref = f:read("*a")
            f:close()
            return keybinding_ref
        end
    end
    keybinding_ref = "(keybinding reference not found)"
    return keybinding_ref
end

return {
    "olimorris/codecompanion.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    opts = {
        adapters = {
            ollama = function()
                return require("codecompanion.adapters").extend("ollama", {
                    schema = {
                        model = { default = "qwen3-coder" },
                    },
                })
            end,
            anthropic = function()
                return require("codecompanion.adapters").extend("anthropic", {
                    env = { api_key = "ANTHROPIC_API_KEY" },
                })
            end,
        },
        strategies = {
            chat = {
                adapter = "ollama",
            },
        },
        prompt_library = {
            ["Explain (devenv)"] = {
                interaction = "chat",
                description = "Explain how to do something in this nvim environment",
                opts = {
                    alias = "explain",
                    auto_submit = true,
                    is_slash_cmd = true,
                    stop_context_insertion = true,
                },
                prompts = {
                    {
                        role = "system",
                        content = function()
                            return "You are an assistant for the nvim-agentic-devenv environment. "
                                .. "When the user asks how to do something, explain step-by-step using "
                                .. "the actual keybindings from this environment. Never execute commands — "
                                .. "just explain clearly.\n\n"
                                .. "## Keybinding Reference\n\n"
                                .. get_keybinding_reference()
                        end,
                    },
                    {
                        role = "user",
                        content = function(context)
                            if context.is_visual then
                                return "Explain what this "
                                    .. context.filetype
                                    .. " code does and how to work with it in our nvim environment:\n\n```"
                                    .. context.filetype
                                    .. "\n"
                                    .. context.code
                                    .. "\n```"
                            end
                            return ""
                        end,
                        condition = function(context)
                            return context.is_visual
                        end,
                    },
                },
            },
            ["Do it (devenv)"] = {
                interaction = "chat",
                description = "Execute an action in the nvim environment",
                opts = {
                    alias = "do",
                    auto_submit = true,
                    is_slash_cmd = true,
                    stop_context_insertion = true,
                },
                prompts = {
                    {
                        role = "system",
                        content = function()
                            return "You are an assistant for the nvim-agentic-devenv environment. "
                                .. "When the user asks you to do something, execute it using the available tools. "
                                .. "You can edit files, run shell commands, and search the codebase. "
                                .. "Explain what you're doing as you go.\n\n"
                                .. "## Keybinding Reference\n\n"
                                .. get_keybinding_reference()
                        end,
                    },
                    {
                        role = "user",
                        content = function(context)
                            if context.is_visual then
                                return "Here is the selected "
                                    .. context.filetype
                                    .. " code for context:\n\n```"
                                    .. context.filetype
                                    .. "\n"
                                    .. context.code
                                    .. "\n```"
                            end
                            return ""
                        end,
                        condition = function(context)
                            return context.is_visual
                        end,
                    },
                },
            },
        },
        display = {
            chat = {
                window = {
                    layout = "vertical",
                    width = 0.4,
                },
            },
        },
    },
    keys = {
        { "<leader>a2", "<cmd>CodeCompanionChat Toggle<cr>", desc = "CodeCompanion chat" },
        {
            "<leader>ae",
            function()
                require("codecompanion").prompt("explain")
            end,
            mode = { "n", "v" },
            desc = "Explain (AI)",
        },
        {
            "<leader>ad",
            function()
                require("codecompanion").prompt("do")
            end,
            mode = { "n", "v" },
            desc = "Do it (AI)",
        },
    },
}
