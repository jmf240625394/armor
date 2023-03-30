--[[
    通用工具
]]
local strings = require "armor.libs.strings"
local tables = require "armor.libs.tables"
local ngx_io = require "ngx.io"

local _M = {}

function _M.load_module(module_name)
    local status, res = pcall(require, module_name)
    if status then
        -- Here we match any character because if a module has a dash '-' in its name, we would need to escape it.
        return true, res
    elseif type(res) == "string" and ngx.re.find(res, "module '" .. module_name .. "' not found", "jos") then
        return false
    else
        error(res)
    end
end

function _M._ip_slice_check(slice)
    local slice = tonumber(slice) or -1
    if slice < 0 or slice > 256 then
        return false
    end
    return true
end

function _M._ip_cidr_check(cidr)
    local cidr = tonumber(cidr) or 0
    if cidr <= 0 or cidr > 32 then
        return false
    end
    return true
end

-- 检查ip地址的合法性，如果合法返回true，不合法返回false
function _M.ip_check(ip)
    local ip = ip or ""

    local ip_zone = strings.split(ip, ".") or {}
    if #ip_zone ~= 4 then
        return false
    end

    local index
    for index = 1, 4 do
        if index == 4 then
            local ip_index4 = strings.split(ip_zone[4], "/")
            if #ip_index4 == 2 then
                if not _M._ip_cidr_check(ip_index4[2]) then
                    return false
                end
            end
            if not _M._ip_slice_check(ip_index4[1]) then
                return false
            else
                return true
            end
        end

        if not _M._ip_slice_check(ip_zone[index]) then
            return false
        end
    end

    return true
end

-- 一行一行的读取文件，并返回一个包含所有行的table
function _M.read_file_by_line(path)
    local f_path = path
    local tab = {}

    if not path then
        return nil
    end

    local f = ngx_io.open(f_path, "r")
    if f then
        for line in f:lines() do
            -- 处理注释，以"#"开头的是注释掉的
            if not strings.startswith(line, [[^\s*#]]) then
                local line_strip = strings.strip(line)
                if line_strip ~= "" then
                    tables.array_append(tab, line_strip)
                end
            end
        end
        f:close()
    end
    return tab
end

-- type: 日志类型，manage或者armor
function _M.write_to_file(path, value)
    -- local path
    -- if type == "manage" then
    --     local armor_manage_log_dir = confs:get("armor_manage_log_dir") or ""
    --     local armor_manage_log_file = confs:get("armor_manage_log_file") or ""
    --     path = armor_manage_log_dir .. "/" .. armor_manage_log_file
    -- elseif type == "armor" then
    --     local armor_log_dir = confs:get("armor_log_dir") or ""
    --     local armor_log_file = confs:get("armor_log_file") or ""
    --     path = armor_log_dir .. "/" .. armor_log_file
    -- end

    if not path or path == "" then
        return false
    end

    if not value or value == "" then
        return true
    end

    local file, err = ngx_io.open(path, "a")
    if err then
        -- 不能打开日志文件，使用nginx自身的日志记录错误日志
        ngx.log(ngx.ERR, err)
        return false
    end

    file:write(value)
    file:write("\n")
    file:close()
    return true
end

return _M
