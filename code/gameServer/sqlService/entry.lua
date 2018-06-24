--[[	作者:叶伟龙@龙川县赤光镇		
--]]
local THIS_NAME='entry'
--查找路径,目录分隔符用\\也行;开始部分可以不要./
package.path = package.path .. ';easyLuaScript/?.lua'
package.path = package.path .. ';easyLuaScript/?/init.lua'

package.path = package.path .. ';code/gameServer/?.lua'
package.path = package.path .. ';code/gameServer/?/init.lua'

package.path = package.path .. ';code/serverShare/?.lua'
package.path = package.path .. ';code/serverShare/?/init.lua'
--print('package.path=',package.path)--查找路径	

package.cpath = package.cpath .. ';./dll_so/?.dll'
--print('package.cpath=',package.cpath)--查找路径

_ENV=require('base').module(THIS_NAME)
require('class')
require('application')

local cApplication=class.create(application.cApplication)
local c=cApplication

	function c.execute(self)
		local asyncWatcher = _elo_.HUB.oLoop:createAsync()
		local mt = util.bindMethod(onMessage, self)
		asyncWatcher:start(mt)

		local serviceLib=require('easyLuaLib.service')
		serviceLib.setAsyncWatcher(asyncWatcher)  --设asyncWatcher关联本service

		_elo_.HUB:join()
	end --execute

	function c.onMessage(self) -- 别的service发来的消息
		local serviceLib=require('easyLuaLib.service')

		local test = util.bindMethod(test, self)

		while true do -- 因为多次唤醒,会表现为一次真正醒来,所以要while True
			local iServiceSource,iMsgType,sMsg=serviceLib.getInternalMsgBlock()  -- iReqestId,  # 阻塞
			if nil == iServiceSource then
				return
			end
			_gi_:spawn(test,iServiceSource,iMsgType,sMsg)
		end
	end

	function c.test(self, iServiceSource, iMsgType, sMsg)
		print('internal msg: iServiceSource=%s,iMsgType=%s,sMsg=%s',iServiceSource, iMsgType, sMsg)
	end
	
_G.gApp = cApplication()
_G.gApp:execute()


require('util')