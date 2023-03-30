local json = require "armor.libs.json"
local tables = require "armor.libs.tables"
local utils = require "armor.libs.utils"
local confs = ngx.shared.confs
local rules = ngx.shared.rules

local plugin_list = json.decode(confs:get("armor_plugins_list"))
local armor_enable = confs:get("armor_enable")
if not tables.is_empty(plugin_list) and armor_enable then 
    -- load plugins
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

    -- check rules:
    -- Whether it's a blacklist or a whitelist, as long as it hits, it returns true. Otherwise, it returns false. 
    -- The blacklist will have a handle function. If the processing method is deny, ngx.exit() will be triggered.
    -- as long as the plug-in name has "white" and returns true, break the loop
    for _, plugin in ipairs(handlers) do
        local plugin_name = plugin.name
        local check_result = plugin.handler:check()
        if ngx.re.find(plugin_name, "white", "jois") and check_result then 
            break
        end
    end

end 

