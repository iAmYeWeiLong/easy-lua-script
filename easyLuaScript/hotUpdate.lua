--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)
require('class')
require('util')

sFileName='beHotUpdate.lua'

local dealFunction__
local resumeOldFunc__
local recordOldFunc__
local resumeOldObj__

--loadfile ([filename [, mode [, env]]])


function update(sModpath)
	--先备份旧的
	local mod=package.loaded[sModpath]
	local dOldNameSpace=u.strictTable()

	for sName,obj in pairs(mod) do -- 只记录类和模块函数		
		if type(obj)=='function' or rawget(obj,'__isClass__') then
			dOldNameSpace[sName]=obj
		end
	end
	
	local dInfo=u.strictTable()
	recordOldFunc__(mod,dInfo) --备份内存中已有的函数
	
	--重新加载模块
	package.loaded[sModpath]=nil
	local mod=require(sModpath)

	resumeOldFunc__(mod,dInfo)

	-- 把旧对象替换回到原来的名称空间去
	for sName,oldObj in pairs(dOldNameSpace):
		if rawget(mod,sName) then
			resumeOldObj__(oldObj,mod[sName])
		end
		mod[sName]=oldObj
	end

	if mod.afterHotUpdate then
		mod.afterHotUpdate()
	end
	return '热更新{}成功'.format(sModpath)

end

--对象记录到名称空间
function resumeOldObj__(oldObj,newObj)
	for sName,attr in pairs(newObj) do		
		oldObj[sName]=attr
	end
end


--备份内存中已有的函数
function recordOldFunc__(obj,dInfo)
	for sName,newobj in pairs(obj) do		
		if type(newobj)=='function' then
			dInfo[sName]=newobj
		elseif rawget(newobj,'__isClass__') then
			dInfo[sName]=u.strictTable()
			recordOldFunc__(newobj,dInfo[sName])
		else
		end
end

-- 还原旧有的函数
function resumeOldFunc__(obj,dInfo)
	for sName,newobj in pairs(obj) do
		local oldFunc = rawget(dInfo,sName)
		if oldFunc then			
			if type(newobj)=='function' then
				dealFunction__(oldFunc,newobj)
			elseif rawget(newobj,'__isClass__') then
				resumeOldFunc__(newobj,oldFunc)
			end
		end
	end
end

local FUNC_UPVALUE_ALIAS = '__funcAlias__'

local function dealFunction__(oldFunc,newFunc)
	local value,index=reflection.getUpValueByName(newFunc,FUNC_UPVALUE_ALIAS)
	reflection.replaceUpValueByName(oldFunc,FUNC_UPVALUE_ALIAS,value)
end


require('reflection')