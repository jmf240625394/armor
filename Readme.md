
# 介绍

armor仅仅是一个waf框架，暂时不提供整体的waf解决方案，armor的目标是：简单、动态、插件化、定制化的waf框架。暂时并没有防止SQLi和XSS的功能，可以自己定制。

这里用到了如下相关技术：
- rxi/classic——lua类和mixins的很好封装
- tokers/lua-io-nginx-module——异步记录日志
- hamishforbes/lua-resty-iputils——IPV4很好用的一个插件
- 整个框架模仿了kong的插件架构

示例插件
- ip_white IP白名单
- ip_black IP黑名单
- uri_white  uri白名单
- uri_black  uri黑名单
- user_agent user_agent规则

# 安装

**openresty编译安装**  
```shell
# 下载好lua-io-nginx-module源码
# 用户和组自己指定就好，这里用www
$ ./configure --prefix=/usr/local/services/openresty \
    --add-module=/usr/local/services/softs/lua-io-nginx-module \
    --user=www \
    --group=www \
    --with-pcre-jit \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-http_v2_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_image_filter_module \
    --with-http_auth_request_module \
    --with-http_secure_link_module \
    --with-http_random_index_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-threads \
    --with-compat \
    --with-http_ssl_module
$ gmake
$ gmake install
```

**nginx配置**  
```nginx
http {
    ...

    lua_code_cache off;
    lua_regex_cache_max_entries 4096;
    lua_shared_dict rules 15m;
    lua_shared_dict confs 1m;
    lua_io_thread_pool default;
    lua_io_write_buffer_size 64k;
    lua_package_path ";;/usr/local/services/openresty/site/?.lua;";
    access_by_lua_file /usr/local/services/openresty/site/armor/armor.lua;

    ...

    server {
        listen       8000;
        server_name  localhost;

        location /manage {
            content_by_lua_file /usr/local/services/openresty/site/armor/manage.lua;
        }
    }
}
```

**安装依赖**
```shell
# 将安装路径加入环境变量
$ sudo echo 'export PATH=$PATH:/usr/local/services/openresty/luajit/bin:/usr/local/services/openresty/bin' >> /etc/profile
$ source /etc/profile
$ opm install hamishforbes/lua-resty-iputils
```

**下载代码包**
```shell
# 将代码包放入如下目录中即可
$ cd /usr/local/services/openresty/site
```

**注意事项**  
```shell
# 1. 第一次启动，和后续每次修改了配置，或者修改了某个插件的规则，
# 需要调用manage接口，动态更新配置
$ curl http://127.0.0.1:8000/manage
# 无需reloadnginx，reload也没有用

# 2. armor/logs目录的权限需要注意

# 3. 如下几个配置项的目录需要注意
armor_log_dir = /usr/local/services/openresty/site/armor/logs
armor_manage_log_dir = /usr/local/services/openresty/site/armor/logs
armor_plugins_dir = /usr/local/services/openresty/site/armor/plugins
```

# 插件开发规范

- 名称相关
    - 插件名统一小写，多个字符串之间可以用`_`隔开
    - `lua`代码统一使用`handler.lua`命名
    - 规则文件统一使用`{插件名}.rule`命名
- 规则编写
    - 使用`#`来注释，`utils`中`read_file_by_line`函数会自动过滤掉注释和空白行
    - 如果一行有多个字段，建议统一使用`;;`进行分割
- `handler.lua`编写
    ```lua
    local confs = ngx.shared.confs  -- 配置的lua-shared-dict
    local rules = ngx.shared.rules  -- 规则的lua-shared-dict

    -- 继承base_plugin
    local uri_black_handler = base_plugin:extend()

    function uri_black_handler:new()
        self._name = "uri_black"
        self._rules_keys = {"uri_black"}
    end

    function uri_black_handler:load_rules()
    end 

    function uri_black_handler:check()
    end

    return uri_black_handler
    ```
    - `new()`初始化函数
        - `_name`插件名，记录日志会用到
        - `_rules_keys`规则存到rules中的key，一般规则比较多，建议分类，并使用不同的key
    - `load_rules()`加载规则
    - `check()`规则检查函数


# 版权

暂定使用MIT协议，由于使用到了第三方的tokers/lua-io-nginx-module和hamishforbes/lua-resty-iputils不确定是否能使用MIT协议。