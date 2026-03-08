local util = require("dotagent.util")

local M = {}

local function build_item(path, config_prefix)
  local content, err = util.read_file(path)
  if content == nil then
    return nil, err
  end

  local metadata, body = util.parse_frontmatter(content)
  local dirname = vim.fn.fnamemodify(path, ":h:t")
  local name = util.trim(metadata.name or dirname)
  if name == "" then
    return nil, "missing item name"
  end

  return {
    id = "skill:" .. name,
    name = name,
    kind = "skill",
    description = util.trim(metadata.description or util.first_paragraph(body)),
    path = path,
    aliases = util.normalize_aliases(metadata.aliases),
    prefix = config_prefix,
    source = "skills",
    content = content,
  }
end

function M.collect(source_config, config_prefix)
  local items = {}
  local warnings = {}

  if util.readable(source_config.path) == false then
    table.insert(warnings, "skills path is not readable: " .. tostring(source_config.path))
    return items, warnings
  end

  local paths = vim.fn.globpath(source_config.path, "*/SKILL.md", false, true)
  table.sort(paths)

  for _, path in ipairs(paths) do
    local item, err = build_item(path, config_prefix)
    if item == nil then
      table.insert(warnings, "failed to parse skill " .. path .. ": " .. err)
    else
      table.insert(items, item)
    end
  end

  return items, warnings
end

return M
