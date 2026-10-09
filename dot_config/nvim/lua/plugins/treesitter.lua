return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = 'main',
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- main branch dropped ensure_installed from setup(); install explicitly
      local wanted = {
        "typescript", "tsx", "javascript", "yaml", "c_sharp", "swift", "rust",
        "css", "html", "json", "bash", "sql", "lua", "regex",
      }
      local installed = require("nvim-treesitter").get_installed()
      local missing = vim.tbl_filter(function(lang)
        return not vim.list_contains(installed, lang)
      end, wanted)
      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end

      -- main branch doesn't start highlighting either; without this most
      -- filetypes fall back to regex syntax and TS-aware plugins (ts-comments)
      -- see no tree. pcall because not every filetype has a parser.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
        callback = function(args)
          if not pcall(vim.treesitter.start, args.buf) then
            return
          end
          -- Syntax-aware folds, all open on load (zc/zo/za to use them)
          vim.wo[0][0].foldmethod = "expr"
          vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo[0][0].foldlevel = 99
          -- Treesitter indent only where the parser ships an indents query;
          -- elsewhere keep the filetype's own indentexpr
          local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
          if lang and vim.treesitter.query.get(lang, "indents") then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
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
}
