vim.keymap.set("n", "<leader>n", function()
  vim.cmd.Texplore()
end, { desc = "Open file explorer" })

vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
