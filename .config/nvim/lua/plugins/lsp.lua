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

      oxlint = {
        settings = {
          -- Shrink tsgolint's footprint in the editing loop.
          --
          -- A project whose oxlint config enables type-aware linting (ours sets
          -- both `typeAware` and `typeCheck`) makes the oxlint LSP spawn
          -- tsgolint, which builds its own type-checked TS program on top of
          -- tsgo's ~1.5GB. With `typeCheck` it is largely re-deriving type
          -- errors tsgo already reports.
          --
          -- MEASURED on vertuo-front (2597 TS files), peak RSS of the tsgolint
          -- processes belonging to one nvim, sampled while opening a buffer:
          --   without this setting : 2270 / 2044 MB
          --   with this setting    : 1312 / 1275 / 1284 MB
          -- So this saves ~870MB per nvim instance but does NOT eliminate
          -- tsgolint: oxlint still reads typeAware/typeCheck from the project's
          -- own oxlint.config.ts. The docs' claim that editor settings take
          -- precedence over project config holds only partially on this path.
          -- Fully removing tsgolint needs `typeCheck: true` dropped from the
          -- shared oxlint.config.ts, which is a team/CI decision.
          --
          -- `--threads` is not an alternative: tsgolint shares one type checker
          -- across workers, so capping it 10 -> 2 only moved peak 4.2GB -> 3.8GB.
          typeAware = false,
        },
      },
    },
  },
}
