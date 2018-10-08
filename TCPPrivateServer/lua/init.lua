math.randomseed(os.time()+ngx.worker.pid()%100)
local delay = 5+math.floor(math.random()*10000000)%5 -- in seconds
ngx.log(ngx.ERR, "delay="..delay)
local handler
handler = function(premature)
    if not premature then
        local gvar = ngx.shared.gvar
        local gmsg = ngx.shared.gmsg
        local gsess = ngx.shared.gsess
        local gkey = ngx.shared.gkey

        -- 定期将 Redis 中的传感器数据刷入 MySQL 数据库；定时批量写入数据库，减小数据库开销
        ngx.log(ngx.ERR, "----timer in------------")
        local cmd='curl -s -m 5 --connect-timeout 2 "http://localhost:9000/store_sensor_data?count=1000" > /dev/null'
        local ret = os.execute(cmd)

        --local curl = require "lcurl"
        --local http = curl.easy()
        --http:setopt(curl.OPT_NOSIGNAL, 1)
        --http:setopt(curl.OPT_TIMEOUT, 5)
        --http:setopt(curl.OPT_CONNECTTIMEOUT, 2)
        --http:setopt_url('http://127.0.0.1:9000/store_sensor_data?count=1000')
        --http:perform()
        --http:close()

        -- 调用共享内存的 flush_expired(0) 方法，清除过期内容
        ngx.log(ngx.ERR, "----timer out-----------")
        gvar:flush_expired(0)
        gmsg:flush_expired(0)
        gsess:flush_expired(0)
        gkey:flush_expired(0)

        -- 尝试再次注册时钟函数，使时钟可以持续运行下去
        local ok, err = ngx.timer.at(delay, handler)
        if not ok then
            return
        end
    end
end

local ok, err = ngx.timer.at(delay, handler)
if not ok then
    return
end