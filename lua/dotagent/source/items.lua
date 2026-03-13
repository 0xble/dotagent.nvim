local util = require("dotagent.util")

local M = {}

function M.collect(source_config, config_prefix)
  local items = {}
  local warnings = {}

  for index, raw_item in ipairs(source_config.items or {}) do
    local name = util.trim(raw_item.name)
    if name == "" then
      table.insert(warnings, "lua item at index " .. index .. " is missing a name")
    else
      table.insert(items, {
        id = raw_item.id or ("item:" .. name),
        name = name,
        kind = raw_item.kind or "item",
        description = util.trim(raw_item.description),
        path = raw_item.path,
        aliases = util.normalize_aliases(raw_item.aliases),
        prefix = raw_item.prefix or config_prefix,
        source = "items",
        content = raw_item.content or "",
        warn_on_duplicate = raw_item.warn_on_duplicate ~= false,
      })
    end
  end

  return items, warnings
end

return M
