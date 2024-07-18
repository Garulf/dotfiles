-- set catppuccin colors for lualine
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        globalstatus = vim.o.laststatus == 3,
        disabled_filetypes = { statusline = { "dashboard", "alpha", "ministarter" } },
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      }
    }
  }
}
