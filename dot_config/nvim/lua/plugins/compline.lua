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

    -- The plugin ships a dark palette only. Light is Lauds, Compline's light
    -- sibling from github.com/joshuablais/compline (nvim/lauds/theme.lua,
    -- ghostty/lauds, alacritty/lauds.toml), mapped onto the plugin's base16
    -- slots so diff, git and plugin highlights still apply.
    local light_palette = {
      base00 = "#f0efeb", base01 = "#e5e3e0", base02 = "#d8d6d3", base03 = "#7d7a75",
      base04 = "#4a4d51", base05 = "#1a1d21", base06 = "#2d2a27", base07 = "#f5f4f2",
      base08 = "#8b6666", base09 = "#7a6d5a", base0A = "#8b7e52", base0B = "#5a6b5a",
      base0C = "#64757d", base0D = "#5a6b7a", base0E = "#546470", base0F = "#4d6b6b",
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
