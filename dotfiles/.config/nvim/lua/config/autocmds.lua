-- Neovim autocommands
-- lua/config/autocmds.lua
--
-- Add your personal autocommands here.

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ─── Highlight on yank ────────────────────────────────────────────────────────
augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
    group    = "YankHighlight",
    callback = function()
        vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
    end,
    desc = "Flash yanked region",
})

-- ─── Restore cursor position ──────────────────────────────────────────────────
augroup("RestoreCursor", { clear = true })
autocmd("BufReadPost", {
    group    = "RestoreCursor",
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
    desc = "Restore cursor to last position",
})

-- ─── Auto-resize splits ───────────────────────────────────────────────────────
augroup("ResizeSplits", { clear = true })
autocmd("VimResized", {
    group    = "ResizeSplits",
    command  = "tabdo wincmd =",
    desc     = "Equalise splits on terminal resize",
})

-- ─── Strip trailing whitespace ────────────────────────────────────────────────
-- Uncomment if you want automatic stripping on save.
--
-- augroup("StripTrailing", { clear = true })
-- autocmd("BufWritePre", {
--     group    = "StripTrailing",
--     pattern  = "*",
--     command  = [[%s/\s\+$//e]],
--     desc     = "Remove trailing whitespace on save",
-- })

-- ─── Add your own autocommands below ─────────────────────────────────────────
