return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
        {
            "nvim-treesitter/nvim-treesitter-textobjects",
        },
    },
    opts = {
        ensure_installed = {
            "python",
            "rust",
            "elixir",
            "c_sharp",
            "typescript",
            "javascript",
            "go",
            "lua",
            "bash",
            "json",
            "yaml",
            "toml",
            "html",
            "css",
            "markdown",
            "markdown_inline",
            "dockerfile",
            "gitcommit",
            "diff",
            "vim",
            "vimdoc",
        },
        textobjects = {
            select = {
                enable = true,
                lookahead = true,
                keymaps = {
                    ["af"] = { query = "@function.outer", desc = "Around function" },
                    ["if"] = { query = "@function.inner", desc = "Inside function" },
                    ["ac"] = { query = "@class.outer", desc = "Around class" },
                    ["ic"] = { query = "@class.inner", desc = "Inside class" },
                },
            },
            move = {
                enable = true,
                goto_next_start = {
                    ["]f"] = { query = "@function.outer", desc = "Next function" },
                    ["]c"] = { query = "@class.outer", desc = "Next class" },
                },
                goto_previous_start = {
                    ["[f"] = { query = "@function.outer", desc = "Previous function" },
                    ["[c"] = { query = "@class.outer", desc = "Previous class" },
                },
            },
        },
    },
}
