-- Kong.init
--   kong.tools.dao_loader:load()
--     singletons.dao = kong.dao.factory(...)
--       _db = kong.dao.cassandra_binary_db(options)
--       for each plugin that has dao/cassandra_binary.lua
--         f = kong.tools.utils.load_module_if_exists(kong.plugins.plugin.dao.cassandra_binary_db)
--         daos[plugin_name] = f(options)
--       for each schema (both core schemas, i.e. apis, consumers, plugins, nodes, and plugin schemas)
--         Factory.daos[schema_name] = kong.dao.dao(_db, its own table, ...)
--   singletons.dao.plugins:find_all()
--     kong.dao.dao:find_all()
--       kong.dao.cassandra_binary_db:find_all(table_name, filter_keys, schema)

-- Kong.init_worker
--   kong.core.handler.init_worker.before()
--     kong.core.reports.init_worker()
--     kong.core.cluster.init_worker()
--   singletons.dao:init()
--     kong.dao.factory:init()
--       kong.dao.cassandra_binary_db:init()
--   for all loaded_plugins
--     plugin.handler:init_worker()

-- Kong.ssl_certificate()
--   kong.core.handler.certificate.before()
--     ngx.ctx.api = kong.core.certificate.execute()
--   for all loaded_plugins
--     plugin.handler:certificate(plugin_conf)

-- Kong.access()
--   kong.core.handler.access.before()
--     ngx.* = kong.core.resolver.execute(uri, headers)
--   for all loaded_plugins
--     plugin.handler:access(plugin_conf)
--   kong.core.handler.access.after()

-- Kong.header_filter()
--   kong.core.handler.header_filter.before()
--   for all loaded_plugins
--     plugin.handler:header_filter(plugin_conf)
--   kong.core.handler.header_filter.after()

-- Kong.body_filter()
--   for all loaded_plugins
--     plugin.handler:body_filter(plugin_conf)
--   kong.core.handler.body_filter.after()

-- Kong.log()
--   for all loaded_plugins
--     plugin.handler:log(plugin_conf)
--   kong.core.handler.log.after()
--     kong.core.reports.log()

-- kong.core.error_handlers(ngx)

-- kong.api.app

-- :new(options) -- from init_by_lua -> kong:init()   init shared dictionaries
-- :init() -- from init_worker_by_lua -> kong.init_worker()
-- :find_all(table_name, filter_keys, schema) -- at least from init_by_lua -> kong.init()

-- :count
-- :delete
-- :find
-- :find_all
-- :find_page
-- :increment
-- :insert
-- :update

local BaseDB = require "kong.dao.base_db"
local db = require "db.cassandra"

local CassBinaryDB = BaseDB:extend()

local function init_cluster(options)
   local cluster = db.cass_cluster_new()
   if nil == cluster then
      return nil, "cannot construct cassandra cluster representation"
   end

   local rc = cluster:set_port(options.port and options.port or 9042)
   if 0 ~= rc then
      return nil, db.cass_error_desc(rc)
   end

   rc = cluster:set_protocol_version(options.protocol_version and options.protocol_version or 3)
   if 0 ~= rc then
      return nil, db.cass_error_desc(rc)
   end

   rc = cluster:set_contact_points(options.contact_points)
   if 0 ~= rc then
      return nil, db.cass_error_desc(rc)
   end

   if options.username and options.password then
      cluster:set_credentials(options.username, options.password)
   end

   if nil ~= options.ssl and nil ~= options.ssl.enabled and options.ssl.enabled then
      local ssl = db.cass_ssl_new()
      if nil == ssl then
	 return nil, "cannot build ssl object; probably out-of-memory"
      end

      rc = ssl:set_verify_flags(options.ssl.verify and 1 or 0)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end

      cluster:set_ssl(ssl)
   end

   if nil ~= options.core_connections_per_host then
      rc = cluster:set_core_connections_per_host(options.core_connections_per_host)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.max_connections_per_host then
      rc = cluster:set_max_connections_per_host(options.max_connections_per_host)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.num_threads_io then
      rc = cluster:set_num_threads_io(options.num_threads_io)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.queue_size_io then
      rc = cluster:set_queue_size_io(options.queue_size_io)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.queue_size_event then
      rc = cluster:set_queue_size_event(options.queue_size_event)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.reconnect_wait_time then
      rc = cluster:set_reconnect_wait_time(options.reconnect_wait_time)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.max_concurrent_creation then
      rc = cluster:set_max_concurrent_creation(options.max_concurrent_creation)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.max_concurrent_requests_threshold then
      rc = cluster:set_max_concurrent_requests_threshold(options.max_concurrent_requests_threshold)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.max_requests_per_flush then
      rc = cluster:set_max_requests_per_flush(options.max_requests_per_flush)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.write_bytes_high_water_mark then
      rc = cluster:set_write_bytes_high_water_mark(options.write_bytes_high_water_mark)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.write_bytes_low_water_mark then
      rc = cluster:set_write_bytes_low_water_mark(options.write_bytes_low_water_mark)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.pending_requests_high_water_mark then
      rc = cluster:set_pending_requests_high_water_mark(options.pending_requests_high_water_mark)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.pending_requests_low_water_mark then
      rc = cluster:set_pending_requests_low_water_mark(options.pending_requests_low_water_mark)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.connect_timeout then
      cluster:set_connect_timeout(options.connect_timeout)
   end

   if nil ~= options.request_timeout then
      cluster:set_request_timeout(options.request_timeout)
   end

   if nil ~= options.load_balance_round_robin and options.load_balance_round_robin then
      cluster:set_load_balance_round_robin()
   end

   if nil ~= options.load_balance_dc_aware then
      rc = cluster:set_load_balance_dc_aware(
	 options.load_balance_dc_aware.local_dc,
	 options.load_balance_dc_aware.used_hosts_per_remote_dc,
	 options.load_balance_dc_aware.allow_remote_dcs_for_local_cl)
      if 0 ~= rc then
	 return nil, db.cass_error_desc(rc)
      end
   end

   if nil ~= options.token_aware_routing then
      cluster:set_token_aware_routing(options.token_aware_routing)
   end

   if nil ~= options.latency_aware_routing then
      cluster:set_latency_aware_routing(options.latency_aware_routing)
   end

   if nil ~= options.latency_aware_routing_settings then
      cluster:set_latency_aware_routing_settings(
	 options.latency_aware_routing_settings.exclusion_threshold,
	 options.latency_aware_routing_settings.scale_ms,
	 options.latency_aware_routing_settings.retry_period_ms,
	 options.latency_aware_routing_settings.update_rate_ms,
	 options.latency_aware_routing_settings.min_measured)
   end

   if nil ~= options.whitelist_filtering then
      cluster:set_whitelist_filtering(options.whitelist_filtering)
   end

   if nil ~= options.blacklist_filtering then
      cluster:set_blacklist_filtering(options.blacklist_filtering)
   end

   if nil ~= options.whitelist_dc_filtering then
      cluster:set_whitelist_dc_filtering(options.whitelist_dc_filtering)
   end

   if nil ~= options.blacklist_dc_filtering then
      cluster:set_blacklist_dc_filtering(options.blacklist_dc_filtering)
   end

   if nil ~= options.tcp_nodelay then
      cluster:set_tcp_nodelay(options.tcp_nodelay)
   end

   if nil ~= options.tcp_keepalive then
      cluster:set_tcp_keepalive(options.tcp_keepalive.enabled, options.tcp_keepalive.delay_secs)
   end

   if nil ~= options.timestamp_gen then
      if "monotonic" == options.timestamp_gen then
	 cluster:set_timestamp_gen(db.cass_timestamp_gen_monotonic_new())
      elseif "server_side" == options.timestamp_gen then
	 cluster:set_timestamp_gen(db.cass_timestamp_gen_server_side_new())
      end
   end

   if nil ~= options.connection_heartbeat_interval then
      cluster:set_connection_heartbeat_interval(options.connection_heartbeat_interval)
   end

   if nil ~= options.connection_idle_timeout then
      cluster:set_connection_idle_timeout(options.connection_idle_timeout)
   end

   if nil ~= options.retry_policy then
      local retry_policy = nil
      local name = options.retry_policy.name and options.retry_policy.name or options.retry_policy
      if "default" == name then
	 retry_policy = db.cass_retry_policy_default_new()
      elseif "downgrading_consistency" == name then
	 retry_policy = db.cass_retry_policy_downgrading_consistency_new()
      elseif "policy_fallthrough" == name then
	 retry_policy = db.cass_retry_policy_fallthrough_new()
      end
      if options.retry_policy.logging then
	 local inner_policy = child_policy
	 retry_policy = db.cass_retry_policy_logging_new(child_policy)
      end
      cluster:set_retry_policy(retry_policy)
   end

   if nil ~= options.use_schema then
      cluster:set_use_schema(options.use_schema)
   end

   return cluster, nil
end

local function init_session(cluster, options)
   if nil == cluster then
      return nil
   end
   local session = cassandra.cass_session_new()
   if nil == session then
      return nil
   end
   local future = session:connect_keyspace(cluster, options.keyspace)
   future:wait()
   local rc = future:error_code()
   if 0 ~= rc then
      return nil
   end
   return session
end

function CassBinaryDB:new(options)
   local conn_opts = {
      shm = "cassandra_binary",
      prepared_shm = "cassandra_binary_prepared",
      contact_points = options.contact_points,
      keyspace = options.keyspace,
      protocol_options = {
	 default_version = options.protocol_version,
	 default_port = options.port
      },
      query_options = {
	 prepare = true
      },
      ssl_options = {
	 enabled = options.ssl.enabled,
	 verify = options.ssl.verify,
	 ca = options.ssl.certificate_authority
      }
   }

   if options.username and options.password then
      conn_opts.auth = {username = options.username, password = options.password}
   end

   local cluster, cl_err = init_cluster(options)
   local session, ss_err = init_session(cluster, options)

   self.cluster = cluster
   self.session = session

   CassBinaryDB.super.new(self, "cassandra_binary", conn_opts)
end

function CassBinaryDB:infos()
   return {
      desc = "keyspace",
      name = self:_get_conn_options().keyspace
   }
end

--function CassBinaryDB:init()
--end

function CassBinaryDB:query(query, args, opts, schema, no_keyspace)
end

function CassBinaryDB:find(table_name, schema, filter_keys)
end

function CassBinaryDB:find_all(table_name, tbl, schema)
end

function CassBinaryDB:find_page(table_name, tbl, paging_state, page_size, schema)
end

function CassBinaryDB:insert(table_name, schema, model, constraints, options)
end

function CassBinaryDB:update(table_name, schema, constraints, filter_keys, values, nils, full, model, options)
end

function CassBinaryDB:count(table_name, tbl, schema)
end

function CassBinaryDB:delete(table_name, schema, primary_keys, constraints)
end

function CassBinaryDB:queries(queries, no_keyspace)
end

function CassBinaryDB:drop_table(table_name)
end

function CassBinaryDB:truncate_table(table_name)
end

function CassBinaryDB:current_migrations()
end

function CassBinaryDB:record_migration(id, name)
end

return CassBinaryDB

local timestamp = require "kong.tools.timestamp"
local Errors = require "kong.dao.errors"
local BaseDB = require "kong.dao.base_db"
local utils = require "kong.tools.utils"
local uuid = require "lua_uuid"

local ngx_stub = _G.ngx
_G.ngx = nil
local cassandra = require "db.cassandra"
_G.ngx = ngx_stub

local CassandraDB = BaseDB:extend()

CassandraDB.dao_insert_values = {
  id = function()
    return uuid()
  end,
  timestamp = function()
    return timestamp.get_utc()
  end
}

function CassandraDB:new(options)
  local conn_opts = {
    shm = "cassandra_binary",
    prepared_shm = "cassandra_binary_prepared",
    contact_points = options.contact_points,
    keyspace = options.keyspace,
    protocol_options = {
      default_port = options.port
    },
    query_options = {
      prepare = true
    },
    ssl_options = {
      enabled = options.ssl.enabled,
      verify = options.ssl.verify,
      ca = options.ssl.certificate_authority
    }
  }

  if options.username and options.password then
     conn_opts.auth = {username = options.username, password = options.password }
  end

  CassandraDB.super.new(self, "cassandra_binary", conn_opts)

  -- we should lock here
  local cluster = get_cluster_from_global_shared_cache()
  if nil == cluster then
     cluster = cassandra.cass_cluster_new()
     if nil == cluster then
	-- TODO
     end
     cluster:set_port(options.port)
     -- TODO
     cluster:set_protocol_version(...)
     cluster:set_contact_points(...)
  end
  local session = get_session_from_global_shared_cache()
  if nil == session then
     session = cassandra.cass_session_new()
     if nil == session then
	-- TODO
     end
     local future = session:connect_keyspace(cluster, options.keyspace)
     future:wait()
     local rc = future:error_code()
     if 0 ~= rc then
	-- TODO
     end
  end
  -- unlock
  self.cluster = cluster
  self.session = session
end

function CassandraDB:infos()
  return {
    desc = "keyspace",
    name = self:_get_conn_options().keyspace
  }
end

-- Formatting

local function serialize_arg(field, value)
  if value == nil then
     -- TODO
     -- returns {value = "unset", type_id = "unset" }
    return cassandra.unset
  elseif field.type == "id" then
     -- TODO
     -- returns {value = value, type_id = 0x0c }
    return cassandra.uuid(value)
  elseif field.type == "timestamp" then
     -- TODO
     -- returns {value = value, type_id = 0x0b }
    return cassandra.timestamp(value)
  elseif field.type == "table" or field.type == "array" then
    local json = require "cjson"
    -- returns a string
    return json.encode(value)
  else
    return value
  end
end

local function deserialize_rows(rows, schema)
  local json = require "cjson"
  for i, row in ipairs(rows) do
    for col, value in pairs(row) do
      if schema.fields[col].type == "table" or schema.fields[col].type == "array" then
        rows[i][col] = json.decode(value)
      end
    end
  end
end

local function get_where(schema, filter_keys, args)
  args = args or {}
  local fields = schema.fields
  local where = {}

  for col, value in pairs(filter_keys) do
    where[#where + 1] = col.." = ?"
    args[#args + 1] = serialize_arg(fields[col], value)
  end

  return table.concat(where, " AND "), args
end

local function get_select_query(table_name, where, select_clause)
  local query = string.format("SELECT %s FROM %s", select_clause or "*", table_name)
  if where ~= nil then
    query = query.." WHERE "..where.." ALLOW FILTERING"
  end

  return query
end

--- Querying

local function check_unique_constraints(self, table_name, constraints, values, primary_keys, update)
  local errors

  for col, constraint in pairs(constraints.unique) do
    -- Only check constraints if value is non-null
    if values[col] ~= nil then
      local where, args = get_where(constraint.schema, {[col] = values[col]})
      local query = get_select_query(table_name, where)
      local rows, err = self:query(query, args, nil, constraint.schema)
      if err then
        return err
      elseif #rows > 0 then
        -- if in update, it's fine if the retrieved row is the same as the one updated
        if update then
          local same_row = true
          for col, val in pairs(primary_keys) do
            if val ~= rows[1][col] then
              same_row = false
              break
            end
          end

          if not same_row then
            errors = utils.add_error(errors, col, values[col])
          end
        else
          errors = utils.add_error(errors, col, values[col])
        end
      end
    end
  end

  return Errors.unique(errors)
end

local function check_foreign_constaints(self, values, constraints)
  local errors

  for col, constraint in pairs(constraints.foreign) do
    -- Only check foreign keys if value is non-null, if must not be null, field should be required
    if values[col] ~= nil then
      local res, err = self:find(constraint.table, constraint.schema, {[constraint.col] = values[col]})
      if err then
        return err
      elseif res == nil then
        errors = utils.add_error(errors, col, values[col])
      end
    end
  end

  return Errors.foreign(errors)
end

function CassandraDB:page_iterator(query, args, query_options)
   local page = 0

   return function(db, previous_rows)
      if previous_rows and previous_rows.meta.has_more_pages == false then
	 return nil -- End iteration after error
      end

      query_options.paging_state = previous_rows and previous_rows.meta.paging_state

      local rows, err = db:inner_execute(query, args, query_options)

      -- If we have some results, increment the page
      if rows ~= nil and #rows > 0 then
	 page = page + 1
      else
	 if err then
	    -- Just expose the error with 1 last iteration
	    return {meta = {has_more_pages = false}}, err, page
	 elseif rows.meta.has_more_pages == false then
	    return nil -- End of the iteration
	 end
      end

      return rows, err, page
   end, self, nil
end

local function read_value(value, value_type)
   local elem = nil
   if nil == value or value:is_null() then
      elem = nil
   elseif cassandra.TYPES.VALUE_TYPE_ASCII == value_type or
      cassandra.TYPES.VALUE_TYPE_TEXT == value_type or
      cassandra.TYPES.VALUE_TYPE_VARCHAR == value_type
   then
      local rc
      rc, elem = value:get_string()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_BIGINT == value_type or
      cassandra.TYPES.VALUE_TYPE_COUNTER == value_type or
      cassandra.TYPES.VALUE_TYPE_TIMESTAMP == value_type or
      cassandra.TYPES.VALUE_TYPE_TIME == value_type
   then
      local rc
      rc, elem = value:get_int64()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_BLOB == value_type or
      cassandra.TYPES.VALUE_TYPE_VARINT == value_type
   then
      local rc
      rc, elem = value:get_bytes()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_BOOLEAN == value_type then
      local rc
      rc, elem = value:get_bool()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_DATE == value_type then
      local rc
      rc, elem = value:get_uint32()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_DECIMAL == value_type then
      local rc
      rc, elem = value:get_decimal()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_DOUBLE == value_type then
      local rc
      rc, elem = value:get_double()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_FLOAT == value_type then
      local rc
      rc, elem = value:get_float()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_INET == value_type then
      local rc
      rc, elem = value:get_inet()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_INT == value_type then
      local rc
      rc, elem = value:get_int32()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_TINYINT == value_type then
      local rc
      rc, elem = value:get_int8()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_SMALLINT == value_type then
      local rc
      rc, elem = value:get_int16()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_UUID == value_type or
      cassandra.TYPES.VALUE_TYPE_TIMEUUID == value_type
   then
      local rc
      rc, elem = value:get_uuid()
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   elseif cassandra.TYPES.VALUE_TYPE_LIST == value_type or
      cassandra.TYPES.VALUE_TYPE_SET == value_type
   then
      local it = value:iterator_from_collection()
      local s = {}
      while it:next() do
	 local val = it:get_value()
	 if nil == val then
	    -- TODO
	 end
	 local v, err = read_value(val, val:type())
	 if err then
	    return nil, err
	 end
	 s[#s + 1] = v
      end
      elem = s
   elseif cassandra.TYPES.VALUE_TYPE_MAP == value_type then
      local it = value:iterator_from_collection()
      local s = {}
      while it:next() do
	 local val = it:get_value()
	 if nil == val then
	    -- TODO
	 end
	 local k, err = read_value(val, val:type())
	 if err then
	    return nil, err
	 end
	 if not it:next() then
	    -- TODO
	 end
	 val = it:get_value()
	 if nil == val then
	    -- TODO
	 end
	 local v
	 v, err = read_value(val, val:type())
	 if err then
	    return nil, err
	 end
	 s[k] = v
      end
      elem = s
   elseif cassandra.TYPES.VALUE_TYPE_UDT == value_type then
      local it = value:iterator_fields_from_user_type()
      local s = {}
      while it:next() do
	 local rc, name = it:get_user_type_field_name()
	 if 0 ~= rc then
	    return nil, cassandra.cass_error_desc(rc)
	 end
	 local val = it:get_user_type_field_value()
	 if nil == val then
	    -- TODO
	 end
	 local v, err = read_value(val, val:type())
	 if err then
	    return nil, err
	 end
	 s[name] = v
      end
      elem = s
   elseif cassandra.TYPES.VALUE_TYPE_TUPLE == value_type then
      local it = value:iterator_from_tuple()
      local s = {}
      while it:next() do
	 local val = it:get_value()
	 if nil == val then
	    -- TODO
	 end
	 local v, err = read_value(val, val:type())
	 if err then
	    return nil, err
	 end
	 s[#s + 1] = v
      end
      elem = s
   else
      elem = nil
   end

   return elem, nil
end

function CassandraDB:prepare(query)
   -- TODO lock
   local p = get_prepared_from_global_cache(query)
   if nil == p then
      local future = self.session:prepare(query)
      future:wait()
      local rc = future:error_code()
      if 0 ~= 0 then
	 return nil, future:error_message()
      end

      p = future:get_prepared()
      set_prepared_into_global_cache(query, p)
   end
   -- TODO unlock
   return p, nil
end

local function bind_value_to_stmt(stmt, value, value_type, ndx)
   if nil == value then
      return stmt:bind_null(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_ASCII == value_type or
      cassandra.TYPES.VALUE_TYPE_TEXT == value_type or
      cassandra.TYPES.VALUE_TYPE_VARCHAR == value_type
   then
      return stmt:bind_string(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_BIGINT == value_type or
      cassandra.TYPES.VALUE_TYPE_COUNTER == value_type or
      cassandra.TYPES.VALUE_TYPE_TIMESTAMP == value_type or
      cassandra.TYPES.VALUE_TYPE_TIME == value_type
   then
      return stmt:bind_int64(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_BLOB == value_type or
      cassandra.TYPES.VALUE_TYPE_VARINT == value_type
   then
      return stmt:bind_bytes(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_BOOLEAN == value_type then
      return stmt:bind_bool(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_DATE == value_type then
      return stmt:bind_uint32(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_DECIMAL == value_type then
      return stmt:bind_decimal(ndx, value.number, value.scale)
   end

   if cassandra.TYPES.VALUE_TYPE_DOUBLE == value_type then
      return stmt:bind_double(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_FLOAT == value_type then
      return stmt:bind_float(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_INET == value_type then
      return stmt:bind_inet(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_INT == value_type then
      return stmt:bind_int32(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_TINYINT == value_type then
      return stmt:bind_int8(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_SMALLINT == value_type then
      return stmt:bind_int16(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_UUID == value_type or
      cassandra.TYPES.VALUE_TYPE_TIMEUUID == value_type
   then
      return stmt:bind_uuid(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_LIST == value_type or
      cassandra.TYPES.VALUE_TYPE_SET == value_type or
      cassandra.TYPES.VALUE_TYPE_MAP == value_type
   then
      return stmt:bind_collection(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_UDT == value_type then
      return stmt:bind_user_type(ndx, value)
   end

   if cassandra.TYPES.VALUE_TYPE_TUPLE == value_type then
      return stmt:bind_tuple(ndx, value)
   end

   return cassandra.ERRORS.LIB_INVALID_VALUE_TYPE
end

function CassandraDB:inner_execute(query, args, query_options)
   local stmt = nil
   if query_options.prepare then
      local prepared, err = self:prepare(query)
      if err then
	 return nil, err
      end

      stmt = prepared:bind()
      for i in 0, #args - 1 do
	 local dt = prepared:parameter_data_type(i)
	 if nil == dt then
	    -- TODO
	 end
	 bind_value_to_stmt(stmt, args[i+1], dt:type(), i)
      end
   else
      stmt = cassandra.cass_statement_new(query, 0)
      -- TODO
      stmt:set_keyspace(...)
   end
   -- TODO: query_options.consistency to cassandra.CL.consistency
   local rc = stmt:set_consistency(query_options.consistency and query_options.consistency or cassandra.CL.ONE)
   if 0 ~= rc then
      return nil, cassandra.cass_error_desc(rc)
   end

   if query_options.auto_paging then
      rc = stmt:set_paging_size(query_options.page_size and query_options.page_size or 50)
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
      rc = stmt:set_paging_state(query_options.paging_state)
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
   end
      
   local future = self.session:execute(stmt)
   future:wait()
   rc = future:error_code()
   if 0 ~= rc then
      return nil, future:error_message()
   end

   local result = future:get_result()

   local rows = {
      type = "ROWS"
      meta = {
	 has_more_pages = result:has_more_pages()
	 paging_state = result
      }
   }

   local column_count = result:column_count()
   local cols = {}
   for i = 0, column_count - 1 do
      local col_name
      local col_type
      local rc
      rc, col_name = result:column_name(i)
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
      rc, col_type = result:column_type(i)
      if 0 ~= rc then
	 return nil, cassandra.cass_error_desc(rc)
      end
      cols[i] = {name = col_name, type = col_type}
   end

   local it = result:iterator()
   while it:next() do
      local row = {}
      local r = it:get_row()
      for i = 0, column_count - 1 do
	 local v, err = read_value(r:get_column(i), cols[i].type)
	 if err then
	    return nil, err
	 end
	 row[cols[i].name] = v
      end
      rows[#rows + 1] = row
   end

   return rows, nil
end

function CassandraDB:session_execute(query, args, query_options)
   if nil == self.session then
      return nil, "no open database session available"
   elseif type(query) ~= "string" then
      return nil, "query must be a string"
   end

   if query_options and query_options.auto_paging then
      return self:page_iterator(query, args, query_options)
   end

   return self:inner_execute(query, args, query_options)
end

function CassandraDB:query(query, args, opts, schema, no_keyspace)
  CassandraDB.super.query(self, query, args)

  local conn_opts = self:_get_conn_options()
  if no_keyspace then
    conn_opts.keyspace = nil
  end

  local res, err = self:session_execute(query, args, opts)
  if err then
    return nil, Errors.db(tostring(err))
  end

  if schema ~= nil and res.type == "ROWS" then
    deserialize_rows(res, schema)
  end

  return res
end

function CassandraDB:insert(table_name, schema, model, constraints, options)
  local err = check_unique_constraints(self, table_name, constraints, model)
  if err then
    return nil, err
  end

  err = check_foreign_constaints(self, model, constraints)
  if err then
    return nil, err
  end

  local cols, binds, args = {}, {}, {}
  for col, value in pairs(model) do
    local field = schema.fields[col]
    cols[#cols + 1] = col
    args[#args + 1] = serialize_arg(field, value)
    binds[#binds + 1] = "?"
  end

  cols = table.concat(cols, ", ")
  binds = table.concat(binds, ", ")

  local query = string.format("INSERT INTO %s(%s) VALUES(%s)%s",
                              table_name, cols, binds, (options and options.ttl) and string.format(" USING TTL %d", options.ttl) or "")
  local err = select(2, self:query(query, args))
  if err then
    return nil, err
  end

  local primary_keys = model:extract_keys()

  local row, err = self:find(table_name, schema, primary_keys)
  if err then
    return nil, err
  end

  return row
end

function CassandraDB:find(table_name, schema, filter_keys)
  local where, args = get_where(schema, filter_keys)
  local query = get_select_query(table_name, where)
  local rows, err = self:query(query, args, nil, schema)
  if err then
    return nil, err
  elseif #rows > 0 then
    return rows[1]
  end
end

function CassandraDB:find_all(table_name, tbl, schema)
  local where, args
  if tbl ~= nil then
    where, args = get_where(schema, tbl)
  end

  local query = get_select_query(table_name, where)
  local res_rows, err = {}, nil

  for rows, page_err in session:execute(query, args, {auto_paging = true}) do
    if page_err then
      err = Errors.db(tostring(page_err))
      res_rows = nil
      break
    end
    if schema ~= nil then
      deserialize_rows(rows, schema)
    end
    for _, row in ipairs(rows) do
      res_rows[#res_rows + 1] = row
    end
  end

  return res_rows, err
end

function CassandraDB:find_page(table_name, tbl, paging_state, page_size, schema)
  local where, args
  if tbl ~= nil then
    where, args = get_where(schema, tbl)
  end

  local query = get_select_query(table_name, where)
  local rows, err = self:query(query, args, {page_size = page_size, paging_state = paging_state}, schema)
  if err then
    return nil, err
  elseif rows ~= nil then
    local paging_state
    if rows.meta and rows.meta.has_more_pages then
      paging_state = rows.meta.paging_state
    end
    rows.meta = nil
    rows.type = nil
    return rows, nil, paging_state
  end
end

function CassandraDB:count(table_name, tbl, schema)
  local where, args
  if tbl ~= nil then
    where, args = get_where(schema, tbl)
  end

  local query = get_select_query(table_name, where, "COUNT(*)")
  local res, err = self:query(query, args)
  if err then
    return nil, err
  elseif res and #res > 0 then
    return res[1].count
  end
end

function CassandraDB:update(table_name, schema, constraints, filter_keys, values, nils, full, model, options)
  -- must check unique constaints manually too
  local err = check_unique_constraints(self, table_name, constraints, values, filter_keys, true)
  if err then
    return nil, err
    end
  err = check_foreign_constaints(self, values, constraints)
  if err then
    return nil, err
  end

  -- Cassandra TTL on update is per-column and not per-row, and TTLs cannot be updated on primary keys.
  -- Not only that, but TTL on other rows can only be incremented, and not decremented. Because of all
  -- of these limitations, the only way to make this happen is to do an upsert operation.
  -- This implementation can be changed once Cassandra closes this issue: https://issues.apache.org/jira/browse/CASSANDRA-9312
  if options and options.ttl then
    if schema.primary_key and #schema.primary_key == 1 and filter_keys[schema.primary_key[1]] then
      local row, err = self:find(table_name, schema, filter_keys)
      if err then
        return nil, err
      elseif row then
        for k, v in pairs(row) do
          if not values[k] then
            model[k] = v -- Populate the model to be used later for the insert
          end
        end

        -- Insert without any contraint check, since the check has already been executed
        return self:insert(table_name, schema, model, {unique={}, foreign={}}, options)
      end
    else
      return nil, "Cannot update TTL on entities that have more than one primary_key"
    end
  end

  local sets, args, where = {}, {}
  for col, value in pairs(values) do
    local field = schema.fields[col]
    sets[#sets + 1] = col.." = ?"
    args[#args + 1] = serialize_arg(field, value)
  end

  -- unset nil fields if asked for
  if full then
    for col in pairs(nils) do
      sets[#sets + 1] = col.." = ?"
      args[#args + 1] = cassandra.unset
    end
  end

  sets = table.concat(sets, ", ")

  where, args = get_where(schema, filter_keys, args)
  local query = string.format("UPDATE %s%s SET %s WHERE %s",
                              table_name, (options and options.ttl) and string.format(" USING TTL %d", options.ttl) or "", sets, where)
  local res, err = self:query(query, args)
  if err then
    return nil, err
  elseif res and res.type == "VOID" then
    return self:find(table_name, schema, filter_keys)
  end
end

local function cascade_delete(self, primary_keys, constraints)
  if constraints.cascade == nil then return end

  for f_entity, cascade in pairs(constraints.cascade) do
    local tbl = {[cascade.f_col] = primary_keys[cascade.col]}
    local rows, err = self:find_all(cascade.table, tbl, cascade.schema)
    if err then
      return nil, err
    end

    for _, row in ipairs(rows) do
      local primary_keys_to_delete = {}
      for _, primary_key in ipairs(cascade.schema.primary_key) do
        primary_keys_to_delete[primary_key] = row[primary_key]
      end

      local ok, err = self:delete(cascade.table, cascade.schema, primary_keys_to_delete)
      if not ok then
        return nil, err
      end
    end
  end
end

function CassandraDB:delete(table_name, schema, primary_keys, constraints)
  local row, err = self:find(table_name, schema, primary_keys)
  if err or row == nil then
    return nil, err
  end

  local where, args = get_where(schema, primary_keys)
  local query = string.format("DELETE FROM %s WHERE %s",
                              table_name, where)
  local res, err =  self:query(query, args)
  if err then
    return nil, err
  elseif res and res.type == "VOID" then
    if constraints ~= nil then
      cascade_delete(self, primary_keys, constraints)
    end
    return row
  end
end

-- Migrations

function CassandraDB:queries(queries, no_keyspace)
  for _, query in ipairs(utils.split(queries, ";")) do
    if utils.strip(query) ~= "" then
      local err = select(2, self:query(query, nil, nil, nil, no_keyspace))
      if err then
        return err
      end
    end
  end
end

function CassandraDB:drop_table(table_name)
  return select(2, self:query("DROP TABLE "..table_name))
end

function CassandraDB:truncate_table(table_name)
  return select(2, self:query("TRUNCATE "..table_name))
end

function CassandraDB:current_migrations()
  -- Check if keyspace exists
  local rows, err = self:query([[
    SELECT * FROM system.schema_keyspaces WHERE keyspace_name = ?
  ]], {self.options.keyspace}, nil, nil, true)
  if err then
    return nil, err
  elseif #rows == 0 then
    return {}
  end

  -- Check if schema_migrations table exists first
  rows, err = self:query([[
    SELECT COUNT(*) FROM system.schema_columnfamilies
    WHERE keyspace_name = ? AND columnfamily_name = ?
  ]], {
    self.options.keyspace,
    "schema_migrations"
  })
  if err then
    return nil, err
  end

  if rows[1].count > 0 then
    return self:query "SELECT * FROM schema_migrations"
  else
    return {}
  end
end

function CassandraDB:record_migration(id, name)
  return select(2, self:query([[
    UPDATE schema_migrations SET migrations = migrations + ? WHERE id = ?
  ]], {
    cassandra.list {name},
    id
  }))
end

return CassandraDB
