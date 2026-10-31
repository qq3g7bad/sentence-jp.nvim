local M = {}

local space_regex = vim.regex("\\s")

--- Check if a character is a whitespace character (including fullwidth space)
--- @param ch string Character to check
--- @return boolean True if character is whitespace
local function is_space_char(ch)
  return space_regex:match_str(ch) ~= nil or ch == "　"
end

--- Check if character at offset from cursor is a space
--- @param offset number Character offset from cursor position (0 = current, 1 = next, -1 = previous)
--- @param outside_line boolean Value to return when the offset falls outside the line
--- @return boolean True if character at offset is whitespace
local function char_at_offset_is_space(offset, outside_line)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line_text = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1] or ""
  local char_len = vim.fn.strchars(line_text)

  if char_len == 0 then
    return true
  end

  local cur_idx = vim.str_utfindex(line_text, pos[2])
  local target_idx = cur_idx + offset

  if target_idx >= char_len or target_idx < 0 then
    return outside_line
  end

  local ch = vim.fn.strcharpart(line_text, target_idx, 1)
  return is_space_char(ch)
end

--- Check if next character after cursor is a space (end of line does not count)
--- @return boolean True if next character is whitespace
local function next_char_is_space()
  return char_at_offset_is_space(1, false)
end

--- Check if current character at cursor is a space
--- @return boolean True if current character is whitespace
local function current_char_is_space()
  return char_at_offset_is_space(0, true)
end

--- Find the start of the whitespace run just before a position on the same line
--- @param pos table Position {line, col}
--- @param include_fullwidth_space boolean Whether to treat fullwidth space as whitespace
--- @return table Position {line, col} of the first preceding whitespace, or pos itself if there is none
local function leading_space_start(pos, include_fullwidth_space)
  local line_text = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1] or ""
  local col = pos[2]
  while col > 0 do
    local prev = line_text:sub(1, col):match("[ \t]$")
      or (include_fullwidth_space and line_text:sub(1, col):match("　$"))
    if not prev then
      break
    end
    col = col - #prev
  end
  return { pos[1], col }
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

--- Opening brackets that may follow a closer at a sentence end (e.g. "「はい。」「いいえ。」")
local OPENERS = "[「『（【〈《〔［｛(\\[]"

--- Build a zero-width Vim regex that fails right after an abbreviation or a list number
--- Placed before the English punctuation, so the final "." of "e.g." or "1." (at line start) is not an ending.
--- @param abbreviations string[] Abbreviations including their final "." (e.g. "e.g.")
--- @return string Vim regex (empty when there is nothing to exclude)
local function build_en_exclusions(abbreviations)
  local words = {}
  local max_len = 0
  for _, abbreviation in ipairs(abbreviations or {}) do
    local word = abbreviation:match("^(.-)%.$")
    if word and word ~= "" then
      table.insert(words, vim.fn.escape(word, "\\.*[]~^$/"))
      max_len = math.max(max_len, #word)
    end
  end

  -- Numbered list item at line start ("1. ", "  12. ")
  local exclusions = "\\%(^\\s*\\d\\+\\)\\@<!"
  if #words > 0 then
    exclusions = "\\%(\\<\\%(" .. table.concat(words, "\\|") .. "\\)\\)\\@" .. max_len .. "<!" .. exclusions
  end
  return exclusions
end

--- Extract the body of a bracket expression (e.g. "[。！？]" -> "。！？")
--- @param pattern string Vim regex character class
--- @return string Characters inside the brackets
local function class_body(pattern)
  return pattern:match("%[(.-)%]") or ""
end

--- Build a Vim regex matching one sentence ending (the whole punctuation run)
--- Japanese punctuation always ends a sentence, even when followed by other text (e.g. "。次").
--- With quote_aware, closers after it ("。」") are included only when followed by end of line,
--- whitespace, another ending or an opening bracket; otherwise ("。」と言った") it is not an ending.
--- English punctuation ends a sentence only when followed by end of line or whitespace,
--- optionally after closing brackets/quotes, so "0.11", "a.b" and "init.lua" are not split.
--- It does not end a sentence after an abbreviation ("e.g.") or a list number at line start ("1.").
--- @param config table Configuration containing punctuation patterns
--- @return string Vim regex pattern for a sentence ending
function M.build_end_pattern(config)
  local jp_chars = class_body(config.punctuation.sentence_endings_jp or "[。！？．]")
  local en_chars = class_body(config.punctuation.sentence_endings_en or "[.!?]")
  local all = "[" .. jp_chars .. en_chars .. "]"
  local closing = config.punctuation.closing or "[」』）】〉》〕］｝\"'”’)\\]]"
  local space = config.include_fullwidth_space and "[[:space:]　]" or "[[:space:]]"

  local branches = {}
  if jp_chars ~= "" then
    -- A run containing at least one Japanese mark (e.g. "。。。", "？!")
    local run = all .. "*[" .. jp_chars .. "]" .. all .. "*"
    if config.quote_aware == false then
      table.insert(branches, run .. closing .. "*")
    else
      local after_closer = "\\%($\\|" .. space .. "\\|" .. all .. "\\|" .. OPENERS .. "\\)\\@="
      -- Either closers that end the quote, or no closer at all ("。」と" does not match)
      table.insert(branches, run .. "\\%(" .. closing .. "\\+" .. after_closer .. "\\|" .. closing .. "\\@!\\)")
    end
  end
  if en_chars ~= "" then
    -- An English run followed by optional closers, then end of line or whitespace
    local exclusions = build_en_exclusions(config.punctuation.abbreviations)
    table.insert(branches, exclusions .. all .. "\\+" .. closing .. "*\\%($\\|" .. space .. "\\)\\@=")
  end

  return "\\%(" .. table.concat(branches, "\\|") .. "\\)"
end

--- Compare two {line, col} positions
--- @param a table Position {line, col}
--- @param b table Position {line, col}
--- @return boolean True if a is strictly before b
local function is_before(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
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

--- Find sentence boundaries around a given position
--- @param line number Line number (1-indexed)
--- @param col number Column byte position (0-indexed)
--- @param bounds? table Optional {start_line: number, end_line: number, start_col?: number} to limit search
---   (start_col: where the text starts on start_line, e.g. after a list marker)
--- @return table|nil {start, start_around, end_inner, end_around} ([line,col] each) or nil if not found
function M.find_sentence_boundaries(line, col, bounds)
  local config = require("sentence-jp.config").get()
  bounds = bounds or {}
  local start_line = bounds.start_line or 1
  local end_line = bounds.end_line or vim.api.nvim_buf_line_count(0)
  start_line, end_line = normalize_bounds(start_line, end_line)
  local start_col = start_line == bounds.start_line and bounds.start_col or 0

  if start_line > end_line then
    return nil
  end

  -- Save cursor position
  local save_cursor = vim.api.nvim_win_get_cursor(0)

  -- Set cursor position (line is 1-indexed, col is 0-indexed)
  vim.api.nvim_win_set_cursor(0, { line, col })

  local end_pattern = M.build_end_pattern(config)
  local origin = { line, col }

  -- The cursor may be inside a sentence ending (e.g. on the 2nd "。" of "。。。" or on a closing quote)
  local found_end = false
  if vim.fn.search(end_pattern, "bcW", start_line) ~= 0 then
    vim.fn.searchpos(end_pattern, "ceW")
    found_end = not is_before(vim.api.nvim_win_get_cursor(0), origin)
  end

  if not found_end then
    vim.api.nvim_win_set_cursor(0, origin)
    if vim.fn.search(end_pattern, "cW", end_line) ~= 0 then
      -- Move forward to end of punctuation run (e.g., "。。" or "...")
      vim.fn.searchpos(end_pattern, "ceW")
      found_end = true
    end
  end

  local end_inner
  local end_around

  if not found_end then
    -- No punctuation found, use end of paragraph
    local end_text = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1] or ""
    local end_col = #end_text > 0 and (#end_text - 1) or 0

    end_inner = { end_line, end_col }
    end_around = end_inner
  else
    -- Found punctuation - now calculate boundaries:
    -- end_inner: INCLUDES the punctuation (Vim default 'is')
    -- end_around: INCLUDES punctuation + trailing whitespace
    end_inner = vim.api.nvim_win_get_cursor(0)

    -- Skip trailing whitespace on the same line only
    if next_char_is_space() then
      local ws_pattern = config.include_fullwidth_space and "[[:space:]　]\\+" or "[[:space:]]\\+"
      vim.fn.searchpos(ws_pattern, "ceW", end_inner[1])
    end
    end_around = vim.api.nvim_win_get_cursor(0)
  end

  -- Find sentence start: search backward from current position for previous punctuation
  vim.api.nvim_win_set_cursor(0, origin)

  local start_pos
  local prev_punct = vim.fn.searchpos(end_pattern, "bW", start_line)
  while prev_punct[1] ~= 0 do
    -- Move to end of the punctuation run
    vim.fn.searchpos(end_pattern, "ceW")
    if is_before(vim.api.nvim_win_get_cursor(0), origin) then
      break
    end
    -- The match is the ending the cursor is on (e.g. inside "。。。"), so look further back
    vim.api.nvim_win_set_cursor(0, { prev_punct[1], prev_punct[2] - 1 })
    prev_punct = vim.fn.searchpos(end_pattern, "bW", start_line)
  end
  if prev_punct[1] ~= 0 then
    -- Move to the character after punctuation, then skip whitespace if present
    move_to_next_char(end_line)
    move_to_next_nonspace(end_line, config.include_fullwidth_space)
    start_pos = vim.api.nvim_win_get_cursor(0)
  else
    -- No previous punctuation found, start from paragraph (or list item text) beginning
    vim.api.nvim_win_set_cursor(0, { start_line, start_col })

    move_to_next_nonspace(end_line, config.include_fullwidth_space)
    start_pos = vim.api.nvim_win_get_cursor(0)
  end

  -- Like Vim's 'as': without trailing whitespace, include the leading whitespace instead
  -- (for the first sentence of a list item, the marker from the line start: "das" deletes "- foo")
  local start_around = start_pos
  local at_item_text = start_col > 0 and start_pos[1] == start_line and start_pos[2] == start_col
  if not is_before(end_inner, end_around) then
    start_around = at_item_text and { start_line, 0 } or leading_space_start(start_pos, config.include_fullwidth_space)
  end

  -- Restore cursor
  vim.api.nvim_win_set_cursor(0, save_cursor)

  return {
    start = start_pos,
    start_around = start_around,
    end_inner = end_inner,
    end_around = end_around,
  }
end

return M
