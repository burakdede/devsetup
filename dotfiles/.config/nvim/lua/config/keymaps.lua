-- Neovim key mappings
-- lua/config/keymaps.lua
--
-- Add your personal key bindings here.
-- Plugin-specific mappings should live inside each plugin's spec file so they
-- are only registered when the plugin is loaded.

local map = vim.keymap.set

-- ─── Leader key ───────────────────────────────────────────────────────────────
-- Set before any plugin loads (done in options.lua).
-- vim.g.mapleader      = " "    -- <Space> as leader  (set in options.lua)
-- vim.g.maplocalleader = "\\"   -- <\> as local leader

-- ─── Window navigation ────────────────────────────────────────────────────────
map("n", "<M-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<M-j>", "<C-w>j", { desc = "Move to below window" })
map("n", "<M-k>", "<C-w>k", { desc = "Move to above window" })
map("n", "<M-l>", "<C-w>l", { desc = "Move to right window" })

-- ─── Buffer navigation ────────────────────────────────────────────────────────
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>",     { desc = "Next buffer" })

-- ─── Search ───────────────────────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- ─── Indentation in visual mode ───────────────────────────────────────────────
map("v", "<", "<gv", { desc = "Decrease indent and reselect" })
map("v", ">", ">gv", { desc = "Increase indent and reselect" })

-- ─── Move lines ───────────────────────────────────────────────────────────────
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- ─── Diagnostics ──────────────────────────────────────────────────────────────
map("n", "[d", vim.diagnostic.goto_prev,  { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next,  { desc = "Next diagnostic" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic float" })

-- ─── Quick file save ──────────────────────────────────────────────────────────
map({ "n", "i", "v" }, "<C-s>", "<Esc><cmd>w<cr>", { desc = "Save file" })

-- ─── Add your own mappings below ──────────────────────────────────────────────
