--[[	作者:叶伟龙@龙川县赤光镇
		u.lua表示util.lua或utility.lua,工具模块
--]]
_ENV=require('base').module(...)
local setmetatable=setmetatable
--这里不允许再require其他模块了,避免搞乱依赖关系	
local unpack=table.unpack or unpack  --各lua版本兼容

function printBytes(sBinary)
	sData=''
	for k,v in pairs({string.byte(sBinary,1,#sBinary)}) do
		sData=sData .. ' ' .. tostring(v)
	end
	print(string.format('printBytes,len=%s,data=%s',#sBinary,sData))
end

local STRICT_FUNCTION = function(t,k) string.format('不存在key为%s这一项',k) end
local STRICT_META_TABLE = {__index=STRICT_FUNCTION}
function strictTable()
	return setmetatable({},STRICT_META_TABLE)
end

function setDefault(t,key,newValue)
	local oldVal=rawget(t,key)
	if oldVal~=nil then
		return oldVal
	end
	t[key]=newValue
	return newValue
end

local READ_ONLY_META_TABLE = {
	__index =function(t,k) string.format('不存在key为%s这一项',k) end ,
	__newindex = function (t,k,v) string.format("试图插入k=%s,v=%s到只读表",k,v) end
}

function setReadOnly(t)--只读,严谨的表
    setmetatable(t, READ_ONLY_META_TABLE)
end

function recursiveReadOnly(t) --递归地表设为readonly,用于策划的导表数据
	setReadOnly(t)
	for k,v in pairs(t) do
		if type(v)=='table' then
			recursiveReadOnly(v)
		end
	end
end


-------------------------------------------------------------------------------------------
local function getFunc4weakRef(dWeak)
	return dWeak.__obj__
end
function weakRef(obj, gcFunc)
	--gcFunc允许为nil,元表的__gc域5.3后起作用的
	return setmetatable({__obj__=obj},{__mode='v',__call=getFunc4weakRef,__gc=gcFunc})
end

-------------------------------------------
local function getFunc4proxy(dProxy,key)
	if rawget(dProxy,'__obj__')==nil then
		error('weakly-referenced object no longer exists',1)
	end
	return dProxy.__obj__[key]
end

local function setFunc4proxy(dProxy,key,value)
	if rawget(dProxy,'__obj__')==nil then
		error('weakly-referenced object no longer exists',1)
	end
	dProxy.__obj__[key]=value
end

function proxy(obj, gcFunc)
	--gcFunc允许为nil,元表的__gc域5.3后起作用的
	return setmetatable({__obj__=obj},{__mode='v',__index=getFunc4proxy,__newindex=setFunc4proxy,__gc=gcFunc})
end

function isWeak(obj)
	return rawget(obj,'__obj__')~=nil
end
-------------------------------------------------------------------------------------------

function mergeList(...)
	local tResult={}
	local iIndex=1
	for i,t in pairs({...}) do
		for k,v in pairs(t) do
			if type(k)=='number' then
				tResult[iIndex]=v
				iIndex=iIndex+1
			else
				error('合并的是元组,不是kv字典表,不可能来这里的',0)
				--tResult[k]=v
			end
		end
	end
	return tResult
end

DEAD={} --表示对象已释放

--闭包成员函数
function bindMethod(func,obj,... )--弱引用实例,不会影响实例的生命期
	if type(func)~='function' then
		error('func参数一定是个function',0)
	end
	local sType=type(obj)
	if sType~='table' and sType~='userdata' and sType~='thread' then
		error('boundMethod一定要传个实例过来',1)
	end
	-- local tag = debug.traceback()
	-- local tag2 = tostring(obj)
	local t1={...}
	local wr=weakRef(obj)--闭包weakRef对象,避免闭包obj本身,免得意外延长obj的生命期
	return function(...)
		--在这里无法用if else 分支区分是否需要引用obj,只要一个分支有强引用的代码,整个bindMethod就会引绑的实例
		local obj=wr() --进行提升
		if obj~=nil then--对象还活着,才进行调用
			local t2={...}
			local t3=mergeList(t2,t1)
			return func(obj, unpack(t3))
		else
			return DEAD
		end
	end
end

--强引用实例,持有实例的生命期
function forceBindMethod(func,obj,... )
	local f = bindMethod(func,obj,... )	--利用现有的实现
	--不能直接返回f,要通过尾部调用包装一下.目的是为了强引用obj
	return function(...)
		local __holder__ = obj --没用的变量,只是为了持有obj
		return f(...)
	end
end
	

function functor(func,...)
	if type(func)~='function' then
		error(string.format('func参数一定是个function,不能是%s',type(func)),1)
	end
	local t1={...}
	return function(...)
		local t2={...}
		local t3=mergeList(t2,t1)
		return func(unpack(t3))
		--如果想中途print结果值,需要用下面的语法
		-- local tResult={func(unpack(t3))}
		-- print (tResult)
		-- return unpack(tResult)
	end
end

function hasAttr(obj, key)
	return getAttr(obj,key)~=nil
end

function getAttr(obj, key,uDefault)
	local bRet,value=pcall(function()
		return obj[key]
	end)
	if bRet then
		return value
	else
		return uDefault
	end
end

--检查函数是否为nil
function checkNil(...) --可以传入忽略检查的变量名
	local lIgnore={...}
	local i=0
	while true do
		i=i+1
		local sName,value=debug.getlocal(2, i)--检查的是调用本函数的函数参数,所以是2		
		if sName==nil then
			break
		end
		if value==nil and not inList(sName,lIgnore) then
			error(string.format('参数"%s"不允许为nil',sName),2)--检查的是调用本函数的函数参数,所以是2
		end
	end
end

function inDict(key,dict)
	local value=rawget(dict,key)
	return value~=nil
end

function inList(value,list)	
	for idx,v in ipairs(list) do --检查数组部分
		if v==value then
			return true
		end
	end
	return false
end

function tryRemoveByValue(ls,value)--只删除查找到的第1个
	return removeByValue(ls,value,false)
end

function removeByValue(ls,value,bNotFoundRaise)--只删除查找到的第1个,返回下标,若下标为0,表示找不到
	if bNotFoundRaise==nil then bNotFoundRaise=true end
	local index=0
	for idx,v in ipairs(ls) do
		if v==value then
			index=idx
			break
		end
	end
	if index~=0 then
		table.remove(ls,index)
	elseif bNotFoundRaise then
		error(string.format('not found value: %s',value))
	end
	return index
end

function shallowCopy(t) -- 浅复制.list,dict都可以
	local new = {}
	for k,v in pairs(t) do
		new[k]=v
	end
	return new
end

function shallowCopyList(lOld) -- 浅复制,仅支持list
	local lNew = {}
	for i = 1,#lOld do
		lNew[i]=lOld[i]
	end
	return lNew
end