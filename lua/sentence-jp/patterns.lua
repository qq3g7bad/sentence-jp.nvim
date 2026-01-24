local M = {}

function M.build_forward_pattern(config)
  -- Multi-language sentence endings (Japanese: 。！？． + English: .!?)
  -- Commas (、,) don't mark sentence boundaries in either language
  local delimiters = config.punctuation.sentence_endings
  local whitespace = config.include_fullwidth_space and '[\\n[:space:]　]' or '[\\n[:space:]]'

  -- Pattern: one or more sentence endings + optional whitespace + non-whitespace char
  return delimiters .. '\\+' .. whitespace .. '*[^[:space:]　]'
end

function M.build_backward_pattern(config)
  -- Multi-language sentence endings (Japanese: 。！？． + English: .!?)
  -- Commas (、,) don't mark sentence boundaries in either language
  local delimiters = config.punctuation.sentence_endings
  local whitespace = config.include_fullwidth_space and '[\\n[:space:]　]' or '[\\n[:space:]]'

  -- Pattern: (sentence ending OR buffer start) + whitespace + \zs + sentence start
  return '\\%(' .. delimiters .. '\\|^\\)' .. whitespace .. '*\\zs[^[:space:]　]'
end

function M.find_next_boundary(start_line, start_col, config)
  local pattern = M.build_forward_pattern(config)

  -- Save cursor position
  local save_cursor = vim.api.nvim_win_get_cursor(0)

  -- Set cursor to search start position
  vim.api.nvim_win_set_cursor(0, { start_line, start_col })

  -- Search for next boundary
  local result = vim.fn.search(pattern, 'W')

  local found_pos = nil
  if result ~= 0 then
    found_pos = vim.api.nvim_win_get_cursor(0)
  end

  -- Restore cursor
  vim.api.nvim_win_set_cursor(0, save_cursor)

  return found_pos
end

function M.find_prev_boundary(start_line, start_col, config)
  local pattern = M.build_backward_pattern(config)

  -- Save cursor position
  local save_cursor = vim.api.nvim_win_get_cursor(0)

  -- Set cursor to search start position
  vim.api.nvim_win_set_cursor(0, { start_line, start_col })

  -- Search backward for previous boundary
  local result = vim.fn.search(pattern, 'Wb')

  local found_pos = nil
  if result ~= 0 then
    found_pos = vim.api.nvim_win_get_cursor(0)
  end

  -- Restore cursor
  vim.api.nvim_win_set_cursor(0, save_cursor)

  return found_pos
end

function M.find_sentence_boundaries(line, col)
  local config = require('sentence-jp.config').get()

  -- Save cursor position
  local save_cursor = vim.api.nvim_win_get_cursor(0)

  -- Set cursor position (line is 1-indexed, col is 0-indexed)
  vim.api.nvim_win_set_cursor(0, { line, col })

  -- Search forward for nearest sentence-ending punctuation (Japanese OR English)
  -- 'ce' flags: 'c' = accept cursor position, 'e' = move to end of match
  local ending_pattern = config.punctuation.sentence_endings
  local punct_line = vim.fn.search(ending_pattern, 'ceW')

  if punct_line == 0 then
    -- No sentence ending punctuation found (rare with multi-language support)
    vim.api.nvim_win_set_cursor(0, save_cursor)
    return nil
  end

  -- Get position after search (cursor should be on the punctuation)
  local punct_pos = vim.api.nvim_win_get_cursor(0)
  local punct_line_text = vim.api.nvim_buf_get_lines(0, punct_pos[1] - 1, punct_pos[1], false)[1] or ""

  -- Calculate positions to match Vim's default behavior:
  -- end_inner: INCLUDES the punctuation mark (like Vim's default 'is')
  -- end_around: includes punctuation + trailing whitespace (like Vim's default 'as')

  -- Move to end of punctuation mark
  vim.fn.searchpos(ending_pattern, 'ce')
  local end_inner = vim.api.nvim_win_get_cursor(0)  -- Position after punctuation

  -- Now skip any trailing whitespace
  local ws_pattern = config.include_fullwidth_space and '[[:space:]　]\\+' or '[[:space:]]\\+'
  vim.fn.searchpos(ws_pattern, 'ceW') -- Skip whitespace if present
  local end_around = vim.api.nvim_win_get_cursor(0)

  -- Find sentence start: search backward for previous sentence boundary
  -- Start from the position before our sentence's punctuation
  vim.api.nvim_win_set_cursor(0, end_inner)

  local start_pattern = M.build_backward_pattern(config)
  local start_line_num = vim.fn.search(start_pattern, 'bW')

  local start_pos
  if start_line_num == 0 then
    -- No previous sentence found, use buffer start
    start_pos = { 1, 0 }
  else
    start_pos = vim.api.nvim_win_get_cursor(0)
  end

  -- Restore cursor
  vim.api.nvim_win_set_cursor(0, save_cursor)

  return {
    start = start_pos,
    end_inner = end_inner,
    end_around = end_around,
  }
end

return M
