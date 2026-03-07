local M = {}

function M.check()
  local health = vim.health or require("health")
  local ok_start = health.start or health.report_start
  local ok_info = health.ok or health.report_ok
  local warn_info = health.warn or health.report_warn

  ok_start("dotagent.nvim")

  local dotagent = require("dotagent")
  local config = dotagent.config()
  local summary = dotagent.refresh()

  ok_info("activation mode: " .. config.activation.mode)
  ok_info("activation env var: " .. config.activation.env_var)
  ok_info("indexed items: " .. tostring(#summary.items))

  if #summary.warnings == 0 then
    ok_info("no source warnings")
  else
    for _, warning in ipairs(summary.warnings) do
      warn_info(warning)
    end
  end
end

return M
