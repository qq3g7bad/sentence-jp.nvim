local M = {}

local utils = require("sentence-jp.utils")

--- Select a visual range in the buffer
--- @param start_pos table Position {line, col} for start of selection
--- @param end_pos table Position {line, col} for end of selection
--- @param cursor_at_start? boolean If true, leave the cursor at the start of the selection
local function select_range(start_pos, end_pos, cursor_at_start)
  local mode = vim.fn.mode()
  local is_visual = mode == "v" or mode == "V" or mode == "\22"

  if is_visual then
    -- Leave Visual mode first: "gv" inside Visual mode swaps with the previous selection
    vim.cmd("normal! \27")
    vim.fn.setpos("'<", { 0, start_pos[1], start_pos[2] + 1, 0 })
    vim.fn.setpos("'>", { 0, end_pos[1], end_pos[2] + 1, 0 })
    vim.cmd("normal! gv")
    -- Sentence objects are characterwise, like Vim's
    if vim.fn.mode() ~= "v" then
      vim.cmd("normal! v")
    end
  else
    vim.api.nvim_win_set_cursor(0, start_pos)
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(0, end_pos)
  end

  if cursor_at_start then
    vim.cmd("normal! o")
  end
end

--- Get sentence region boundaries at current cursor position
--- @return table|nil Sentence boundaries {start, end_inner, end_around} or nil if not found
function M.get_sentence_region()
  return (utils.sentence_at(vim.api.nvim_win_get_cursor(0)))
end

--- Check if two positions are the same
--- @param a table Position {line, col}
--- @param b table Position {line, col}
--- @return boolean True if a and b are equal
local function same_pos(a, b)
  return a[1] == b[1] and a[2] == b[2]
end

--- Extend a selection end forward by one unit
--- Like Vim, for "is" the whitespace between sentences counts as a unit of its own;
--- for "as" each unit is a sentence with its trailing whitespace.
--- @param pos table Current end of the selection {line, col}
--- @param around boolean True for "as", false for "is"
--- @return table|nil new_end New end position, or nil if there is nothing more in the paragraph
--- @return table|nil boundaries Boundaries of the sentence the new end belongs to
local function next_unit_end(pos, around)
  local boundaries, _, end_line = utils.sentence_at(pos)
  if not around and boundaries and same_pos(pos, boundaries.end_inner) then
    if utils.is_before(boundaries.end_inner, boundaries.end_around) then
      return boundaries.end_around, boundaries
    end
  end

  local next_char = utils.search_nonspace(pos, "W", end_line)
  if not next_char then
    return nil
  end
  local next_boundaries = utils.sentence_at(next_char)
  if not next_boundaries then
    return nil
  end
  return around and next_boundaries.end_around or next_boundaries.end_inner, next_boundaries
end

--- Extend a selection start backward by one unit (see next_unit_end)
--- @param pos table Current start of the selection {line, col}
--- @param around boolean True for "as", false for "is"
--- @return table|nil New start position, or nil if there is nothing more in the paragraph
local function prev_unit_start(pos, around)
  local start_line = utils.find_paragraph_bounds(pos[1])

  -- Whitespace after a sentence belongs to that sentence
  local probe = pos
  local text = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1] or ""
  local char = vim.fn.strcharpart(text:sub(pos[2] + 1), 0, 1)
  if char:match("^%s$") or char == "　" then
    probe = utils.search_nonspace(pos, "bW", start_line) or pos
  end

  local boundaries = utils.sentence_at(probe)
  if not boundaries then
    return nil
  end
  if utils.is_before(boundaries.start, pos) then
    return boundaries.start
  end

  local prev_char = utils.search_nonspace(boundaries.start, "bW", start_line)
  if not prev_char then
    return nil
  end

  -- For "is", the whitespace before the sentence is a unit of its own
  if not around and prev_char[1] == boundaries.start[1] then
    local prev_text = vim.api.nvim_buf_get_lines(0, prev_char[1] - 1, prev_char[1], false)[1] or ""
    local char = vim.fn.strcharpart(prev_text:sub(prev_char[2] + 1), 0, 1)
    local gap_start = { prev_char[1], prev_char[2] + #char }
    if utils.is_before(gap_start, boundaries.start) then
      return gap_start
    end
  end

  local prev_boundaries = utils.sentence_at(prev_char)
  return prev_boundaries and prev_boundaries.start
end

--- Select `count` sentences starting at the cursor
--- @param around boolean True for "as", false for "is"
--- @param count number Number of units
local function select_sentences(around, count)
  local first = M.get_sentence_region()
  if not first then
    return
  end

  local last = first
  local end_pos = around and first.end_around or first.end_inner
  for _ = 2, count do
    local new_end, boundaries = next_unit_end(end_pos, around)
    if not new_end then
      break
    end
    end_pos, last = new_end, boundaries
  end

  -- Like Vim's "as": without trailing whitespace, include the leading whitespace instead
  local start_pos = first.start
  if around and same_pos(last.end_inner, last.end_around) then
    start_pos = first.start_around
  end

  select_range(start_pos, end_pos)
end

--- Extend the current visual selection by `count` units in the direction of the cursor
--- @param around boolean True for "as", false for "is"
--- @param count number Number of units
local function extend_selection(around, count)
  local anchor_mark = vim.fn.getpos("v")
  local anchor = { anchor_mark[2], anchor_mark[3] - 1 }
  local cursor = vim.api.nvim_win_get_cursor(0)
  local backward = utils.is_before(cursor, anchor)

  for _ = 1, count do
    local target
    if backward then
      target = prev_unit_start(cursor, around)
    else
      target = next_unit_end(cursor, around)
    end
    if not target then
      break
    end
    cursor = target
  end

  if backward then
    select_range(cursor, anchor, true)
  else
    select_range(anchor, cursor)
  end
end

--- Select (or extend the visual selection by) sentences
--- @param around boolean True for "as", false for "is"
local function select_object(around)
  local count = vim.v.count1
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local anchor = vim.fn.getpos("v")
    local cursor = vim.api.nvim_win_get_cursor(0)
    -- Like Vim, a selection of more than one character is extended
    if anchor[2] ~= cursor[1] or anchor[3] - 1 ~= cursor[2] then
      extend_selection(around, count)
      return
    end
  end
  select_sentences(around, count)
end

--- Select inner sentence (includes punctuation, excludes trailing whitespace)
--- Implements the 'is' text object
function M.select_inner_sentence()
  select_object(false)
end

--- Select around sentence (includes punctuation and trailing whitespace, or leading whitespace if none)
--- Implements the 'as' text object
function M.select_around_sentence()
  select_object(true)
end

--- Text objects: {key name in textobject.keys, <Plug> name, callback, description}
local objects = {
  { "inner", "<Plug>(sentence-jp-inner)", M.select_inner_sentence, "Inner sentence (includes punctuation, JP/EN)" },
  {
    "around",
    "<Plug>(sentence-jp-around)",
    M.select_around_sentence,
    "Around sentence (with punctuation + space, JP/EN)",
  },
}

--- Define the <Plug> mappings (always available, even when textobject.enable is false)
function M.setup_plug()
  for _, object in ipairs(objects) do
    utils.map({ "o", "x" }, object[2], object[3], { silent = true, desc = object[4] })
  end
end

--- Setup text object keymaps for sentence selection
--- @param buffer? number Buffer handle for buffer-local mappings (nil for global)
function M.setup(buffer)
  local config = require("sentence-jp.config").get()

  if not config.textobject.enable then
    return
  end

  for _, object in ipairs(objects) do
    local key = config.textobject.keys[object[1]]
    if key and key ~= "" then
      utils.map({ "o", "x" }, key, object[3], { silent = true, buffer = buffer, desc = object[4] })
    end
  end
end

return M
