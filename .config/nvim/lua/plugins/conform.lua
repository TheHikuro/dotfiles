return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    notify_on_error = false,

    formatters_by_ft = {
      javascript = { "oxfmt", lsp_format = "fallback" },
      typescript = { "oxfmt", lsp_format = "fallback" },
      javascriptreact = { "oxfmt", lsp_format = "fallback" },
      typescriptreact = { "oxfmt", lsp_format = "fallback" },
      json = { "oxfmt", lsp_format = "fallback" },
      lua = { "stylua" },
    },

    formatters = {
      oxfmt = {
        command = require("conform.util").from_node_modules("oxfmt"),
        args = { "$FILENAME" },
        stdin = false,
        cwd = require("conform.util").root_file({ ".oxfmtrc.json", ".oxfmtrc.jsonc" }),
      },
    },
  },
}
