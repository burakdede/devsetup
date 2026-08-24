# Neovim

[← back to README](../README.md)

## Neovim

Plugins are managed by lazy.nvim and pinned in
`dotfiles/.config/nvim/lazy-lock.json`. Update with `:Lazy update`, then commit
the lock file so both machines move together.

### treesitter is on the `main` branch

This matters, because `main` is a **full, incompatible rewrite** of
nvim-treesitter and most guidance you will find online is for `master`. On
`main`:

- `ensure_installed`, `highlight = { enable = true }`, `indent`, and
  `auto_install` **do not exist**. Writing them is silently ignored, which
  leaves you with Vim's regex syntax and no treesitter at all.
- Parsers are installed with `require("nvim-treesitter").install{...}`.
- Highlighting is turned on per buffer with `vim.treesitter.start()`, which the
  config does from a `FileType` autocommand.
- It needs **Neovim >= 0.12** and the **`tree-sitter` CLI >= 0.26.1**, which
  master never required. Upstream is explicit that it must come from a package
  manager and **not npm**, so it is `tree-sitter-cli` in the Brewfile on macOS
  and a release binary via `github-tools.txt` on Ubuntu.

### Language servers come from Mason

Mason is a package manager for LSP servers that lives inside Neovim. It exists
here for one reason: it is the only place macOS and Ubuntu converge for free.
Installing servers natively would mean four mechanisms for four servers
(`brew`, `go install`, `npm -g`, `rustup component`), each different per OS.
Mason turns that into one list that resolves identically on both machines.

The tradeoff is a second package manager alongside brew/apt/mise, and servers
that only exist inside Neovim. That is the right trade for this setup, but it
is a real one.

### Everyday Neovim workflows

| Task | How |
|---|---|
| Add a language server | Add the lspconfig name to `servers` in `lua/plugins/lsp.lua`, restart. Mason installs it |
| Add a treesitter parser | Add the parser name to `parsers` in the same file, restart |
| Update plugins | `:Lazy update`, then commit `lazy-lock.json` so both machines match |
| Update parsers | `:TSUpdate` |
| See what is installed | `:Mason`, `:checkhealth nvim-treesitter`, `:checkhealth vim.lsp` |
| Diagnose a slow start | `nvim --startuptime /tmp/st && sort -k2 -rn /tmp/st \| head` |

Plugin versions are pinned in `lazy-lock.json`. Commit it after any `:Lazy
update`; that file is what keeps the two machines on identical plugin versions.
