-- Run with the applied configuration:
-- nvim --headless '+luafile tests/nvim/live.lua'
local ok, err = xpcall(function()
  assert(vim.g.colors_name == "horizon" and vim.o.background == "dark")
  assert(vim.g.mapleader == ",")
  local lazy = require("lazy")
  local plugins = require("lazy.core.config").plugins
  assert(plugins["blink.cmp"] and not plugins["nvim-cmp"])
  lazy.load({ plugins = { "blink.cmp", "conform.nvim", "neotest", "tsc.nvim", "nvim-dap" } })
  assert(require("blink.cmp").get_lsp_capabilities().textDocument.completion.completionItem.snippetSupport)
  assert(require("conform").get_formatter_config("stylua"))
  assert(require("neotest") and require("tsc") and require("dap"))

  local state = vim.fn.tempname()
  vim.fn.mkdir(state, "p")
  local filename = state .. "/format.lua"
  vim.fn.writefile({ "local x={hello='world'}" }, filename)
  vim.cmd.edit(vim.fn.fnameescape(filename))
  assert(vim.bo.filetype == "lua")
  assert(vim.wo.number and vim.bo.shiftwidth == 2)
  assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "Lua highlighting not active")
  assert(require("conform").get_formatter_info("stylua", 0).available, "StyLua unavailable")
  vim.cmd("silent write")
  assert(vim.deep_equal(vim.fn.readfile(filename), { 'local x = { hello = "world" }' }), "save did not format Lua")
  vim.cmd.bdelete()
  vim.fn.delete(state, "rf")

  for _, tool in ipairs(require("config.runtime").tools()) do
    assert(not tool.required or tool.available, "Missing required tool: " .. tool.name)
  end
  assert(require("dotfiles.health").check)
  print("PASS: live startup, plugin APIs, highlighting, Lua save formatting, tools")
end, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd.cquit(1)
end
vim.cmd.qa()
