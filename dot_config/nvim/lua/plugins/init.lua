-- Basic plugins with no major config needed. The Essentials.
return {
  "tpope/vim-surround",
  { "nvim-tree/nvim-web-devicons",     opts = {} },
  { "j-hui/fidget.nvim", event = "LspAttach", opts = {} },
  -- Makes gc use {/* */} inside JSX instead of the file's // commentstring
  { "folke/ts-comments.nvim", event = "VeryLazy", opts = {} },
  -- Auto-close JSX/HTML tags, and rename the closing tag with the opening one
  { "windwp/nvim-ts-autotag", event = { "BufReadPre", "BufNewFile" }, opts = {} },
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
