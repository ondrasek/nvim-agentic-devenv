return {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {
        -- Default mappings: sa (add), sd (delete), sr (replace), sf (find), sF (find left), sh (highlight)
        -- Examples: saiw) wraps word in (), sd" deletes surrounding ", sr"' changes " to '
        mappings = {
            add = "gsa",
            delete = "gsd",
            replace = "gsr",
            find = "gsf",
            find_left = "gsF",
            highlight = "gsh",
            update_n_lines = "gsn",
        },
    },
}
