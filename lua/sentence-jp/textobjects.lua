local M = {}

--- Select a visual range in the buffer
--- @param start_pos table Position {line, col} for start of selection
--- @param end_pos table Position {line, col} for end of selection
--- @param linewise? boolean If true, use linewise visual mode
local function select_range(start_pos, end_pos, linewise)
  local mode = vim.fn.mode()
  local is_visual = mode == "v" or mode == "V" or mode == "\22"

  if is_visual then
    local s_col = (start_pos[2] or 0) + 1
    local e_col = (end_pos[2] or 0) + 1
    if linewise then
      s_col = 1
      e_col = 1
    end

    vim.fn.setpos("'<", { 0, start_pos[1], s_col, 0 })
    vim.fn.setpos("'>", { 0, end_pos[1], e_col, 0 })
    vim.cmd("normal! gv")

    if linewise and mode ~= "V" then
      vim.cmd("normal! V")
    end

    return
  end

  vim.api.nvim_win_set_cursor(0, start_pos)
  if linewise then
    vim.cmd("normal! V")
  else
    vim.cmd("normal! v")
  end
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

  select_range(boundaries.start, boundaries.end_inner, boundaries.linewise)
end

--- Select around sentence (includes punctuation and trailing whitespace)
--- Implements the 'as' text object
function M.select_around_sentence()
  local boundaries = M.get_sentence_region()

  if not boundaries then
    return
  end

  select_range(boundaries.start, boundaries.end_around, boundaries.linewise)
end

--- Setup text object keymaps for sentence selection
function M.setup()
  local config = require("sentence-jp.config").get()

  if not config.textobject.enable then
    return
  end

  -- Always use 's' key - works for both Japanese and English!
  vim.keymap.set({ "o", "x" }, "is", function()
    M.select_inner_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Inner sentence (includes punctuation, JP/EN)",
  })

  vim.keymap.set({ "o", "x" }, "as", function()
    M.select_around_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Around sentence (with punctuation + space, JP/EN)",
  })
end

return M
