local M = {}

--- Select a visual range in the buffer
--- @param start_pos table Position {line, col} for start of selection
--- @param end_pos table Position {line, col} for end of selection
local function select_range(start_pos, end_pos)
  local mode = vim.fn.mode()
  local is_visual = mode == "v" or mode == "V" or mode == "\22"

  if is_visual then
    vim.fn.setpos("'<", { 0, start_pos[1], start_pos[2] + 1, 0 })
    vim.fn.setpos("'>", { 0, end_pos[1], end_pos[2] + 1, 0 })
    vim.cmd("normal! gv")
    return
  end

  vim.api.nvim_win_set_cursor(0, start_pos)
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(0, end_pos)
end

--- Get paragraph bounds for current cursor position
--- @return number start_line First non-blank line of paragraph
--- @return number end_line Last non-blank line of paragraph
local function get_paragraph_bounds()
  local utils = require("sentence-jp.utils")
  local start_line, end_line = utils.find_paragraph_bounds()
  return start_line, end_line
end

--- Get sentence region boundaries at current cursor position
--- @return table|nil Sentence boundaries {start, end_inner, end_around} or nil if not found
function M.get_sentence_region()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local patterns = require("sentence-jp.patterns")
  local start_line, end_line = get_paragraph_bounds()

  return patterns.find_sentence_boundaries(cursor[1], cursor[2], {
    start_line = start_line,
    end_line = end_line,
  })
end

--- Select inner sentence (includes punctuation, excludes trailing whitespace)
--- Implements the 'is' text object
function M.select_inner_sentence()
  local boundaries = M.get_sentence_region()

  if not boundaries then
    return
  end

  select_range(boundaries.start, boundaries.end_inner)
end

--- Select around sentence (includes punctuation and trailing whitespace, or leading whitespace if none)
--- Implements the 'as' text object
function M.select_around_sentence()
  local boundaries = M.get_sentence_region()

  if not boundaries then
    return
  end

  select_range(boundaries.start_around, boundaries.end_around)
end

--- Setup text object keymaps for sentence selection
function M.setup()
  local config = require("sentence-jp.config").get()

  if not config.textobject.enable then
    return
  end

  -- Always use 's' key - works for both Japanese and English!
  require("sentence-jp.utils").map({ "o", "x" }, "is", function()
    M.select_inner_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Inner sentence (includes punctuation, JP/EN)",
  })

  require("sentence-jp.utils").map({ "o", "x" }, "as", function()
    M.select_around_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Around sentence (with punctuation + space, JP/EN)",
  })
end

return M
