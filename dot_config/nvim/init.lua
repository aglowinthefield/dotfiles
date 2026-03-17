if vim.fn.has("win32") == 1 then
  vim.o.shell = "pwsh"
  vim.o.shellcmdflag = "-NoLogo -Command"
  vim.o.shellquote = ""
  vim.o.shellxquote = ""
end

require("config.lazy")

local o = vim.opt

vim.cmd("colorscheme kanagawa-paper")
vim.cmd("set number")

o.tabstop = 2
o.softtabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.autoindent = true
o.smartindent = true

o.cursorline = true
o.signcolumn = 'yes'

o.clipboard = "unnamedplus"
o.mouse = "a"

o.splitright = true
o.splitbelow = true

o.undofile = true

o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = false

o.termguicolors = true

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "cs", "swift" },
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
    vim.bo.shiftwidth = 4
  end,
})
