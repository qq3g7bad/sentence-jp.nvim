local M = {}

function M.next_sentence(count)
  count = count or vim.v.count1
  local config = require("sentence-jp.config").get()
  local pattern = require("sentence-jp.patterns").build_forward_pattern(config)

  -- Search for nearest sentence boundary (Japanese OR English)
  for i = 1, count do
    local result = vim.fn.search(pattern, "W")
    if result == 0 then
      break -- No more sentences
    end
  end
end

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
