return {
  "stevedylandev/compline-nvim",
  lazy = false,
  priority = 1000,
  config = function()
    -- compline gives @keyword (#c0b8bc) and @string (#b8c4b8) almost the same
    -- luminance, so SQL inside a sql`...` template in TS, which is a string,
    -- reads as one flat colour. Override only the sql-language captures so
    -- everything else keeps the theme's palette.
    local function sql_contrast()
      local set = vim.api.nvim_set_hl
      set(0, "@keyword.sql", { fg = "#8fb0d6", bold = true })
      set(0, "@keyword.operator.sql", { fg = "#8fb0d6", bold = true })
      set(0, "@keyword.modifier.sql", { fg = "#8fb0d6" })
      set(0, "@keyword.conditional.sql", { fg = "#8fb0d6" })
      set(0, "@type.builtin.sql", { fg = "#d6a77a" })
      set(0, "@function.call.sql", { fg = "#c79fd0" })
    end
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "compline",
      group = vim.api.nvim_create_augroup("compline_sql", { clear = true }),
      callback = sql_contrast,
    })
    vim.cmd.colorscheme("compline")
  end,
}
