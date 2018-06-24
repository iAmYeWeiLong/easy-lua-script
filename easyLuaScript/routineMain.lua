--[[	作者:叶伟龙@龙川县赤光镇
		主协程
--]]
_ENV=require('base').module(...)
require('class')
require('routineBase')

local unpack=table.unpack or unpack  --各lua版本兼容

-----------------------------------------------------------------
cMainRoutine=class.create(routineBase.cRoutineBase)--单例,只有一个MAIN协程的
local c=cMainRoutine
	function c.createJob_(self) --override
		local mainJob,bIsMain=coroutine.running()
		assert(bIsMain,'这绝b是main coroutine')		
		return mainJob --忽略参数func与...
		--return {}--只是一个唯一标识		
	end
	
	function c.__tostring(self)
		return '<main coroutine>'
	end
	

