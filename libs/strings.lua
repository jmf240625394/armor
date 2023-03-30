local string_byte = string.byte
local string_char = string.char
local string_format = string.format
local ngx_gsub = ngx.re.gsub
local ngx_find = ngx.re.find
require "resty.core.regex"

local _M = {}

-- 去掉字符串中所有的空格
function _M.trim_all(str)
    if not str or str == "" then
        return ""
    end

    local newstr, n, err = ngx_gsub(str, [[\s+]], "", "jos")
    if newstr then
        return newstr
    else
        return ""
    end
end

-- 去掉字符串开头和结尾的空格
function _M.strip(str)
    if not str or str == "" then
        return ""
    end

    local newstr, _, _ = ngx_gsub(str, [=[^\s*|\s+$]=], "", "jos")
    if newstr then
        return newstr
    else
        return ""
    end
end

-- 按给定的分隔符，对字符串进行分割，返回一个数组
function _M.split(str, delimiter)
    if not str or str == "" then
        return {}
    end
    if not delimiter or delimiter == "" then
        return {str}
    end

    local elements = {}
    local pattern = "([^" .. delimiter .. "]+)"
    string.gsub(
        str,
        pattern,
        function(value)
            elements[#elements + 1] = value
        end
    )
    return elements
end

-- 判断字符串是否以substr开头
function _M.startswith(str, substr)
    if str == nil or substr == nil then
        return false
    end

    local from, _, _ = ngx_find(str, substr, "jos")
    if from ~= 1 then
        return false
    else
        return true
    end
end

-- 判断字符串是否以substr结尾
function _M.endswith(str, substr)
    if str == nil or substr == nil then
        return false
    end

    local str_reverse = string.reverse(str)
    local substr_reverse = string.reverse(substr)
    local from, _, _ = ngx_find(str_reverse, substr_reverse, "jos")
    if from ~= 1 then
        return false
    else
        return true
    end
end

-- 为一串字符串按16进制编码
function _M.hex_encode(str)
    return (str:gsub(
        ".",
        function(c)
            return string_format("%02x", string_byte(c))
        end
    ))
end

-- 为一串16进制的字符串解码
function _M.hex_decode(str)
    local value

    if
        (pcall(
            function()
                value =
                    str:gsub(
                    "..",
                    function(cc)
                        return string_char(tonumber(cc, 16))
                    end
                )
            end
        ))
     then
        return value
    else
        return str
    end
end

return _M
