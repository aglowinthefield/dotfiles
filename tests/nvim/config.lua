local root = vim.fn.getcwd() .. "/dot_config/nvim"
vim.opt.rtp:prepend(root)
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

dofile(root .. "/lua/config/options.lua")
assert(vim.o.background == "dark")
assert(vim.o.number and vim.o.expandtab and vim.o.undofile)
assert(vim.o.tabstop == 2 and vim.o.shiftwidth == 2)
assert(vim.o.clipboard == "unnamedplus")
dofile(root .. "/lua/config/autocmds.lua")
local count = #vim.api.nvim_get_autocmds({ group = "DotfilesIndent" })
dofile(root .. "/lua/config/autocmds.lua")
assert(#vim.api.nvim_get_autocmds({ group = "DotfilesIndent" }) == count, "reload duplicates autocmds")
for _, ft in ipairs({ "cs", "swift", "typescript" }) do
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.bo.filetype = ft
  local expected = ft == "typescript" and 2 or 4
  assert(vim.bo.shiftwidth == expected, ft .. " indent")
  assert(vim.bo.tabstop == expected, ft .. " tabstop")
end
local completion = dofile(root .. "/lua/plugins/completion.lua")
assert(#completion == 1 and completion[1][1] == "saghen/blink.cmp")
assert(completion[1].opts.sources.default[1] == "lsp")
local treesitter = dofile(root .. "/lua/plugins/treesitter.lua")
assert(#treesitter == 2 and treesitter[1].lazy == false)
assert(treesitter[1].build == ":TSUpdate")
local base = dofile(root .. "/lua/plugins/init.lua")
for _, spec in ipairs(base) do
  local name = type(spec) == "table" and spec[1] or spec
  assert(not name:find("nvim%-treesitter"), "Treesitter duplicated in basic plugins")
end
print("PASS: options, reload-safe autocmds, buffer-local indentation, modular plugin specs")
