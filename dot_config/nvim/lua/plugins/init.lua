-- Basic plugins with no major config needed. The Essentials.
return {
  "tpope/vim-sensible",
  "tpope/vim-commentary",
  "tpope/vim-surround",
  { "nvim-tree/nvim-web-devicons",     opts = {} },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = 'master',
    lazy = false,
    build = ":TSUpdate",
    opts = {
      ensure_installed = { "typescript", "tsx", "javascript", "yaml" },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
              ["aa"] = "@parameter.outer",
              ["ia"] = "@parameter.inner",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              ["]m"] = "@function.outer",
              ["]]"] = "@class.outer",
            },
            goto_previous_start = {
              ["[m"] = "@function.outer",
              ["[["] = "@class.outer",
            },
          },
        },
      })
    end,
  },
  { "j-hui/fidget.nvim", event = "LspAttach", opts = {} },
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
