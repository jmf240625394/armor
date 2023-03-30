local _M = {}

-- 判断table是否为空
function _M.is_empty(tab)
    -- {}或者nil都返回true
    return tab == nil or next(tab) == nil
end

-- 两个table合并
function _M.table_union(tab1, tab2)
    for k, v in pairs(tab2) do
        tab1[k] = v
    end
    return table1
end

-- 数组追加，或者两个数组合并
function _M.array_union(a, b)
    -- handle some ugliness
    local c = type(b) == "table" and b or {b}

    local a_count = #a

    for i = 1, #c do
        a_count = a_count + 1
        a[a_count] = c[i]
    end
end

-- 不管element是什么类型，直接加入tab1
function _M.array_append(tab1, element)
    local tab1_count = #tab1
    tab1[tab1_count + 1] = element
    return tab1
end

-- 数组去重
function _M.array_unique(tab)
    local local_tab = tab

    local temp_tab = {}
    for k, v in ipairs(local_tab) do
        temp_tab[v] = k
    end

    local result_tab = {}
    for k, _ in pairs(temp_tab) do
        _M.array_append(result_tab, k)
    end

    return result_tab
end

-- 数组包含
function _M.array_contain(tab, element)
    for _, v in ipairs(tab) do
        if v == element then
            return true
        end
    end
    return false
end

-- 使用递归的方式在本地深度拷贝一个table
function _M.table_copy(tab)
    local tab_type = type(tab)
    local copy

    if tab_type == "table" then
        copy = {}

        for tab_key, tab_value in next, tab, nil do
            copy[_M.table_copy(tab_key)] = _M.table_copy(tab_value)
        end

        setmetatable(copy, _M.table_copy(getmetatable(tab)))
    else
        copy = tab
    end
    return copy
end

-- 获取指定table的所有keys组成的数组
function _M.table_keys(tab)
    if type(tab) ~= "table" then
        logger.fatal_fail(type(tab) .. " was given to table_keys!")
    end

    local t = {}
    local n = 0

    for key, _ in pairs(tab) do
        n = n + 1
        t[n] = tostring(key)
    end

    return t
end

-- 获取指定table的所有values组成的数组
function _M.table_values(tab)
    if type(tab) ~= "table" then
        logger.fatal_fail(type(tab) .. " was given to table_values!")
    end

    local t = {}
    local n = 0

    for _, value in pairs(tab) do
        -- if a table as a table of values, we need to break them out and add them individually
        -- request_url_args is an example of this, e.g. ?foo=bar&foo=bar2
        if type(value) == "table" then
            for _, values in pairs(value) do
                n = n + 1
                t[n] = tostring(values)
            end
        else
            n = n + 1
            t[n] = tostring(value)
        end
    end

    return t
end

-- 判断给定的key在tab中是否存在
function _M.table_haskey(tab, key)
    -- tab不是table，tab是空的，key是nil，都直接返回false
    if type(tab) ~= "table" or next(tab) == nil or key == nil then
        return false
    end

    return tab[key] ~= nil
end

-- 判断给定的value在tab中是否存在
function _M.table_hasvalue(tab, value)
    -- tab不是table，tab是空的，value是nil，都直接返回false
    if type(tab) ~= "table" or next(tab) == nil or value == nil then
        return false
    end

    for _, v in pairs(tab) do
        if v == value then
            return true
        end
    end

    return false
end

return _M
