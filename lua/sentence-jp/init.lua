local M = {}

--- Setup the sentence-jp plugin with user configuration
--- @param user_config? table User configuration to merge with defaults
function M.setup(user_config)
  -- 1. Initialize configuration
  local config = require("sentence-jp.config")
  config.setup(user_config or {})

  -- Remove mappings and autocmds from a previous setup() so that changed options take effect
  local utils = require("sentence-jp.utils")
  utils.unmap_all()
  local group = vim.api.nvim_create_augroup("sentence-jp", { clear = true })

  local textobjects = require("sentence-jp.textobjects")
  local motions = require("sentence-jp.motions")

  -- 2. <Plug> mappings are always available
  textobjects.setup_plug()
  motions.setup_plug()

  -- 3. Default keys for text objects and motions
  local function map_keys(buffer)
    textobjects.setup(buffer)
    motions.setup_motions(buffer)
  end

  local filetypes = config.get().filetypes
  if filetypes == nil then
    map_keys(nil)
    return
  end

  -- Only in the given filetypes, as buffer-local mappings
  local function update_buffer(buffer)
    utils.unmap_buffer(buffer)
    if vim.tbl_contains(filetypes, vim.bo[buffer].filetype) then
      map_keys(buffer)
    end
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      update_buffer(args.buf)
    end,
  })

  -- Buffers already open when setup() runs (e.g. lazy-loaded on VeryLazy)
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      update_buffer(buffer)
    end
  end
end

--- Get the current configuration
--- @return table The current configuration table
function M.get_config()
  return require("sentence-jp.config").get()
end

--- Find sentence boundaries at the current cursor position
--- @return table|nil Sentence boundaries {start, end_inner, end_around} or nil if not found
function M.find_sentence()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local utils = require("sentence-jp.utils")
  local start_line, end_line = utils.find_paragraph_bounds()

  return require("sentence-jp.patterns").find_sentence_boundaries(cursor[1], cursor[2], {
    start_line = start_line,
    end_line = end_line,
  })
end

return M
