local module_path = os.getenv("AUTO_UPDATE_MODULE") or (vim.fn.getcwd() .. "/dot_config/nvim/lua/config/auto-update.lua")
local state = vim.fn.tempname()
vim.fn.mkdir(state, "p")
local original_stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind) return kind == "state" and state or original_stdpath(kind) end
local original_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function() return { {} } end
local calls = 0
package.loaded.lazy = { update = function(opts)
  assert(opts.show == false and opts.wait == false)
  calls = calls + 1
end }
local function fresh() return dofile(module_path) end
local function startup()
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
  vim.wait(100, function() return false end, 10)
end
local function clear_stamp() vim.fn.delete(state .. "/lazy-auto-update") end
local function setup() fresh().setup() end
setup()
startup()
assert(calls == 1, "first interactive startup updates")
setup()
startup()
assert(calls == 1, "second startup within 24h skips")
local old = os.time() - 86401
assert(vim.uv.fs_utime(state .. "/lazy-auto-update", old, old))
setup()
startup()
assert(calls == 2, "updates again after 24h")
clear_stamp()
vim.api.nvim_list_uis = function() return {} end
setup()
startup()
assert(calls == 2, "headless skips")
vim.api.nvim_list_uis = function() return { {} } end
for _, ft in ipairs({ "gitcommit", "gitrebase" }) do
  vim.bo.filetype = ft
  setup()
  startup()
  assert(calls == 2, ft .. " skips")
end
vim.bo.filetype = ""
setup()
vim.api.nvim_exec_autocmds("StdinReadPre", {})
startup()
assert(calls == 2, "stdin skips")
setup()
startup()
assert(calls == 3, "skipped launches do not consume daily update")
clear_stamp()
local notifications = 0
vim.notify = function() notifications = notifications + 1 end
package.loaded.lazy.update = function() error("simulated update failure") end
setup()
startup()
assert(notifications == 1, "update errors are reported without crashing")
setup()
startup()
assert(notifications == 1, "failed attempts are also throttled")
vim.fn.delete(state, "rf")
vim.api.nvim_list_uis = original_uis
print("PASS: first launch, throttle, expiry, headless, gitcommit, gitrebase, stdin, skip eligibility, error handling, failure throttle")
