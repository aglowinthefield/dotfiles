-- Runtime prerequisites are reported by :checkhealth dotfiles, not installed here.
local M = {}

function M.has(command)
  return vim.fn.executable(command) == 1
end

function M.is_windows()
  return vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1
end

function M.supported()
  return vim.fn.has('nvim-0.12') == 1
end

-- Leave the user's shell untouched unless PowerShell 7 is actually available.
function M.options()
  if not M.is_windows() or not M.has('pwsh') then
    return
  end

  -- Official :help shell-powershell / shell-pwsh settings (UTF-8, no ANSI).
  vim.o.shell = 'pwsh'
  vim.o.shelltemp = false
  vim.o.shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command '
    .. '[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();'
    .. "$PSDefaultParameterValues['Out-File:Encoding']='utf8';"
    .. "$PSStyle.OutputRendering = 'PlainText';"
  vim.o.shellpipe = '> %s 2>&1'
  vim.o.shellredir = '> %s 2>&1'
  vim.o.shellquote = ''
  vim.o.shellxquote = ''
  vim.env.__SuppressAnsiEscapeSequences = '1'
end

function M.setup()
  if not M.supported() then
    error('Dotfiles require Neovim 0.12+ (nvim-treesitter main). Upgrade Neovim before loading plugins.', 0)
  end
  M.options()
  -- Do not set vim.g.clipboard: let Neovim detect a usable provider for the
  -- current session. An installed wl-copy does not imply a Wayland connection.
end

-- tree-sitter-cli is the package name; its executable is tree-sitter.
-- A C compiler is required to build parsers; any supported compiler suffices.
function M.tools()
  local tools = {
    { name = 'git', commands = { 'git' }, required = true, detail = 'plugin downloads and Git integration' },
    { name = 'rg', commands = { 'rg' }, required = true, detail = 'ripgrep for picker search' },
    { name = 'fd', commands = { 'fd' }, required = true, detail = 'file discovery for pickers' },
    { name = 'tree-sitter-cli', commands = { 'tree-sitter' }, required = true, detail = 'Treesitter parser generation' },
    { name = 'tar', commands = { 'tar' }, required = true, detail = 'Treesitter archive extraction' },
    { name = 'curl', commands = { 'curl' }, required = true, detail = 'Treesitter downloads' },
    { name = 'C compiler', commands = { 'cc', 'gcc', 'clang', 'cl', 'zig' }, required = true, detail = 'Treesitter parser compilation' },
    { name = 'sourcekit-lsp', commands = { 'sourcekit-lsp' }, required = false, detail = 'Swift/Objective-C LSP; disabled when absent' },
    { name = 'netcoredbg', commands = { 'netcoredbg' }, required = false, detail = '.NET debugging; install on PATH before starting DAP' },
    { name = 'dotnet-csharpier', commands = { 'dotnet-csharpier' }, required = false, detail = 'C# formatting' },
    { name = 'stylua', commands = { 'stylua' }, required = false, detail = 'Lua formatting' },
    { name = 'lazygit', commands = { 'lazygit' }, required = false, detail = '<leader>gg Git UI' },
  }
  if M.is_windows() then
    tools[#tools + 1] = { name = 'pwsh', commands = { 'pwsh' }, required = false, detail = 'PowerShell 7; keeps the existing shell when absent' }
  end
  for _, tool in ipairs(tools) do
    tool.available = false
    for _, command in ipairs(tool.commands) do
      if M.has(command) then
        tool.available = true
        tool.command = command
        break
      end
    end
  end
  return tools
end

return M
