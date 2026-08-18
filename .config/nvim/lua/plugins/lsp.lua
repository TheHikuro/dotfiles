-- Latency-oriented LSP tuning. See also `plugins/tsgo.lua` for tsgo's
-- code-action keymaps and `config/options.lua` for the server selection.
return {
  "neovim/nvim-lspconfig",
  opts = {
    -- Every `textDocument/didChange` otherwise triggers a `textDocument/inlayHint`
    -- refresh for the visible range, on top of diagnostics. The per-server
    -- `inlayHints` settings from the tsgo extra stay in place but no longer
    -- render; flip this back to `true` (or `<leader>uh`) to get them back.
    inlay_hints = { enabled = false },

    servers = {
      tsgo = {
        -- Collapse the language server to one client per git repository.
        --
        -- LazyVim's default root markers for tsgo are
        -- { "tsconfig.json", "package.json", "jsconfig.json" }, so a monorepo
        -- spawns one tsgo process per package. Pinning to `.git` gives a single
        -- client instead.
        --
        -- TRADE-OFF: one client loads the whole repo's TS program, so in a very
        -- large monorepo this can cost more memory than it saves in CPU. Check
        -- `:checkhealth vim.lsp` for the client count with and without it, and
        -- delete this block if the per-package split was better for you.
        ---@param on_dir fun(root_dir?: string)
        root_dir = function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, { ".git" })
          if root then
            on_dir(root)
          end
        end,
        single_file_support = false,
      },
    },
  },
}
