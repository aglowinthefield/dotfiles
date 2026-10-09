return {
  {
    'neovim/nvim-lspconfig',
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim" },
      "b0o/SchemaStore.nvim",
      -- blink registers its client capabilities (snippets, resolve, ...) in
      -- vim.lsp.config('*') when it loads; it must load before any server
      -- starts, or those servers run without them
      "saghen/blink.cmp",
    },

    config = function()
      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim' }
            }
          }
        }
      })

      -- sourcekit-lsp ships with Xcode (not Mason-managed)
      -- Requires buildServer.json for Xcode projects (generate with xcode-build-server)
      if require('config.runtime').has('sourcekit-lsp') then
        vim.lsp.config('sourcekit', {
          cmd = { 'sourcekit-lsp' },
          filetypes = { 'swift', 'objc', 'objcpp', 'c', 'cpp' },
          root_markers = { 'buildServer.json', 'Package.swift', '*.xcodeproj', '.git' },
        })
        vim.lsp.enable('sourcekit')
      end

      -- tailwindcss registers `**/` file watchers from the workspace root, and
      -- in silk-remix that root holds ~1.2M directories (node_modules plus
      -- .worktrees' 60-odd checkouts). Without inotifywait, nvim walked the
      -- tree itself and sat at 100% CPU; with it, `inotifywait --recursive`
      -- blows through fs.inotify.max_user_watches (524288), errors, and eats
      -- the user's watch budget while it tries. nvim only excludes .git, so
      -- there's no way to scope it. The watchers only pick up tailwind
      -- config/lockfile edits, which :LspRestart covers. The exclude also
      -- stops the server creating a project for every worktree's copy of
      -- tailwind.config.ts.
      vim.lsp.config('tailwindcss', {
        capabilities = {
          workspace = { didChangeWatchedFiles = { dynamicRegistration = false } },
        },
        settings = {
          tailwindCSS = {
            files = {
              exclude = { '**/.git/**', '**/node_modules/**', '**/.hg/**', '**/.svn/**', '**/.worktrees/**' },
            },
          },
        },
      })

      -- SchemaStore catalog: package.json, tsconfig, .eslintrc, eas.json,
      -- GitHub workflows, compose files, ... validated and completed by name
      vim.lsp.config('jsonls', {
        settings = {
          json = {
            schemas = require('schemastore').json.schemas(),
            validate = { enable = true },
          },
        },
      })
      vim.lsp.config('yamlls', {
        settings = {
          yaml = {
            -- yamlls's own catalog fetch would duplicate SchemaStore.nvim's
            schemaStore = { enable = false, url = "" },
            schemas = require('schemastore').yaml.schemas(),
          },
        },
      })

      local ft_lsp_group = vim.api.nvim_create_augroup("ft_lsp_group", { clear = true })
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        pattern = { "docker-compose.yaml", "compose.yaml" },
        group = ft_lsp_group,
        desc = "Fix the issue where the LSP does not start with docker-compose.",
        callback = function()
          vim.opt.filetype = "yaml.docker-compose"
        end
      })

      -- Full multi-line messages only under the cursor's line; a short inline
      -- hint everywhere else, so a file full of lint warnings doesn't push the
      -- code around
      vim.diagnostic.config({
        virtual_lines = { current_line = true },
        virtual_text = { current_line = false, spacing = 2 },
        severity_sort = true,
        float = { border = 'rounded', source = true },
      })

    end
  },
  {
    'mason-org/mason-lspconfig.nvim',
    opts = {
      ensure_installed = {
        'lua_ls',
        'pyright',
        'neocmake',
        'clangd',
        'docker_language_server',
        'fish_lsp',
        'gopls',
        -- vtsls rather than ts_ls: it drives the same tsserver but handles a
        -- large multi-project workspace better, which is what silk-remix is —
        -- 6 apps and 6 packages, ~3.6k TS files, with packages/shared imported
        -- as source rather than as a built package.
        'vtsls',
        -- Surfaces lint errors in-editor instead of only in CI
        'eslint',
        -- className completion/hover (see the tailwindcss config above)
        'tailwindcss',
        'jsonls',
        'yamlls',
      },
      -- ts_ls got installed at some point and was being auto-enabled alongside
      -- vtsls, doubling tsserver memory and every diagnostic/completion
      automatic_enable = { exclude = { 'ts_ls' } },
    },
    lazy = false,
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "neovim/nvim-lspconfig",
    }
  },
}
