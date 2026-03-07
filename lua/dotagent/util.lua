local M = {}

function M.readable(path)
  return path ~= nil and path ~= "" and vim.uv.fs_stat(path) ~= nil
end

function M.read_file(path)
  local fd = io.open(path, "r")
  if fd == nil then
    return nil, "could not open file"
  end

  local content = fd:read("*a")
  fd:close()
  return content
end

function M.trim(value)
  if value == nil then
    return ""
  end

  if type(value) ~= "string" then
    if type(value) == "number" or type(value) == "boolean" then
      value = tostring(value)
    else
      return ""
    end
  end

  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.split_lines(value)
  if value == nil or value == "" then
    return {}
  end

  return vim.split(value, "\n", { plain = true })
end

function M.parse_frontmatter(content)
  if content == nil or not vim.startswith(content, "---\n") then
    return {}, content
  end

  local marker_start = 5
  local marker_end = content:find("\n---\n", marker_start, true)
  if marker_end == nil then
    return {}, content
  end

  local block = content:sub(marker_start, marker_end - 1)
  local rest = content:sub(marker_end + 5)
  local metadata = {}
  local active_list_key = nil

  for _, raw_line in ipairs(M.split_lines(block)) do
    local line = M.trim(raw_line)
    if line ~= "" then
      local list_value = line:match("^%-%s+(.+)$")
      if list_value ~= nil and active_list_key ~= nil then
        metadata[active_list_key] = metadata[active_list_key] or {}
        table.insert(metadata[active_list_key], M.trim(list_value))
      else
        local key, value = line:match("^([%w_-]+):%s*(.*)$")
        if key ~= nil then
          active_list_key = nil
          if value == "" then
            metadata[key] = metadata[key] or {}
            active_list_key = key
          elseif key == "aliases" then
            metadata[key] = {}
            for alias in value:gmatch("[^,%[%]]+") do
              local trimmed = M.trim(alias:gsub("^['\"]", ""):gsub("['\"]$", ""))
              if trimmed ~= "" then
                table.insert(metadata[key], trimmed)
              end
            end
          else
            metadata[key] = M.trim(value:gsub("^['\"]", ""):gsub("['\"]$", ""))
          end
        end
      end
    end
  end

  return metadata, rest
end

function M.first_heading(content)
  for _, line in ipairs(M.split_lines(content or "")) do
    local heading = line:match("^#%s+(.+)$")
    if heading ~= nil then
      return M.trim(heading)
    end
  end

  return nil
end

function M.first_paragraph(content)
  local paragraph = {}

  for _, raw_line in ipairs(M.split_lines(content or "")) do
    local line = M.trim(raw_line)
    if line ~= "" and not vim.startswith(line, "#") then
      table.insert(paragraph, line)
    elseif #paragraph > 0 then
      break
    end
  end

  return M.trim(table.concat(paragraph, " "))
end

function M.normalize_aliases(aliases)
  if type(aliases) ~= "table" then
    return {}
  end

  local seen = {}
  local normalized = {}

  for _, alias in ipairs(aliases) do
    local value = M.trim(alias)
    if value ~= "" and not seen[value] then
      seen[value] = true
      table.insert(normalized, value)
    end
  end

  return normalized
end

function M.token_context(line, cursor_col, prefixes)
  local line_before_cursor = (line or ""):sub(1, cursor_col or 0)

  for _, prefix in ipairs(prefixes or {}) do
    local escaped_prefix = vim.pesc(prefix)
    local token = line_before_cursor:match("(" .. escaped_prefix .. "[%w_-]*)$")
    if token ~= nil then
      local body = token:sub(#prefix + 1)
      if body:match("^[A-Z0-9_]+$") and body:find("[A-Z]") ~= nil then
        return nil
      end

      return {
        token = token,
        prefix = prefix,
        query = body,
      }
    end
  end

  return nil
end

function M.score_item(item, query)
  if query == "" then
    return item.name
  end

  if item.name == query then
    return "0-" .. item.name
  end

  if vim.startswith(item.name, query) then
    return "1-" .. item.name
  end

  for _, alias in ipairs(item.aliases or {}) do
    if alias == query then
      return "2-" .. item.name
    end
    if vim.startswith(alias, query) then
      return "3-" .. item.name
    end
  end

  return "9-" .. item.name
end

return M
