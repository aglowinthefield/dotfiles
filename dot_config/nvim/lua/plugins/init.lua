-- Basic plugins with no major config needed. The Essentials.
return {
  "tpope/vim-sensible",
  "tpope/vim-commentary",
  "tpope/vim-surround",
  { "nvim-tree/nvim-web-devicons",     opts = {} },
  { "nvim-treesitter/nvim-treesitter", branch = 'master', lazy = false, build = ":TSUpdate" },
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
