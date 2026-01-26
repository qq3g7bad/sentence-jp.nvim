local M = {}

--- Setup the sentence-jp plugin with user configuration
--- @param user_config? table User configuration to merge with defaults
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

--- Get the current configuration
--- @return table The current configuration table
function M.get_config()
  return require("sentence-jp.config").get()
end

--- Find sentence boundaries at the current cursor position
--- @return table|nil Sentence boundaries {start, end_inner, end_around} or nil if not found
function M.find_sentence()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local utils = require("sentence-jp.utils")
  local start_line, end_line = utils.find_paragraph_bounds()

  return require("sentence-jp.patterns").find_sentence_boundaries(cursor[1], cursor[2], {
    start_line = start_line,
    end_line = end_line,
  })
end

return M
