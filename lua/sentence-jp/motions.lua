local M = {}

--- Compare two {line, col} positions
--- @param a table Position {line, col}
--- @param b table Position {line, col}
--- @return boolean True if a is strictly before b
local function is_before(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
end

--- Check if a line contains only whitespace (a paragraph boundary)
--- @param lnum number Line number (1-indexed)
--- @return boolean True if the line is blank
local function is_blank(lnum)
  local text = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
  return text:match("^%s*$") ~= nil
end

--- Search for a non-whitespace character from a position
--- @param pos table Position {line, col} to search from (excluded)
--- @param flags string searchpos() flags ("W" or "bW")
--- @param stop_line? number Line to stop searching at
--- @return table|nil Position {line, col} of the match, or nil if not found
local function search_nonspace(pos, flags, stop_line)
  local config = require("sentence-jp.config").get()
  local nonspace = config.include_fullwidth_space and "[^[:space:]　]" or "[^[:space:]]"

  vim.api.nvim_win_set_cursor(0, pos)
  local found = vim.fn.searchpos(nonspace, flags, stop_line or 0)
  if found[1] == 0 then
    return nil
  end
  return { found[1], found[2] - 1 }
end

--- Find sentence boundaries at a position within its paragraph
--- @param pos table Position {line, col}
--- @return table|nil boundaries Sentence boundaries, or nil if not found
--- @return number start_line First line of the paragraph
--- @return number end_line Last line of the paragraph
local function boundaries_at(pos)
  local start_line, end_line = require("sentence-jp.utils").find_paragraph_bounds(pos[1])
  local boundaries = require("sentence-jp.patterns").find_sentence_boundaries(pos[1], pos[2], {
    start_line = start_line,
    end_line = end_line,
  })
  return boundaries, start_line, end_line
end

--- Find the start of the next sentence (blank lines count as boundaries, like Vim)
--- @param pos table Cursor position {line, col}
--- @return table|nil Target position {line, col}, or nil if there is none
local function next_start(pos)
  if is_blank(pos[1]) then
    -- From a blank line, go to the first sentence of the next paragraph
    return search_nonspace(pos, "W")
  end

  local boundaries, _, end_line = boundaries_at(pos)
  if boundaries then
    -- Cursor is before the sentence start (e.g. on whitespace between sentences)
    if is_before(pos, boundaries.start) then
      return boundaries.start
    end

    local found = search_nonspace(boundaries.end_inner, "W", end_line)
    if found then
      return found
    end
  end

  -- No more sentences in this paragraph: stop at the blank line below
  if end_line < vim.api.nvim_buf_line_count(0) then
    return { end_line + 1, 0 }
  end
  return nil
end

--- Find the start of the current or previous sentence (blank lines count as boundaries, like Vim)
--- @param pos table Cursor position {line, col}
--- @return table|nil Target position {line, col}, or nil if there is none
local function prev_start(pos)
  if is_blank(pos[1]) then
    -- From a blank line, go to the last sentence of the previous paragraph
    local found = search_nonspace(pos, "bW")
    local boundaries = found and boundaries_at(found)
    return boundaries and boundaries.start
  end

  local boundaries, start_line = boundaries_at(pos)
  if boundaries and is_before(boundaries.start, pos) then
    return boundaries.start
  end

  -- Already at the sentence start: go to the previous sentence in this paragraph
  local found = search_nonspace(boundaries and boundaries.start or pos, "bW", start_line)
  if found then
    local prev = boundaries_at(found)
    return prev and prev.start
  end

  -- First sentence of the paragraph: stop at the blank line above
  if start_line > 1 then
    return { start_line - 1, 0 }
  end
  return nil
end

--- Move the cursor `count` times using `find_target`, stopping when there is no target
--- @param find_target function Function(pos) returning the next position or nil
--- @param count number Number of moves
local function move(find_target, count)
  for _ = 1, count do
    local cursor = vim.api.nvim_win_get_cursor(0)
    local target = find_target(cursor)
    if not target then
      vim.api.nvim_win_set_cursor(0, cursor)
      break
    end
    vim.api.nvim_win_set_cursor(0, target)
  end
end

--- Move cursor to the next sentence
--- @param count? number Number of sentences to move (default: vim.v.count1)
function M.next_sentence(count)
  move(next_start, count or vim.v.count1)
end

--- Move cursor to the previous sentence
--- @param count? number Number of sentences to move backward (default: vim.v.count1)
function M.prev_sentence(count)
  move(prev_start, count or vim.v.count1)
end

--- Setup motion keymaps for sentence navigation
function M.setup_motions()
  local config = require("sentence-jp.config").get()

  if not config.motions.enable then
    return
  end

  local next_key = config.motions.next_sentence
  local prev_key = config.motions.prev_sentence

  -- Set up motions for normal, visual, and operator-pending modes
  vim.keymap.set({ "n", "x", "o" }, next_key, function()
    M.next_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Next sentence (JP/EN)",
  })

  vim.keymap.set({ "n", "x", "o" }, prev_key, function()
    M.prev_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Previous sentence (JP/EN)",
  })
end

return M
