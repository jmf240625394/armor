--[[
    请求指纹相关的工具
]]
local utils = require "armor.libs.utils"
require "resty.core.regex"

local _M = {}

-- 获取来访IP
function _M.get_client_ip()
    -- Ali_Cdn_Real_Ip 为阿里云透传的直实用户IP
    local client_ip = ngx.req.get_headers()["Ali_Cdn_Real_Ip"]
    if client_ip == nil then
        client_ip = ngx.req.get_headers()["X_Forwarded_For"]
    end
    if client_ip == nil then
        client_ip = ngx.var.remote_addr
    else
        -- 多个ip的情况, 保留一个
        client_ip = string.gsub(tostring(client_ip), ", .*", "")
    end
    if client_ip == nil then
        client_ip = "unknown"
    end
    if type(client_ip) ~= "string" then
        client_ip = "unknown"
    end
    return client_ip
end

-- 获取请求域名
function _M.get_server_host()
    return ngx.var.host
end

-- 获取请求方法
function _M.get_req_method()
    return ngx.req.get_method()
end

-- 获取UserAgent
function _M.get_user_agent()
    local user_agent = ngx.var.http_user_agent
    if type(user_agent) == "table" then
        user_agent = user_agent[1]
    elseif user_agent == nil or ngx.re.find(user_agent, [[^\s*$]], "jos") then
        user_agent = "unknown"
    end
    return user_agent
end

-- 获取uri解码后的结果
function _M.get_uri()
    local uri = ngx.var.uri
    return ngx.unescape_uri(uri)
end

-- 以table的方式返回uri的参数，第二个返回值是确认是否是空
function _M.get_uri_args_table()
    -- 当请求参数里面key是空值时，返回的uri_args是nil
    local uri_args = ngx.req.get_uri_args()
    if utils.is_empty(uri_args) then
        return nil, true
    else
        return uri_args, false
    end
end

-- 以字符串方式返回uri中的参数，如果没有参数返回nil
function _M.get_uri_args_string()
    -- nginx的args：http://nginx.org/en/docs/varindex.html
    -- uri中参数，无论key和value是空值，都没有影响；
    return ngx.var.args
end

return _M
