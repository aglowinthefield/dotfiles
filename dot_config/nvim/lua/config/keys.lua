vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit window" })
vim.keymap.set("n", "<leader>x", "<cmd>x<cr>", { desc = "Save and quit window" })

vim.api.nvim_create_user_command("Q", "quit<bang>", { bang = true })
vim.api.nvim_create_user_command("X", "xit<bang>", { bang = true })
