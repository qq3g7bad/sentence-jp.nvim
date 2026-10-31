describe("config", function()
  local notify = vim.notify
  local messages

  before_each(function()
    messages = {}
    vim.notify = function(msg, level)
      table.insert(messages, { msg = msg, level = level })
    end
  end)

  after_each(function()
    vim.notify = notify
    require("sentence-jp").setup()
  end)

  it("warns about unknown keys", function()
    require("sentence-jp").setup({ punctuation = { sentence_endings = "[。]" }, typo = true })
    assert.equals(1, #messages)
    assert.equals(vim.log.levels.WARN, messages[1].level)
    assert.matches("punctuation.sentence_endings, typo", messages[1].msg, 1, true)
  end)

  it("does not warn about known keys", function()
    require("sentence-jp").setup({
      punctuation = { sentence_endings_jp = "[。！？．‼⁉]", closing = "[」]" },
      quote_aware = false,
    })
    assert.same({}, messages)
  end)

  it("applies sentence_endings_jp", function()
    require("sentence-jp").setup({ punctuation = { sentence_endings_jp = "[。‼]" } })
    local h = require("tests.helpers")
    h.buf({ "すごい‼次。" })
    h.at(1, "次")
    h.normal("dis")
    assert.same({ "すごい‼" }, h.get())
  end)
end)
