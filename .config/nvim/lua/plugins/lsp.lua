-- Latency-oriented LSP tuning. See also `plugins/tsgo.lua` for tsgo's
-- code-action keymaps and `config/options.lua` for the server selection.
return {
  "neovim/nvim-lspconfig",
  opts = {
    -- Every `textDocument/didChange` otherwise triggers a `textDocument/inlayHint`
    -- refresh for the visible range, on top of diagnostics. The per-server
    -- `inlayHints` settings from the tsgo extra stay in place but no longer
    -- render; `<leader>uh` toggles them back on per buffer.
    inlay_hints = { enabled = false },

    servers = {
      tsgo = {
        -- Collapse tsgo to one client per git repository. LazyVim's default
        -- markers are { "tsconfig.json", "package.json", "jsconfig.json" }, so
        -- a monorepo otherwise spawns one tsgo process per package.
        --
        -- Must be `root_markers`, NOT a `root_dir` function: a `root_dir` that
        -- calls `on_dir()` synchronously resolves the root and spawns the client
        -- before `mason-lspconfig.setup()` has rewritten `cmd` to the mason
        -- binary, so the client tries to exec lspconfig's bare default (`tsc`,
        -- since lspconfig deprecated the `tsgo` name in favour of `tsc`) and
        -- dies with "not installed, missing from PATH, or not executable".
        -- Native root-marker detection is deferred and doesn't race.
        root_markers = { ".git" },
      },
    },
  },
}
