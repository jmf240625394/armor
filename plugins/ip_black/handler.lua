--[[
    IP黑名单模块
]]
local base_plugin = require "armor.plugins.base_plugin"
local tables = require "armor.libs.tables"
local utils = require "armor.libs.utils"
local json = require "armor.libs.json"
local finger = require "armor.libs.finger"
local iputils = require("resty.iputils")
-- Cache the last 40000 IPs (~10MB memory) by default
iputils.enable_lrucache(40000)

local confs = ngx.shared.confs
local rules = ngx.shared.rules

local ip_black_handler = base_plugin:extend()

function ip_black_handler:new()
    self._name = "ip_black"
    self._rules_keys = {"ip_black"}
end

-- 加载规则
function ip_black_handler:load_rules()
    local tab = {}
    local key = self._rules_keys[1]
    local plugin_dir = confs:get("armor_plugins_dir")
    local rule_file_path = plugin_dir .. "/" .. self._name .. "/" .. self._name .. ".rule"
    local temp_tab = utils.read_file_by_line(rule_file_path)

    if not tables.is_empty(temp_tab) then
        for _, raw_ip in pairs(temp_tab) do
            if utils.ip_check(raw_ip) then
                tables.array_append(tab, raw_ip)
            end
        end
    end

    if not tables.is_empty(tab) then
        local log_record = {}
        log_record[key] = tab
        self:log_manage_record(log_record)

        rules:set(key, json.encode(tab))
        return true
    else
        self:log_manage_record({ip_black = "the rules are null or unvalid."})
    end
end

-- 检查规则
function ip_black_handler:check()

    local key = self._rules_keys[1]
    local temp_rule = rules:get(key)
    local armor_ip_black_rule = json.decode(temp_rule)
    local req_real_ip = finger.get_client_ip()

    if armor_ip_black_rule then
        local ip_black_rule_range_tab = iputils.parse_cidrs(armor_ip_black_rule)
        if iputils.ip_in_cidrs(req_real_ip, ip_black_rule_range_tab) then
            -- 黑名单记录日志，处理，返回true
            self:log_armor_record(true, " ")
            self:handle()
            return true
        end
    end

    return false
end

return ip_black_handler
