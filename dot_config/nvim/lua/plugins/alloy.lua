-- Grafana Alloy (*.alloy) config: filetype detection, syntax and indent.
-- Plain vim plugin, so load it by filetype rather than at startup.
return {
  "grafana/vim-alloy",
  ft = "alloy",
  init = function()
    vim.filetype.add({ extension = { alloy = "alloy" } })
  end,
}
