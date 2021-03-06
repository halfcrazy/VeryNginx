-- -*- coding: utf-8 -*-
-- -- @Date    : 2016-01-02 00:35
-- -- @Author  : Alexa (AlexaZhou@163.com)
-- -- @Link    : 
-- -- @Disc    : url router of verynginx's control panel 

local summary = require "summary"
local status = require "status"
local cookie = require "cookie"
local VeryNginxConfig = require "VeryNginxConfig"
local encrypt_seed = require "encrypt_seed"
local json = require "json"

local _M = {}

_M.url_route = {}
_M.mime_type = {}
_M.mime_type['.js'] = "application/x-javascript"
_M.mime_type['.css'] = "text/css"
_M.mime_type['.html'] = "text/html"


function _M.filter()
    
    local method = ngx.req.get_method()
    local uri = ngx.var.uri
    --local base_uri = VeryNginxConfig.configs['base_uri']
    local base_uri = VeryNginxConfig.configs['base_uri']

    if string.find( uri, base_uri ) then

        local path = string.sub( uri, string.len( base_uri ) + 1 )
       
        for i,item in ipairs( _M.route_table ) do
            if method == item['method'] and path == item['path'] then
                ngx.header.content_type = "application/json"
                ngx.header.charset = "utf-8"
                if item['auth'] == true and _M.check_session() == false then
                    local info = json.encode({["ret"]="failed",["err"]="need login"})
                    ngx.say( info )
                    ngx.exit(401)
                else
                    ngx.say( item['handle']() )
                    ngx.exit(200)
                end
            end
        end

        ngx.req.set_uri( path )
        ngx.var.vn_static_root = VeryNginxConfig.home_path() .."/dashboard" 
        ngx.exec('@vn_static') -- will jump out at the exec 
    end
end

function _M.check_session()
    -- get all cookies
    local user, session
    
    local cookie_obj, err = cookie:new()
    local fields = cookie_obj:get_all()
    if not fields then
        return false
    end
    
    user = fields['verynginx_user'] 
    session = fields['verynginx_session']
    
    if user == nil or session == nil then
        return false
    end
    
    for i,v in ipairs( VeryNginxConfig.configs['admin'] ) do
        if v["user"] == user and v["enable"] == true then
            if session == ngx.md5( encrypt_seed.get_seed()..v["user"]) then
                return true
            else
                return false
            end
        end
    end
    
    return false
end


function _M.login()
    
    local args = nil
    local err = nil

    ngx.req.read_body()
    args, err = ngx.req.get_post_args()
    if not args then
        ngx.say("failed to get post args: ", err)
        return
    end

    for i,v in ipairs( VeryNginxConfig.configs['admin'] ) do
        if v['user'] == args['user'] and v['password'] == args["password"] and v['enable'] == true then
            local data = {}
            data['ret'] = 'success'
            data['err'] = err
            data['verynginx_session'] = ngx.md5(encrypt_seed.get_seed()..v['user'])
            data['verynginx_user'] = v['user']
            
            return json.encode( data )
        end
    end 
    
    return json.encode({["ret"]="failed",["err"]=err})

end

_M.route_table = {
    { ['method'] = "POST", ['auth']= false, ["path"] = "/login", ['handle'] = _M.login },
    { ['method'] = "GET",  ['auth']= true,  ["path"] = "/summary", ['handle'] = summary.report },
    { ['method'] = "GET",  ['auth']= true,  ["path"] = "/status", ['handle'] = status.report },
    { ['method'] = "GET",  ['auth']= true,  ["path"] = "/config", ['handle'] = VeryNginxConfig.report },
    { ['method'] = "POST", ['auth']= true,  ["path"] = "/config", ['handle'] = VeryNginxConfig.set },
    { ['method'] = "GET",  ['auth']= true,  ["path"] = "/loadconfig", ['handle'] = VeryNginxConfig.load_from_file },
}



return _M
