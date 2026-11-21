return {
  "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
  event = "LspAttach",
  config = function()
    require("lsp_lines").setup()
    -- Disable default virtual text since lsp_lines replaces it
    -- Use vim.schedule to run after LazyVim's own diagnostic config
    vim.schedule(function()
      vim.diagnostic.config({ virtual_text = false })
    end)
  end,
}
