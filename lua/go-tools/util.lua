local M = {}

function M.err(msg, title)
  vim.notify(msg, vim.log.levels.ERROR, { title = title or "go-tools" })
end

function M.ins(what, notify)
  if notify then
    vim.notify(vim.inspect(what))
  else
    print(vim.inspect(what))
  end
end

function M.debug(what, noti)
  if vim.env.DEBUG == "go-tools" then
    M.ins(what, noti)
  end
end

return M
