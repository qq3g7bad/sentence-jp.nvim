local h = require("tests.helpers")

describe("abbreviations and list numbers", function()
  local notify = vim.notify

  before_each(function()
    require("sentence-jp").setup()
  end)

  after_each(function()
    vim.notify = notify
    require("sentence-jp").setup()
  end)

  it("does not end a sentence after e.g.", function()
    h.buf({ "This is e.g. the case. Next." })
    h.at(1, "This")
    h.normal("dis")
    assert.same({ " Next." }, h.get())
  end)

  it("does not end a sentence after Mr.", function()
    h.buf({ "前。Mr. Smith came. Next." })
    h.at(1, "Smith")
    h.normal("dis")
    assert.same({ "前。 Next." }, h.get())
  end)

  it("still ends a sentence after a word containing an abbreviation", function()
    h.buf({ "I saw Dr. Who. Next." })
    h.at(1, "Who")
    h.normal("dis")
    assert.same({ " Next." }, h.get())
  end)

  it("does not end a sentence after a list number at line start", function()
    h.buf({ "1. 項目です。次。" })
    h.at(1, "項目")
    h.normal("dis")
    assert.same({ "次。" }, h.get())
  end)

  it("does not end a sentence after an indented list number", function()
    h.buf({ "  12. Item here. Next." })
    h.at(1, "Item")
    h.normal(")")
    assert.equals("1:Ne", h.ch())
  end)

  it("ends a sentence after a number in the middle of a line", function()
    h.buf({ "Chapter 1. Next." })
    h.at(1, "Next")
    h.normal("dis")
    assert.same({ "Chapter 1. " }, h.get())
  end)

  it("does not split English punctuation followed directly by Japanese", function()
    h.buf({ "I like it.次は日本語。後。" })
    h.at(1, "like")
    h.normal("dis")
    assert.same({ "後。" }, h.get())
  end)

  it("replaces the default list with a user list", function()
    require("sentence-jp").setup({ punctuation = { abbreviations = { "Prof." } } })
    h.buf({ "Prof. X met Mr. Y. Next." })
    h.at(1, "Prof")
    h.normal("dis")
    assert.same({ " Y. Next." }, h.get())
  end)

  it("disables abbreviations with an empty list", function()
    require("sentence-jp").setup({ punctuation = { abbreviations = {} } })
    h.buf({ "See e.g. this. Next." })
    h.at(1, "See")
    h.normal("dis")
    assert.same({ " this. Next." }, h.get())
  end)

  it("does not warn about a long user list", function()
    local messages = {}
    vim.notify = function(msg)
      table.insert(messages, msg)
    end
    local list = {}
    for i = 1, 12 do
      table.insert(list, "a" .. i .. ".")
    end
    require("sentence-jp").setup({ punctuation = { abbreviations = list } })
    assert.same({}, messages)
  end)
end)
