local M = {}

function M.setup()
  local wd = vim.fs.joinpath(vim.fn.stdpath("data") --[[@as string]], "gotools")
  if not vim.uv.fs_stat(wd) then
    vim.fn.mkdir(wd)
  end

  require("go-tools.gotest").setup()
  require("go-tools.gotags").setup()
end

return M
