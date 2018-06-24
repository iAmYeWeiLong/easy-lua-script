--[[	作者:叶伟龙@龙川县赤光镇
		反射,为热更新服务的
--]]
_ENV=require('base').module(...)
require('class')

cInterface=class.create()
local c=cInterface
	function c.getUpValueByName(self,closure,sTargetName)--返回0表示找不到
		assert(closure ~= nil)
		assert(sTargetName ~= nil and sTargetName ~= '')
		for i = 1, math.huge do
			local sName,value=debug.getupvalue(closure,i)
			if sName==nil then --找完了
				return nil,0 --表示没有
			end
			if sName==sTargetName then
				return value,i
			end
		end
	end

	function c.replaceUpValueByName(self,closure,sTargetName,newVal)
		assert(closure ~= nil)
		assert(sTargetName ~= nil and sTargetName ~= '')
				
		for i = 1, math.huge do
			local sName,value=debug.getupvalue(closure,i)
			if sName==nil then --找完了
				error(string.format("根本没有%s这个upvalue",sTargetName))
			elseif sName==sTargetName then		
				debug.setupvalue(closure,i,newVal)
				return
			end
		end
	end


--[[

local function foo(x,y)
	local function bindMethod(...)
		print('x==>',x,y)
	end		
	return bindMethod
end


local bar=foo(123,'abc')

local value,index=getUpValueByName(bar,'y')
print('y==value ,index===>',value,index)

replaceUpValueByName(bar,'y',2)


print('after update ')

local value,index=getUpValueByName(bar,'y')
print('y==value ,index===>',value,index)


]]