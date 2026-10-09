return {
  "akinsho/horizon.nvim",
  url = "git@github.com:akinsho/horizon.nvim.git",
  version = "*",
  lazy = false,
  priority = 1000,
  config = function()
    vim.cmd.colorscheme("horizon")
  end,
}
