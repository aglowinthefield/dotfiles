local M = {}

-- Optional tools only affect their named feature; this check never installs anything.
function M.check()
  local health = vim.health
  local runtime = require('config.runtime')
  health.start('Dotfiles: Neovim')
  if runtime.supported() then
    health.ok('Neovim 0.12+ (required by nvim-treesitter main)')
  else
    health.error('Neovim 0.12+ is required by nvim-treesitter main', { 'Upgrade Neovim before loading plugins.' })
  end

  health.start('Dotfiles: required tools')
  local tools = runtime.tools()
  for _, tool in ipairs(tools) do
    if tool.required then
      if tool.available then
        health.ok(tool.name .. ': ' .. tool.command .. ' (' .. tool.detail .. ')')
      else
        health.error(tool.name .. ' missing (' .. tool.detail .. ')', {
          'Install on PATH: ' .. table.concat(tool.commands, ' or '),
        })
      end
    end
  end

  health.start('Dotfiles: optional tools')
  for _, tool in ipairs(tools) do
    if not tool.required then
      if tool.available then
        health.ok(tool.name .. ' (' .. tool.detail .. ')')
      else
        health.warn(tool.name .. ' missing (' .. tool.detail .. ')', {
          'Install on PATH only if you need this feature.',
        })
      end
    end
  end

  health.start('Dotfiles: clipboard')
  health.info('Clipboard provider selection is left to Neovim auto-detection. See :help provider-clipboard and :checkhealth vim.provider.')
  health.info('Wayland needs a working compositor connection, not just wl-copy on PATH. Headless/SSH sessions may have no system clipboard.')
  health.info('OSC52 is an optional terminal/SSH alternative: see :help clipboard-osc52 (terminal support required). It is not forced by this config.')
end

return M
