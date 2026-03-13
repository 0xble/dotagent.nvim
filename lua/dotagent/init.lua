local config_mod = require("dotagent.config")
local index = require("dotagent.index")
local util = require("dotagent.util")

local M = {}

local state = {
  user_config = {},
  config = config_mod.defaults(),
  commands_registered = false,
  autocommands_registered = false,
  initial_prompt_attached = false,
}

local function current_config()
  return state.config
end

local function is_prompt_env_enabled()
  local env_name = current_config().activation.env_var
  return vim.env[env_name] == "1"
end

local function set_buffer_enabled(bufnr, enabled)
  vim.b[bufnr].dotagent_enabled = enabled == true
end

local function attach_initial_prompt_buffer()
  if state.initial_prompt_attached then
    return
  end

  if current_config().activation.mode ~= "contextual" then
    return
  end

  if is_prompt_env_enabled() == false then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype == "terminal" then
    return
  end

  set_buffer_enabled(bufnr, true)
  state.initial_prompt_attached = true
end

local function ensure_autocmds()
  if state.autocommands_registered then
    return
  end

  local group = vim.api.nvim_create_augroup("dotagent.nvim", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      attach_initial_prompt_buffer()
    end,
  })

  state.autocommands_registered = true
end

local function ensure_commands()
  if state.commands_registered then
    return
  end

  vim.api.nvim_create_user_command("DotagentRefresh", function()
    M.refresh()
  end, {})

  vim.api.nvim_create_user_command("DotagentAttach", function(command)
    local target = command.args ~= "" and tonumber(command.args) or vim.api.nvim_get_current_buf()
    M.attach(target)
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("DotagentDetach", function(command)
    local target = command.args ~= "" and tonumber(command.args) or vim.api.nvim_get_current_buf()
    M.detach(target)
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("DotagentBrowse", function()
    M.browse()
  end, {})

  vim.api.nvim_create_user_command("DotagentHealth", function()
    vim.cmd("checkhealth dotagent")
  end, {})

  state.commands_registered = true
end

local function ensure_setup()
  ensure_commands()
  ensure_autocmds()
end

local function insert_text_at_cursor(value)
  vim.api.nvim_put({ value }, "c", true, true)
end

function M.setup(user_config)
  state.user_config = vim.deepcopy(user_config or {})
  state.config = config_mod.normalize(state.user_config)
  ensure_setup()
  index.refresh(state.config)
  attach_initial_prompt_buffer()
end

function M.config()
  return current_config()
end

function M.refresh()
  ensure_setup()
  state.config = config_mod.normalize(state.user_config)
  return index.refresh(current_config())
end

function M.get_items()
  ensure_setup()
  return index.items()
end

function M.get_warnings()
  ensure_setup()
  return index.warnings()
end

function M.attach(bufnr)
  ensure_setup()
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  set_buffer_enabled(bufnr, true)
end

function M.detach(bufnr)
  ensure_setup()
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  set_buffer_enabled(bufnr, false)
end

function M.is_buffer_enabled(bufnr)
  ensure_setup()
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if current_config().activation.mode == "global" then
    return vim.bo[bufnr].buftype ~= "terminal"
  end

  return vim.b[bufnr].dotagent_enabled == true
end

function M.browse()
  ensure_setup()
  local items = M.get_items()

  vim.ui.select(items, {
    prompt = current_config().browse.prompt,
    format_item = function(item)
      local detail = item.description ~= "" and (" - " .. item.description) or ""
      return item.prefix .. item.name .. " [" .. item.kind .. "]" .. detail
    end,
  }, function(item)
    if item ~= nil then
      insert_text_at_cursor(item.prefix .. item.name)
    end
  end)
end

function M.complete_token(line, cursor_col)
  local token = util.token_context(line, cursor_col, current_config().prefixes)
  if token == nil then
    return {}
  end

  local matches = {}
  for _, item in ipairs(M.get_items()) do
    if item.prefix == token.prefix then
      table.insert(matches, item)
    end
  end
  return matches
end

function M._register_commands()
  ensure_commands()
end

function M._maybe_attach_initial_buffer()
  attach_initial_prompt_buffer()
end

return M
