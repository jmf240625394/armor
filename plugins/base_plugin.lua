--[[
    基本的插件类，其余插件都要集成此插件，实现日志记录、拦截处理等
]]
local Object = require "armor.libs.classic"
local finger = require "armor.libs.finger"
local utils = require "armor.libs.utils"
local ngx_io = require "ngx.io"
local strings = require "armor.libs.strings"
local tables = require "armor.libs.tables"
local json = require "armor.libs.json"
local confs = ngx.shared.confs

local base_plugin = Object:extend()

function base_plugin:new()
end

-- 用来记录armor日志
function base_plugin:log_armor_record(is_hit, rule_value)
    -- 更新时间缓存
    ngx.update_time()
    local time_s = ngx.localtime()
    -- local time_ms = strings.split(tostring(ngx.now()), ".")
    -- local time
    -- if time_ms[2] then
    --     time = time_s .. "." .. time_ms[2]
    -- else
    --     time = time_s .. "." .. "0"
    -- end

    local real_ip = finger.get_client_ip()
    local host = finger.get_server_host()
    local uri = finger.get_uri()
    local method = finger.get_req_method()
    local user_agent = finger.get_user_agent()
    local plugin_name = self._name
    local is_hit = is_hit
    local rule_value = rule_value

    -- 日志如果使用json处理会失真
    local log_str =
        string.format(
        [[{"time": "%s", "real_ip": "%s", "host": "%s", "uri": "%s", "method": "%s", "user_agent": "%s", "plugin_name": "%s", "is_hit": "%s", "rule_value": "%s"}]],
        time_s,
        real_ip,
        host,
        uri,
        method,
        user_agent,
        plugin_name,
        is_hit,
        rule_value
    )

    local armor_log_dir = confs:get("armor_log_dir")
    local armor_log_file = confs:get("armor_log_file")
    utils.write_to_file(armor_log_dir .. "/" .. armor_log_file, log_str)
end

-- 用来记录manage的日志
function base_plugin:log_manage_record(value)
    -- 更新时间缓存
    ngx.update_time()
    local time_s = ngx.localtime()
    -- local time_ms = strings.split(tostring(ngx.now()), ".")
    -- if time_ms[2] then
    --     time = time_s .. "." .. time_ms[2]
    -- else
    --     time = time_s .. "." .. "0"
    -- end

    local plugin_name = self._name
    local log_prefix_str = string.format([[time: %s, plugin: %s, ]], time_s, plugin_name)
    for k, v in pairs(value) do
        log_prefix_str = log_prefix_str .. k .. ": "
        if type(v) == "table" then
            for _, inner_v in ipairs(v) do
                log_prefix_str = log_prefix_str .. inner_v .. ","
            end
        elseif type(v) == "string" then
            log_prefix_str = log_prefix_str .. v
        end
    end

    local armor_manage_log_dir = confs:get("armor_manage_log_dir")
    local armor_manage_log_file = confs:get("armor_manage_log_file")
    utils.write_to_file(armor_manage_log_dir .. "/" .. armor_manage_log_file, log_prefix_str)
end

function base_plugin:handle()
    local handle = confs:get("armor_handle")

    if handle == "onlylog" then
        return
    end

    if handle == "redirect" then
        local armor_redirect_url = confs:get("armor_redirect_url") or "http://www.baidu.com/"
        ngx.redirect(armor_redirect_url, 301)
    else
        local armor_deny_code = confs:get("armor_deny_code") or 503
        ngx.status = armor_deny_code
        ngx.say(
            json.encode(
                {
                    -- 默认就是deny
                    handle_type = handle,
                    http_code = armor_deny_code,
                    message = "Please contact the admin of this site.",
                    from = "ARMOR"
                }
            )
        )
        return ngx.exit(armor_deny_code)
    end
end

-- 插件需要继承的加载规则函数
function base_plugin:load_rules()
end

-- 插件需要继承的检查规则函数
function base_plugin:check()
end

return base_plugin
