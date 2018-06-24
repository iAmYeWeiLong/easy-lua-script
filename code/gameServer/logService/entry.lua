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
	function c.__init__(self,...)
		application.cApplication.__init__(self,...)
		-- self.iCount = 0
	end

	function c.execute(self)
		self:startMyself(_G.SERVICE_NAME)
		
		require('manager')
		_G.lepMgr = manager.cManager()

		self.thisVm:iAmReady()

		collectgarbage('collect')
		_elo_.HUB:join()
		print('execute end')
	end--execute

	function c.onInternalMessage_(self, sServiceName, iSourceVm, iSession, iMsgType, msg, sz)
		local serviceLib=require('easyLuaLib.service')		
		if iMsgType == 1 then
			--local sLpcName,b,c,d,e,f,g = serviceLib.unpack(msg, sz)

			--local s = string.format('iSourceVm=%s,iSession=%s,iMsgType=%s,msg=%s, sz=%s',iSourceVm,iSession,iMsgType,msg, sz)
			--print(s,'abcdefg====',sLpcName,b,c,d,e,f,g)
			--local sText = string.format('logService:internal msg: iSourceVm=%s,iSession=%s,iMsgType=%s,sMsg=%s',iSourceVm, iSession, iMsgType, sMsg )
			--print(sText)
			local lep = _G.lepMgr:getObj(sServiceName)
			lep:recvMsg(sServiceName, iSourceVm, iSession, serviceLib.unpack(msg, sz))
			serviceLib.trash(msg)
			msg = nil


			--lep:lpcFuckyyyouuuu(5,3,1)

		elseif iMsgType == 2 then
			local sCmd,iSourceVm,sServiceName = serviceLib.unpack(msg, sz)
			serviceLib.trash(msg)
			msg = nil
			require('localEndPoint')
			if sCmd == 'REPORT' then --若是有的服务有多个线程,就会报到多次
				local lep = _G.lepMgr:getObj(sServiceName)
				if lep == nil then
					lep = localEndPoint.cLocalEndPoint(sServiceName)
					_G.lepMgr:addObj(sServiceName, lep)
				end
				--lep:lpcFuck(1,2,3,'abc',{x=100})
			else

			end
		else
			
		end
	end

	-- function c.onMessage__(self) -- 别的service发来的消息
	-- 	print('logService.onMessage__')
	-- 	application.cApplication.onMessage__(self)
	-- end
_G.gApp = cApplication()
_G.gApp:execute()


require('util')