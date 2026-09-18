return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
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
    format_on_save = function(bufnr)
      -- Only auto-format filetypes that have a formatter configured
      if #require("conform").list_formatters(bufnr) == 0 then
        return
      end
      return { timeout_ms = 3000, lsp_format = "fallback" }
    end,
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
