local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  package.path,
}, ";")

local config_mod = require("dotagent.config")
local dotagent = require("dotagent")
local source = require("dotagent.completion.blink").new()

local temp_root = vim.fn.tempname()
vim.fn.mkdir(temp_root, "p")

local function mkdir(path)
  vim.fn.mkdir(path, "p")
end

local function writefile(lines, path)
  vim.fn.writefile(lines, path)
end

local function completion_for(line)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, #line })

  local response
  source:get_completions({
    line = line,
    cursor = { 1, #line },
  }, function(result)
    response = result
  end)

  vim.wait(1000, function()
    return response ~= nil
  end)

  assert(response ~= nil, "completion response missing for " .. line)
  return response
end

local function find_item(items, kind, name)
  for _, item in ipairs(items) do
    if item.kind == kind and item.name == name then
      return item
    end
  end

  error("missing item " .. kind .. ":" .. name)
end

local function has_warning(warnings, fragment)
  for _, warning in ipairs(warnings) do
    if warning:find(fragment, 1, true) ~= nil then
      return true
    end
  end

  return false
end

local legacy_commands = temp_root .. "/legacy/commands"
local legacy_skills = temp_root .. "/legacy/skills"
local legacy_prompts = temp_root .. "/legacy/prompts"

mkdir(legacy_commands)
mkdir(legacy_skills .. "/auth")
mkdir(legacy_prompts)

writefile({
  "---",
  "description: Ship the current branch",
  "aliases:",
  "  - deploy",
  "---",
  "# Ship",
  "",
  "Push current changes.",
}, legacy_commands .. "/ship.md")

writefile({
  "# Review",
  "",
  "Inspect a diff carefully.",
}, legacy_commands .. "/review.md")

writefile({
  "---",
  "description: Manage auth state",
  "---",
  "# Auth",
  "",
  "Auth skill body.",
}, legacy_skills .. "/auth/SKILL.md")

writefile({
  "---",
  "description: Reusable prompt",
  "---",
  "# System",
  "",
  "Reusable prompt body.",
}, legacy_prompts .. "/system.md")

local agent_alpha = temp_root .. "/agent-alpha"
local agent_beta = temp_root .. "/agent-beta"
local override_prompts = temp_root .. "/override/prompts"
local same_name_prompts = temp_root .. "/same-name/prompts"
local duplicate_commands_one = temp_root .. "/dupe-one/commands"
local duplicate_commands_two = temp_root .. "/dupe-two/commands"
local missing_prompt_dir = temp_root .. "/missing/prompts"

mkdir(agent_alpha .. "/commands")
mkdir(agent_alpha .. "/skills/explain")
mkdir(agent_alpha .. "/prompts")
mkdir(agent_beta .. "/commands")
mkdir(agent_beta .. "/skills/debug")
mkdir(override_prompts)
mkdir(same_name_prompts)
mkdir(duplicate_commands_one)
mkdir(duplicate_commands_two)

writefile({
  "# Alpha",
  "",
  "Alpha command body.",
}, agent_alpha .. "/commands/alpha.md")

writefile({
  "---",
  "description: Explain a concept",
  "---",
  "# Explain",
  "",
  "Explain skill body.",
}, agent_alpha .. "/skills/explain/SKILL.md")

writefile({
  "---",
  "description: Shared prompt",
  "---",
  "# System Prompt",
  "",
  "Prompt from derived agent root.",
}, agent_alpha .. "/prompts/system.md")

writefile({
  "# Beta",
  "",
  "Beta command body.",
}, agent_beta .. "/commands/beta.md")

writefile({
  "# Debug",
  "",
  "Debug skill body.",
}, agent_beta .. "/skills/debug/SKILL.md")

writefile({
  "---",
  "description: Override prompt",
  "---",
  "# Override Prompt",
  "",
  "Prompt from explicit prompt_dirs.",
}, override_prompts .. "/override.md")

writefile({
  "# Review Prompt",
  "",
  "Prompt sharing a command name.",
}, same_name_prompts .. "/review.md")

writefile({
  "# Ship",
  "",
  "First duplicate command.",
}, duplicate_commands_one .. "/ship.md")

writefile({
  "# Ship",
  "",
  "Second duplicate command.",
}, duplicate_commands_two .. "/ship.md")

local defaults = config_mod.defaults()
assert(
  vim.tbl_contains(defaults.agent_dirs, vim.fn.expand("~/.claude")),
  "expected ~/.claude default agent root"
)
assert(defaults.icons.prompt == "󰘧", "expected default prompt icon")

local derived_config = config_mod.normalize({
  agent_dirs = { agent_alpha, agent_beta },
})
assert(#derived_config.command_dirs == 2, "expected derived command dirs from agent roots")
assert(#derived_config.skill_dirs == 2, "expected derived skill dirs from agent roots")
assert(#derived_config.prompt_dirs == 1, "expected only existing prompt dirs to be derived")
assert(derived_config.prompt_dirs[1] == agent_alpha .. "/prompts", "expected derived prompt dir")

local override_config = config_mod.normalize({
  agent_dirs = { agent_alpha },
  prompt_dirs = { override_prompts },
})
assert(
  #override_config.prompt_dirs == 1,
  "expected explicit prompt_dirs to override derived prompt dirs"
)
assert(override_config.prompt_dirs[1] == override_prompts, "expected explicit prompt override path")

local mixed_config = config_mod.normalize({
  prompt_dirs = { override_prompts },
  sources = {
    { type = "commands", path = legacy_commands },
    { type = "skills", path = legacy_skills },
  },
})
assert(
  #mixed_config.command_dirs == 1 and mixed_config.command_dirs[1] == legacy_commands,
  "expected legacy command source to survive prompt override"
)
assert(
  #mixed_config.skill_dirs == 1 and mixed_config.skill_dirs[1] == legacy_skills,
  "expected legacy skill source to survive prompt override"
)
assert(
  #mixed_config.prompt_dirs == 1 and mixed_config.prompt_dirs[1] == override_prompts,
  "expected explicit prompt override in mixed config"
)

local agent_override_config = config_mod.normalize({
  agent_dirs = { agent_alpha },
  sources = {
    { type = "commands", path = legacy_commands },
    { type = "skills", path = legacy_skills },
    { type = "prompts", path = legacy_prompts },
  },
})
assert(
  #agent_override_config.command_dirs == 1
    and agent_override_config.command_dirs[1] == agent_alpha .. "/commands",
  "expected agent_dirs to override legacy command paths"
)
assert(
  #agent_override_config.skill_dirs == 1
    and agent_override_config.skill_dirs[1] == agent_alpha .. "/skills",
  "expected agent_dirs to override legacy skill paths"
)
assert(
  #agent_override_config.prompt_dirs == 1
    and agent_override_config.prompt_dirs[1] == agent_alpha .. "/prompts",
  "expected agent_dirs to override legacy prompt paths"
)

local legacy_config = config_mod.normalize({
  sources = {
    { type = "commands", path = legacy_commands },
    { type = "skills", path = legacy_skills },
    { type = "prompts", path = legacy_prompts },
  },
})
assert(
  vim.tbl_isempty(legacy_config.agent_dirs),
  "legacy source mode should not expose derived agent dirs"
)
assert(
  #legacy_config.prompt_dirs == 1 and legacy_config.prompt_dirs[1] == legacy_prompts,
  "expected legacy prompt source"
)

local partial_legacy_config = config_mod.normalize({
  sources = {
    { type = "commands", path = legacy_commands },
  },
})
assert(
  #partial_legacy_config.command_dirs == 1
    and partial_legacy_config.command_dirs[1] == legacy_commands,
  "expected partial legacy commands source"
)
assert(
  vim.tbl_isempty(partial_legacy_config.skill_dirs),
  "expected omitted legacy skills to stay omitted"
)
assert(
  vim.tbl_isempty(partial_legacy_config.prompt_dirs),
  "expected omitted legacy prompts to stay omitted"
)

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  sources = {
    { type = "commands", path = legacy_commands },
    { type = "skills", path = legacy_skills },
    { type = "prompts", path = legacy_prompts },
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
assert(#summary.items == 5, "expected five indexed items in legacy source mode")
assert(#summary.warnings == 0, "expected no legacy source warnings")

dotagent.attach(0)
assert(dotagent.is_buffer_enabled(0) == true, "buffer should be attached")

local command_response = completion_for("/sh")
assert(#command_response.items >= 1, "expected matching command completion items")
assert(command_response.items[1].label == "/ship", "expected ship completion")
assert(command_response.items[1].kind_icon == "⚡", "expected default command icon")

local skill_response = completion_for("/au")
assert(#skill_response.items >= 1, "expected matching skill completion items")
assert(skill_response.items[1].label == "/auth", "expected auth completion")
assert(skill_response.items[1].kind_icon == "󰧑", "expected default skill icon")

local prompt_response = completion_for("/sys")
assert(#prompt_response.items >= 1, "expected matching prompt completion items")
assert(prompt_response.items[1].label == "/system", "expected system prompt completion")
assert(prompt_response.items[1].kind_icon == "󰘧", "expected default prompt icon")

local env_response = completion_for("/HOME")
assert(#env_response.items == 0, "env-like tokens should not complete")

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  agent_dirs = { agent_alpha, agent_beta },
  sources = {
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

summary = dotagent.refresh()
assert(#summary.items == 6, "expected derived agent dirs plus item source")
assert(#summary.warnings == 0, "expected no warnings for derived agent dirs")
assert(#dotagent.config().prompt_dirs == 1, "expected one derived prompt dir")

local derived_prompt = find_item(summary.items, "prompt", "system")
assert(derived_prompt.path == agent_alpha .. "/prompts/system.md", "expected derived prompt path")

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  agent_dirs = { agent_alpha },
  prompt_dirs = { override_prompts },
})

summary = dotagent.refresh()
assert(#summary.warnings == 0, "expected no warnings with explicit prompt override")
local override_prompt = find_item(summary.items, "prompt", "override")
assert(
  override_prompt.path == override_prompts .. "/override.md",
  "expected explicit prompt override item"
)

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  prompt_dirs = { override_prompts },
  sources = {
    { type = "commands", path = legacy_commands },
    { type = "skills", path = legacy_skills },
  },
})

summary = dotagent.refresh()
assert(#summary.warnings == 0, "expected no warnings in mixed legacy-plus-prompt config")
assert(
  find_item(summary.items, "command", "ship").path == legacy_commands .. "/ship.md",
  "expected legacy command source in mixed config"
)
assert(
  find_item(summary.items, "skill", "auth").path == legacy_skills .. "/auth/SKILL.md",
  "expected legacy skill source in mixed config"
)
assert(
  find_item(summary.items, "prompt", "override").path == override_prompts .. "/override.md",
  "expected explicit prompt source in mixed config"
)

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  command_dirs = { legacy_commands },
  prompt_dirs = { same_name_prompts },
})

summary = dotagent.refresh()
assert(
  find_item(summary.items, "command", "review").path == legacy_commands .. "/review.md",
  "expected command to remain when prompt shares the same name"
)
assert(
  find_item(summary.items, "prompt", "review").path == same_name_prompts .. "/review.md",
  "expected prompt to remain when command shares the same name"
)

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  sources = {
    { type = "commands", path = legacy_commands },
  },
})

summary = dotagent.refresh()
assert(#summary.items == 2, "expected partial legacy sources to stay authoritative")

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  agent_dirs = { agent_alpha },
  sources = {
    { type = "commands", path = legacy_commands },
    { type = "skills", path = legacy_skills },
    { type = "prompts", path = legacy_prompts },
  },
})

summary = dotagent.refresh()
assert(#summary.warnings == 0, "expected no warnings when agent_dirs override legacy sources")
assert(
  find_item(summary.items, "command", "alpha").path == agent_alpha .. "/commands/alpha.md",
  "expected derived command source when agent_dirs are set"
)
assert(
  find_item(summary.items, "skill", "explain").path == agent_alpha .. "/skills/explain/SKILL.md",
  "expected derived skill source when agent_dirs are set"
)
assert(
  find_item(summary.items, "prompt", "system").path == agent_alpha .. "/prompts/system.md",
  "expected derived prompt source when agent_dirs are set"
)

local dynamic_agent = temp_root .. "/dynamic-agent"
mkdir(dynamic_agent .. "/commands")
mkdir(dynamic_agent .. "/skills/dynamic")

writefile({
  "# Dynamic",
  "",
  "Dynamic command body.",
}, dynamic_agent .. "/commands/dynamic.md")

writefile({
  "# Dynamic Skill",
  "",
  "Dynamic skill body.",
}, dynamic_agent .. "/skills/dynamic/SKILL.md")

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  agent_dirs = { dynamic_agent },
})

summary = dotagent.refresh()
assert(
  find_item(summary.items, "command", "dynamic") ~= nil,
  "expected dynamic command before prompt creation"
)

mkdir(dynamic_agent .. "/prompts")
writefile({
  "# Later Prompt",
  "",
  "Prompt created after setup.",
}, dynamic_agent .. "/prompts/later.md")

summary = dotagent.refresh()
assert(
  find_item(summary.items, "prompt", "later").path == dynamic_agent .. "/prompts/later.md",
  "expected refresh to pick up new prompt directories"
)

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  agent_dirs = { agent_alpha },
  prompt_dirs = { missing_prompt_dir },
})

summary = dotagent.refresh()
assert(
  has_warning(summary.warnings, "prompts path is not readable"),
  "expected explicit missing prompt warning"
)

dotagent.setup({
  activation = {
    mode = "manual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  command_dirs = { duplicate_commands_one, duplicate_commands_two },
  skill_dirs = { legacy_skills },
})

summary = dotagent.refresh()
assert(
  has_warning(summary.warnings, "duplicate item /command:ship ignored"),
  "expected duplicate warning for commands"
)
local duplicate_ship = find_item(summary.items, "command", "ship")
assert(
  duplicate_ship.path == duplicate_commands_one .. "/ship.md",
  "expected first command dir to win duplicates"
)

dotagent.detach(0)
assert(dotagent.is_buffer_enabled(0) == false, "buffer should be detached")

vim.env.DOTAGENT_EDITOR_PROMPT = "1"
dotagent.setup({
  activation = {
    mode = "contextual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  command_dirs = { legacy_commands },
})
dotagent._maybe_attach_initial_buffer()
assert(dotagent.is_buffer_enabled(0) == true, "env marker should attach the initial buffer")

vim.cmd("enew")
assert(dotagent.is_buffer_enabled(0) == false, "subsequent buffers should stay detached")

print("dotagent.nvim tests passed")
