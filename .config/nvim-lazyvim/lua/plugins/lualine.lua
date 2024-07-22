-- set catppuccin colors for lualine
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        icons_enabled = false,
        globalstatus = vim.o.laststatus == 3,
        disabled_filetypes = { statusline = { "dashboard", "alpha", "ministarter" } },
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
        refresh = {
          statusline = 1000,
          tabline = 1000,
          winbar = 1000
        },
      }
    }
  }
}
