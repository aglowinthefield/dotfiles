local M = {}

function M.setup()
  local stdin = false
  local group = vim.api.nvim_create_augroup("DailyPluginUpdate", { clear = true })
  vim.api.nvim_create_autocmd("StdinReadPre", {
    group = group,
    callback = function()
      stdin = true
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VeryLazy",
    once = true,
    callback = function()
      vim.schedule(function()
        local ft = vim.bo.filetype
        if stdin or #vim.api.nvim_list_uis() == 0 or ft == "gitcommit" or ft == "gitrebase" then
          return
        end

        local state = vim.fn.stdpath("state")
        local stamp = state .. "/lazy-auto-update"
        local uv = vim.uv or vim.loop
        local stat = uv.fs_stat(stamp)
        if stat and os.time() - stat.mtime.sec < 24 * 60 * 60 then
          return
        end

        -- Record attempts, not successes, to avoid retrying on every offline launch.
        vim.fn.mkdir(state, "p")
        local file, err = io.open(stamp, "w")
        if not file then
          vim.notify("Plugin auto-update skipped: " .. tostring(err), vim.log.levels.WARN)
          return
        end
        file:close()

        -- Update on disk without opening Lazy's UI or waiting for the network.
        -- Already-loaded plugins are not deliberately reloaded; restart to use updates.
        local ok, update_err = pcall(function()
          require("lazy").update({ show = false, wait = false })
        end)
        if not ok then
          vim.notify("Plugin auto-update failed: " .. tostring(update_err), vim.log.levels.WARN)
        end
      end)
    end,
  })
end

return M
