-- Runs `node --test` suites (silk-remix's web, api, shared and the other
-- packages) for the current file or the test under the cursor. neotest-jest
-- only covers packages that depend on jest (apps/mobile), and the off-the-shelf
-- node:test adapter loads TS with Node's type stripping instead of tsx, which
-- can't resolve the repo's @silk/* path aliases.
--
-- Rather than hardcode flags, it reuses the owning package's own npm script and
-- swaps its file list for the current file. That keeps each workspace's quirks
-- (web's --import ./tests/test-env.ts, api's Redis env and pretest) in step with
-- the repo instead of drifting from it.
local M = {}

local function read_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  local ok_json, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  return ok_json and type(data) == "table" and data or nil
end

-- Nearest package.json above `file` that satisfies `pred`, as dir, pkg.
local function find_package(file, pred)
  for dir in vim.fs.parents(file) do
    local pkg = read_json(dir .. "/package.json")
    if pkg and pred(pkg) then
      return dir, pkg
    end
  end
end

local function is_node_test(script)
  return type(script) == "string" and script:find("%-%-test") ~= nil and script:find("jest") == nil
end

-- Drop the script's own file selection: `$(find ...)` substitutions and quoted
-- `**` globs (the root test:db script).
local function strip_file_args(script)
  script = script:gsub("%$%(find[^)]*%)", "")
  script = script:gsub("'[^']*%*%*[^']*'", "")
  return vim.trim(script)
end

-- *.db-test.ts files only run under the root `test:db` script; every other
-- test file runs under its own package's `test` script.
local function resolve(file)
  if file:match("%.db%-test%.tsx?$") then
    local dir, pkg = find_package(file, function(p)
      return p.workspaces ~= nil and p.scripts and is_node_test(p.scripts["test:db"])
    end)
    if dir then
      return dir, pkg.scripts["test:db"], nil
    end
    return nil
  end
  if not file:match("%.test%.tsx?$") then
    return nil
  end
  local dir, pkg = find_package(file, function(p)
    return p.scripts and p.scripts.test ~= nil
  end)
  if dir and is_node_test(pkg.scripts.test) then
    return dir, pkg.scripts.test, pkg.scripts.pretest
  end
end

function M.applies(file)
  return resolve(file) ~= nil
end

-- POSIX sh quoting. vim.fn.shellescape() follows 'shell', and for fish it
-- doubles backslashes, which sh would then pass through literally.
local function sh_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- `-` stays unescaped: `\-` is a syntax error if node builds the RegExp with
-- the u flag.
local function escape_regex(s)
  return (s:gsub("[%^%$%(%)%.%[%]%*%+%?%{%}|\\/]", function(c)
    return "\\" .. c
  end))
end

local test_fns = { describe = true, it = true, test = true, suite = true }

-- Innermost describe/it/test call around the cursor whose name is a literal.
local function nearest_name(bufnr)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr })
  if not ok then
    return nil
  end
  while node do
    if node:type() == "call_expression" then
      local fn = node:field("function")[1]
      local callee = fn and vim.treesitter.get_node_text(fn, bufnr)
      -- describe.only, it.skip, t.test, ...
      local base = callee and (callee:match("^([%w_]+)") or callee)
      local last = callee and callee:match("([%w_]+)$")
      if base and (test_fns[base] or test_fns[last or ""]) then
        local args = node:field("arguments")[1]
        local first = args and args:named_child(0)
        if first and (first:type() == "string" or first:type() == "template_string") then
          local text = vim.treesitter.get_node_text(first, bufnr)
          local name = text:sub(2, -2)
          if not name:find("%${") then
            return name
          end
        end
      end
    end
    node = node:parent()
  end
end

-- Returns { cwd, cmd } for running `file`, optionally filtered to `name`.
function M.command(file, name)
  local cwd, script, pretest = resolve(file)
  if not cwd then
    return nil
  end
  local parts = { strip_file_args(script) }
  if name then
    table.insert(parts, "--test-name-pattern=" .. sh_quote(escape_regex(name)))
  end
  table.insert(parts, sh_quote(file))
  local cmd = table.concat(parts, " ")
  if pretest then
    cmd = "npm run pretest --silent && " .. cmd
  end
  return { cwd = cwd, cmd = cmd }
end

local last

local function run(spec)
  last = spec
  vim.cmd("botright 15new")
  -- argv form so the script runs under sh, not the user's shell (fish can't
  -- parse the scripts' $(...) and VAR=${VAR:-default} syntax)
  vim.fn.jobstart({ "sh", "-c", spec.cmd }, { cwd = spec.cwd, term = true })
  vim.cmd("normal! G")
end

function M.run_file(bufnr)
  bufnr = bufnr or 0
  local spec = M.command(vim.api.nvim_buf_get_name(bufnr))
  if spec then
    run(spec)
  end
end

function M.run_nearest(bufnr)
  bufnr = bufnr or 0
  local name = nearest_name(bufnr)
  local spec = M.command(vim.api.nvim_buf_get_name(bufnr), name)
  if spec then
    run(spec)
  end
end

function M.run_last()
  if not last then
    return false
  end
  run(last)
  return true
end

M._nearest_name = nearest_name

return M
