-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = ","
vim.g.maplocalleader = "\\"

-- Register startup hooks before lazy.nvim emits VeryLazy.
require("config.auto-update").setup()

-- lazy.nvim defaults GIT_SSH_COMMAND to a bare `ssh`, which overrides git's
-- core.sshCommand. Git for Windows resolves that to its bundled ssh, which can't
-- reach the agent's named pipe, so every clone fails with "Permission denied
-- (publickey)". Point it at the Windows ssh on PATH instead; lazy keeps an
-- existing value. Forward slashes because git runs the command through sh.
if vim.fn.has("win32") == 1 and not vim.env.GIT_SSH_COMMAND then
  vim.env.GIT_SSH_COMMAND = vim.fn.exepath("ssh"):gsub("\\", "/") .. " -oBatchMode=yes"
end

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- import your plugins
    { import = "plugins" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "compline" } },
  -- Daily startup updates handle fetching; avoid a second periodic checker.
  checker = { enabled = false },
  change_detection = {
    enabled = true,
    notify = false
  }
})
