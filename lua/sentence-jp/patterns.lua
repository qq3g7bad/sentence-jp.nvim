local M = {}

--- Check if a character is a whitespace character (including fullwidth space)
--- @param ch string Character to check
--- @return boolean True if character is whitespace
local function is_space_char(ch)
  return vim.regex("\\s"):match_str(ch) ~= nil or ch == "　"
end

--- Check if character at offset from cursor is a space
--- @param offset number Character offset from cursor position (0 = current, 1 = next, -1 = previous)
--- @return boolean True if character at offset is whitespace
local function char_at_offset_is_space(offset)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line_text = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1] or ""
  local char_len = vim.fn.strchars(line_text)

  if char_len == 0 then
    return true
  end

  local cur_idx = vim.str_utfindex(line_text, pos[2])
  local target_idx = cur_idx + offset

  if target_idx >= char_len or target_idx < 0 then
    return true
  end

  local ch = vim.fn.strcharpart(line_text, target_idx, 1)
  return is_space_char(ch)
end

--- Check if next character after cursor is a space
--- @return boolean True if next character is whitespace
local function next_char_is_space()
  return char_at_offset_is_space(1)
end

--- Check if current character at cursor is a space
--- @return boolean True if current character is whitespace
local function current_char_is_space()
  return char_at_offset_is_space(0)
end

--- Move cursor to next non-space character within bounds
--- @param end_line number Last line to search within
--- @param include_fullwidth_space boolean Whether to treat fullwidth space as whitespace
local function move_to_next_nonspace(end_line, include_fullwidth_space)
  if not current_char_is_space() then
    return
  end

  local nonspace = include_fullwidth_space and "[^[:space:]　]" or "[^[:space:]]"
  vim.fn.searchpos(nonspace, "W", end_line)
end

--- Check if a line is a code fence line (starts with ```)
--- @param line number Line number to check (1-indexed)
--- @return boolean True if line starts with ```
local function is_fence_line(line)
  local text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ""
  return text:match("^```") ~= nil
end

--- Normalize paragraph bounds by excluding code fence lines
--- @param start_line number Starting line number
--- @param end_line number Ending line number
--- @return number start_line Adjusted start line
--- @return number end_line Adjusted end line
local function normalize_bounds(start_line, end_line)
  while start_line <= end_line and is_fence_line(start_line) do
    start_line = start_line + 1
  end

  while end_line >= start_line and is_fence_line(end_line) do
    end_line = end_line - 1
  end

  return start_line, end_line
end

--- Build a raw punctuation character class (no lookahead)
--- Used for matching consecutive punctuation with \+
--- @param config table Configuration containing punctuation patterns
--- @return string Vim regex character class for all sentence-ending punctuation
function M.build_raw_punctuation_pattern(config)
  local jp_pattern = config.punctuation.sentence_endings_jp or "[。！？．]"
  local en_pattern = config.punctuation.sentence_endings_en or "[.!?]"

  -- Extract characters from bracket expressions and combine them
  local jp_chars = jp_pattern:match("%[(.-)%]") or ""
  local en_chars = en_pattern:match("%[(.-)%]") or ""

  return "[" .. jp_chars .. en_chars .. "]"
end

--- Build a Vim regex pattern for sentence-ending punctuation
--- Handles both Japanese (。！？．) and English (.!?) punctuation
--- Special handling for periods to require trailing space or end of line
--- @param config table Configuration containing punctuation patterns
--- @return string Vim regex pattern for sentence endings
function M.build_sentence_ending_pattern(config)
  local jp_pattern = config.punctuation.sentence_endings_jp or "[。！？．]"
  local en_pattern = config.punctuation.sentence_endings_en or "[.!?]"

  local has_dot = en_pattern:find("%.") ~= nil
  local en_no_dot = en_pattern
  if has_dot then
    en_no_dot = en_no_dot:gsub("%.", "")
    if en_no_dot == "[]" then
      en_no_dot = ""
    end
  end

  local dot_pattern = ""
  if has_dot then
    dot_pattern = "\\.\\%($\\|\\_s\\+\\|　\\+\\)"
  end

  local parts = { jp_pattern }
  if en_no_dot ~= "" then
    table.insert(parts, en_no_dot)
  end
  if dot_pattern ~= "" then
    table.insert(parts, dot_pattern)
  end

  return "\\%(" .. table.concat(parts, "\\|") .. "\\)"
end

--- Move cursor to next character, handling multi-byte characters
--- @param end_line number Last line to consider
--- @return boolean True if successfully moved, false if at end
local function move_to_next_char(end_line)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line_text = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1] or ""
  local char_len = vim.fn.strchars(line_text)

  if char_len > 0 then
    local cur_idx = vim.str_utfindex(line_text, pos[2])
    local next_idx = cur_idx + 1

    if next_idx < char_len then
      local next_byte = vim.str_byteindex(line_text, next_idx)
      vim.api.nvim_win_set_cursor(0, { pos[1], next_byte })
      return true
    end
  end

  if pos[1] < end_line then
    vim.api.nvim_win_set_cursor(0, { pos[1] + 1, 0 })
    return true
  end

  return false
end

--- Build forward search pattern for finding next sentence
--- Pattern matches sentence endings + optional whitespace + non-whitespace
--- Uses raw punctuation pattern to properly match consecutive punctuation (e.g., "..." or "。。")
--- @param config table Configuration containing punctuation patterns
--- @return string Vim regex pattern for forward sentence search
function M.build_forward_pattern(config)
  -- Multi-language sentence endings (Japanese: 。！？． + English: .!?)
  -- Commas (、,) don't mark sentence boundaries in either language
  -- Use raw punctuation to match all consecutive punctuation marks (greedy)
  local raw_punct = M.build_raw_punctuation_pattern(config)
  local whitespace = config.include_fullwidth_space and "[\\n[:space:]　]" or "[\\n[:space:]]"

  -- Pattern: one or more punctuation chars + optional whitespace + non-whitespace char
  -- This ensures we match all consecutive punctuation like "..." or "。。。"
  -- Note: For Japanese, sentences often have no space between them (。次の文),
  -- so whitespace is optional. For English, periods without following space
  -- (like "Mr.Smith") may match, but this is acceptable for motion purposes.
  return raw_punct .. "\\+" .. whitespace .. "*[^[:space:]　]"
end

--- Build backward search pattern for finding previous sentence
--- Pattern matches sentence start after punctuation or buffer start
--- Uses raw punctuation pattern to properly skip consecutive punctuation (e.g., "..." or "。。")
--- @param config table Configuration containing punctuation patterns
--- @return string Vim regex pattern for backward sentence search
function M.build_backward_pattern(config)
  -- Multi-language sentence endings (Japanese: 。！？． + English: .!?)
  -- Commas (、,) don't mark sentence boundaries in either language
  -- Use raw punctuation to match all consecutive punctuation marks
  local raw_punct = M.build_raw_punctuation_pattern(config)
  local whitespace = config.include_fullwidth_space and "[\\n[:space:]　]" or "[\\n[:space:]]"

  -- Pattern: (one or more punctuation OR buffer start) + optional whitespace + \zs + sentence start
  -- The \+ ensures we skip past all consecutive punctuation when moving backward
  return "\\%(" .. raw_punct .. "\\+\\|^\\)" .. whitespace .. "*\\zs[^[:space:]　]"
end

--- Find sentence boundaries around a given position
--- @param line number Line number (1-indexed)
--- @param col number Column byte position (0-indexed)
--- @param bounds? table Optional {start_line: number, end_line: number} to limit search
--- @return table|nil {start: [line,col], end_inner: [line,col], end_around: [line,col]} or nil if not found
function M.find_sentence_boundaries(line, col, bounds)
  local config = require("sentence-jp.config").get()
  bounds = bounds or {}
  local start_line = bounds.start_line or 1
  local end_line = bounds.end_line or vim.api.nvim_buf_line_count(0)
  start_line, end_line = normalize_bounds(start_line, end_line)

  if start_line > end_line then
    return nil
  end

  -- Save cursor position
  local save_cursor = vim.api.nvim_win_get_cursor(0)

  -- Set cursor position (line is 1-indexed, col is 0-indexed)
  vim.api.nvim_win_set_cursor(0, { line, col })

  -- Use raw punctuation pattern for matching consecutive punctuation
  local raw_punct = M.build_raw_punctuation_pattern(config)
  local punct_line = vim.fn.search(raw_punct, "cW", end_line)

  local end_inner
  local end_around

  if punct_line == 0 then
    -- No punctuation found, use end of paragraph
    local end_text = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1] or ""
    local end_col = #end_text > 0 and (#end_text - 1) or 0

    end_inner = { end_line, end_col }
    end_around = end_inner
  else
    -- Found punctuation - now calculate boundaries:
    -- end_inner: INCLUDES the punctuation (Vim default 'is')
    -- end_around: INCLUDES punctuation + trailing whitespace

    -- Move forward to end of punctuation run (e.g., "。。" or "...")
    -- Using raw pattern with \+ to properly match all consecutive punctuation
    vim.fn.searchpos(raw_punct .. "\\+", "ceW")
    end_inner = vim.api.nvim_win_get_cursor(0)

    -- Skip any trailing whitespace (within paragraph bounds)
    if next_char_is_space() then
      local ws_pattern = config.include_fullwidth_space and "[[:space:]　]\\+" or "[[:space:]]\\+"
      vim.fn.searchpos(ws_pattern, "ceW", end_line)
    end
    end_around = vim.api.nvim_win_get_cursor(0)
  end

  -- Find sentence start: search backward from current position for previous punctuation
  vim.api.nvim_win_set_cursor(0, { line, col })

  local start_pos
  local prev_punct = vim.fn.searchpos(raw_punct, "bW", start_line)
  if prev_punct[1] ~= 0 then
    -- Move to end of the punctuation run
    vim.fn.searchpos(raw_punct .. "\\+", "ceW")

    -- Move to the character after punctuation, then skip whitespace if present
    move_to_next_char(end_line)
    move_to_next_nonspace(end_line, config.include_fullwidth_space)
    start_pos = vim.api.nvim_win_get_cursor(0)
  else
    -- No previous punctuation found, start from paragraph beginning
    vim.api.nvim_win_set_cursor(0, { start_line, 0 })

    move_to_next_nonspace(end_line, config.include_fullwidth_space)
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
