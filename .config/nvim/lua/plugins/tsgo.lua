-- Re-add the TypeScript code-action keymaps that were lost when switching
-- from vtsls to tsgo (`vim.g.lazyvim_ts_lsp = "tsgo"`). These are attached to
-- the tsgo LSP server. Note: tsgo (@typescript/native-preview) is still a
-- preview and may not implement every code action yet; if `<leader>cM` does
-- nothing, tsgo simply doesn't support that action on your version.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tsgo = {
          keys = {
            {
              "<leader>cM",
              LazyVim.lsp.action["source.addMissingImports.ts"],
              desc = "Add missing imports",
            },
            {
              "<leader>cu",
              LazyVim.lsp.action["source.removeUnused.ts"],
              desc = "Remove unused imports",
            },
            {
              "<leader>co",
              LazyVim.lsp.action["source.organizeImports"],
              desc = "Organize imports",
            },
          },
        },
      },
    },
  },
}
