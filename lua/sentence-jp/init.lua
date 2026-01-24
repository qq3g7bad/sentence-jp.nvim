local M = {}

function M.setup(user_config)
  -- 1. Initialize configuration
  local config = require("sentence-jp.config")
  config.setup(user_config or {})

  -- 2. Setup text objects
  if config.get().textobject.enable then
    require("sentence-jp.textobjects").setup()
  end

  -- 3. Setup motion commands
  if config.get().motions.enable then
    require("sentence-jp.motions").setup_motions()
  end
end

function M.get_config()
  return require("sentence-jp.config").get()
end

function M.find_sentence()
  return require("sentence-jp.patterns").find_sentence_boundaries(
    vim.api.nvim_win_get_cursor(0)[1],
    vim.api.nvim_win_get_cursor(0)[2]
  )
end

return M
