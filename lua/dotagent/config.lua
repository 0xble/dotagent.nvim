local util = require("dotagent.util")

local M = {}

local path_source_types = {
  commands = true,
  prompts = true,
  skills = true,
}

local function default_agent_dirs()
  return {
    vim.fn.expand("~/.agent/shared"),
    vim.fn.expand("~/.agent/runtimes/codex"),
    vim.fn.expand("~/.agent/runtimes/claude"),
    vim.fn.expand("~/.claude"),
  }
end

local function normalize_dir_list(dirs)
  local normalized = {}
  local seen = {}

  if type(dirs) ~= "table" then
    return normalized
  end

  for _, raw_path in ipairs(dirs) do
    local path = vim.fn.expand(util.trim(raw_path))
    if path ~= "" and not seen[path] then
      seen[path] = true
      table.insert(normalized, path)
    end
  end

  return normalized
end

local function normalize_sources(sources)
  if type(sources) ~= "table" then
    return {}
  end

  local normalized = {}

  for _, source in ipairs(sources) do
    local item = vim.deepcopy(source)
    if path_source_types[item.type] and type(item.path) == "string" then
      item.path = vim.fn.expand(util.trim(item.path))
    end
    table.insert(normalized, item)
  end

  return normalized
end

local function split_sources(sources)
  local path_sources = {}
  local passthrough_sources = {}

  for _, source in ipairs(sources) do
    if path_source_types[source.type] then
      table.insert(path_sources, source)
    else
      table.insert(passthrough_sources, source)
    end
  end

  return path_sources, passthrough_sources
end

local function source_paths(sources, source_type)
  local paths = {}

  for _, source in ipairs(sources) do
    if source.type == source_type and type(source.path) == "string" and source.path ~= "" then
      table.insert(paths, source.path)
    end
  end

  return paths
end

local function derive_subdirs(agent_dirs, subdir)
  local derived = {}

  for _, root in ipairs(agent_dirs) do
    table.insert(derived, root .. "/" .. subdir)
  end

  return derived
end

local function existing_dirs(dirs)
  local existing = {}

  for _, path in ipairs(dirs) do
    if util.readable(path) then
      table.insert(existing, path)
    end
  end

  return existing
end

local function append_sources(target, source_type, dirs, warn_on_duplicate)
  for _, path in ipairs(dirs) do
    table.insert(target, {
      type = source_type,
      path = path,
      warn_on_duplicate = warn_on_duplicate ~= false,
    })
  end
end

local function resolve_dirs(
  explicit_dirs,
  legacy_dirs,
  derived_dirs,
  prefer_derived,
  allow_derived_fallback
)
  if explicit_dirs ~= nil then
    return normalize_dir_list(explicit_dirs), false
  end

  if prefer_derived then
    return derived_dirs, true
  end

  if #legacy_dirs > 0 then
    return vim.deepcopy(legacy_dirs), false
  end

  if not allow_derived_fallback then
    return {}, false
  end

  return derived_dirs, true
end

function M.defaults()
  return {
    prefixes = { "/" },
    icons = {
      command = "⚡",
      skill = "󰧑",
      prompt = "󰘧",
    },
    activation = {
      mode = "contextual",
      env_var = "DOTAGENT_EDITOR_PROMPT",
    },
    agent_dirs = default_agent_dirs(),
    sources = {},
    browse = {
      prompt = "Dotagent",
    },
    blink = {
      score_offset = 90,
    },
  }
end

function M.normalize(user_config)
  user_config = user_config or {}

  local config = vim.tbl_deep_extend("force", M.defaults(), user_config)
  local normalized_sources = normalize_sources(user_config.sources)
  local legacy_path_sources, passthrough_sources = split_sources(normalized_sources)
  local has_legacy_path_config = #legacy_path_sources > 0

  if type(config.prefixes) ~= "table" or vim.tbl_isempty(config.prefixes) then
    config.prefixes = { "/" }
  end

  if type(config.icons) ~= "table" then
    config.icons = vim.deepcopy(M.defaults().icons)
  else
    config.icons = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults().icons), config.icons)
  end

  if config.activation == nil then
    config.activation = M.defaults().activation
  end

  if config.activation.mode == nil then
    config.activation.mode = "contextual"
  end

  if config.activation.env_var == nil or config.activation.env_var == "" then
    config.activation.env_var = "DOTAGENT_EDITOR_PROMPT"
  end

  if type(config.agent_dirs) ~= "table" or vim.tbl_isempty(config.agent_dirs) then
    config.agent_dirs = default_agent_dirs()
  else
    config.agent_dirs = normalize_dir_list(config.agent_dirs)
  end

  local effective_agent_dirs = user_config.agent_dirs ~= nil
      and normalize_dir_list(user_config.agent_dirs)
    or vim.deepcopy(config.agent_dirs)

  local default_command_dirs = user_config.agent_dirs ~= nil
      and derive_subdirs(effective_agent_dirs, "commands")
    or existing_dirs(derive_subdirs(effective_agent_dirs, "commands"))
  local default_skill_dirs = user_config.agent_dirs ~= nil
      and derive_subdirs(effective_agent_dirs, "skills")
    or existing_dirs(derive_subdirs(effective_agent_dirs, "skills"))
  local default_prompt_dirs = existing_dirs(derive_subdirs(effective_agent_dirs, "prompts"))

  local effective_command_dirs, derived_command_dirs = resolve_dirs(
    user_config.command_dirs,
    source_paths(legacy_path_sources, "commands"),
    default_command_dirs,
    user_config.agent_dirs ~= nil,
    not has_legacy_path_config
  )
  local effective_skill_dirs, derived_skill_dirs = resolve_dirs(
    user_config.skill_dirs,
    source_paths(legacy_path_sources, "skills"),
    default_skill_dirs,
    user_config.agent_dirs ~= nil,
    not has_legacy_path_config
  )
  local effective_prompt_dirs, derived_prompt_dirs = resolve_dirs(
    user_config.prompt_dirs,
    source_paths(legacy_path_sources, "prompts"),
    default_prompt_dirs,
    user_config.agent_dirs ~= nil,
    not has_legacy_path_config
  )

  config.sources = {}
  append_sources(
    config.sources,
    "commands",
    effective_command_dirs,
    not (derived_command_dirs and user_config.agent_dirs == nil)
  )
  append_sources(
    config.sources,
    "skills",
    effective_skill_dirs,
    not (derived_skill_dirs and user_config.agent_dirs == nil)
  )
  append_sources(
    config.sources,
    "prompts",
    effective_prompt_dirs,
    not (derived_prompt_dirs and user_config.agent_dirs == nil)
  )
  vim.list_extend(config.sources, passthrough_sources)

  local uses_agent_dirs = user_config.agent_dirs ~= nil
    or derived_command_dirs
    or derived_skill_dirs
    or derived_prompt_dirs
  config.agent_dirs = uses_agent_dirs and effective_agent_dirs or {}
  config.command_dirs = effective_command_dirs
  config.skill_dirs = effective_skill_dirs
  config.prompt_dirs = effective_prompt_dirs

  return config
end

return M
