-- Basic plugins with no major config needed. The Essentials.
return {
  "tpope/vim-sensible",
  "tpope/vim-commentary",
  "tpope/vim-surround",
  { "nvim-tree/nvim-web-devicons",     opts = {} },
  { "nvim-treesitter/nvim-treesitter", branch = 'master', lazy = false, build = ":TSUpdate" }
}
