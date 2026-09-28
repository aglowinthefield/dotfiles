return {
  "stevearc/conform.nvim",
  cmd = { "ConformInfo" },
  init = function()
    -- Owns save-time formatting instead of conform's format_on_save so the
    -- order is fixed: prettier, then ESLint's fix-all — the same two steps, in
    -- the same order, as silk-remix's lint-staged. Two separate BufWritePre
    -- hooks would run in registration order, which lazy-loading makes
    -- unpredictable.
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("format_on_save", { clear = true }),
      callback = function(args)
        local conform = require("conform")
        -- Only auto-format filetypes that have a formatter configured
        if #conform.list_formatters(args.buf) > 0 then
          conform.format({ bufnr = args.buf, timeout_ms = 3000, lsp_format = "fallback" })
        end
        -- Buffer-local command lspconfig defines when the eslint server attaches
        if vim.api.nvim_buf_get_commands(args.buf, {}).LspEslintFixAll then
          vim.api.nvim_buf_call(args.buf, function()
            vim.cmd("LspEslintFixAll")
          end)
        end
      end,
    })
  end,
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true })
      end,
      desc = "Format Buffer",
    },
  },
  opts = {
    -- The prettier entries mirror, language for language, the per-language
    -- block in silk-remix's tracked .vscode/settings.json. That repo gates
    -- `npm run format:check` in CI and runs prettier through lint-staged on
    -- commit, so without these a buffer saved here is reformatted later by the
    -- pre-commit hook — the diff you read stops being the diff you commit.
    formatters_by_ft = {
      cs = { "csharpier" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      markdown = { "prettier" },
      yaml = { "prettier" },
      css = { "prettier" },
      html = { "prettier" },
    },
    formatters = {
      csharpier = {
        command = "dotnet-csharpier",
        args = { "--write-stdout" },
        stdin = true,
      },
      -- Equivalent of prettier.requireConfig: only format where the project
      -- actually asks for prettier, rather than imposing its defaults on every
      -- repo that happens to contain a .json file. conform resolves the binary
      -- from node_modules first, so the project's pinned version wins.
      prettier = {
        condition = function(_, ctx)
          return vim.fs.find({
            ".prettierrc",
            ".prettierrc.json",
            ".prettierrc.yaml",
            ".prettierrc.yml",
            ".prettierrc.js",
            ".prettierrc.cjs",
            ".prettierrc.mjs",
            "prettier.config.js",
            "prettier.config.cjs",
            "prettier.config.mjs",
          }, { path = ctx.dirname, upward = true })[1] ~= nil
        end,
      },
    },
  },
}
