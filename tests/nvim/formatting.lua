-- Run from the chezmoi source root: nvim --headless -u NONE -l tests/nvim/formatting.lua
local source = vim.fn.getcwd() .. "/dot_config/nvim"
package.path = source .. "/lua/?.lua;" .. source .. "/lua/?/init.lua;" .. package.path
local scratch = assert(vim.env.TMPDIR, "Set TMPDIR to a scratch directory")
local root = vim.fn.tempname()
assert(root:sub(1, #scratch) == scratch, "Fixtures must stay in TMPDIR")
vim.fn.mkdir(root, "p")
-- Treat the fixture root as the filesystem root so an unrelated config in
-- the user's home directory cannot change the no-config assertions.
local dirname = vim.fs.dirname
vim.fs.dirname = function(path)
  return path == root and root or dirname(path)
end
local checks = 0
local function equal(actual, expected, label)
  assert(vim.deep_equal(actual, expected), label .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
  checks = checks + 1
end
local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  assert(vim.fn.writefile(vim.split(text or "", "\n", { plain = true }), path) == 0)
end
local function project(name)
  local dir = root .. "/" .. name
  vim.fn.mkdir(dir .. "/src/deep", "p")
  return dir, dir .. "/src/deep"
end
local function run()
  local formatting = require("config.formatting")
  -- Keep this list independent of the implementation, aligned with upstream.
  local names = {
    ".prettierrc", ".prettierrc.json", ".prettierrc.yml", ".prettierrc.yaml", ".prettierrc.json5",
    ".prettierrc.js", "prettier.config.js", ".prettierrc.ts", "prettier.config.ts",
    ".prettierrc.mjs", "prettier.config.mjs", ".prettierrc.mts", "prettier.config.mts",
    ".prettierrc.cjs", "prettier.config.cjs", ".prettierrc.cts", "prettier.config.cts", ".prettierrc.toml",
  }
  for i, name in ipairs(names) do
    local dir, leaf = project("name-" .. i)
    write(dir .. "/" .. name, "{}")
    equal(formatting.find_prettier_config(leaf), dir .. "/" .. name, "discover " .. name)
  end
  local dir, leaf = project("nearest")
  write(dir .. "/.prettierrc", "{}")
  write(dir .. "/src/prettier.config.mts", "export default {}")
  equal(formatting.find_prettier_config(leaf), dir .. "/src/prettier.config.mts", "nearest directory wins over name priority")
  write(dir .. "/src/.prettierrc.toml", "semi = false")
  equal(formatting.find_prettier_config(leaf), dir .. "/src/prettier.config.mts", "upstream name precedence within directory")
  write(dir .. "/src/package.json", '{"prettier":{}}')
  equal(formatting.find_prettier_config(leaf), dir .. "/src/package.json", "package field takes precedence")

  local manifests = {
    { '{"prettier":{"semi":false}}', true, "object field" },
    { '{"prettier":{}}', true, "empty object field" },
    { '{"prettier":"@company/prettier-config"}', true, "shared config string" },
    { '{"name":"not-configured"}', false, "ordinary package" },
    { '{"scripts":{"prettier":"prettier ."}}', false, "nested field" },
    { '{"prettier":null}', false, "null field" },
    { '{"prettier":false}', false, "false field" },
    { '{"prettier":""}', false, "empty string field" },
    { '{"prettier":0}', false, "zero field" },
    { '{"prettier":', false, "malformed package" },
    { '', false, "empty package" },
    { 'null', false, "null package" },
    { '42', false, "scalar package" },
    { '\239\187\191{"prettier":{}}', true, "BOM package" },
  }
  for i, case in ipairs(manifests) do
    dir, leaf = project("manifest-" .. i)
    write(dir .. "/.prettierrc", "{}")
    write(dir .. "/src/package.json", case[1])
    equal(formatting.find_prettier_config(leaf), case[2] and dir .. "/src/package.json" or dir .. "/.prettierrc", case[3] .. ": parent traversal")
  end
  dir, leaf = project("malformed-sibling")
  write(dir .. "/package.json", '{"prettier":')
  write(dir .. "/.prettierrc.cts", "module.exports = {}")
  equal(formatting.find_prettier_config(leaf), dir .. "/.prettierrc.cts", "malformed manifest does not hide sibling")
  dir, leaf = project("directory-marker")
  vim.fn.mkdir(dir .. "/.prettierrc", "p")
  equal(formatting.find_prettier_config(leaf), nil, "directories are not configs")
  dir, leaf = project("no-config")
  write(dir .. "/package.json", '{"name":"plain"}')
  equal(formatting.find_prettier_config(leaf), nil, "unconfigured project")

  -- YAML parsing belongs to Prettier; the helper must delegate, not guess from
  -- a manifest's existence or attempt to implement a YAML parser in Lua.
  dir, leaf = project("yaml")
  write(dir .. "/package.yaml", "prettier: {}")
  local calls = 0
  equal(formatting.find_prettier_config(leaf, function()
    calls = calls + 1
    return dir .. "/package.yaml"
  end), dir .. "/package.yaml", "package.yaml delegates discovery")
  equal(calls, 1, "only existing YAML manifests trigger delegation")
  write(dir .. "/.prettierrc.toml", "semi = false")
  equal(formatting.find_prettier_config(leaf, function() return nil end), dir .. "/.prettierrc.toml", "unconfigured YAML does not hide sibling")

  local spec = dofile(source .. "/lua/plugins/conform.lua")
  equal(spec.opts.formatters_by_ft.lua, { "stylua" }, "Lua uses built-in StyLua")
  equal(spec.opts.notify_no_formatters, false, "missing tools do not generate no-formatter notifications")
  equal(spec.opts.formatters.prettier.command, nil, "retain Conform's project-pinned Prettier resolver")
  equal(spec.opts.format_on_save, nil, "no competing Conform save hook")
  equal(spec.opts.format_after_save, nil, "no asynchronous competing save hook")
  local condition = spec.opts.formatters.prettier.condition
  dir, leaf = project("condition")
  write(dir .. "/.prettierrc.ts", "export default {}")
  equal(condition({}, { dirname = leaf }), true, "Prettier condition uses complete discovery")
  dir, leaf = project("condition-empty")
  equal(condition({}, { dirname = leaf }), false, "requireConfig stays opt-in")

  dir, leaf = project("yaml-condition")
  write(dir .. "/package.yaml", "prettier: {}")
  local system = vim.system
  local command_calls, yaml_ctx = 0, { dirname = leaf, filename = leaf .. "/file.js" }
  vim.system = function(command, opts)
    equal(command, { dir .. "/node_modules/.bin/prettier", "--find-config-path", yaml_ctx.filename }, "YAML uses the resolved project command")
    equal(opts.cwd, leaf, "YAML discovery runs in the buffer directory")
    return { wait = function(_, timeout)
      equal(timeout, 1000, "YAML discovery is bounded")
      return { code = 0, stdout = dir .. "/package.yaml\n" }
    end }
  end
  equal(condition({ command = function(_, ctx)
    equal(ctx, yaml_ctx, "built-in command resolver receives original context")
    command_calls = command_calls + 1
    return dir .. "/node_modules/.bin/prettier"
  end }, yaml_ctx), true, "YAML config accepted")
  equal(command_calls, 1, "project command resolution occurs once")
  vim.system = function() return { wait = function() return { code = 1, stdout = "" } end } end
  equal(condition({ command = "prettier" }, yaml_ctx), false, "CLI with no YAML config is a no-op")
  vim.system = function() error("ENOENT") end
  equal(condition({ command = "prettier" }, yaml_ctx), false, "missing YAML resolver is safe")
  vim.system = system

  -- Exercise the real BufWritePre autocmd with only the plugin API substituted.
  -- This is independent of installed plugins, executables, and live init.lua.
  local calls_log, available, options = {}, true, nil
  package.loaded.conform = {
    list_formatters = function(bufnr)
      equal(bufnr, vim.api.nvim_get_current_buf(), "availability queried for saved buffer")
      return available and { { name = "prettier", available = true } } or {}
    end,
    format = function(opts)
      options = opts
      calls_log[#calls_log + 1] = "prettier"
    end,
  }
  spec.init()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_create_user_command(buf, "LspEslintFixAll", function()
    calls_log[#calls_log + 1] = "eslint"
  end, {})
  vim.api.nvim_exec_autocmds("BufWritePre", { buffer = buf })
  equal(calls_log, { "prettier", "eslint" }, "Prettier then ESLint, synchronously")
  equal(options.bufnr, buf, "format targets saved buffer")
  equal(options.timeout_ms, 3000, "save timeout retained")
  equal(options.lsp_format, "fallback", "existing save LSP behavior retained")
  equal(options.async, nil, "save remains synchronous")
  available, calls_log = false, {}
  vim.api.nvim_exec_autocmds("BufWritePre", { buffer = buf })
  equal(calls_log, { "eslint" }, "missing formatter does not skip ESLint")
  vim.api.nvim_buf_del_user_command(buf, "LspEslintFixAll")
  calls_log = {}
  vim.api.nvim_exec_autocmds("BufWritePre", { buffer = buf })
  equal(calls_log, {}, "missing formatter and ESLint are safe no-ops")
  vim.api.nvim_del_augroup_by_name("format_on_save")
  vim.api.nvim_buf_delete(buf, { force = true })
end
local ok, err = xpcall(run, debug.traceback)
vim.fs.dirname = dirname
vim.fn.delete(root, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("formatting.lua: " .. checks .. " assertions passed")
