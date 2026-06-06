-- modules/neovim/init.lua

-- Example: Standard muted, clean UI settings
vim.opt.number = true          -- Show line numbers
vim.opt.relativenumber = true  -- Relative line numbers
vim.opt.termguicolors = true   -- True color support
vim.opt.wrap = false           -- Don't wrap long lines

-- Set leader key to space
vim.g.mapleader = " "

-- A simple keymap example
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save File" })
