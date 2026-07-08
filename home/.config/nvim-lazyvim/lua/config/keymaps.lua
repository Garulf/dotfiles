-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here


vim.keymap.set('n', '<tab>', '<cmd>bnext<cr>')
vim.keymap.set('n', '<s-tab>', '<cmd>bprevious<cr>')

vim.keymap.set('n', '<leader>e', function()
  require('neo-tree.command').execute({ action = 'focus', dir = LazyVim.root() })
end, { desc = 'Focus Explorer NeoTree' })
vim.keymap.set('n', '<leader>E', function()
  require('neo-tree.command').execute({ toggle = true, dir = LazyVim.root() })
end, { desc = 'Toggle Explorer NeoTree' })
