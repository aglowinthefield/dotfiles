-- Basic plugins with no major config needed. The Essentials.
return {
  "tpope/vim-surround",
  { "nvim-tree/nvim-web-devicons",     opts = {} },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = 'main',
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- main branch dropped ensure_installed from setup(); install explicitly
      local wanted = { "typescript", "tsx", "javascript", "yaml", "c_sharp", "swift", "rust" }
      local installed = require("nvim-treesitter").get_installed()
      local missing = vim.tbl_filter(function(lang)
        return not vim.list_contains(installed, lang)
      end, wanted)
      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      -- Configure via config.update (no .setup() in new API)
      local config = require("nvim-treesitter-textobjects.config")
      config.update({
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      -- Textobject select keymaps
      local select = require("nvim-treesitter-textobjects.select")
      vim.keymap.set({ "x", "o" }, "af", function() select.select_textobject("@function.outer") end)
      vim.keymap.set({ "x", "o" }, "if", function() select.select_textobject("@function.inner") end)
      vim.keymap.set({ "x", "o" }, "ac", function() select.select_textobject("@class.outer") end)
      vim.keymap.set({ "x", "o" }, "ic", function() select.select_textobject("@class.inner") end)
      vim.keymap.set({ "x", "o" }, "aa", function() select.select_textobject("@parameter.outer") end)
      vim.keymap.set({ "x", "o" }, "ia", function() select.select_textobject("@parameter.inner") end)

      -- Textobject move keymaps
      local move = require("nvim-treesitter-textobjects.move")
      vim.keymap.set({ "n", "x", "o" }, "]m", function() move.goto_next_start("@function.outer") end)
      vim.keymap.set({ "n", "x", "o" }, "]c", function() move.goto_next_start("@class.outer") end)
      vim.keymap.set({ "n", "x", "o" }, "[m", function() move.goto_previous_start("@function.outer") end)
      vim.keymap.set({ "n", "x", "o" }, "[c", function() move.goto_previous_start("@class.outer") end)
    end,
  },
  { "j-hui/fidget.nvim", event = "LspAttach", opts = {} },
  { "brenoprata10/nvim-highlight-colors", event = { "BufReadPre", "BufNewFile" }, opts = {} },
  {
    'alker0/chezmoi.vim',
    lazy = false,
    init = function()
      -- This option is required.
      vim.g['chezmoi#use_tmp_buffer'] = true
      -- add other options here if needed.
    end,
  },
}
