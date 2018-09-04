--[[	作者:叶伟龙@龙川县赤光镇		
--]]
local THIS_NAME='entry'
_G.SERVICE_NAME = ... --启动本服务所需要的参数

--查找路径,目录分隔符用\\也行;开始部分可以不要./
package.path = package.path .. ';easyLuaScript/?.lua' --库代码
package.path = package.path .. ';easyLuaScript/?/init.lua'

package.path = package.path .. ';code/serverShare/?.lua' --多个服务器进程都共用的代码
package.path = package.path .. ';code/serverShare/?/init.lua'

package.path = package.path .. ';code/gameServer/?.lua' --同一个进程多个服务共用的代码
package.path = package.path .. ';code/gameServer/?/init.lua'
--print('package.path=',package.path)--查找路径	

package.cpath = package.cpath .. ';./dll_so/?.dll'
--print('package.cpath=',package.cpath)--查找路径

_ENV=require('base').module(THIS_NAME)
require('class')
require('application')

local cApplication=class.create(application.cApplication)
local c=cApplication

	function c.execute(self)		
		self.context = self:startMyself(_G.SERVICE_NAME)		
		--collectgarbage('collect')
		local serviceLib=require('easyLuaLib.service')

		local function test( ... )
			local i = 1
			self.context:iAmReady()
			while true do				
				_eli_:sleep(2)
				-- msg = string.format("is a fucker msg %d",i)
				
				-- local msg,sz = serviceLib.pack(1,2,3,4)
				-- print('pack result',msg,sz)
				-- local ret = self.thisVm:sendByServiceName('logService',msg,sz)
				-- serviceLib.trash(msg)
				-- msg = nil
				-- print('mainService:sleep.....',ret)
				-- i = i + 1

				
				local msg,sz = serviceLib.pack('fuck',1,2,3,{})

				-- local ret = self.context:sendByServiceName('logService', msg, sz)
				local ret = self.context:sendByServiceName('mysql_service', msg, sz)
				serviceLib.trash(msg)
				msg = nil
				
			end
		end
		local job = _eli_:spawn(test)
		job:join()


		_elo_.HUB:join()
	end --execute

	function c.onInternalMessage_(self,sServiceName, iSourceVm, iSession, iMsgType, msg, sz) --override
		local serviceLib=require('easyLuaLib.service')
		local sText = string.format('mainService:internal msg:sServiceName=%s,iSourceVm=%s,iSession=%s,iMsgType=%s,sMsg=%s',sServiceName, iSourceVm, iSession, iMsgType, msg)
		print(sText)

		serviceLib.trash(msg)
	end

_G.gApp=cApplication()
_G.gApp:execute()
