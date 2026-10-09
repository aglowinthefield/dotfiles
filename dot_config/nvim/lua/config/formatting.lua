local M = {}

-- Prettier's documented search order, applied directory-by-directory so a
-- nearby config wins over an ancestor's higher-priority filename.
local config_names = {
  "package.json", "package.yaml", ".prettierrc",
  ".prettierrc.json", ".prettierrc.yml", ".prettierrc.yaml", ".prettierrc.json5",
  ".prettierrc.js", "prettier.config.js", ".prettierrc.ts", "prettier.config.ts",
  ".prettierrc.mjs", "prettier.config.mjs", ".prettierrc.mts", "prettier.config.mts",
  ".prettierrc.cjs", "prettier.config.cjs", ".prettierrc.cts", "prettier.config.cts",
  ".prettierrc.toml",
}

local function package_has_prettier(path)
  local ok, pkg = pcall(function()
    local contents = table.concat(vim.fn.readfile(path), "\n"):gsub("^\239\187\191", "")
    return vim.json.decode(contents)
  end)
  if not ok or type(pkg) ~= "table" then
    return false
  end
  local value = pkg.prettier
  -- Match upstream's Boolean(prettier), including null and empty strings.
  return value ~= nil and value ~= vim.NIL and value ~= false and value ~= "" and value ~= 0
end

function M.find_prettier_config(dirname, resolve_yaml)
  local dir = vim.fs.normalize(dirname)
  while dir do
    for _, name in ipairs(config_names) do
      local path = dir .. "/" .. name
      local stat = (vim.uv or vim.loop).fs_stat(path)
      if stat and stat.type == "file" then
        if name == "package.json" then
          if package_has_prettier(path) then
            return path
          end
        elseif name == "package.yaml" then
          -- Neovim has no YAML decoder. Let the project's Prettier interpret
          -- YAML (quoted keys, aliases, flow mappings, malformed manifests).
          local resolved = resolve_yaml and resolve_yaml()
          if resolved then
            return resolved
          end
        else
          return path
        end
      end
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
end

function M.prettier_condition(self, ctx)
  return M.find_prettier_config(ctx.dirname, function()
    -- Keep Conform's built-in node_modules-first command resolution; a global
    -- executable check would incorrectly disable project-local installations.
    local command = type(self.command) == "function" and self.command(self, ctx) or self.command
    if not command then
      return nil
    end
    local ok, result = pcall(function()
      return vim.system({ command, "--find-config-path", ctx.filename }, {
        cwd = ctx.dirname,
        text = true,
      }):wait(1000)
    end)
    if ok and result.code == 0 then
      local path = vim.trim(result.stdout or "")
      if path ~= "" then
        return path
      end
    end
  end) ~= nil
end

return M
