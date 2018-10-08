-------------------------------------------------------------------------
-- MySQL & Redis function sector                    --
-------------------------------------------------------------------------
function db_exec(sql)
    local rst = nil
    local rcount = 0
    local data = 0
    local resp = nil
    local i,row,col,val
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/exec_sql?sql=' .. ngx.escape_uri(sql)
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
    resp=res.body
    if resp ~= "" then
        local parser = require "rds.parser"
        res, err = parser.parse(resp)
        if res ~= nil then
            local rows = res.resultset
            if rows ~= nil then
                rcount = #rows
                if rows and rcount > 0 then
                    rst={}
                    for i,row in ipairs(rows) do
                        data={}
                        for col, val in pairs(row) do
                            data[col] = val
                        end
                        rst[i]=data
                    end
                end
            end
        end
    end
    return rst,rcount
end

function redis_set_ex(key, val, expire)
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/mt_redis_set_ex?key=' .. key .. '&expire=' .. expire .. '&val=' .. ngx.escape_uri(val)
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
end

function redis_expire(key,expire)
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/redis_expire?key=' .. key .. '&expire=' .. expire
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
end

function redis_persist(key)
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/redis_persist?key=' .. key
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
end

function redis_set1(key,val)
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/mt_redis_set1?key=' .. key .. '&val=' .. ngx.escape_uri(val)
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
end

function redis_set0(key,val)
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/mt_redis_set0?key=' .. key .. '&val' .. ngx.escape_uri(val)
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
end

function redis_get(key)
    local resp = nil
    local typ = nil
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/redis_get?key=' .. key
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
    resp=res.body
    if resp ~= "" then
        local redis_parser = require("redis.parser")
        res, typ = redis_parser.parse_reply(resp)
    else
        res=nil
    end
    return res,typ
end

function redis_exists(key)
    local resp = nil
    local typ = nil
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/redis_exists?key=' .. key
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
    resp=res.body
    if resp ~= "" then
        local redis_parser = require("redis.parser")
        res, typ = redis_parser.parse_reply(resp)
    else
        res=nil
    end
    return res,typ
end

function redis_del(key)
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/redis_del?key=' .. key
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
end

function redis_upload_sensor(gwId, sensorId, value)
    local http_lib = require "resty.http"
    local http_conn = http_lib:new()
    http_conn:set_timeout(10000)
    local notify_url='http://10.47.101.66:2001/upload_sensor_data?gwId=' .. gwId .. "&sensorId=" .. sensorId .. "&data=" .. value
    local res, err = http_conn:request_uri(notify_url, {method="GET"})
end


-------------------------------------------------------------------------
-- Logic sector & Main programe                    --
-------------------------------------------------------------------------
local json_data
local cjson = require("cjson")
cjson.encode_keep_buffer = 0
local gvar = ngx.shared.gvar
local gmsg = ngx.shared.gmsg
-- local gsess = ngx.shared.gsess

local stream, err = ngx.req.socket(true)
local data, partial
stream:settimeout(5000)

local vdata={}
local arrayData={}
local sql
local result
local cmd
local session
local sequence 
local content
local flow
local gwId

local bytes
local err

while not ngx.worker.exiting() do
data, err, partial = stream:receive()

repeat 
    if not data then
        if err ~= 'timeout' then
            ngx.log(ngx.ERR, 'receive error:', err)
            return
        end
    end

    if gwId ~= nil and string.len(gwId)>0 then
        local queryKey="query_request_"..gwId
        local queryRes, queryTyp = redis_get(queryKey)
        if queryRes ~= nil then
            ngx.log(ngx.ERR, "found query_request command.")
            ngx.log(ngx.ERR, queryRes)
            queryRes, queryTyp = redis_del(queryKey)
        end

        local configKey="config_request_"..gwId
        local configRes, configTyp = redis_get(configKey)
        if configRes ~= nil then
            ngx.log(ngx.ERR, "found config_request command.")
            bytes,err = stream:send(configRes)
            configRes, configTyp = redis_del(configKey)
        end

        local getConfigKey="get_config_request_"..gwId
        local getConfigRes, getConfigTyp = redis_get(getConfigKey)
        if getConfigRes ~= nil then
            ngx.log(ngx.ERR, "found get_config_request command.")
            bytes,err = stream:send(getConfigRes)
            getConfigRes, configTyp = redis_del(getConfigKey)
        end 

        local commandKey="command_request_"..gwId
        local commandRes, commandTyp = redis_get(commandKey)
        if commandRes ~= nil then
            ngx.log(ngx.ERR, "found command_request command.")
            bytes,err = stream:send(commandRes)
            commandRes, commandTyp = redis_del(commandKey)
        end 

        local messageKey="message_request_"..gwId
        local messageRes, messageTyp = redis_get(messageKey)
        if messageRes ~= nil then
            ngx.log(ngx.ERR, "found message_request command.")
            bytes,err=stream:send(messageRes)
            messageRes, messageTyp = redis_del(messageKey)
        end
    end

    if data == nil or string.len(data)<0 then
        --ngx.log(ngx.ERR, 'data is nil.')
        break
    end

    ngx.log(ngx.ERR, data)

    vdata={}
    vdata=cjson.decode(data)
    cmd = vdata["command"]
    session = vdata["session"]
    sequence = vdata["sequence"]
    content = vdata["content"]
    flow = vdata["flow"]

    if cmd == 1 then
        for k,v in pairs(content) do
            gwId = v["gwId"]
        end

        vdata = {}
        vdata["name"]="DDP"
        vdata["version"]="1.0"
        vdata["session"]=session
        vdata["sequence"]=sequence
        vdata["command"]=1
        vdata["flow"]=1
        result={}

        sql="SELECT gwName from gateway WHERE sid=\'" .. gwId .. "\'"
        local rs, rcount=db_exec(sql)

        if rs ~= nil then 
            vdata["code"] = 200
            vdata["message"] = "ok"
            result["session"] = "1"
            vdata["result"] = result
            --gsess:set(gwId, 1)
        else
            vdata["code"] = 451
            vdata["message"] = "device not exist"
            result["session"] = "0"
            vdata["result"] = result
        end

        json_data = cjson.encode(vdata)
        bytes,err = stream:send(json_data)
    elseif cmd == 2 then
        -- gsess:set(gwId, 0)
        return
    elseif cmd == 3 then
        arrayData={}

        for k,v in pairs(content) do
            gwId = v["gwId"]
            arrayData = v["data"]
        end

        local sensorId
        local sensorValue

        for k,v in pairs(arrayData) do
            sensorId = v["sensor"]
            sensorValue = v["value"]
            -- sql="INSERT INTO sensorData (gwId,sensorId,time,value), VALUES(\'" .. gwId .. "\',\'".. sensorId .. "\',\'" .. ngx.localtime() .. "\',\'" .. sensorValue .. "\')"
            -- local rs, rcount=db_exec(sql)
            --1. store sensor real data to redis for request for client.
            --2. store record key to share memory
            --3. store record to redis
            if sensorId == nil and gwId == nil and sensorValue == nil then
                ngx.log(ngx.ERR, "DDP.lua null")
            else
                --ngx.log(ngx.ERR, "DDP.lua gwid="..gwId.."sensorId="..sensorId.."sensorValue="..sensorValue)
                local dbres, dberr= redis_upload_sensor(gwId, sendorId, sensorValue)
            end
        end

        vdata={}
        vdata["name"]="DDP"
        vdata["version"]="1.0"
        vdata["session"]=session
        vdata["sequence"]=sequence
        vdata["flow"]=1
        vdata["code"]=200
        vdata["message"]="ok"
        vdata["command"]=3
        json_data = cjson.encode(vdata)
        bytes, err = stream:send(json_data)
    elseif cmd == 4 then
        if flow == 1 then
            local resultKey="query_response_"..gwId
            redis_set1(resultKey, data)
            ngx.log(ngx.ERR, "query response stored into redis successfully!")
        else
            ngx.log(ngx.ERR, "mistake pdu.")
        end
    elseif cmd == 5 then
        if flow == 1 then
            local resultKey="message_response_"..gwId
            redis_set1(resultKey, data)
            ngx.log(ngx.ERR, "message response stored into redis successfully!")
        else
            ngx.log(ngx.ERR, "mistake pdu.")
        end
    elseif cmd == 6 then
        if flow == 1 then
            local cmdKey="command_response_"..gwId
            redis_set1(cmdKey, data)
            ngx.log(ngx.ERR, "command response stored into redis successfully")
        else
            ngx.log(ngx.ERR, "mistake pdu.")
        end
    elseif cmd == 7 then
        if flow == 1 then 
            local cmdKey="config_response_"..gwId
            redis_set1(cmdKey, data)
            ngx.log(ngx.ERR, "config response stored into redis successfully!")
        else
            ngx.log(ngx.ERR, "mistake pdu.")
        end
    elseif cmd == 8 then
        if flow == 1 then
            local getConfigKey="get_config_response_"..gwId
            redis_set1(cmdKey, data)
            ngx.log(ngx.ERR, "get config response stored into redis successfully!")
        else
            ngx.log(ngx.ERR, "mistake pdu.")
        end
    else
        ngx.log(ngx.ERR, '------------else----------------------------------')
        end

    until true
end

