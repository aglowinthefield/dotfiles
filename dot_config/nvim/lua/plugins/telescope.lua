return {
  -- Native fzf sorter (build step required)
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    -- On Windows, prefer CMake; elsewhere `make` is fine
    build = (vim.loop.os_uname().version:match("Windows"))
      and "cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build"
      or "make",
  },

  -- Telescope core
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-fzf-native.nvim" },
    config = function()
      require("telescope").setup({
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
        },
      })
      require("telescope").load_extension("fzf")
      local builtin = require('telescope.builtin')

      -- Files and search
      vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Buffers' })
      vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
      vim.keymap.set('n', '<leader>fo', builtin.oldfiles, { desc = 'Recent files' })
      vim.keymap.set('n', '<leader>fw', builtin.grep_string, { desc = 'Grep word under cursor' })

      -- LSP
      vim.keymap.set('n', 'gr', builtin.lsp_references, { desc = 'References' })
      vim.keymap.set('n', 'gd', builtin.lsp_definitions, { desc = 'Definitions' })
      vim.keymap.set('n', 'gi', builtin.lsp_implementations, { desc = 'Implementations' })
      vim.keymap.set('n', 'gt', builtin.lsp_type_definitions, { desc = 'Type definitions' })
      vim.keymap.set('n', '<leader>ds', builtin.lsp_document_symbols, { desc = 'Document symbols' })
      vim.keymap.set('n', '<leader>ws', builtin.lsp_workspace_symbols, { desc = 'Workspace symbols' })

      -- Diagnostics
      vim.keymap.set('n', '<leader>dd', builtin.diagnostics, { desc = 'Diagnostics' })
    end,
  },
}

