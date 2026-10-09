-- Run from any directory: nvim --headless -u NONE -l /path/to/tests/nvim/runtime.lua
-- No plugins, installs, subprocesses, or live configuration are needed.
local real_vim = vim
local root = real_vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local lua = root .. '/dot_config/nvim/lua/'
local tests = {}
local function test(name, fn)
  tests[#tests + 1] = { name, fn }
end
local function eq(actual, expected)
  assert(real_vim.deep_equal(actual, expected), real_vim.inspect(actual) .. ' != ' .. real_vim.inspect(expected))
end
local function load(path)
  return assert(loadfile(lua .. path))()
end
local function shell_options()
  return {
    shell = 'custom-shell', shellcmdflag = 'custom-flags', shelltemp = true,
    shellpipe = 'custom-pipe', shellredir = 'custom-redir',
    shellquote = 'custom-quote', shellxquote = 'custom-xquote',
  }
end
local function tool_named(runtime, name)
  for _, tool in ipairs(runtime.tools()) do
    if tool.name == name then return tool end
  end
end

local function fixture()
  local state = { windows = false, win64 = false, supported = true, commands = {}, probes = {}, notifications = {} }
  local fake = {
    o = shell_options(), env = {}, g = { clipboard = 'user-provider' },
    fn = {}, api = {}, diagnostic = { config = function() end },
    opt = {}, log = { levels = { WARN = 3 } },
    lsp = { config = function() end, enable = function() end },
  }
  fake.fn.has = function(feature)
    if feature == 'win32' then return state.windows and 1 or 0 end
    if feature == 'win64' then return state.win64 and 1 or 0 end
    if feature == 'nvim-0.12' then return state.supported and 1 or 0 end
    return 0
  end
  fake.fn.executable = function(command)
    state.probes[#state.probes + 1] = command
    return state.commands[command] and 1 or 0
  end
  fake.fn.sign_define = function() end
  fake.api.nvim_create_augroup = function() return 1 end
  fake.api.nvim_create_autocmd = function() end
  fake.notify = function(message, level)
    state.notifications[#state.notifications + 1] = { message = message, level = level }
  end
  return fake, state
end

test('Unix preserves shell and clipboard even with pwsh/wl-copy available', function(fake, state, runtime)
  state.commands = { pwsh = true, ['wl-copy'] = true }
  local before = real_vim.deepcopy(fake.o)
  runtime.setup()
  eq(fake.o, before)
  eq(fake.g.clipboard, 'user-provider')
  fake.g = {}
  runtime.setup()
  eq(fake.g.clipboard, nil)
  eq(state.probes, {})
  eq(tool_named(runtime, 'pwsh'), nil)
end)

test('Windows without pwsh preserves every shell setting', function(fake, state, runtime)
  state.windows = true
  local before = real_vim.deepcopy(fake.o)
  runtime.setup()
  eq(fake.o, before)
  eq(fake.env.__SuppressAnsiEscapeSequences, nil)
  eq(tool_named(runtime, 'pwsh').required, false)
  eq(tool_named(runtime, 'pwsh').available, false)
end)

test('Windows pwsh uses documented UTF-8, redirection, and no-profile settings', function(fake, state, runtime)
  state.windows = true
  state.commands.pwsh = true
  runtime.setup()
  eq(fake.o, {
    shell = 'pwsh', shelltemp = false,
    shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command '
      .. '[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();'
      .. "$PSDefaultParameterValues['Out-File:Encoding']='utf8';"
      .. "$PSStyle.OutputRendering = 'PlainText';",
    shellpipe = '> %s 2>&1', shellredir = '> %s 2>&1', shellquote = '', shellxquote = '',
  })
  eq(fake.env.__SuppressAnsiEscapeSequences, '1')
  eq(fake.g.clipboard, 'user-provider')
  local once = real_vim.deepcopy(fake.o)
  runtime.setup()
  eq(fake.o, once)
end)

test('win64 detection also enables available pwsh', function(fake, state, runtime)
  state.win64 = true
  state.commands.pwsh = true
  runtime.options()
  eq(fake.o.shell, 'pwsh')
end)

test('unsupported Neovim aborts before shell changes', function(fake, state, runtime)
  state.supported = false
  state.windows = true
  state.commands.pwsh = true
  local before = real_vim.deepcopy(fake.o)
  local ok, message = pcall(runtime.setup)
  eq(ok, false)
  assert(message:find('Neovim 0.12+', 1, true))
  eq(fake.o, before)
  eq(state.probes, {})
end)

test('required/optional inventory and executable aliases are accurate', function(_, state, runtime)
  local required = {}
  for _, tool in ipairs(runtime.tools()) do
    if tool.required then required[#required + 1] = tool.name end
    eq(tool.available, false)
  end
  eq(required, { 'git', 'rg', 'fd', 'tree-sitter-cli', 'tar', 'curl', 'C compiler' })
  state.commands = { ['tree-sitter'] = true, cl = true, lazygit = true }
  eq(tool_named(runtime, 'tree-sitter-cli').available, true)
  eq(tool_named(runtime, 'C compiler').command, 'cl')
  eq(tool_named(runtime, 'lazygit').required, false)
  eq(tool_named(runtime, 'sourcekit-lsp').required, false)
  eq(tool_named(runtime, 'netcoredbg').required, false)
  eq(tool_named(runtime, 'dotnet-csharpier').required, false)
  eq(tool_named(runtime, 'stylua').required, false)
  state.commands.cl = nil
  state.commands.clang = true
  eq(tool_named(runtime, 'C compiler').command, 'clang')
end)

test('sourcekit is configured and enabled only when executable', function(fake, state)
  package.loaded.schemastore = {
    json = { schemas = function() return {} end }, yaml = { schemas = function() return {} end },
  }
  local configured, enabled = {}, {}
  fake.lsp.config = function(name, options) configured[name] = options end
  fake.lsp.enable = function(name) enabled[#enabled + 1] = name end
  local spec
  for _, candidate in ipairs(load('plugins/lsp.lua')) do
    if candidate[1] == 'neovim/nvim-lspconfig' then spec = candidate end
  end
  assert(spec, 'missing nvim-lspconfig spec')
  spec.config()
  eq(configured.sourcekit, nil)
  eq(enabled, {})
  state.commands['sourcekit-lsp'] = true
  spec.config()
  eq(configured.sourcekit.cmd, { 'sourcekit-lsp' })
  eq(configured.sourcekit.root_markers, { 'buildServer.json', 'Package.swift', '*.xcodeproj', '.git' })
  eq(enabled, { 'sourcekit' })
end)

test('netcoredbg missing aborts resolution; installing later permits launch', function(_, state)
  local dap = {
    adapters = {}, configurations = {},
    listeners = { after = { event_initialized = {} }, before = { event_terminated = {}, event_exited = {} } },
  }
  package.loaded.dap = dap
  package.loaded.dapui = { setup = function() end }
  load('plugins/dap.lua')[1].config()
  local callbacks, adapter = 0
  local function resolve(value) callbacks = callbacks + 1; adapter = value end
  dap.adapters.coreclr(resolve)
  eq(callbacks, 0)
  eq(#state.notifications, 1)
  assert(state.notifications[1].message:find('netcoredbg', 1, true))
  assert(state.notifications[1].message:find('PATH', 1, true))
  eq(state.notifications[1].level, vim.log.levels.WARN)
  state.commands.netcoredbg = true
  dap.adapters.coreclr(resolve)
  eq(callbacks, 1)
  eq(adapter, { type = 'executable', command = 'netcoredbg', args = { '--interpreter=vscode' } })
  eq(#state.notifications, 1)
end)

test('lazygit key warns without spawning and works once tool appears', function(_, state)
  local calls = 0
  _G.Snacks = { lazygit = function() calls = calls + 1 end }
  local key
  for _, candidate in ipairs(load('plugins/which-key.lua').opts.spec) do
    if candidate[1] == '<leader>gg' then key = candidate[2] end
  end
  assert(key, 'missing lazygit key')
  key()
  eq(calls, 0)
  eq(#state.notifications, 1)
  assert(state.notifications[1].message:find('lazygit', 1, true))
  assert(state.notifications[1].message:find('PATH', 1, true))
  state.commands.lazygit = true
  key()
  eq(calls, 1)
  eq(#state.notifications, 1)
end)

test('health distinguishes required errors, optional warnings, clipboard guidance', function(fake, state)
  local reports = { start = {}, ok = {}, error = {}, warn = {}, info = {} }
  fake.health = {}
  for kind, entries in pairs(reports) do
    fake.health[kind] = function(message) entries[#entries + 1] = message end
  end
  load('dotfiles/health.lua').check()
  eq(#reports.error, 7)
  eq(#reports.warn, 5)
  eq(#reports.info, 3)
  assert(table.concat(reports.info, ' '):find('OSC52', 1, true))
  assert(table.concat(reports.info, ' '):find('auto-detection', 1, true))
  eq(fake.g.clipboard, 'user-provider')
  state.supported = false
  state.windows = true
  load('dotfiles/health.lua').check()
  eq(#reports.error, 15)
  eq(#reports.warn, 11)
  state.supported = true
  for _, command in ipairs({ 'git', 'rg', 'fd', 'tree-sitter', 'tar', 'curl', 'gcc', 'pwsh', 'sourcekit-lsp', 'netcoredbg', 'dotnet-csharpier', 'stylua', 'lazygit' }) do
    state.commands[command] = true
  end
  load('dotfiles/health.lua').check()
  eq(#reports.error, 15)
  eq(#reports.warn, 11)
end)

-- Exercise actual Neovim option setters too, without launching a Windows shell.
test('documented pwsh options are accepted by real Neovim', function(_, _, runtime)
  _G.vim = real_vim
  local has, executable = real_vim.fn.has, real_vim.fn.executable
  local saved, env = {}, real_vim.env.__SuppressAnsiEscapeSequences
  for option in pairs(shell_options()) do saved[option] = real_vim.o[option] end
  real_vim.fn.has = function(feature) return (feature == 'win32' or feature == 'nvim-0.12') and 1 or 0 end
  real_vim.fn.executable = function(command) return command == 'pwsh' and 1 or 0 end
  local ok, message = xpcall(function()
    runtime.setup()
    eq(real_vim.o.shell, 'pwsh')
    eq(real_vim.o.shelltemp, false)
    eq(real_vim.o.shellpipe, '> %s 2>&1')
    eq(real_vim.o.shellredir, '> %s 2>&1')
    eq(real_vim.o.shellquote, '')
    eq(real_vim.o.shellxquote, '')
    eq(real_vim.env.__SuppressAnsiEscapeSequences, '1')
  end, debug.traceback)
  real_vim.fn.has, real_vim.fn.executable = has, executable
  -- Restore shell first, then its dependent options.
  real_vim.o.shell = saved.shell
  for option, value in pairs(saved) do real_vim.o[option] = value end
  real_vim.env.__SuppressAnsiEscapeSequences = env
  assert(ok, message)
end)

local modules = { 'config.runtime', 'schemastore', 'dap', 'dapui' }
for _, entry in ipairs(tests) do
  local saved_modules = {}
  for _, name in ipairs(modules) do saved_modules[name] = package.loaded[name] end
  local snacks = _G.Snacks
  local fake, state = fixture()
  _G.vim = fake
  local ok, message = xpcall(function()
    local runtime = load('config/runtime.lua')
    package.loaded['config.runtime'] = runtime
    entry[2](fake, state, runtime)
  end, debug.traceback)
  _G.vim, _G.Snacks = real_vim, snacks
  for _, name in ipairs(modules) do package.loaded[name] = saved_modules[name] end
  if not ok then error('FAIL ' .. entry[1] .. '\n' .. message, 0) end
  print('PASS ' .. entry[1])
end
print(('runtime: %d tests passed'):format(#tests))
