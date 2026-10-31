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

return M
