vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("DotfilesIndent", { clear = true }),
  pattern = { "cs", "swift" },
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
    vim.bo.shiftwidth = 4
  end,
})
