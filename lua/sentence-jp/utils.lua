local M = {}

--- Build a Vim regex matching a blank line (a paragraph boundary)
--- @return string Vim regex pattern
function M.blank_line_pattern()
  local config = require("sentence-jp.config").get()
  return config.include_fullwidth_space and "^[[:space:]　]*$" or "^\\s*$"
end

--- Check if a line contains only whitespace (a paragraph boundary)
--- @param lnum number Line number (1-indexed)
--- @return boolean True if the line is blank
function M.is_blank_line(lnum)
  local text = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
  return vim.fn.match(text, M.blank_line_pattern()) ~= -1
end

--- Find the start and end lines of the current paragraph (bounded by blank lines)
--- @param line? number Optional line number to check (defaults to cursor line)
--- @return number start_line First non-blank line of paragraph
--- @return number end_line Last non-blank line of paragraph
--- @return number|nil next_blank Line number of next blank line, or nil if none
function M.find_paragraph_bounds(line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  local cursor = vim.api.nvim_win_get_cursor(0)
  local buf_last = vim.api.nvim_buf_line_count(0)

  local start_line = 1
  local end_line = buf_last

  local blank = M.blank_line_pattern()

  vim.api.nvim_win_set_cursor(0, { line, 0 })
  local prev_blank = vim.fn.search(blank, "bnW")
  if prev_blank ~= 0 then
    start_line = prev_blank + 1
  end

  vim.api.nvim_win_set_cursor(0, { line, 0 })
  local next_blank = vim.fn.search(blank, "nW")
  if next_blank ~= 0 then
    end_line = next_blank - 1
  end

  vim.api.nvim_win_set_cursor(0, cursor)

  return start_line, end_line, next_blank
end

--- Compare two {line, col} positions
--- @param a table Position {line, col}
--- @param b table Position {line, col}
--- @return boolean True if a is strictly before b
function M.is_before(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
end

--- Search for a non-whitespace character from a position
--- @param pos table Position {line, col} to search from (excluded)
--- @param flags string searchpos() flags ("W" or "bW")
--- @param stop_line? number Line to stop searching at
--- @return table|nil Position {line, col} of the match, or nil if not found
function M.search_nonspace(pos, flags, stop_line)
  local config = require("sentence-jp.config").get()
  local nonspace = config.include_fullwidth_space and "[^[:space:]　]" or "[^[:space:]]"

  vim.api.nvim_win_set_cursor(0, pos)
  local found = vim.fn.searchpos(nonspace, flags, stop_line or 0)
  if found[1] == 0 then
    return nil
  end
  return { found[1], found[2] - 1 }
end

--- Get the column where the text of a list item starts (e.g. 2 for "- foo")
--- @param lnum number Line number (1-indexed)
--- @return number|nil Byte column after the list marker, or nil if the line is not a list item (or list_items is off)
function M.list_content_col(lnum)
  local list_items = require("sentence-jp.config").get().list_items
  if not (list_items and list_items.enable) then
    return nil
  end
  local text = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
  local col = vim.fn.matchend(text, list_items.pattern)
  return col > 0 and col or nil
end

--- Get the start of the list marker when a position is on the marker or at the start of the item's text
--- @param pos table Position {line, col}
--- @return table|nil Position {line, 0}, or nil if pos is not at the start of a list item
function M.list_marker_start(pos)
  local col = M.list_content_col(pos[1])
  if col and pos[2] <= col then
    return { pos[1], 0 }
  end
  return nil
end

--- Narrow paragraph lines to the list item (or the text before the first item) containing a line
--- @param line number Line number (1-indexed)
--- @param start_line number First line of the paragraph
--- @param end_line number Last line of the paragraph
--- @return number start_line First line of the block
--- @return number end_line Last line of the block
--- @return number|nil start_col Column where the text of the list item starts, if the block is a list item
local function block_bounds(line, start_line, end_line)
  local list_items = require("sentence-jp.config").get().list_items
  if not (list_items and list_items.enable) then
    return start_line, end_line, nil
  end

  local start_col
  for lnum = line, start_line, -1 do
    start_col = M.list_content_col(lnum)
    if start_col then
      start_line = lnum
      break
    end
  end
  for lnum = line + 1, end_line do
    if M.list_content_col(lnum) then
      end_line = lnum - 1
      break
    end
  end
  return start_line, end_line, start_col
end

--- Find sentence boundaries at a position within its paragraph (and list item, see list_items)
--- @param pos table Position {line, col}
--- @return table|nil boundaries Sentence boundaries, or nil if not found
--- @return number start_line First line of the paragraph
--- @return number end_line Last line of the paragraph
function M.sentence_at(pos)
  local start_line, end_line = M.find_paragraph_bounds(pos[1])
  local block_start, block_end, start_col = block_bounds(pos[1], start_line, end_line)
  local boundaries = require("sentence-jp.patterns").find_sentence_boundaries(pos[1], pos[2], {
    start_line = block_start,
    end_line = block_end,
    start_col = start_col,
  })
  return boundaries, start_line, end_line
end

--- Mappings created by the plugin, as {modes, lhs, buffer} entries (buffer is nil for global mappings)
local mappings = {}

--- Create a keymap and remember it so that it can be removed by unmap_all() / unmap_buffer()
--- @param modes string[] Modes
--- @param lhs string Left-hand side
--- @param rhs function Callback
--- @param opts table Options passed to vim.keymap.set() (opts.buffer makes it buffer-local)
function M.map(modes, lhs, rhs, opts)
  vim.keymap.set(modes, lhs, rhs, opts)
  table.insert(mappings, { modes, lhs, opts.buffer })
end

--- Remove keymaps created by map() for which `should_remove(buffer)` is true
--- @param should_remove function Function(buffer) returning true to remove the mapping
local function unmap_if(should_remove)
  local kept = {}
  for _, mapping in ipairs(mappings) do
    local modes, lhs, buffer = mapping[1], mapping[2], mapping[3]
    if should_remove(buffer) then
      for _, mode in ipairs(modes) do
        pcall(vim.keymap.del, mode, lhs, { buffer = buffer })
      end
    else
      table.insert(kept, mapping)
    end
  end
  mappings = kept
end

--- Remove all keymaps created by map()
function M.unmap_all()
  unmap_if(function()
    return true
  end)
end

--- Remove the buffer-local keymaps created by map() for a buffer
--- @param buffer number Buffer handle
function M.unmap_buffer(buffer)
  unmap_if(function(mapped_buffer)
    return mapped_buffer == buffer
  end)
end

return M
