-- Repo-wide type errors in the quickfix list. The LSP only reports files you
-- have open, so a change in a shared package that breaks an app goes unseen
-- until CI.
return {
  "dmmulroy/tsc.nvim",
  cmd = { "TSC", "TSCOpen", "TSCClose", "TSCStop" },
  keys = {
    { "<leader>ct", "<cmd>TSC<cr>", desc = "Type-check Project (tsc)" },
  },
  config = function()
    -- Neither built-in mode fits an npm-workspaces monorepo like silk-remix:
    -- the default checks the cwd's tsconfig, whose `include` is empty there,
    -- and monorepo mode globs every tsconfig*.json (prototypes, *.base.json
    -- presets) and trips max_tsconfig_files. Check exactly the workspaces
    -- instead — the same set `npm run type-check` walks — and outside a
    -- workspace root fall back to the tsconfig nearest the current buffer.
    local utils = require("tsc.utils")
    utils.find_tsconfigs = function()
      local root = vim.fs.root(0, function(name, path)
        if name ~= "package.json" then
          return false
        end
        local ok, pkg = pcall(vim.json.decode, table.concat(vim.fn.readfile(path .. "/" .. name), "\n"))
        return ok and type(pkg) == "table" and pkg.workspaces ~= nil
      end)
      if root then
        local pkg = vim.json.decode(table.concat(vim.fn.readfile(root .. "/package.json"), "\n"))
        -- workspaces is either a list of globs or { packages = [...] }
        local globs = pkg.workspaces.packages or pkg.workspaces
        local configs = {}
        for _, glob in ipairs(globs) do
          for _, dir in ipairs(vim.fn.glob(root .. "/" .. glob, false, true)) do
            local tsconfig = dir .. "/tsconfig.json"
            if vim.uv.fs_stat(tsconfig) then
              table.insert(configs, tsconfig)
            end
          end
        end
        if #configs > 0 then
          return configs
        end
      end
      local nearest = vim.fs.find("tsconfig.json", { path = vim.fn.expand("%:p:h"), upward = true })[1]
      return nearest and { nearest } or {}
    end

    require("tsc").setup({
      -- run_as_monorepo makes run() call find_tsconfigs above and keep one
      -- process per tsconfig; the file-count cap is irrelevant once we pick them
      run_as_monorepo = true,
      max_tsconfig_files = 50,
      use_trouble_qflist = true,
    })
  end,
}
