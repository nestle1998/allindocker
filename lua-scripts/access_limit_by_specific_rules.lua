-- local cjson = require "cjson"

--[[
    当前策略:
    请求可能携带token,cookie或直接访问;对直接访问的请求通过ip识别身份(但一个ip可能对应多个client),因此配置一个较高的每秒频率,超过频率后对ip进行全局forbidden至指定时间;对携带token/cookie访问的请求通过token/cookie识别身份(通常是同一个client),设置一个较低的频率,超过频率后对该token/cookie和其所在ip进行全局forbidden至指定时间
]]

-- ip最大频率
local ipMaxFreq = 9
-- token最大频率
local tokenMaxFreq = 9
-- cookie最大频率
local cookieMaxFreq = 9
-- 超过阈值后被ban时间
local banExpire = 600

--[[
    初始化redis
]]
local redis = require "redis"
local red = redis:new()

--[[
    优先判断是否存在token
]]
--token名称,此处根据实际情况修改
local token = "Authorization"

clientToken = ngx.req.get_headers()[token]

--[[
    获取客户端真实IP
]]
local clientIP = ngx.req.get_headers()["X-Real-IP"]
if clientIP == nil then
    clientIP = ngx.req.get_headers()["x_forwarded_for"]
end
if clientIP == nil then
    clientIP = ngx.var.remote_addr
end

-- 获取所有cookie，这里获取到的是一个字符串，如果不存在则返回nil
-- local clientHttpCookie = ngx.var.http_cookie

-- 获取单个cookie，_后面的cookie的name，如果不存在则返回nil
local clientCookie = ngx.var.http_cookie

if clientToken ~= nil then
    local incrKey = "user:"..clientToken..":freq"
    local tokenBlockKey = "userToken:"..clientToken..":block"
    local ipBlockKey = "userIp:"..clientIP..":block"

    --[[
        判断是否被ban
    ]]
    local is_block,err = red:get(tokenBlockKey) -- check if token is blocked
    if tonumber(is_block) == 1 then
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    local is_block,err = red:get(ipBlockKey) -- check if ip is blocked
    if tonumber(is_block) == 1 then
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    --[[
    每秒访问频率+1
    ]]
    res, err = red:incr(incrKey)

    --[[
        上一步操作成功,则为当前key设置过期时间
    ]]
    if res == 1 then
        res, err = red:expire(incrKey,1)
    end

    --[[
        每秒请求数大于阈值,屏蔽指定值(秒)
    ]]
    if res > tokenMaxFreq then
        -- ban token
        res, err = red:set(tokenBlockKey,1, 'EX', banExpire)

        -- ban ip
        res, err = red:set(ipBlockKey,1, 'EX', banExpire)

        -- ngx.log(ngx.ERR, tokenBlockKey)
        -- ngx.log(ngx.ERR, ipBlockKey)
    end
elseif clientCookie ~= nil then
    local incrKey = "user:"..clientCookie..":freq"
    local cookieBlockKey = "userToken:"..clientCookie..":block"
    local ipBlockKey = "userIp:"..clientIP..":block"

    --[[
        判断是否被ban
    ]]
    local is_block,err = red:get(cookieBlockKey) -- check if token is blocked
    if tonumber(is_block) == 1 then
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    local is_block,err = red:get(ipBlockKey) -- check if ip is blocked
    if tonumber(is_block) == 1 then
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    --[[
    每秒访问频率+1
    ]]
    res, err = red:incr(incrKey)

    --[[
        上一步操作成功,则为当前key设置过期时间
    ]]
    if res == 1 then
        res, err = red:expire(incrKey,1)
    end

    --[[
        每秒请求数大于阈值,屏蔽指定值(秒)
    ]]
    if res > cookieMaxFreq then
        -- ban cookie
        res, err = red:set(cookieBlockKey,1, 'EX' banExpire)

        -- ban ip
        res, err = red:set(ipBlockKey,1, 'EX', banExpire)

        -- ngx.log(ngx.ERR, cookieBlockKey)
        -- ngx.log(ngx.ERR, ipBlockKey)
    end
else
    local incrKey = "user:"..clientIP..":freq"
    local blockKey = "userIp:"..clientIP..":block"

    --[[
        判断是否被ban
    ]]
    local is_block,err = red:get(blockKey) -- check if ip is blocked
    if tonumber(is_block) == 1 then
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    --[[
        每秒访问频率+1
    ]]
    res, err = red:incr(incrKey)

    --[[
        上一步操作成功,则为当前key设置过期时间
    ]]
    if res == 1 then
        res, err = red:expire(incrKey,1)
    end

    --[[
        每秒请求数大于阈值,屏蔽指定值(秒)
    ]]
    if res > ipMaxFreq then
        res, err = red:set(blockKey,1, 'EX', banExpire)
    end
end
