-- Buffer helpers shared by specs.
-- Text objects and motions are run with `normal` (no `!`) so the plugin's mappings are used.

local M = {}

--- Replace the current buffer with `lines`
--- @param lines string[]
function M.buf(lines)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

--- @return string[] Current buffer lines
function M.get()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

--- Put the cursor on the first occurrence of `substr` in line `lnum`
--- @param lnum number
--- @param substr string
function M.at(lnum, substr)
  local col = M.get()[lnum]:find(substr, 1, true)
  assert(col, ("%q not found in line %d"):format(substr, lnum))
  vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
end

--- @return string "lnum:<two chars under cursor>"
function M.ch()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1] .. ":" .. vim.fn.strcharpart(M.get()[cursor[1]]:sub(cursor[2] + 1), 0, 2)
end

--- Run normal-mode keys through mappings
--- @param keys string
function M.normal(keys)
  vim.cmd("normal " .. keys)
end

return M
