local h = require("tests.helpers")

--- @return boolean True if `lhs` is mapped in `mode` for the current buffer (global or buffer-local)
local function has_map(mode, lhs)
  return vim.fn.maparg(lhs, mode) ~= ""
end

describe("<Plug> mappings and keys", function()
  after_each(function()
    pcall(vim.keymap.del, "o", "iS")
    require("sentence-jp").setup()
  end)

  it("defines <Plug> mappings", function()
    require("sentence-jp").setup()
    assert.is_true(has_map("o", "<Plug>(sentence-jp-inner)"))
    assert.is_true(has_map("x", "<Plug>(sentence-jp-around)"))
    assert.is_true(has_map("n", "<Plug>(sentence-jp-next)"))
    assert.is_true(has_map("o", "<Plug>(sentence-jp-prev)"))
  end)

  it("keeps <Plug> mappings when the default keys are disabled", function()
    require("sentence-jp").setup({ textobject = { enable = false } })
    assert.is_false(has_map("o", "is"))
    vim.keymap.set("o", "iS", "<Plug>(sentence-jp-inner)", { remap = true })
    h.buf({ "前。対象の文。後。" })
    h.at(1, "対象")
    h.normal("diS")
    assert.same({ "前。後。" }, h.get())
  end)

  it("uses textobject.keys", function()
    require("sentence-jp").setup({ textobject = { keys = { inner = "ij", around = "aj" } } })
    assert.is_false(has_map("o", "is"))
    h.buf({ "前。対象の文。後。" })
    h.at(1, "対象")
    h.normal("dij")
    assert.same({ "前。後。" }, h.get())
  end)
end)

describe("filetypes", function()
  after_each(function()
    require("sentence-jp").setup()
  end)

  it("maps keys only in the given filetypes", function()
    require("sentence-jp").setup({ filetypes = { "markdown" } })
    h.buf({ "前。対象の文。後。" })
    vim.bo.filetype = "lua"
    assert.is_false(has_map("o", "is"))
    assert.is_false(has_map("n", ")"))

    h.buf({ "前。対象の文。後。" })
    vim.bo.filetype = "markdown"
    assert.is_true(has_map("o", "is"))
    h.at(1, "対象")
    h.normal("dis")
    assert.same({ "前。後。" }, h.get())
  end)

  it("maps keys in buffers already open when setup() runs", function()
    h.buf({ "x" })
    vim.bo.filetype = "text"
    require("sentence-jp").setup({ filetypes = { "text" } })
    assert.is_true(has_map("o", "is"))
  end)

  it("removes the keys when the filetype changes", function()
    require("sentence-jp").setup({ filetypes = { "markdown" } })
    h.buf({ "x" })
    vim.bo.filetype = "markdown"
    assert.is_true(has_map("o", "is"))
    vim.bo.filetype = "lua"
    assert.is_false(has_map("o", "is"))
  end)

  it("keeps <Plug> mappings global", function()
    require("sentence-jp").setup({ filetypes = { "markdown" } })
    h.buf({ "x" })
    vim.bo.filetype = "lua"
    assert.is_true(has_map("o", "<Plug>(sentence-jp-inner)"))
  end)

  it("returns to global keys on re-setup without filetypes", function()
    require("sentence-jp").setup({ filetypes = { "markdown" } })
    require("sentence-jp").setup()
    h.buf({ "x" })
    vim.bo.filetype = "lua"
    assert.is_true(has_map("o", "is"))
  end)
end)
