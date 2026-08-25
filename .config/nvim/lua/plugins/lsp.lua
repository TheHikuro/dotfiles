-- Latency-oriented LSP tuning. See also `plugins/tsc.lua` for tsc's
-- code-action keymaps and `config/options.lua` for the server selection.
return {
  "neovim/nvim-lspconfig",
  opts = {
    -- Every `textDocument/didChange` otherwise triggers a `textDocument/inlayHint`
    -- refresh for the visible range, on top of diagnostics. The per-server
    -- `inlayHints` settings on `tsc` below stay in place but no longer
    -- render; `<leader>uh` toggles them back on per buffer.
    inlay_hints = { enabled = false },

    servers = {
      -- LazyVim's `lang.typescript` extra picks a TS server from
      -- `vim.g.lazyvim_ts_lsp`, whose only options are "vtsls" and the
      -- deprecated "tsgo" — so let it fall back to vtsls, switch that off, and
      -- enable `tsc` below instead. LazyVim disables tsserver/ts_ls/tsgo by
      -- itself as soon as they are not the chosen one.
      vtsls = { enabled = false },

      -- `tsc` is the TypeScript 7 compiler's built-in language server, i.e. the
      -- released form of the `tsgo` native preview. Mason deprecated the `tsgo`
      -- package (@typescript/native-preview) on 2026-08-13 in favour of `tsc`
      -- (npm typescript@7), and lspconfig's `tsgo` config is now an alias of
      -- `tsc` that is scheduled for removal in nvim-lspconfig 3.0.0.
      tsc = {
        -- lspconfig's defaults omit these two; LazyVim's extras list them so
        -- that related extras (vue, …) can extend the list.
        filetypes = {
          "javascript",
          "javascriptreact",
          "javascript.jsx",
          "typescript",
          "typescriptreact",
          "typescript.tsx",
        },
        -- No root override here, unlike the old `tsgo` entry that pinned
        -- `root_markers = { ".git" }` to avoid one client per monorepo package:
        -- lspconfig's `tsc` already resolves the root from the nearest
        -- package-manager lockfile (falling back to `.git`), and a single `tsc`
        -- process serves every tsconfig under it.
        --
        -- That `root_dir` function is also what probes for a `--lsp`-capable
        -- binary (TypeScript >= 7, so a project-local TS 5 in `node_modules/.bin`
        -- is skipped in favour of mason's `tsc` on `$PATH`) and caches it for
        -- `cmd`; replacing it would leave `cmd` exec'ing a bare `tsc`. And
        -- `root_markers` is no way around that either — see `:h lsp-root_markers`,
        -- it is ignored whenever `root_dir` is set.
        settings = {
          -- The server reads the `js/ts`, `typescript`, `javascript` and
          -- `editor` configuration sections. lspconfig's defaults fill in
          -- `js/ts`; this is LazyVim's tighter inlay-hint set, kept from the
          -- `lang.typescript.tsgo` extra we no longer import.
          typescript = {
            inlayHints = {
              enumMemberValues = { enabled = true },
              functionLikeReturnTypes = { enabled = false },
              parameterNames = {
                enabled = "literals",
                suppressWhenArgumentMatchesName = true,
              },
              parameterTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              variableTypes = { enabled = false },
            },
          },
        },
      },

      oxlint = {
        settings = {
          -- Shrink tsgolint's footprint in the editing loop.
          --
          -- A project whose oxlint config enables type-aware linting (ours sets
          -- both `typeAware` and `typeCheck`) makes the oxlint LSP spawn
          -- tsgolint, which builds its own type-checked TS program on top of
          -- tsc's ~1.5GB. With `typeCheck` it is largely re-deriving type
          -- errors tsc already reports.
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
