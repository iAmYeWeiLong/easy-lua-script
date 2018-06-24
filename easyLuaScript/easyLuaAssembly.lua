--[[	作者:叶伟龙@龙川县赤光镇
		对外接口,集中到这里时行包装
--]]
_ENV=require('base').module(...)
require('class')
require('reflection')
require('routineHub')
require('timeout')
---------------------------------------------------
cInterface=class.create(
	reflection.cInterface,
	routineHub.cInterface,
	timeout.cInterface
	)--单例
local c=cInterface
	function c.getCurrent(self)
		return routineBase.getCurrent()
	end

	function c.isMainRoutine(self)
		return routineUtil.isMainRoutine()
	end
	function c.spawn(self,...)
		return routineSub.cRoutineSub:spawn(...)
	end
	function c.clock(self)
		return os.clock()
	end	
	function c.time(self)
		return os.time()
	end	

---------------------------------------------------
local cNone = class.create()
local c = cNone
	 --[[
	 A special object you must never pass to any gevent API.
	 Used as a marker object for keyword arguments that cannot have the
	 builtin None (because that might be a valid value).
	 ]]

	function c.__tostring(self)
		return '<default value>'
	end


---------------------------------------------------
cInstance=class.create()--单例
local c=cInstance
	function c.__init__(self,dArgs)
		self.HUB=self:createHub_(dArgs)
		self.MAIN=self:createMain_(dArgs)
		self.NONE = cNone()		
	end

	function c.createMain_(self,dArgs)
		local obj=routineMain.cMainRoutine()
		return obj
	end

	function c.createHub_(self,dArgs)
		local obj=routineHub.cHubRoutine()
		return obj
	end

require('routineUtil')
require('routineBase')
require('routineMain')
require('routineSub')

