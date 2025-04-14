local present = require("present")
local parse_slides = present._parse_slides

describe("present.parse_slides", function()
  it("should parse empty file", function()
    assert.are.same({}, parse_slides({}))
  end)

  it("should parse file with one slide", function()
    assert.are.same({
      {
        header = "# This is header",
        body = { "This is body" },
      },
    }, parse_slides({ "# This is header", "This is body" }))
  end)

  it("should parse file with one slide and multi-line body", function()
    assert.are.same({
      {
        header = "# This is header",
        body = { "This is body", "This is body second line" },
      },
    }, parse_slides({ "# This is header", "This is body", "This is body second line" }))
  end)

  it("should parse file with two slides", function()
    assert.are.same({
      {
        header = "# This is header",
        body = { "This is #1 body" },
      },
      {
        header = "# Another header",
        body = { "Another body", "Line 2" },
      },
    }, parse_slides({ "# This is header", "This is #1 body", "# Another header", "Another body", "Line 2" }))
  end)
end)
