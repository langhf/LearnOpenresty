local function close_db(db)
    if not db then
        return
    end
    db:close()
end

local mysql=require("resty.mysql")
local db, err = mysql:new()
if not db then
    ngx.say("new mysql error:", err)
    return
end

db:set_timeout(1000)
local props={
    host="127.0.0.1",
    port=3306,
    database="testserver",
    user="root",
    password="hahahaha8"
}
local res, err, errno, sqlstate = db:connect(props)
if not res then
    ngx.say("connect to mysql error:", err, ",errno:", errno, ",sqlstate:",sqlstate)
    return close_db(db)
end
local select_sql = "select * from department"
res, err, errno, sqlstate = db:query(select_sql)

if not res then
    ngx.say("connect to mysql error:", err, ",errno:", errno, ",sqlstate:",sqlstate)
    return close_db(db)
end
cjson=require("cjson")
local json_data = cjson.encode(res)
ngx.say(json_data)
-- for i, row in ipairs(res) do
--    for name, value in pairs(row) do
--      ngx.say("select row ", i, " : ", name, " = ", value, "<br/>")
--    end
-- end
-- ngx.say("<br/>")