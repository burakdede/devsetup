-- LSP configuration
-- lua/plugins/lsp.lua
--
-- Stack:
--   mason.nvim          -- installs/manages LSP servers, formatters, linters
--   mason-lspconfig     -- bridges mason ↔ nvim-lspconfig
--   nvim-lspconfig      -- configures each LSP server
--   nvim-cmp            -- completion engine
--   LuaSnip             -- snippet engine (required by cmp)
--
-- Adding a new language
-- ─────────────────────
-- 1. Find the server name at https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
-- 2. Add it to `servers` below (empty table {} uses defaults).
-- 3. On next launch, mason-lspconfig auto-installs it.
-- 4. Optionally add language-specific `settings` inside `server_config()`.

return {
	-- ─── Mason: LSP / formatter / linter installer ────────────────────────────
	--
	-- NOTE the repo owner: mason moved from williamboman/ to mason-org/. The old
	-- paths still work through a GitHub redirect, but the canonical name is this.
	--
	-- NOT lazy-loaded. Upstream: "Lazy-loading the plugin, or somehow deferring
	-- the setup, is not recommended." Gating it on cmd = "Mason" also meant
	-- :MasonInstall did not exist until you had opened :Mason once.
	{
		"mason-org/mason.nvim",
		lazy = false,
		opts = {
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		},
	},

	-- ─── mason-lspconfig: auto-install + auto-enable ──────────────────────────
	--
	-- mason-lspconfig v2 enables every installed server for you (automatic_enable
	-- defaults to true), so this config only needs to declare which servers to
	-- install and any per-server settings. Do NOT also call vim.lsp.enable() in
	-- a loop here -- that is duplicated work and tries to start servers that may
	-- not be installed yet.
	{
		"mason-org/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason-org/mason.nvim",
			"neovim/nvim-lspconfig",
		},
		config = function()
			-- ── Servers ────────────────────────────────────────────────────────
			-- Keys are nvim-lspconfig server names; values are settings passed to
			-- vim.lsp.config. An empty table accepts all defaults.
			local servers = {
				-- Python
				pyright = {},
				ruff = {}, -- fast linting/formatting via ruff

				-- Go
				gopls = {
					settings = {
						gopls = {
							gofumpt = true,
							staticcheck = true,
							analyses = { unusedparams = true },
						},
					},
				},

				-- Rust (rustup provides the toolchain; rust-analyzer via mason)
				rust_analyzer = {
					settings = {
						["rust-analyzer"] = {
							-- Current schema. The old checkOnSave = { command = ... }
							-- shape was deprecated and is ignored by recent
							-- rust-analyzer releases.
							check = { command = "clippy" },
						},
					},
				},

				-- Java (jdtls requires a JDK; installed by SDKMAN via sdk.sh)
				jdtls = {},

				-- TypeScript / JavaScript
				ts_ls = {},
				eslint = {},

				-- Lua (for editing this very config)
				lua_ls = {
					settings = {
						Lua = {
							runtime = { version = "LuaJIT" },
							workspace = { checkThirdParty = false },
							telemetry = { enable = false },
							diagnostics = { globals = { "vim" } },
						},
					},
				},

				-- Shell
				bashls = {},

				-- YAML / JSON / TOML
				yamlls = {},
				jsonls = {},
				taplo = {}, -- TOML

				-- Docker
				dockerls = {},
				docker_compose_language_service = {},

				-- HTML / CSS
				html = {},
				cssls = {},

				-- Markdown
				marksman = {},

				-- ── Add more servers here ─────────────────────────────────────
				-- kotlin_language_server = {},
				-- clangd                 = {},
				-- terraformls            = {},
			}

			-- Completion capabilities for every server, applied via the '*'
			-- wildcard rather than repeated per server.
			vim.lsp.config("*", {
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
			})

			-- Per-server settings. Servers with no overrides need no call.
			for name, opts in pairs(servers) do
				if next(opts) ~= nil then
					vim.lsp.config(name, opts)
				end
			end

			require("mason-lspconfig").setup({
				ensure_installed = vim.tbl_keys(servers),
			})
		end,
	},

	-- ─── nvim-lspconfig ───────────────────────────────────────────────────────
	{
		"neovim/nvim-lspconfig",
		lazy = true,
	},

	-- ─── Completion engine ────────────────────────────────────────────────────
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp", -- LSP source
			"hrsh7th/cmp-buffer", -- buffer words
			"hrsh7th/cmp-path", -- filesystem paths
			"L3MON4D3/LuaSnip", -- snippet engine
			"saadparwaiz1/cmp_luasnip", -- snippet source
			"rafamadriz/friendly-snippets", -- community snippets
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")
			require("luasnip.loaders.from_vscode").lazy_load()

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = false }),
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()
						else
							fallback()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_prev_item()
						elseif luasnip.jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end, { "i", "s" }),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
				}, {
					{ name = "buffer" },
					{ name = "path" },
				}),
				formatting = {
					format = function(_, item)
						local icons = {
							Text = "󰉿",
							Method = "󰆧",
							Function = "󰊕",
							Constructor = "",
							Field = "󰜢",
							Variable = "󰀫",
							Class = "󰠱",
							Interface = "",
							Module = "",
							Property = "󰜢",
							Unit = "󰑭",
							Value = "󰎠",
							Enum = "",
							Keyword = "󰌋",
							Snippet = "",
							Color = "󰏘",
							File = "󰈙",
							Reference = "󰈇",
							Folder = "󰉋",
							EnumMember = "",
							Constant = "󰏿",
							Struct = "󰙅",
							Event = "",
							Operator = "󰆕",
							TypeParameter = "",
						}
						item.kind = string.format("%s %s", icons[item.kind] or "", item.kind)
						return item
					end,
				},
			})
		end,
	},

	-- ─── Treesitter: syntax highlighting & indentation ───────────────────────
	--
	-- NOTE: this is the `main` branch of nvim-treesitter, which is a full,
	-- incompatible rewrite. The old master-branch options -- ensure_installed,
	-- highlight = { enable = true }, indent = { enable = true }, auto_install --
	-- DO NOT EXIST here and are silently ignored if you write them. Parsers are
	-- installed with require("nvim-treesitter").install(), and highlighting is
	-- turned on per buffer with vim.treesitter.start().
	--
	-- Requires Neovim >= 0.12 (pinned in packages/versions.txt).
	--
	-- Adding a language: add its parser name below, restart, and it installs on
	-- next launch. `:checkhealth nvim-treesitter` lists what is installed.
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			local ts = require("nvim-treesitter")
			ts.setup()

			local parsers = {
				"bash",
				"c",
				"cmake",
				"css",
				"diff",
				"dockerfile",
				"go",
				"gomod",
				"gowork",
				"html",
				"java",
				"javascript",
				"json",
				"json5",
				"kotlin",
				"lua",
				"luadoc",
				"make",
				"markdown",
				"markdown_inline",
				"python",
				"regex",
				"ron",
				"rst",
				"rust",
				"scala",
				"sql",
				"toml",
				"tsx",
				"typescript",
				"vim",
				"vimdoc",
				"yaml",
			}

			-- install() is async and re-downloads what it is given, so only ask
			-- for what is actually missing. Keeps startup free after first run.
			local installed = ts.get_installed()
			local missing = vim.tbl_filter(function(parser)
				return not vim.tbl_contains(installed, parser)
			end, parsers)
			if #missing > 0 then
				ts.install(missing)
			end

			-- Enable per buffer. Deriving the language from the filetype rather
			-- than listing patterns means tsx/typescriptreact and friends map
			-- correctly, and a filetype with no parser is simply skipped.
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true }),
				callback = function(ev)
					local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
					if not lang then
						return
					end
					-- Fails when the parser is not installed yet; that is fine,
					-- the buffer just falls back to regex syntax.
					if not pcall(vim.treesitter.start, ev.buf, lang) then
						return
					end
					vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
				desc = "Start treesitter highlighting and indentation",
			})
		end,
	},
}
