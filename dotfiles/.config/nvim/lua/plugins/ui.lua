-- UI plugins
-- lua/plugins/ui.lua
--
-- Colour scheme, status line, and visual enhancements.
-- Un-comment the sections you want; they are all lazy-loaded.

return {
    -- ─── Colour scheme ────────────────────────────────────────────────────────
    -- Pick one and un-comment it. More schemes: https://dotfyle.com/neovim/colorscheme
    --
    {
        "catppuccin/nvim",
        name     = "catppuccin",
        lazy     = false,
        priority = 1000,
        config   = function() vim.cmd.colorscheme("catppuccin-mocha") end,
    },
    -- {
    --     "folke/tokyonight.nvim",
    --     priority = 1000,
    --     config   = function() vim.cmd.colorscheme("tokyonight-night") end,
    -- },
    -- {
    --     "rose-pine/neovim",
    --     name     = "rose-pine",
    --     priority = 1000,
    --     config   = function() vim.cmd.colorscheme("rose-pine") end,
    -- },

    -- ─── Status line ──────────────────────────────────────────────────────────
    {
        "nvim-lualine/lualine.nvim",
        event        = "VeryLazy",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts         = { theme = "auto" },
    },

    -- ─── Icons ────────────────────────────────────────────────────────────────
    -- {
    --     "nvim-tree/nvim-web-devicons",
    --     lazy = true,
    -- },

    -- ─── Indent guides ────────────────────────────────────────────────────────
    -- {
    --     "lukas-reineke/indent-blankline.nvim",
    --     event = "BufReadPre",
    --     main  = "ibl",
    --     opts  = {},
    -- },
}
