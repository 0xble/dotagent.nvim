local M = {}

local collectors = {
  commands = require("dotagent.source.commands"),
  skills = require("dotagent.source.skills"),
  items = require("dotagent.source.items"),
}

local state = {
  items = {},
  warnings = {},
}

local function dedupe(items)
  local seen = {}
  local deduped = {}
  local warnings = {}

  for _, item in ipairs(items) do
    local key = item.prefix .. item.name
    if seen[key] == nil then
      seen[key] = item.path or item.source
      table.insert(deduped, item)
    else
      table.insert(
        warnings,
        "duplicate item " .. key .. " ignored from " .. tostring(item.path or item.source) .. ", first seen at " .. tostring(seen[key])
      )
    end
  end

  return deduped, warnings
end

function M.refresh(config)
  local all_items = {}
  local warnings = {}
  local default_prefix = config.prefixes[1]

  for _, source_config in ipairs(config.sources or {}) do
    local collector = collectors[source_config.type]
    if collector == nil then
      table.insert(warnings, "unknown source type: " .. tostring(source_config.type))
    else
      local items, source_warnings = collector.collect(source_config, default_prefix)
      vim.list_extend(all_items, items)
      vim.list_extend(warnings, source_warnings)
    end
  end

  table.sort(all_items, function(left, right)
    if left.name == right.name then
      return left.kind < right.kind
    end
    return left.name < right.name
  end)

  local deduped_items, duplicate_warnings = dedupe(all_items)
  vim.list_extend(warnings, duplicate_warnings)

  state.items = deduped_items
  state.warnings = warnings

  return {
    items = vim.deepcopy(state.items),
    warnings = vim.deepcopy(state.warnings),
  }
end

function M.items()
  return vim.deepcopy(state.items)
end

function M.warnings()
  return vim.deepcopy(state.warnings)
end

return M
