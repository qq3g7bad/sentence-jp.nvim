local M = {}

function M.get_sentence_region()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local patterns = require('sentence-jp.patterns')

  return patterns.find_sentence_boundaries(cursor[1], cursor[2])
end

function M.select_inner_sentence()
  local boundaries = M.get_sentence_region()

  if not boundaries then
    return
  end

  -- Set selection
  local start = boundaries.start
  local end_pos = boundaries.end_inner

  vim.api.nvim_win_set_cursor(0, start)
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, end_pos)
end

function M.select_around_sentence()
  local boundaries = M.get_sentence_region()

  if not boundaries then
    return
  end

  -- Set selection
  local start = boundaries.start
  local end_pos = boundaries.end_around

  vim.api.nvim_win_set_cursor(0, start)
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, end_pos)
end

function M.setup()
  local config = require('sentence-jp.config').get()

  if not config.textobject.enable then
    return
  end

  -- Always use 's' key - works for both Japanese and English!
  vim.keymap.set({'o', 'x'}, 'is', function()
    M.select_inner_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Inner sentence (includes punctuation, JP/EN)"
  })

  vim.keymap.set({'o', 'x'}, 'as', function()
    M.select_around_sentence()
  end, {
    noremap = true,
    silent = true,
    desc = "Around sentence (with punctuation + space, JP/EN)"
  })
end

return M
