--[[
    IP白名单模块
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


local ip_white_handler = base_plugin:extend()

function ip_white_handler:new()
    -- 第一个ip_white是插件名
    -- 第二个ip_white是rules保存到lua-shared-dict rules中的key
    -- 统一使用表，当规则比较多，拆分成多个，另外后面做check()时会根据这个去rules中获取具体规则
    self._name = "ip_white"
    self._rules_keys = {"ip_white"}
end

-- 加载规则
function ip_white_handler:load_rules()
    local tab = {}
    -- 因为只有一个key，直接获取
    local key = self._rules_keys[1]
    local plugin_dir = confs:get("armor_plugins_dir")
    local rule_file_path = plugin_dir .. "/" .. self._name .. "/" .. self._name .. ".rule"
    local temp_tab = utils.read_file_by_line(rule_file_path)

    -- 需要对rules中的IPV4地址做合法性校验
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

        -- 规则同步到rules中
        rules:set(key, json.encode(tab))
        return true
    else
        self:log_manage_record({ip_white = "the rules are null or unvalid."})
    end
end

-- 检查规则
function ip_white_handler:check()

    -- 只有一个key，直接写就行
    local key = self._rules_keys[1]
    local temp_rule = rules:get(key)
    local armor_ip_white_rule = json.decode(temp_rule)
    local req_real_ip = finger.get_client_ip()

    -- 如果 ip_white 规则不为空 进行规则匹配
    if armor_ip_white_rule then
        local ip_white_rule_range_tab = iputils.parse_cidrs(armor_ip_white_rule)
        if iputils.ip_in_cidrs(req_real_ip, ip_white_rule_range_tab) then
            -- 白名单只有开启debug时才记录日志，并返回
            if confs:get("armor_log_level") == "DEBUG" then
                self:log_armor_record(true, " ")
            end
            return true
        end
    end

    return false
end

return ip_white_handler
