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
    {
        "williamboman/mason.nvim",
        cmd  = "Mason",
        opts = {
            ui = {
                icons = {
                    package_installed   = "✓",
                    package_pending     = "➜",
                    package_uninstalled = "✗",
                },
            },
        },
    },

    -- ─── mason-lspconfig: auto-install + auto-setup ───────────────────────────
    {
        "williamboman/mason-lspconfig.nvim",
        event        = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "williamboman/mason.nvim",
            "neovim/nvim-lspconfig",
        },
        config = function()
            -- ── Servers ────────────────────────────────────────────────────────
            -- Keys are nvim-lspconfig server names; values override default opts.
            -- Use an empty table {} to accept all defaults for that server.
            local servers = {
                -- Python
                pyright        = {},
                ruff           = {},      -- fast linting/formatting via ruff

                -- Go
                gopls          = {
                    settings = {
                        gopls = {
                            gofumpt        = true,
                            staticcheck    = true,
                            analyses       = { unusedparams = true },
                        },
                    },
                },

                -- Rust (rustup must be installed; rust-analyzer is managed by mason)
                rust_analyzer  = {
                    settings = {
                        ["rust-analyzer"] = {
                            checkOnSave = { command = "clippy" },
                        },
                    },
                },

                -- Java (jdtls requires a JDK; installed by SDKMAN via sdk.sh)
                jdtls          = {},

                -- TypeScript / JavaScript
                ts_ls          = {},
                eslint         = {},

                -- Lua (for editing this very config)
                lua_ls         = {
                    settings = {
                        Lua = {
                            runtime     = { version = "LuaJIT" },
                            workspace   = { checkThirdParty = false },
                            telemetry   = { enable = false },
                            diagnostics = { globals = { "vim" } },
                        },
                    },
                },

                -- Shell
                bashls         = {},

                -- YAML / JSON / TOML
                yamlls         = {},
                jsonls         = {},
                taplo          = {},      -- TOML

                -- Docker
                dockerls       = {},
                docker_compose_language_service = {},

                -- HTML / CSS
                html           = {},
                cssls          = {},

                -- Markdown
                marksman       = {},

                -- ── Add more servers here ─────────────────────────────────────
                -- kotlin_language_server = {},
                -- scala_language_server  = {},
                -- clangd                 = {},
                -- cmake                  = {},
                -- terraformls            = {},
            }

            -- ── Mason ensure-install ───────────────────────────────────────────
            require("mason-lspconfig").setup({
                ensure_installed = vim.tbl_keys(servers),
            })

            -- ── Shared on_attach ───────────────────────────────────────────────
            local function on_attach(_, bufnr)
                local map = function(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
                end

                -- Navigation
                map("n", "gd",         vim.lsp.buf.definition,       "Go to definition")
                map("n", "gD",         vim.lsp.buf.declaration,       "Go to declaration")
                map("n", "gi",         vim.lsp.buf.implementation,    "Go to implementation")
                map("n", "gr",         vim.lsp.buf.references,        "List references")
                map("n", "gy",         vim.lsp.buf.type_definition,   "Go to type definition")

                -- Hover / signature
                -- <C-k> is reserved for vim-tmux-navigator (TmuxNavigateUp) -- do NOT
                -- bind it in normal mode here or pane navigation breaks when LSP is active.
                -- Signature help is available in insert mode or via :lua vim.lsp.buf.signature_help()
                map("n", "K",          vim.lsp.buf.hover,             "Hover docs")
                map("i", "<C-k>",      vim.lsp.buf.signature_help,    "Signature help")

                -- Actions
                map("n", "<leader>rn", vim.lsp.buf.rename,            "Rename symbol")
                map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
                map("n", "<leader>f",  function()
                    vim.lsp.buf.format({ async = true })
                end, "Format file")

                -- Workspace
                map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder,    "Add workspace folder")
                map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
                map("n", "<leader>wl", function()
                    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                end, "List workspace folders")
            end

            -- ── Capabilities (extended by nvim-cmp) ───────────────────────────
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

            -- ── Setup each server (nvim 0.11+ vim.lsp.config API) ────────────
            for server_name, server_opts in pairs(servers) do
                local opts = vim.tbl_deep_extend("force", {
                    on_attach    = on_attach,
                    capabilities = capabilities,
                }, server_opts or {})
                vim.lsp.config(server_name, opts)
                vim.lsp.enable(server_name)
            end
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
        event        = "InsertEnter",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",       -- LSP source
            "hrsh7th/cmp-buffer",          -- buffer words
            "hrsh7th/cmp-path",            -- filesystem paths
            "L3MON4D3/LuaSnip",            -- snippet engine
            "saadparwaiz1/cmp_luasnip",    -- snippet source
            "rafamadriz/friendly-snippets", -- community snippets
        },
        config = function()
            local cmp     = require("cmp")
            local luasnip = require("luasnip")
            require("luasnip.loaders.from_vscode").lazy_load()

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"]     = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<C-e>"]     = cmp.mapping.abort(),
                    ["<CR>"]      = cmp.mapping.confirm({ select = false }),
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
                            Text          = "󰉿", Method      = "󰆧", Function = "󰊕",
                            Constructor   = "", Field       = "󰜢", Variable = "󰀫",
                            Class         = "󰠱", Interface   = "", Module   = "",
                            Property      = "󰜢", Unit        = "󰑭", Value    = "󰎠",
                            Enum          = "", Keyword     = "󰌋", Snippet  = "",
                            Color         = "󰏘", File        = "󰈙", Reference= "󰈇",
                            Folder        = "󰉋", EnumMember  = "", Constant = "󰏿",
                            Struct        = "󰙅", Event       = "", Operator = "󰆕",
                            TypeParameter = "",
                        }
                        item.kind = string.format("%s %s", icons[item.kind] or "", item.kind)
                        return item
                    end,
                },
            })
        end,
    },

    -- ─── Treesitter: syntax highlighting & text-objects ───────────────────────
    {
        "nvim-treesitter/nvim-treesitter",
        build  = ":TSUpdate",
        lazy   = false,
        opts   = {
            ensure_installed = {
                "bash", "c", "cmake", "css", "diff",
                "dockerfile", "go", "gomod", "gowork",
                "html", "java", "javascript", "json", "json5",
                "kotlin", "lua", "luadoc", "make",
                "markdown", "markdown_inline",
                "python", "regex", "ron", "rst",
                "rust", "scala", "sql",
                "toml", "tsx", "typescript",
                "vim", "vimdoc", "yaml",
            },
            auto_install = true,
            highlight    = { enable = true },
            indent       = { enable = true },
        },
    },

    -- ─── Inline diagnostics (optional; un-comment to enable) ─────────────────
    -- {
    --     "folke/trouble.nvim",
    --     dependencies = { "nvim-tree/nvim-web-devicons" },
    --     cmd  = { "Trouble", "TroubleToggle" },
    --     keys = {
    --         { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
    --     },
    --     opts = {},
    -- },
}
