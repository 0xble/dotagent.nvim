local M = {}

local function default_sources()
  return {
    {
      type = "commands",
      path = vim.fn.expand("~/dotfiles/dot_agent/commands"),
    },
    {
      type = "skills",
      path = vim.fn.expand("~/dotfiles/dot_agent/skills"),
    },
    {
      type = "items",
      items = {},
    },
  }
end

function M.defaults()
  return {
    prefixes = { "/" },
    icons = {
      command = "",
      skill = "󰈙",
    },
    activation = {
      mode = "contextual",
      env_var = "DOTAGENT_EDITOR_PROMPT",
    },
    sources = default_sources(),
    browse = {
      prompt = "Dotagent",
    },
    blink = {
      score_offset = 90,
    },
  }
end

function M.normalize(user_config)
  local config = vim.tbl_deep_extend("force", M.defaults(), user_config or {})

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

  if type(config.sources) ~= "table" or vim.tbl_isempty(config.sources) then
    config.sources = default_sources()
  end

  return config
end

return M
