--[[
    url_white url白名单插件
]]
local base_plugin = require "armor.plugins.base_plugin"
local strings = require "armor.libs.strings"
local tables = require "armor.libs.tables"
local utils = require "armor.libs.utils"
local json = require "armor.libs.json"
local finger = require "armor.libs.finger"
local ngx_find = ngx.re.find
local confs = ngx.shared.confs
local rules = ngx.shared.rules
require "resty.core.regex"

local uri_white_handler = base_plugin:extend()

function uri_white_handler:new()
    self._name = "uri_white"
    self._rules_keys = {"uri_white_host", "uri_white_uri", "uri_white_host_uri"}
end

-- 配置文件中host和uri的校验
function uri_white_handler:_host_or_uri_check(type, value)
    -- uri如果是以/结尾，会添加\S*
    if type == "uri" then
        local temp = string.char(string.byte(value, 3, -1))
        if string.char(string.byte(temp)) ~= "/" then
            temp = "/" .. temp
        end
        if string.char(string.byte(temp, -1, -1)) == "/" then
            temp = temp .. "\\S*"
        end
        return temp
    elseif type == "host" then
        local temp = string.char(string.byte(value, 1, -3))
        if string.char(string.byte(temp, -1, -1)) == "/" then
            return string.char(string.byte(temp, 1, -2))
        else
            return temp
        end
    elseif type == "all" then
        local tab = strings.split(value, ";;")
        if #tab < 2 then
            return nil
        else
            local host, uri = tab[1], tab[2]
            if string.char(string.byte(host, -1, -1)) == "/" then
                host = string.char(string.byte(temp_line, 1, -2))
            end
            if string.char(string.byte(uri)) ~= "/" then
                uri = "/" .. uri
            end
            if string.char(string.byte(uri, -1, -1)) == "/" then
                uri = uri .. "\\S*"
            end

            return host .. uri
        end
    else
        return nil
    end
end

-- table自检是否包含
function uri_white_handler:_table_self_contain_check(tab, exclude_tab)
    for k, v in ipairs(tab) do
        for inner_k, inner_v in ipairs(tab) do
            if k ~= inner_k then
                local str = v .. "/"
                local pattern = inner_v .. "/"
                if ngx_find(str, "(" .. pattern .. ")", "jios") then
                    tables.array_append(exclude_tab, v)
                end
            end
        end
    end
end

-- 加载规则
function uri_white_handler:load_rules()
    local sorted_host = {}
    local sorted_uri = {}
    local sorted_host_uri = {}
    -- 当rules_keys有多个时，在load_rules阶段记录日志和捞入rules中直接用即可
    local rules_keys = self._rules_keys
    local plugin_dir = confs:get("armor_plugins_dir")
    local rule_file_path = plugin_dir .. "/" .. self._name .. "/" .. self._name .. ".rule"
    local temp_tab = utils.read_file_by_line(rule_file_path)

    -- 1. 对规则分类
    if not tables.is_empty(temp_tab) then
        for _, line in ipairs(temp_tab) do
            if strings.startswith(line, ";;") then
                -- 只有uri
                local uri = self:_host_or_uri_check("uri", line)
                if uri then
                    tables.array_append(sorted_uri, uri)
                end
            elseif strings.endswith(line, ";;") then
                -- 只有host
                local host = self:_host_or_uri_check("host", line)
                if host then
                    tables.array_append(sorted_host, host)
                end
            elseif ngx_find(line, ";;", "jos") then
                -- 既有uri，又有host的
                local host_uri = self:_host_or_uri_check("all", line)
                if host_uri then
                    tables.array_append(sorted_host_uri, host_uri)
                end
            end
        end
    end

    -- 过程日志，简单一点
    self:log_manage_record({sorted_host = sorted_host})
    self:log_manage_record({sorted_uri = sorted_uri})
    self:log_manage_record({sorted_host_uri = sorted_host_uri})

    -- 2. 去重
    local unique_host = tables.array_unique(sorted_host)
    local unique_uri = tables.array_unique(sorted_uri)
    local unique_host_uri = tables.array_unique(sorted_host_uri)

    -- 3. 交叉去重，保存重复的，最后再去掉
    local exclude_host_uri = {}
    local exclude_uri = {}

    -- 3.1 host和uri范围更广，更可能覆盖host_uri的规则
    for _, h_v in ipairs(unique_host) do
        for _, hu_v in ipairs(unique_host_uri) do
            if strings.startswith(hu_v, h_v) then
                tables.array_append(exclude_host_uri, hu_v)
            end
        end
    end
    for _, u_v in ipairs(unique_uri) do
        for _, hu_v in ipairs(unique_host_uri) do
            if ngx_find(hu_v, u_v .. "/", "jos") then
                tables.array_append(exclude_host_uri, hu_v)
            end
        end
    end

    -- 3.2 检查unique_uri和unique_host_uri有没有自包含的规则
    self:_table_self_contain_check(unique_uri, exclude_uri)
    self:_table_self_contain_check(unique_host_uri, exclude_host_uri)
    self:log_manage_record({exclude_uri = exclude_uri})
    self:log_manage_record({exclude_host_uri = exclude_host_uri})

    -- 4. 自包含的规则去除
    local last_host_uri = {}
    local last_uri = {}
    for _, v in ipairs(unique_uri) do
        if not tables.array_contain(exclude_uri, v) then
            tables.array_append(last_uri, v)
        end
    end
    for _, v in ipairs(unique_host_uri) do
        if not tables.array_contain(exclude_host_uri, v) then
            tables.array_append(last_host_uri, v)
        end
    end
    -- 记录日志，这里就不去self里面获取规则的keys了，直接参考new函数里面的
    -- {"uri_white_host", "uri_white_uri", "uri_white_host_uri"}
    self:log_manage_record({uri_white_host = unique_host})
    self:log_manage_record({uri_white_uri = last_uri})
    self:log_manage_record({uri_white_host_uri = last_host_uri})

    -- 5. 将规则同步到lua-shared-dict rules中
    if not tables.is_empty(unique_host) then
        rules:set("uri_white_host", json.encode(unique_host))
    end
    if not tables.is_empty(last_uri) then
        rules:set("uri_white_uri", json.encode(last_uri))
    end
    if not tables.is_empty(last_host_uri) then
        rules:set("uri_white_host_uri", json.encode(last_host_uri))
    end
end

-- 检查规则
function uri_white_handler:check()

    -- url白名单有3个key
    local keys = self._rules_keys
    local host = finger.get_server_host()
    local uri = finger.get_uri()

    for _, key in ipairs(keys) do
        local temp_rule = rules:get(key)
        local armor_uri_white_rules = json.decode(temp_rule)

        if armor_uri_white_rules then
            for _, v in pairs(armor_uri_white_rules) do
                -- 处理要分三种情况{"url_white_host", "url_white_uri", "url_white_host_uri"}
                if key == "uri_white_host" then
                    -- 域名直接判断字符串是否相等
                    if host == v then
                        -- 白名单
                        if confs:get("armor_log_level") == "DEBUG" then
                            self:log_armor_record(true, v)
                        end
                        return true
                    end
                elseif key == "uri_white_uri" then 
                    local pattern = "(?:" .. v .. ")"
                    if ngx_find(uri, v, "jos") then
                        -- 白名单
                        if confs:get("armor_log_level") == "DEBUG" then
                            self:log_armor_record(true, v)
                        end
                        return true
                    end
                elseif key == "uri_white_host_uri" then
                    local pattern = "(?:" .. v .. ")"
                    if ngx_find(host .. uri, pattern, "jos") then
                        -- 白名单
                        if confs:get("armor_log_level") == "DEBUG" then
                            self:log_armor_record(true, v)
                        end
                        return true
                    end
                end 
                
            end
        end

    end 

    return false
end

return uri_white_handler
