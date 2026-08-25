-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- The single TypeScript language server is `tsc` — TypeScript 7's built-in LSP
-- (`tsc --lsp`), the released form of the old `tsgo` native preview. It is not
-- selected through `vim.g.lazyvim_ts_lsp`, whose only valid values are "vtsls"
-- and the deprecated "tsgo"; `plugins/lsp.lua` turns LazyVim's pick off and
-- enables `tsc` itself.
-- Linting/fixes are handled by oxc (oxlint); vtsls/biome/eslint are disabled.
