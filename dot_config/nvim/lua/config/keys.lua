vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit window" })
vim.keymap.set("n", "<leader>x", "<cmd>x<cr>", { desc = "Save and quit window" })

vim.api.nvim_create_user_command("Q", "quit<bang>", { bang = true })
vim.api.nvim_create_user_command("X", "xit<bang>", { bang = true })

-- Code references and annotations. A reference is path:line or path:start-end,
-- relative to the git root, so it can be pasted into an agent session or note.
local function current_ref(range)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("Buffer has no file", vim.log.levels.WARN)
    return
  end
  local root = vim.fs.root(file, ".git")
  local path = root and vim.fs.relpath(root, file) or vim.fn.fnamemodify(file, ":~")
  local a, b = vim.fn.line("."), vim.fn.line(".")
  if range then
    a, b = vim.fn.line("v"), vim.fn.line(".")
    if a > b then a, b = b, a end
  end
  local ref = a == b and ("%s:%d"):format(path, a) or ("%s:%d-%d"):format(path, a, b)
  return ref, root, a, b
end

local function leave_visual()
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
end

vim.keymap.set("n", "<leader>yp", function()
  local ref = current_ref(false)
  if ref then
    vim.fn.setreg("+", ref)
    vim.notify("Copied " .. ref)
  end
end, { desc = "Copy path:line" })
vim.keymap.set("x", "<leader>yp", function()
  local ref = current_ref(true)
  leave_visual()
  if ref then
    vim.fn.setreg("+", ref)
    vim.notify("Copied " .. ref)
  end
end, { desc = "Copy path:start-end" })

-- One notes file per repo, kept out of the repo itself. Lives in the Obsidian
-- vault when it exists (so notes show up beside the rest of the work notes),
-- otherwise under nvim's data dir. Override with vim.g.annotations_dir.
-- Outside a git repo (a vault note, say) the file is named for the annotated
-- file instead, so notes on one plan don't share a scratch file with everything
-- else. The `annotations` agent skill reads these files back.
local function notes_file(root, file)
  local vault = vim.fn.expand("~/Documents/Dev/Work/Annotations")
  local dir = vim.g.annotations_dir
    or (vim.uv.fs_stat(vim.fn.fnamemodify(vault, ":h")) and vault)
    or (vim.fn.stdpath("data") .. "/annotations")
  vim.fn.mkdir(dir, "p")
  local name = root and vim.fs.basename(root)
    or (file and file ~= "" and vim.fn.fnamemodify(file, ":t:r"))
    or "scratch"
  return dir .. "/" .. name .. ".md"
end

local function annotate(range)
  local ref, root, a, b = current_ref(range)
  if range then leave_visual() end
  if not ref then return end
  -- Capture now: the prompt can move the cursor or change the buffer
  local lines = vim.api.nvim_buf_get_lines(0, a - 1, b, false)
  local ft = vim.bo.filetype
  local bufname = vim.api.nvim_buf_get_name(0)
  vim.ui.input({ prompt = "Note on " .. ref .. ": " }, function(note)
    if not note or note == "" then return end
    local branch = root and vim.trim(vim.fn.system({ "git", "-C", root, "branch", "--show-current" })) or ""
    local out = { ("- `%s` %s%s — %s"):format(ref, os.date("%Y-%m-%d %H:%M"), branch ~= "" and (" @" .. branch) or "", note) }
    -- Quote the code too, so the note survives the lines moving
    if #lines > 0 and #lines <= 12 then
      table.insert(out, "  ```" .. ft)
      for _, l in ipairs(lines) do table.insert(out, "  " .. l) end
      table.insert(out, "  ```")
    end
    local file = notes_file(root, bufname)
    vim.fn.writefile(out, file, "a")
    vim.notify("Noted in " .. vim.fn.fnamemodify(file, ":~"))
  end)
end

vim.keymap.set("n", "<leader>ya", function() annotate(false) end, { desc = "Annotate line" })
vim.keymap.set("x", "<leader>ya", function() annotate(true) end, { desc = "Annotate selection" })
vim.keymap.set("n", "<leader>yn", function()
  local _, root = current_ref(false)
  vim.cmd.edit(vim.fn.fnameescape(notes_file(root, vim.api.nvim_buf_get_name(0))))
end, { desc = "Open notes for this repo" })
