local M = {}

function M.err(msg, title)
  vim.notify(msg, vim.log.levels.ERROR, { title = title or "go-test" })
end

function M.ins(what, notify)
  if notify then
    vim.notify(vim.inspect(what))
  else
    print(vim.inspect(what))
  end
end

return M
