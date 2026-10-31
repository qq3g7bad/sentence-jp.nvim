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

--- Find sentence boundaries at a position within its paragraph
--- @param pos table Position {line, col}
--- @return table|nil boundaries Sentence boundaries, or nil if not found
--- @return number start_line First line of the paragraph
--- @return number end_line Last line of the paragraph
function M.sentence_at(pos)
  local start_line, end_line = M.find_paragraph_bounds(pos[1])
  local boundaries = require("sentence-jp.patterns").find_sentence_boundaries(pos[1], pos[2], {
    start_line = start_line,
    end_line = end_line,
  })
  return boundaries, start_line, end_line
end

--- Mappings created by the plugin, as {modes, lhs} pairs
local mappings = {}

--- Create a keymap and remember it so that it can be removed by unmap_all()
--- @param modes string[] Modes
--- @param lhs string Left-hand side
--- @param rhs function Callback
--- @param opts table Options passed to vim.keymap.set()
function M.map(modes, lhs, rhs, opts)
  vim.keymap.set(modes, lhs, rhs, opts)
  table.insert(mappings, { modes, lhs })
end

--- Remove all keymaps created by map()
function M.unmap_all()
  for _, mapping in ipairs(mappings) do
    for _, mode in ipairs(mapping[1]) do
      pcall(vim.keymap.del, mode, mapping[2])
    end
  end
  mappings = {}
end

return M
