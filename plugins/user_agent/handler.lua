--[[
    user_agent检查
]]
local base_plugin = require "armor.plugins.base_plugin"
local tables = require "armor.libs.tables"
local utils = require "armor.libs.utils"
local json = require "armor.libs.json"
local finger = require "armor.libs.finger"
local ngx_find = ngx.re.find
local confs = ngx.shared.confs
local rules = ngx.shared.rules
require "resty.core.regex"

local user_agent_handler = base_plugin:extend()

function user_agent_handler:new()
    self._name = "user_agent"
    self._rules_keys = {"user_agent"}
end

-- 加载规则
function user_agent_handler:load_rules()
    local tab = {}
    local key = self._rules_keys[1]
    local plugin_dir = confs:get("armor_plugins_dir")
    local rule_file_path = plugin_dir .. "/" .. self._name .. "/" .. self._name .. ".rule"
    local temp_tab = utils.read_file_by_line(rule_file_path)

    -- 没有特殊合法性需要进行校验
    if not tables.is_empty(temp_tab) then
        tab = temp_tab
    end

    if not tables.is_empty(tab) then
        local log_record = {}
        log_record[key] = tab
        self:log_manage_record(log_record)

        rules:set(key, json.encode(tab))
        return true
    else
        self:log_manage_record({user_agent = "the rules are null or unvalid."})
    end
end

-- 检查规则
function user_agent_handler:check()

    local key = self._rules_keys[1]
    local temp_rule = rules:get(key)
    local waf_user_agent_rule = json.decode(temp_rule)
    local req_user_agent = finger.get_user_agent()

    if waf_user_agent_rule and req_user_agent ~= "unknown" then
        for _, pattern in pairs(waf_user_agent_rule) do
            local from, _, _ = ngx_find(req_user_agent, pattern, "jois")
            if from then
                -- 匹配到了规则，需要记录日志
                self:log_armor_record(true, pattern)
                -- 拦截：直接返回用户
                self:handle()
                return true
            end
        end
    end 
    
    return false
end

return user_agent_handler
