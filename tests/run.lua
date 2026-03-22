local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  package.path,
}, ";")

local dotagent = require("dotagent")
local source = require("dotagent.completion.blink").new()

local temp_root = vim.fn.tempname()
vim.fn.mkdir(temp_root, "p")
vim.fn.mkdir(temp_root .. "/commands", "p")
vim.fn.mkdir(temp_root .. "/skills/auth", "p")

vim.fn.writefile({
  "---",
  "description: Ship the current branch",
  "aliases:",
  "  - deploy",
  "---",
  "# Ship",
  "",
  "Push current changes.",
}, temp_root .. "/commands/ship.md")

vim.fn.writefile({
  "# Review",
  "",
  "Inspect a diff carefully.",
}, temp_root .. "/commands/review.md")

vim.fn.writefile({
  "---",
  "description: Manage auth state",
  "---",
  "# Auth",
  "",
  "Auth skill body.",
}, temp_root .. "/skills/auth/SKILL.md")

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  sources = {
    { type = "commands", path = temp_root .. "/commands" },
    { type = "skills", path = temp_root .. "/skills" },
    {
      type = "items",
      items = {
        {
          name = "status",
          kind = "command",
          description = "Show status",
        },
      },
    },
  },
})

local summary = dotagent.refresh()
assert(#summary.items == 4, "expected four indexed items")
assert(#summary.warnings == 0, "expected no warnings")

dotagent.attach(0)
assert(dotagent.is_buffer_enabled(0) == true, "buffer should be attached")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "/sh" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })

local completion_response
source:get_completions({
  line = "/sh",
  cursor = { 1, 3 },
}, function(response)
  completion_response = response
end)

vim.wait(1000, function()
  return completion_response ~= nil
end)

assert(completion_response ~= nil, "completion response missing")
assert(#completion_response.items >= 1, "expected matching completion items")
assert(completion_response.items[1].label == "/ship", "expected ship completion")
assert(completion_response.items[1].kind_icon == "⚡", "expected default command icon")
assert(
  not completion_response.items[1].documentation.value:find("Kind:", 1, true),
  "documentation should not include the item kind label"
)
assert(
  completion_response.items[1].documentation.value:find("Ship the current branch", 1, true) ~= nil,
  "documentation should keep the item description"
)

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "/au" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })

local skill_response
source:get_completions({
  line = "/au",
  cursor = { 1, 3 },
}, function(response)
  skill_response = response
end)

vim.wait(1000, function()
  return skill_response ~= nil
end)

assert(skill_response ~= nil, "skill response missing")
assert(#skill_response.items >= 1, "expected matching skill completion items")
assert(skill_response.items[1].label == "/auth", "expected auth completion")
assert(skill_response.items[1].kind_icon == "󰧑", "expected default skill icon")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "/HOME" })
vim.api.nvim_win_set_cursor(0, { 1, 5 })

local env_response
source:get_completions({
  line = "/HOME",
  cursor = { 1, 5 },
}, function(response)
  env_response = response
end)

vim.wait(1000, function()
  return env_response ~= nil
end)

assert(env_response ~= nil, "env response missing")
assert(#env_response.items == 0, "env-like tokens should not complete")

dotagent.detach(0)
assert(dotagent.is_buffer_enabled(0) == false, "buffer should be detached")

vim.env.DOTAGENT_EDITOR_PROMPT = "1"
dotagent.setup({
  activation = {
    mode = "contextual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  sources = {
    { type = "commands", path = temp_root .. "/commands" },
  },
})
dotagent._maybe_attach_initial_buffer()
assert(dotagent.is_buffer_enabled(0) == true, "env marker should attach the initial buffer")

vim.cmd("enew")
assert(dotagent.is_buffer_enabled(0) == false, "subsequent buffers should stay detached")

print("dotagent.nvim tests passed")
