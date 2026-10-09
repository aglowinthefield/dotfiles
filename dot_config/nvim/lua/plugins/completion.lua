return {
  {
    -- blink.cmp over nvim-cmp: native vim.snippet expansion (nvim-cmp had no
    -- snippet engine wired, so LSP snippets inserted raw), buffer/path sources
    -- in insert mode, built-in signature help, and a Rust fuzzy matcher. On
    -- nvim 0.11+ it registers its LSP capabilities itself via vim.lsp.config('*'),
    -- which is why nvim-lspconfig and roslyn list it as a dependency.
    'saghen/blink.cmp',
    -- 1.* pulls the prebuilt fuzzy-matcher binary for the release tag
    version = '1.*',
    event = { "InsertEnter", "CmdlineEnter" },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = 'none',
        ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
        ['<C-e>'] = { 'hide', 'fallback' },
        ['<CR>'] = { 'accept', 'fallback' },
        -- Tab accepts, taking the first item when nothing is selected — the
        -- behaviour the old nvim-cmp mapping had
        ['<Tab>'] = { 'select_and_accept', 'snippet_forward', 'fallback' },
        ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
        ['<C-n>'] = { 'select_next', 'fallback' },
        ['<C-p>'] = { 'select_prev', 'fallback' },
        ['<Down>'] = { 'select_next', 'fallback' },
        ['<Up>'] = { 'select_prev', 'fallback' },
        ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
        ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
        ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },
      },
      completion = {
        -- Pre-highlight the first item so <CR> accepts it, like select = true did
        list = { selection = { preselect = true, auto_insert = false } },
        menu = { border = 'rounded', scrollbar = true },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = { border = 'rounded', max_width = 60, max_height = 20 },
        },
      },
      signature = { enabled = true, window = { border = 'rounded' } },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
      cmdline = {
        keymap = {
          preset = 'cmdline',
          ['<Tab>'] = { 'show_and_insert', 'select_and_accept' },
        },
        completion = { menu = { auto_show = true } },
      },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
  },
}
