return {
  "folke/snacks.nvim",
  priority = 1000, -- Load before other plugins
  lazy = false, -- Don't lazy-load; snacks needs to be available immediately
  ---@type snacks.Config
  opts = {
    -- Disables LSP features, treesitter, and other heavy processing for large files
    bigfile = { enabled = true },
    -- Startup dashboard with recent files, shortcuts, etc.
    dashboard = { enabled = true },
    -- File explorer sidebar (replaces neo-tree, nvim-tree, etc.)
    explorer = { enabled = true },
    -- Animated indent guides showing scope
    indent = { enabled = true },
    -- Improved vim.ui.input() replacement with floating window
    input = { enabled = true },
    -- Non-intrusive notification popups (replaces nvim-notify)
    notifier = {
      enabled = true,
      timeout = 3000, -- Auto-dismiss after 3 seconds
    },
    -- Fuzzy finder / picker UI (replaces telescope, fzf-lua, etc.)
    picker = { enabled = true },
    -- Instantly opens files before plugins load (skips lazy-loading overhead for known filetypes)
    quickfile = { enabled = true },
    -- Detects and highlights the current scope/block you're in
    scope = { enabled = true },
    -- Smooth scrolling animations
    scroll = { enabled = true },
    -- Custom status column with fold, sign, and line number segments
    statuscolumn = { enabled = true },
    -- Highlights and allows jumping between references of the word under cursor
    words = { enabled = true },
    styles = {
      notification = {
        -- wo = { wrap = true } -- Wrap notifications
      },
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end

        -- Override print to use snacks for `:=` command
        if vim.fn.has("nvim-0.11") == 1 then
          vim._print = function(_, ...)
            dd(...)
          end
        else
          vim.print = _G.dd
        end

        -- Create some toggle mappings
        Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
        Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
        Snacks.toggle.diagnostics():map("<leader>ud")
        Snacks.toggle.line_number():map("<leader>ul")
        Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>uc")
        Snacks.toggle.treesitter():map("<leader>uT")
        Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
        Snacks.toggle.inlay_hints():map("<leader>uh")
        Snacks.toggle.indent():map("<leader>ug")
        Snacks.toggle.dim():map("<leader>uD")
      end,
    })
  end,
}
