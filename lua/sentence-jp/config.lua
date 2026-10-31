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
  -- Closing brackets/quotes that may follow sentence-ending punctuation (e.g. "。」", ".)")
  punctuation = {
    sentence_endings_jp = "[。！？．]",
    sentence_endings_en = "[.!?]",
    closing = "[」』）】〉》〕］｝\"'”’)\\]]",
    -- English abbreviations whose final "." does not end a sentence (e.g. "e.g. the", "Mr. Smith")
    abbreviations = { "e.g.", "i.e.", "etc.", "Mr.", "Mrs.", "Dr.", "vs.", "cf." },
  },

  -- Behavior
  include_fullwidth_space = true,
  -- Treat "。」" as the end of a sentence only when the closer is followed by end of line,
  -- whitespace, another ending or an opening bracket. "「行く。」と言った。" stays one sentence.
  -- false: "。」" always ends a sentence.
  quote_aware = true,
}

local config = vim.deepcopy(defaults)

--- Setup configuration with user overrides
--- @param user_config? table User configuration to merge with defaults
function M.setup(user_config)
  local unknown = M.unknown_keys(user_config or {}, defaults)
  if #unknown > 0 then
    vim.notify("sentence-jp: Unknown option(s): " .. table.concat(unknown, ", "), vim.log.levels.WARN)
  end

  config = vim.tbl_deep_extend("force", defaults, user_config or {})

  -- tbl_deep_extend merges lists by index; a user-specified list replaces the default instead
  local user_punctuation = type(user_config) == "table" and user_config.punctuation
  if type(user_punctuation) == "table" and user_punctuation.abbreviations ~= nil then
    config.punctuation.abbreviations = user_punctuation.abbreviations
  end

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

local islist = vim.islist or vim.tbl_islist

--- Collect option paths in `user` that do not exist in `reference` (e.g. "punctuation.sentence_endings")
--- @param user table User configuration
--- @param reference table Configuration with all known keys
--- @param prefix? string Path prefix for nested keys
--- @return string[] Sorted list of unknown option paths
function M.unknown_keys(user, reference, prefix)
  local unknown = {}
  if type(user) ~= "table" then
    return unknown
  end

  for key, value in pairs(user) do
    local path = (prefix or "") .. tostring(key)
    if reference[key] == nil then
      table.insert(unknown, path)
    elseif type(value) == "table" and type(reference[key]) == "table" and not islist(reference[key]) then
      vim.list_extend(unknown, M.unknown_keys(value, reference[key], path .. "."))
    end
  end

  table.sort(unknown)
  return unknown
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
    for _, field in ipairs({ "sentence_endings_jp", "sentence_endings_en", "closing" }) do
      if cfg.punctuation[field] and type(cfg.punctuation[field]) ~= "string" then
        return false
      end
    end
  end

  local abbreviations = cfg.punctuation and cfg.punctuation.abbreviations
  if abbreviations ~= nil then
    if type(abbreviations) ~= "table" then
      return false
    end
    for _, abbreviation in ipairs(abbreviations) do
      if type(abbreviation) ~= "string" then
        return false
      end
    end
  end

  if cfg.quote_aware ~= nil and type(cfg.quote_aware) ~= "boolean" then
    return false
  end

  return true
end

return M
