local M = {
  test = require("go-tools.gotest"),
  tags = require("go-tools.gotags"),
}

function M.setup()
  M.test.setup()
  M.tags.setup()
end

local function install()
  local wd = vim.fs.joinpath(vim.fn.stdpath("data") --[[@as string]], "gotools")
  if not vim.uv.fs_stat(wd) then
    vim.fn.mkdir(wd)
  end

  if vim.fn.executable("gomodifytags") == 0 then
    -- vim.print("Installing gomodifytags")
    -- vim.system({ "go", "install", "github.com/fatih/gomodifytags@latest" })
  end

  -- vim.notify("Go tools installed", vim.log.levels.INFO, { title = "go-tools" })
end

install()

return M
