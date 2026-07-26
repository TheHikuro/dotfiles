-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Use the fast Go-based `tsgo` LSP as the single TypeScript language server.
-- Linting/fixes are handled by oxc (oxlint); vtsls/biome/eslint are disabled.
vim.g.lazyvim_ts_lsp = "tsgo"
