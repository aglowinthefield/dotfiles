-- Token (ThorstenRhau/token). Needs Neovim 0.12+.
--
-- Pinned to the release tag range rather than main: the plugin regenerates its
-- contrib/ extras on every release, and the terminal palette in
-- ~/code/alacritty-tools (share/colors/token-{dark,light}.toml) is a manual
-- conversion of contrib/kitty. Tracking main would let the editor drift ahead
-- of the terminal without warning.
--
-- No `background` is set here on purpose. Neovim queries the terminal for its
-- background colour (OSC 11) and sets `background` from the answer, so
-- `alacritty-theme dark|light` already flips the editor with everything else.
return {
  "ThorstenRhau/token",
  version = "*",
  lazy = false,
  priority = 1000,
  opts = {
    -- gitsigns and snacks are both in this config; the rest of the plugin
    -- integrations would be dead weight.
    plugins = {
      all = false,
      gitsigns = true,
      snacks = true,
    },
  },
}
