local M = {}

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

  vim.api.nvim_win_set_cursor(0, { line, 0 })
  local prev_blank = vim.fn.search("^\\s*$", "bnW")
  if prev_blank ~= 0 then
    start_line = prev_blank + 1
  end

  vim.api.nvim_win_set_cursor(0, { line, 0 })
  local next_blank = vim.fn.search("^\\s*$", "nW")
  if next_blank ~= 0 then
    end_line = next_blank - 1
  end

  vim.api.nvim_win_set_cursor(0, cursor)

  return start_line, end_line, next_blank
end

return M
