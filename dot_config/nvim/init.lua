require("config.lazy")

local o = vim.opt

vim.cmd("colorscheme kanagawa-paper")
vim.cmd("set number")

-- 2 spaces always (for now)
o.tabstop = 2
o.softtabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.autoindent = true
o.smartindent = true

-- Always show gutter and cursor line
o.cursorline = true
o.signcolumn = 'yes'

-- Clipboard stuff
o.clipboard = "unnamedplus"
o.mouse = "a"

-- Split mgmt
o.splitright = true -- Always open a new vsplit to the right
o.splitbelow = true -- Always open a new split below

-- Undo
o.undofile = true -- Preserve undo history between sessions

-- Search
o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = false

-- GUI
o.termguicolors = true
