local M = {}

local defaults = {
  -- Text object settings
  -- Always uses 's' key - works for both Japanese and English!
  textobject = {
    enable = true,
  },

  -- Motion settings
  -- Finds nearest sentence boundary regardless of language
  motions = {
    enable = true,
    next_sentence = ")",
    prev_sentence = "(",
  },

  -- Multi-language punctuation patterns
  -- Automatically handles BOTH Japanese and English punctuation
  -- Finds the NEAREST sentence boundary from cursor position
  -- Japanese: 。！？． (period, exclamation, question, fullwidth period)
  -- English: .!? (period, exclamation, question)
  punctuation = {
    sentence_endings_jp = "[。！？．]",
    sentence_endings_en = "[.!?]",
  },

  -- Behavior
  include_fullwidth_space = true,
}

local config = vim.deepcopy(defaults)

--- Setup configuration with user overrides
--- @param user_config? table User configuration to merge with defaults
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", defaults, user_config or {})

  if not M.validate(config) then
    vim.notify("sentence-jp: Invalid configuration, using defaults", vim.log.levels.WARN)
    config = vim.deepcopy(defaults)
  end
end

--- Get the current configuration
--- @return table The current configuration table
function M.get()
  return config
end

--- Validate configuration structure
--- @param cfg table Configuration to validate
--- @return boolean True if configuration is valid, false otherwise
function M.validate(cfg)
  if type(cfg) ~= "table" then
    return false
  end

  if cfg.textobject and type(cfg.textobject) ~= "table" then
    return false
  end

  if cfg.motions and type(cfg.motions) ~= "table" then
    return false
  end

  if cfg.punctuation then
    if type(cfg.punctuation) ~= "table" then
      return false
    end
    for _, field in ipairs({ "sentence_endings_jp", "sentence_endings_en" }) do
      if cfg.punctuation[field] and type(cfg.punctuation[field]) ~= "string" then
        return false
      end
    end
  end

  return true
end

return M
