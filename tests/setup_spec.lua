local function has_map(mode, lhs)
  return vim.fn.maparg(lhs, mode) ~= ""
end

describe("setup", function()
  after_each(function()
    require("sentence-jp").setup()
  end)

  it("removes text objects when re-setup with enable = false", function()
    require("sentence-jp").setup()
    assert.is_true(has_map("o", "is"))
    require("sentence-jp").setup({ textobject = { enable = false } })
    assert.is_false(has_map("o", "is"))
    assert.is_false(has_map("x", "as"))
    assert.is_true(has_map("n", ")"))
  end)

  it("removes motions when re-setup with enable = false", function()
    require("sentence-jp").setup()
    require("sentence-jp").setup({ motions = { enable = false } })
    assert.is_false(has_map("n", ")"))
    assert.is_false(has_map("o", "("))
    assert.is_true(has_map("o", "is"))
  end)

  it("removes old motion keys when the keys change", function()
    require("sentence-jp").setup()
    require("sentence-jp").setup({ motions = { next_sentence = "]s", prev_sentence = "[s" } })
    assert.is_false(has_map("n", ")"))
    assert.is_true(has_map("n", "]s"))
  end)
end)
