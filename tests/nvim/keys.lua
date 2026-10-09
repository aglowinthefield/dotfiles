-- Run from the chezmoi source: nvim --headless -u NONE -i NONE -l tests/nvim/keys.lua
vim.g.mapleader = ","
vim.o.hidden = false
dofile("dot_config/nvim/lua/config/keys.lua")
dofile("dot_config/nvim/lua/config/keys.lua")

for key, command in pairs({ q = "q", w = "w", x = "x" }) do
  local mapping = vim.fn.maparg("," .. key, "n", false, true)
  assert(mapping.rhs:lower() == "<cmd>" .. command .. "<cr>")
  assert(not mapping.nowait or mapping.nowait == 0, "Keep longer diagnostics mappings reachable")
end
local commands = vim.api.nvim_get_commands({ builtin = false })
assert(commands.Q.definition == "quit<bang>" and commands.Q.bang)
assert(commands.X.definition == "xit<bang>" and commands.X.bang)

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local function open_file(name)
  vim.cmd.vnew()
  local file = root .. "/" .. name
  vim.api.nvim_buf_set_name(0, file)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "saved text" })
  return file
end
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

local file = open_file("write.txt")
press(",w")
assert(vim.deep_equal(vim.fn.readfile(file), { "saved text" }))
assert(not vim.bo.modified)
local windows = #vim.api.nvim_list_wins()
press(",q")
assert(#vim.api.nvim_list_wins() == windows - 1)

file = open_file("quit.txt")
local ok, err = pcall(vim.cmd, "Q")
assert(not ok and tostring(err):find("E37"), ":Q must not discard unsaved changes: " .. tostring(err))
vim.cmd("Q!")
assert(vim.fn.filereadable(file) == 0, ":Q! must not write")

for index, command in ipairs({ "X", "X!", ",x" }) do
  file = open_file("exit-" .. index .. ".txt")
  windows = #vim.api.nvim_list_wins()
  if command == ",x" then
    press(command)
  else
    vim.cmd(command)
  end
  assert(#vim.api.nvim_list_wins() == windows - 1)
  assert(vim.deep_equal(vim.fn.readfile(file), { "saved text" }))
end
vim.fn.delete(root, "rf")
print("PASS: leader q/w/x, Q/X aliases and bang forms, unsaved-change protection, reload")
vim.cmd.qa()
