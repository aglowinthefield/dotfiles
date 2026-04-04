return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "rouge8/neotest-rust",
  },
  keys = {
    { "<leader>tt", function() require("neotest").run.run() end, desc = "Run Nearest Test" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File Tests" },
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
    { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Run Last Test" },
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

    require("neotest").setup({
      adapters = {
        rust_adapter,
      },
    })
  end,
}
