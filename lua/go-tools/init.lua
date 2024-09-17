local M = {
  test = require("go-tools.gotest"),
  tags = require("go-tools.gotags"),
}

---@class gotools.Opts
---@field gotags? gotags.Opts
---@field gotest? gotest.Opts

---@param opts? gotools.Opts
function M.setup(opts)
  opts = opts or {}
  M.tags.setup(opts.gotags)
  M.test.setup(opts.gotest)
end

return M
