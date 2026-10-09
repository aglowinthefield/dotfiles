return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "rouge8/neotest-rust",
    "nvim-neotest/neotest-jest",
  },
  keys = {
    -- node:test files (everything outside apps/mobile) go to config.node-test;
    -- jest files stay with neotest
    { "<leader>tt", function()
      local nt = require("config.node-test")
      if nt.applies(vim.api.nvim_buf_get_name(0)) then return nt.run_nearest() end
      require("neotest").run.run()
    end, desc = "Run Nearest Test" },
    { "<leader>tf", function()
      local nt = require("config.node-test")
      if nt.applies(vim.api.nvim_buf_get_name(0)) then return nt.run_file() end
      require("neotest").run.run(vim.fn.expand("%"))
    end, desc = "Run File Tests" },
    { "<leader>tT", function()
      -- Use the adapter's project root so it works from monorepo roots
      local neotest = require("neotest")
      local ids = neotest.state.adapter_ids()
      for _, adapter_id in ipairs(ids) do
        local tree = neotest.state.positions(adapter_id)
        if tree then
          neotest.run.run(tree:data().path)
          return
        end
      end
      neotest.run.run(vim.uv.cwd())
    end, desc = "Run All Tests" },
    { "<leader>tl", function()
      local nt = require("config.node-test")
      if nt.applies(vim.api.nvim_buf_get_name(0)) and nt.run_last() then return end
      require("neotest").run.run_last()
    end, desc = "Run Last Test" },
    { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Summary" },
    { "<leader>to", function() require("neotest").output.open({ enter_on_open = true }) end, desc = "Show Output" },
    { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle Output Panel" },
    { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop" },
    { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug Nearest Test" },
    { "[t", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Prev Failed Test" },
    { "]t", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next Failed Test" },
  },
  config = function()
    -- Patch neotest-rust's filter_dir to avoid vim.wait crash in async context
    local rust_adapter = require("neotest-rust")
    rust_adapter.filter_dir = function(name)
      return name ~= "target"
    end

    -- Mirrors silk-remix's apps/mobile `npm test`: the .cjs config (the .js
    -- one beside it is stale), run from the package dir, with --forceExit.
    -- Jest detection is already scoped by the adapter to packages whose
    -- package.json depends on jest, so node:test suites elsewhere are left alone.
    local function jest_config(file)
      return vim.fs.find({ "jest.config.cjs", "jest.config.js", "jest.config.ts" },
        { path = vim.fs.dirname(file), upward = true })[1]
    end
    local jest_adapter = require("neotest-jest")({
      jestCommand = "npx jest --forceExit",
      jestConfigFile = function(file)
        return jest_config(file) or "jest.config.js"
      end,
      cwd = function(file)
        local config = jest_config(file)
        return config and vim.fs.dirname(config) or vim.uv.cwd()
      end,
    })

    -- The adapter only skips node_modules, so discovery would also walk
    -- silk-remix's .worktrees (60-odd full checkouts, ~400k files) looking for
    -- tests. Skip dot-dirs, build output and native mobile trees.
    local skip_dirs = { node_modules = true, dist = true, build = true, coverage = true, ios = true, android = true }
    jest_adapter.filter_dir = function(name)
      return not skip_dirs[name] and not vim.startswith(name, ".")
    end

    require("neotest").setup({
      adapters = {
        rust_adapter,
        jest_adapter,
      },
    })
  end,
}
