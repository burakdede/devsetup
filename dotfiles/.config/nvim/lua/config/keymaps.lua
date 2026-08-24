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
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- ─── Search ───────────────────────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- ─── Indentation in visual mode ───────────────────────────────────────────────
map("v", "<", "<gv", { desc = "Decrease indent and reselect" })
map("v", ">", ">gv", { desc = "Increase indent and reselect" })

-- ─── Move lines ───────────────────────────────────────────────────────────────
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- ─── Diagnostics ──────────────────────────────────────────────────────────────
-- vim.diagnostic.goto_prev/goto_next were deprecated in Neovim 0.11 in favour
-- of vim.diagnostic.jump.
map("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
map("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic float" })

-- ─── Quick file save ──────────────────────────────────────────────────────────
map({ "n", "i", "v" }, "<C-s>", "<Esc><cmd>w<cr>", { desc = "Save file" })

-- ─── LSP mappings ─────────────────────────────────────────────────────────────
-- Registered on LspAttach rather than passed as a per-server on_attach, so they
-- apply to every server without repeating them in the server table, and so they
-- are buffer-local to buffers that actually have a language server.
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
	callback = function(ev)
		local function lmap(mode, lhs, rhs, desc)
			map(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
		end

		-- Navigation
		lmap("n", "gd", vim.lsp.buf.definition, "Go to definition")
		lmap("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
		lmap("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
		lmap("n", "gr", vim.lsp.buf.references, "List references")
		lmap("n", "gy", vim.lsp.buf.type_definition, "Go to type definition")

		-- Hover / signature.
		-- <C-k> in NORMAL mode is reserved for vim-tmux-navigator (pane up);
		-- binding it here would break pane navigation in any buffer with an LSP.
		lmap("n", "K", vim.lsp.buf.hover, "Hover docs")
		lmap("i", "<C-k>", vim.lsp.buf.signature_help, "Signature help")

		-- Actions
		lmap("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
		lmap({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
		lmap("n", "<leader>f", function()
			vim.lsp.buf.format({ async = true })
		end, "Format buffer")

		-- Workspace
		lmap("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
		lmap("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
		lmap("n", "<leader>wl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, "List workspace folders")
	end,
	desc = "Buffer-local LSP mappings",
})

-- ─── Add your own mappings below ──────────────────────────────────────────────
