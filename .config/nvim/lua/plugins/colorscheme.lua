return {
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("solarized-osaka").setup({
        styles = {
          floats = "transparent",
        },
      })
      vim.cmd([[colorscheme solarized-osaka]])
    end,
  },
  {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("colorizer").setup({
        -- Scoped to filetypes that actually contain colors. On "*" the full
        -- parser chain (css_fn/oklch/oklab/tailwind) ran per visible line on
        -- every buffer, including large JSON and log files.
        filetypes = {
          "css",
          "scss",
          "sass",
          "less",
          "html",
          "javascript",
          "typescript",
          "javascriptreact",
          "typescriptreact",
          "svelte",
          "vue",
        },
        user_default_options = {
          rgb = true,
          rrggbb = true,
          rgb_fn = true,
          hsl_fn = true,
          oklch = true,
          oklab = true,
          css = true,
          css_fn = true, -- enables css color() + modern funcs like oklch()
          names = false,
          mode = "background", -- or "virtualtext"
          tailwind = true,
          -- `always_update` nvim_buf_attach'es an on_lines handler so *background*
          -- buffers keep re-highlighting as they change. Only the visible buffer
          -- needs to be current.
          always_update = false,
        },
      })
    end,
  },
}
