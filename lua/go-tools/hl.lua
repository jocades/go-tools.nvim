local highlight = {
  fg = "#38BDF8",
}

local target = "hl"

local ns = vim.api.nvim_create_namespace("go-tools-test-hl")

local msg = "Press 'x' to run the test"

vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

vim.api.nvim_buf_set_extmark(0, ns, 5 - 2, 0, {
  virt_lines = { { { msg, "CursorLineSign" } } },
  -- ephemeral = true,
  -- priority = 0,
  -- hl_group = "GoTestHelp",
})

-- vim.api.nvim_set_hl(ns, "GoTestHelp", {})

print(target)
