--[[	作者:叶伟龙@龙川县赤光镇
		整个进程的入口
--]]
local THIS_NAME='entrance'
_G.SERVICE_NAME = ... --启动本服务所需要的参数(这里可能是nil)
print('entrance,_G.SERVICE_NAME:',_G.SERVICE_NAME)


--查找路径,目录分隔符用\\也行;开始部分可以不要./
package.path = package.path .. ';easyLuaScript/?.lua'
package.path = package.path .. ';easyLuaScript/?/init.lua'

_ENV=require('base').module(THIS_NAME)
require('class')
require('application')

local cApplication=class.create(application.cApplication)
local c=cApplication
	function c.execute(self)
		local serviceLib=require('easyLuaLib.service')

		------启动服务------------------------------------------
		--多个线程的服务
		local service_name = 'mysql_service'
		local cmd_line = string.format([[code\gameServer\mysql_service\entry.lua %s]],service_name)
		for i = 0, 10 do
			local iVmId1,iServiceId2 = serviceLib.startService(cmd_line) --阻塞接口
		end

		--[==[
		local sServiceName = 'logService'
		local sCmdLine = string.format([[code\gameServer\logService\entry.lua %s]],sServiceName)
		local iVmId1,iServiceId2 = serviceLib.startService(sCmdLine) --阻塞接口

		local sServiceName = 'mainService'
		local sCmdLine = string.format([[code\gameServer\mainService\entry.lua %s]],sServiceName)
		local iVmId2,iServiceId2 = serviceLib.startService(sCmdLine) --阻塞接口
		]==]
		------主线程不能退出,否则整个进程会退出------------------------------------------
		while true do
			s = io.read()--阻塞读取
			if s == 'q' or s == 'quit' then
				break
			end
			--print('debug.getinfo(1).short_src:',debug.getinfo(1).short_src)
			--print('debug.getinfo(1).source:',debug.getinfo(1).source)
		end
	end

_G.gApp=cApplication()
_G.gApp:execute()

--[=[
------加载c模块------------------------------------------
local dInterface = {
	--函数,动态库里广泛使用
	createCls = class.create,
	isInstance = class.isInstance,
	isSubClass = class.isSubClass,
	--几个异常类,只在socket动态库中使用
	cSocketError = except.cSocketError,
	cSocketGaiError = except.cSocketGaiError,
	cSocketHError = except.cSocketHError,
	cSocketTimeout = except.cSocketTimeout,
}

local searcher=package.searchers[4]
local loader,sPath=searcher('easyLuaLib.service')
package.preload['easyLuaLib.service']=util.functor(loader,sPath,dInterface)
local serviceLib=require('easyLuaLib.service')

------启动服务------------------------------------------
local sServiceName = '[i_am_logService]'
local sCmdLine = string.format([[code\gameServer\logService\entry.lua %s]],sServiceName)
local iVmId1,iServiceId2 = serviceLib.startService(sCmdLine) --阻塞接口

------主线程不能退出,否则整个进程会退出------------------------------------------
while true do
	io.read()--阻塞读取
end
--]=]

--[[
--低层接口
oService.send(sMsg)
--中层接口
oMainService:send(iMsgType,'abc',123,{test = 'xyz',test2 = {hello = 'world'}})

--高层接口
local msg = oService:lpcDoSomething(a,b,d) --调用服务 向服务发包

-- 服务如果是一个对象.生命期如何管理
-- 用__gc管理 ,配合shared_ptr
-- 服务如何自杀,他杀

local oService = el4service.queryService(iServiceId)  --根据id取得服务对象

--]]

