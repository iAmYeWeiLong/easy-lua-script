--[[	作者:叶伟龙@龙川县赤光镇
		最基本设置,这个模块不能依赖别的模块
--]]

local function newIndexOfModule_(mod,k,v)-- 对于函数,引入一个间接层,为了方便热更新
	if type(v)=='function' then
		local __funcAlias__=v --起个别名,方便被debug.getupvalue()查找.
		local function func(...)
			return __funcAlias__(...)
		end		
		rawset(mod,k,func) --用rawset避免死递归
	elseif type(v)=='table' and rawget(v,'__isClass__') and type(k)=='string' then --给类设名字,和class.lua配合一起用的
		if rawget(v,'__name__')==nil then
			v.__name__=string.format('<%s class>',k)
		end
		rawset(mod,k,v) --用rawset避免死递归
	else
		rawset(mod,k,v) --用rawset避免死递归
	end
end

local tDefineVars = {}
tDefineVars["_PROMPT"]=true --在luaforwindows的命令提示符下需要这个来绕过报错

setmetatable(_G,{
	__newindex = function (_, key,value)
		tDefineVars[key]=true
		--rawset(_,key,value)
		newIndexOfModule_(_,key,value)
	end,
	__index = function (_, key)
		if tDefineVars[key]~=true then
			error(string.format('没有定义的属性 "%s"',key), 2)
		end
		return nil
	end,
})

------------------------------------
local STRICT_FUNCTION = function(t,k) string.format('不存在key为%s这一项',k) end
local STRICT_META_TABLE = {__index=STRICT_FUNCTION}
function TABLE()
	return setmetatable({},STRICT_META_TABLE)
end
DICT = TABLE
LIST = TABLE
------------------------------------

local function module_(sModName)--lua5.3需要这个函数
	--print("in base.module,sModName==",sModName)
	local pre=_G
	local m
	for s in string.gmatch(sModName,'[%w_]+') do --模块之间是用点分隔的
		--print('--->',s)
		m=rawget(pre,s)
		if m==nil then
			m=setmetatable({},{__index=_G,__newindex=newIndexOfModule_}) -- 
			pre[s]=m
			pre=m
			for k,v in pairs(_G) do --为了加速访问.如果为了更快,各模块local一下系统函数更好
				rawset(m,k,v)
			end
		end
	end
	package.loaded[sModName]=m
	--把路径中的点替换成下划线,把模块直接放在最顶层,比起有层级的模块性能会更好
	local sNewModName, _ = string.gsub(sModName,'.', '_')
	package.loaded[sNewModName]=m

	return m
end

if _VERSION=='Lua 5.1' then
	module(..., package.seeall)
else
	--print("u... -->",...)
	_ENV=module_(...)
	_ENV.module=module_
end


