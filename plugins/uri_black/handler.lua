--[[
    文件限制
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

local uri_black_handler = base_plugin:extend()

function uri_black_handler:new()
    self._name = "uri_black"
    self._rules_keys = {"uri_black"}
end

-- 加载规则
function uri_black_handler:load_rules()
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
        self:log_manage_record({uri_black = "the rules are null or unvalid."})
    end
end

-- 检查规则
function uri_black_handler:check()

    local key = self._rules_keys[1]
    local uri = finger.get_uri()
    local temp_rule = rules:get(key)
    local waf_file_restrict_rule = json.decode(temp_rule)

    if finger.get_req_method() == "GET" and waf_file_restrict_rule then 
        for _, pattern in pairs(waf_file_restrict_rule) do
            local from, _, _ = ngx_find(uri, pattern, "jois")
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

return uri_black_handler
