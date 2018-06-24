--[[	作者:叶伟龙@龙川县赤光镇
		协程工具函数
--]]
_ENV=require('base').module(...)

require('class')
-----------------------------------------------------------------
function isMainRoutine()
	local job,bIsMain=coroutine.running()
	if job==nil then--说明是5.1
		return true
	end
	--5.3 直接判断第2个返回值就可以
	return bIsMain
end


require('util')