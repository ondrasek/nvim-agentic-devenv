return {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    keys = {
        {
            "grn",
            function()
                return ":IncRename " .. vim.fn.expand("<cword>")
            end,
            expr = true,
            desc = "Rename (live preview)",
        },
    },
    opts = {},
}
