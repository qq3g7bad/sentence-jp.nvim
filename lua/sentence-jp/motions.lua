local M = {}

--- Move cursor to the next sentence
--- @param count? number Number of sentences to move (default: vim.v.count1)
function M.next_sentence(count)
  count = count or vim.v.count1
  local config = require("sentence-jp.config").get()
  local pattern = require("sentence-jp.patterns").build_forward_pattern(config)

  -- Search for nearest sentence boundary (Japanese OR English)
  for i = 1, count do
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_text = vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1] or ""
    if line_text:match("^%s*$") then
      local next_nonblank = vim.fn.search("^\\S", "W")
      if next_nonblank ~= 0 then
        vim.api.nvim_win_set_cursor(0, { next_nonblank, 0 })
      end
      break
    end

    local utils = require("sentence-jp.utils")
    local _, end_line, next_blank = utils.find_paragraph_bounds()

    local stop_line = end_line

    local result = vim.fn.search(pattern, "eW", stop_line)
    if result == 0 then
      if next_blank ~= 0 then
        vim.api.nvim_win_set_cursor(0, { next_blank, 0 })
      end
      break -- No more sentences before blank line
    end
  end
end

--- Move cursor to the previous sentence
--- @param count? number Number of sentences to move backward (default: vim.v.count1)
function M.prev_sentence(count)
  count = count or vim.v.count1
  local config = require("sentence-jp.config").get()
  local pattern = require("sentence-jp.patterns").build_backward_pattern(config)

  -- Search for nearest sentence boundary (Japanese OR English)
  for i = 1, count do
    local result = vim.fn.search(pattern, "Wb")
    if result == 0 then
      break -- No more sentences
    end
  end
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
