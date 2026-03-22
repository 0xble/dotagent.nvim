local util = require("dotagent.util")

local M = {}
local Source = {}
Source.__index = Source

local function completion_kind(item)
  local ok, blink_types = pcall(require, "blink.cmp.types")
  if ok then
    if item.kind == "skill" then
      return blink_types.CompletionItemKind.Module
    end
    return blink_types.CompletionItemKind.Keyword
  end

  return vim.lsp.protocol.CompletionItemKind.Keyword
end

local function completion_icon(item)
  local config = require("dotagent").config()
  local icon = config.icons ~= nil and config.icons[item.kind] or nil
  if type(icon) ~= "string" or icon == "" then
    return nil
  end

  return icon
end

local function documentation_value(item)
  local lines = {}

  if item.description ~= nil and item.description ~= "" then
    table.insert(lines, item.description)
  end

  if item.path ~= nil and item.path ~= "" then
    if #lines > 0 then
      table.insert(lines, "")
    end
    table.insert(lines, "Path: " .. item.path)
  end

  if item.content ~= nil and item.content ~= "" then
    if #lines > 0 then
      table.insert(lines, "")
    end
    table.insert(lines, item.content)
  end

  return table.concat(lines, "\n")
end

local function response_items(context)
  local dotagent = require("dotagent")
  local config = dotagent.config()
  local token = util.token_context(context.line, context.cursor[2], config.prefixes)

  if token == nil then
    return {}
  end

  local items = {}

  for _, item in ipairs(dotagent.get_items()) do
    if item.prefix == token.prefix then
      local matches = token.query == ""
        or vim.startswith(item.name, token.query)
        or item.name:find(token.query, 1, true) ~= nil

      if not matches then
        for _, alias in ipairs(item.aliases or {}) do
          if vim.startswith(alias, token.query) or alias:find(token.query, 1, true) ~= nil then
            matches = true
            break
          end
        end
      end

      if matches then
        table.insert(items, {
          label = item.prefix .. item.name,
          insertText = item.prefix .. item.name,
          insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
          filterText = item.prefix .. item.name,
          sortText = util.score_item(item, token.query),
          kind = completion_kind(item),
          kind_icon = completion_icon(item),
          detail = item.description ~= "" and item.description or item.kind,
          documentation = {
            kind = vim.lsp.protocol.MarkupKind.Markdown,
            value = documentation_value(item),
          },
          data = {
            dotagent_item = item,
          },
        })
      end
    end
  end

  return items
end

function Source.new()
  return setmetatable({}, Source)
end

function Source:enabled()
  return require("dotagent").is_buffer_enabled(vim.api.nvim_get_current_buf())
end

function Source:get_trigger_characters()
  return require("dotagent").config().prefixes
end

function Source:should_show_items(context, items)
  return util.token_context(context.line, context.cursor[2], require("dotagent").config().prefixes) ~= nil and #items > 0
end

function Source:get_completions(context, callback)
  vim.schedule(function()
    callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = response_items(context),
    })
  end)
end

function Source:resolve(item, callback)
  callback(item)
end

function Source:reload()
  require("dotagent").refresh()
end

function M.new()
  return Source.new()
end

function M.provider()
  return {
    name = "Dotagent",
    module = "dotagent.completion.blink",
    enabled = function()
      return require("dotagent").is_buffer_enabled(vim.api.nvim_get_current_buf())
    end,
    score_offset = require("dotagent").config().blink.score_offset,
    fallbacks = {},
    min_keyword_length = 0,
  }
end

return M
