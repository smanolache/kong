-- Kong resolver core-plugin
--
-- This core-plugin is executed before any other, and allows to map a Host header
-- to an API added to Kong. If the API was found, it will set the $backend_url variable
-- allowing nginx to proxy the request as defined in the nginx configuration.
--
-- Executions: 'access', 'header_filter'

local BasePlugin = require "kong.plugins.base_plugin"
local init_worker = require "kong.reports.init_worker"

local ReportsHandler = BasePlugin:extend()

function ReportsHandler:new()
  ReportsHandler.super.new(self, "reports")
end

function ReportsHandler:init_worker()
  ReportsHandler.super.init_worker(self)
  init_worker.execute()
end

return ReportsHandler
