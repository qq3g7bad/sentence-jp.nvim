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

--- Get the start of the sentence a non-space character belongs to, when it is a list marker before it
--- @param pos table Position {line, col} of a non-space character
--- @return table Position {line, col}
local function skip_marker(pos)
  local boundaries = boundaries_at(pos)
  if boundaries and is_before(pos, boundaries.start) then
    return boundaries.start
  end
  return pos
end

--- Find the start of the next sentence (blank lines count as boundaries, like Vim)
--- @param pos table Cursor position {line, col}
--- @return table|nil target Target position {line, col}, or nil if there is none
--- @return boolean|nil inclusive True if the target is the last character of the buffer (like Vim's ")")
local function next_start(pos)
  if utils.is_blank_line(pos[1]) then
    -- From a blank line, go to the first sentence of the next paragraph
    local found = search_nonspace(pos, "W")
    return found and skip_marker(found)
  end

  local boundaries, _, end_line = boundaries_at(pos)
  if boundaries then
    -- Cursor is before the sentence start (e.g. on whitespace between sentences)
    if is_before(pos, boundaries.start) then
      return boundaries.start
    end

    local found = search_nonspace(boundaries.end_inner, "W", end_line)
    if found then
      return skip_marker(found)
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

  -- Already at the sentence start: go to the previous sentence in this paragraph (skipping a list marker)
  local from = boundaries and boundaries.start or pos
  local found = search_nonspace(utils.list_marker_start(from) or from, "bW", start_line)
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

--- Motions: {key name in config.motions, <Plug> name, callback, description}
local motions = {
  {
    "next_sentence",
    "<Plug>(sentence-jp-next)",
    function()
      M.next_sentence()
    end,
    "Next sentence (JP/EN)",
  },
  {
    "prev_sentence",
    "<Plug>(sentence-jp-prev)",
    function()
      M.prev_sentence()
    end,
    "Previous sentence (JP/EN)",
  },
}

--- Define the <Plug> mappings (always available, even when motions.enable is false)
function M.setup_plug()
  for _, motion in ipairs(motions) do
    utils.map({ "n", "x", "o" }, motion[2], motion[3], { silent = true, desc = motion[4] })
  end
end

--- Setup motion keymaps for sentence navigation
--- @param buffer? number Buffer handle for buffer-local mappings (nil for global)
function M.setup_motions(buffer)
  local config = require("sentence-jp.config").get()

  if not config.motions.enable then
    return
  end

  -- Set up motions for normal, visual, and operator-pending modes
  for _, motion in ipairs(motions) do
    local key = config.motions[motion[1]]
    if key and key ~= "" then
      utils.map({ "n", "x", "o" }, key, motion[3], { silent = true, buffer = buffer, desc = motion[4] })
    end
  end
end

return M
