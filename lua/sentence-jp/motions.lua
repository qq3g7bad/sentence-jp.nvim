local M = {}

local utils = require("sentence-jp.utils")
local is_before = utils.is_before
local search_nonspace = utils.search_nonspace
local boundaries_at = utils.sentence_at

--- Get the position of the last character of a line
--- @param lnum number Line number (1-indexed)
--- @return table Position {line, col}
local function last_char_pos(lnum)
  local text = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
  local last = vim.fn.strcharpart(text, vim.fn.strchars(text) - 1)
  return { lnum, #text - #last }
end

--- Find the start of the next sentence (blank lines count as boundaries, like Vim)
--- @param pos table Cursor position {line, col}
--- @return table|nil target Target position {line, col}, or nil if there is none
--- @return boolean|nil inclusive True if the target is the last character of the buffer (like Vim's ")")
local function next_start(pos)
  if utils.is_blank_line(pos[1]) then
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

  -- Last sentence of the buffer: go to its last character
  local last = last_char_pos(end_line)
  if is_before(pos, last) then
    return last, true
  end
  return nil
end

--- Find the start of the current or previous sentence (blank lines count as boundaries, like Vim)
--- @param pos table Cursor position {line, col}
--- @return table|nil Target position {line, col}, or nil if there is none
local function prev_start(pos)
  if utils.is_blank_line(pos[1]) then
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
--- @param find_target function Function(pos) returning the next position (or nil) and whether it is inclusive
--- @param count number Number of moves
local function move(find_target, count)
  local origin = vim.api.nvim_win_get_cursor(0)
  local cursor = origin
  local inclusive = false
  for _ = 1, count do
    local target, target_inclusive = find_target(cursor)
    if not target then
      break
    end
    cursor, inclusive = target, target_inclusive or false
  end

  vim.api.nvim_win_set_cursor(0, origin)
  if vim.fn.mode() == "n" and (cursor[1] ~= origin[1] or cursor[2] ~= origin[2]) then
    -- Like Vim's "(" and ")", record the position in the jumplist
    vim.cmd("normal! m'")
  end
  if inclusive and vim.fn.mode(1):sub(1, 2) == "no" then
    -- Operator-pending: select up to and including the last character (e.g. "d)" on the last sentence)
    vim.cmd("normal! v")
  end
  vim.api.nvim_win_set_cursor(0, cursor)
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
  utils.map({ "n", "x", "o" }, next_key, function()
    M.next_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Next sentence (JP/EN)",
  })

  utils.map({ "n", "x", "o" }, prev_key, function()
    M.prev_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Previous sentence (JP/EN)",
  })
end

return M
