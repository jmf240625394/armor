--[[
    load armor.conf to lua-shared-dict confs中
    load plugins's rule to lua-shared-dict rules中
]]
local utils = require "armor.libs.utils"
local tables = require "armor.libs.tables"
local json = require "armor.libs.json"
local strings = require "armor.libs.strings"
local confs = ngx.shared.confs
local rules = ngx.shared.rules

-- get the home dir
local info = debug.getinfo(1, "S")
local cur_file = info["short_src"]
local app_home
if cur_file and cur_file ~= "" then
    app_home = string.match(cur_file, "^.*/")
end

-- read the armor.conf
local config_file = app_home .. "conf/armor.conf"
local raw_configs = utils.read_file_by_line(config_file)

local configs = {}
for _, v in ipairs(raw_configs) do
    local kv = strings.split(v, "=")
    local kv_k, kv_v = strings.strip(kv[1]), strings.strip(kv[2])
    local conf_k, conf_v
    if kv_k == "armor_enable" then
        conf_k = kv_k
        if kv_v == "true" then
            conf_v = true
        else
            conf_v = false
        end
    elseif kv_k == "armor_deny_code" then
        conf_k = kv_k
        conf_v = tonumber(kv_v)
    else
        conf_k = kv_k
        conf_v = kv_v
    end

    configs[conf_k] = conf_v
end

-- write armor.conf to lua-shared-dict
for k, v in pairs(configs) do
    confs:set(k, v)
end

-- load plugins
local plugin_list = json.decode(confs:get("armor_plugins_list"))

local handlers = {}
for _, v in ipairs(plugin_list) do
    local loaded, plugin_handler = utils.load_module("armor.plugins." .. v .. ".handler")
    if not loaded then
        ngx.log(ngx.ERR, "load hander fail: " .. v)
    else
        tables.array_append(
            handlers,
            {
                name = v,
                -- instance the plugin
                handler = plugin_handler()
            }
        )
    end
end

-- load rules to lua-shared-dict rules
for _, plugin in ipairs(handlers) do
    plugin.handler:load_rules()
end
