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
      local light = vim.o.background == "light"
      local kw = light and "#2f5f9a" or "#8fb0d6"
      set(0, "@keyword.sql", { fg = kw, bold = true })
      set(0, "@keyword.operator.sql", { fg = kw, bold = true })
      set(0, "@keyword.modifier.sql", { fg = kw })
      set(0, "@keyword.conditional.sql", { fg = kw })
      set(0, "@type.builtin.sql", { fg = light and "#8a5a22" or "#d6a77a" })
      set(0, "@function.call.sql", { fg = light and "#7a3f8a" or "#c79fd0" })
    end

    -- The plugin ships a dark palette only. The light one is the kitty
    -- "Compline Soft Light" palette (dot_config/kitty/create_light-theme.auto.conf).
    local light_palette = {
      base00 = "#e8e6e0", base01 = "#dedcd5", base02 = "#c3cdd4", base03 = "#6b7178",
      base04 = "#575d65", base05 = "#3a3f46", base06 = "#3a3f46", base07 = "#f0eee9",
      base08 = "#8a4646", base09 = "#a05a5a", base0A = "#7a5a28", base0B = "#466352",
      base0C = "#3b6e6c", base0D = "#47596b", base0E = "#615878", base0F = "#4d8280",
    }

    -- colors/compline.vim always loads the dark palette. Changing 'background'
    -- makes Neovim re-source it and fire ColorScheme, so paint the light
    -- palette over it here. Neovim queries the terminal (OSC 11) for
    -- 'background' and updates it when the OS appearance flips.
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "compline",
      group = vim.api.nvim_create_augroup("compline_variant", { clear = true }),
      callback = function()
        if vim.o.background == "light" then
          require("compline-colorscheme").setup(light_palette)
          vim.g.colors_name = "compline"
        end
        sql_contrast()
      end,
    })
    vim.cmd.colorscheme("compline")
  end,
}
