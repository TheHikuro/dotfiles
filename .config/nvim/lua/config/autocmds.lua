-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- Auto-fix with oxc (oxlint) on save.
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
  callback = function(event)
    local clients = vim.lsp.get_clients({ bufnr = event.buf, name = "oxlint" })
    if #clients == 0 then
      return
    end
    vim.lsp.buf.code_action({
      context = { only = { "source.fixAll.oxc" }, diagnostics = {} },
      apply = true,
    })
  end,
})
