---@meta

---@class go_test.Entry
---@field Time string
---@field Action string
---@field Package string
---@field Test? string
---@field Output? string
---@field Elapsed? number

---@class go_test.StartEntry : go_test.Entry
---@field Action "start"

---@class go_test.RunEntry : go_test.Entry
---@field Action "run"
---@field Test string

---@class go_test.OutputEntry : go_test.Entry
---@field Action "output"
---@field Test string
---@field Output string

---@class go_test.DoneEntry : go_test.OutputEntry
---@field Action "pass" | "fail"
---@field Test string
---@field Elapsed number

---@class go_test.PassEntry : go_test.DoneEntry
---@field Action "pass"

---@class go_test.FailEntry : go_test.DoneEntry
---@field Action "fail"
