local M = {
  test = require("go-tools.gotest"),
  tags = require("go-tools.gotags"),
}

function M.setup()
  M.test.setup()
  M.tags.setup()
end

return M
