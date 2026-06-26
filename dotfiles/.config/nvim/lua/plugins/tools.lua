-- Developer tools plugins
-- lua/plugins/tools.lua
--
-- File navigation, fuzzy finding, git integration, and other utilities.
-- Un-comment the sections you want.

return {
    -- ─── Tmux-aware pane navigation ───────────────────────────────────────────
    -- Use Ctrl-h/j/k/l to move seamlessly between Neovim splits and tmux panes.
    {
        "christoomey/vim-tmux-navigator",
        event = "VeryLazy",
        init = function()
            vim.g.tmux_navigator_no_mappings = 1
        end,
        keys = {
            { "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Pane left (nvim/tmux)" },
            { "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Pane down (nvim/tmux)" },
            { "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Pane up (nvim/tmux)" },
            { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Pane right (nvim/tmux)" },
        },
    },

    -- ─── Fuzzy finder (telescope) ─────────────────────────────────────────────
    {
        "nvim-telescope/telescope.nvim",
        cmd          = "Telescope",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<leader>ff", "<cmd>Telescope find_files<cr>",  desc = "Find files" },
            { "<leader>fg", "<cmd>Telescope live_grep<cr>",   desc = "Live grep" },
            { "<leader>fb", "<cmd>Telescope buffers<cr>",     desc = "Buffers" },
            { "<leader>fr", "<cmd>Telescope oldfiles<cr>",    desc = "Recent files" },
        },
    },

    -- ─── File tree ────────────────────────────────────────────────────────────
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch       = "v3.x",
        dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
        keys = {
            { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file tree" },
        },
        opts = {
            window = { width = 30 },
            filesystem = {
                follow_current_file = { enabled = true },
                hijack_netrw_behavior = "open_current",
            },
        },
    },

    -- ─── Git ──────────────────────────────────────────────────────────────────
    {
        "lewis6991/gitsigns.nvim",
        event = "BufReadPre",
        opts  = {},
    },

    -- ─── Which-key ────────────────────────────────────────────────────────────
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts  = {},
    },

    -- ─── Auto-pairs ───────────────────────────────────────────────────────────
    -- {
    --     "windwp/nvim-autopairs",
    --     event = "InsertEnter",
    --     opts  = {},
    -- },

    -- ─── Comment ──────────────────────────────────────────────────────────────
    -- {
    --     "numToStr/Comment.nvim",
    --     keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
    --     opts = {},
    -- },
}
