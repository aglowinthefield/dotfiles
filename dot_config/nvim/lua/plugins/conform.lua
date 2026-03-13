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
    formatters_by_ft = {
      cs = { "csharpier" },
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
    },
  },
}
