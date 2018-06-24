--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)

local networkLib=require('easyLuaLib.network')
local unpack=table.unpack or unpack  --各lua版本兼容

local cCallback

local DUMMY_FUNCTION = class.cObject() --唯一标识而已
--local DUMMY_FUNCTION=function(timer) print('DUMMY_FUNCTION') end
--local prepareFunction=function(timer) print('prepareFunction') end

cLoop=class.create(networkLib.cLoop)
local c=cLoop
	function c.__init__(self,oHub) --override
		assert(oHub)
		--self.oHub=oHub
		networkLib.cLoop.__init__(self,oHub)
		self.lCallbacks={}

		--用来执行callback
		self.prepare=self:createPrepare()
		local method=util.bindMethod(self.runCallBacks_,self)
		self.prepare:start(method)--method prepareFunction
		self.prepare:unRef()

		--只是用来唤醒循环作用
		self.wakeupTimer=self:createTimer(0,0.001)
		self.wakeupTimer:start(DUMMY_FUNCTION)
		self.wakeupTimer:unRef()
		--两个都要unRef,不能因为这2个watcher是激活的而进入了事件循环,进而因为没有其他事件,导致永久block

		self.error_handler = nil
	end

	function c.run_callback(self,func,...)--对外接口
		local cb = cCallback(func, ...)
		self.lCallbacks[#self.lCallbacks+1]=cb
		-- print ('self.wakeupTimer:hasRef()==',self.wakeupTimer:hasRef())
		-- print ('self.wakeupTimer:isActive()==',self.wakeupTimer:isActive())
		if not self.wakeupTimer:hasRef() then
			self.wakeupTimer:ref()
		end
		if not self.wakeupTimer:isActive() then 
			local ret=self.wakeupTimer:start(DUMMY_FUNCTION)
		end
		--self.prepare:ref()激活后再uv_run,只会永久性block,因为没有其他事件
		return cb

	end

	function c.runCallBacks_(self)
		--print('runCallBacks_........begin')
		local count = 1000
		
		--require('routineUtil')
		--assert(_eli_:getCurrent()==self.oHub)

		self.wakeupTimer:stop()
		while #self.lCallbacks>0 and count > 0 do
			local callbacks = self.lCallbacks
			--print('runCallBacks_.....aaaaaaa')
			self.lCallbacks = {}
			for _,cb in ipairs(callbacks) do
				local func = cb:getFunc()
				--print('runCallBacks_.....11111')
				--assert(_eli_:getCurrent()==self.oHub)
				func(cb:getArgs()) --todo: 以后,这个要捕捉错误,不然会中断
				--assert(_eli_:getCurrent()==self.oHub)
				--print('runCallBacks_.....222222')
				count =count - 1
			end  --for
			--print('runCallBacks_.....bbbbbbb')
		end --while

		if #self.lCallbacks>0 then
			self.wakeupTimer:start(DUMMY_FUNCTION)
		end
		--print('runCallBacks_........end')

	end --function
	
	function c.handle_error(self, context, type, value, tb)
		local handle_error = nil
		local error_handler = self.error_handler
		if error_handler ~= nil then
			-- we do want to do getattr every time so that setting Hub.handle_error property just works
			handle_error = util.getAttr(error_handler, 'handle_error', error_handler)
			handle_error(error_handler,context, type, value, tb)
		else
			self:_default_handle_error(context, type, value, tb)
		end
	end

	function c._default_handle_error(self, context, type, value, tb)
		-- note: Hub sets its own error handler so this is not used by gevent
		-- this is here to make core.loop usable without the rest of gevent
		
		--traceback.print_exception(type, value, tb)
		--libev.ev_break(self._ptr, libev.EVBREAK_ONE)
	end

	function c.run(self,mode) --override --UV_RUN_ONCE UV_RUN_NOWAIT UV_RUN_DEFAULT
		--if mode==nil then mode=networkLib.UV_RUN_DEFAULT end
		return networkLib.cLoop.run(self,mode)
	end


	function c.createIdle(self, ...)
		return cIdle(self, ...)
	end

	function c.createPrepare(self, ...)
		return cPrepare(self, ...)
	end

	function c.createTimer(self,fTimeout,fRepeat,dArgs, ...)
		if fTimeout == nil then fTimeout = 0 end
		if fRepeat == nil then fRepeat = 0 end
		return cTimer(self, fTimeout, fRepeat, ...) --return networkLib.cTimer(self)
	end

	function c.createIO(self, fd, events, ...)
		return cPoll(self, fd, events, ...)
	end

	function c.createAsync(self,...)
		return cAsync(self, ...)
	end

	-- function c.child(self,...)
	-- end
------------------------------------------------
local cWatcherMother=class.create()
local c = cWatcherMother
	function c.__init__(self)
		self.oWaiter = nil
	end

	function c.setWaiter(self, oWaiter)
		self.oWaiter = oWaiter
	end
------------------------------------------------
cPrepare=class.create(networkLib.cPrepare,cWatcherMother)
local c=cPrepare
	function c.__init__(self, oLoop, ...)
		util.checkNil()
		networkLib.cPrepare.__init__(self, oLoop, ...)
		cWatcherMother.__init__(self)
	end

	function c.start(self,func,...)
		util.checkNil()
		local ft=util.functor(func,...)
		return networkLib.cPrepare.start(self,ft)
	end
	
	function c.stop(self)
		self:setWaiter(nil)
		networkLib.cPrepare.stop(self)
	end
------------------------------------------------
cTimer=class.create(networkLib.cTimer,cWatcherMother)
local c=cTimer
	function c.__init__(self, oLoop, fTimeout, fRepeat, ...)
		util.checkNil()
		networkLib.cTimer.__init__(self, oLoop, ...)
		cWatcherMother.__init__(self)

		--以下是start的参数
		self.fTimeout=fTimeout
		self.fRepeat=fRepeat
	end

	function c.start(self, func, ...)
		util.checkNil()
		if func==DUMMY_FUNCTION then
			func=nil --c层支持传nil值作回调函数了
		else
			func=util.functor(func, ...)
		end
		return networkLib.cTimer.start(self, func, self.fTimeout, self.fRepeat)
	end

	function c.stop(self)
		self:setWaiter(nil)
		networkLib.cTimer.stop(self)
	end
------------------------------------------------
cIdle=class.create(networkLib.cIdle,cWatcherMother)
local c=cIdle
	function c.__init__(self, oLoop, ...)
		networkLib.cIdle.__init__(self, oLoop, ...)
		cWatcherMother.__init__(self)
	end

	function c.start(self,func,...)
		assert(func ~= nil)
		local ft=util.functor(func,...)
		networkLib.cIdle.start(self, ft)
	end

	function c.stop(self)
		self:setWaiter(nil)
		networkLib.cIdle.stop(self)
	end

-----------------------------------------------
cPoll=class.create(networkLib.cPoll,cWatcherMother)
local c=cPoll
	function c.__init__(self, oLoop, fd, events, ...)
		self.events = events
		networkLib.cPoll.__init__(self, oLoop, fd, ...)
		cWatcherMother.__init__(self)
	end

	function c.start(self,func,...)
		assert(func ~= nil)
		local ft=util.functor(func,...)
		networkLib.cPoll.start(self, ft, self.events)
	end

	function c.stop(self)
		self:setWaiter(nil)
		networkLib.cPoll.stop(self)
	end	
-----------------------------------------------
cAsync=class.create(networkLib.cAsync,cWatcherMother)
local c=cAsync
	function c.__init__(self, oLoop, ...)
		local delegate__ = util.bindMethod(self.delegate__,self)
		self.cb = nil
		networkLib.cAsync.__init__(self, oLoop, delegate__, ...)
		cWatcherMother.__init__(self)
	end

	function c.delegate__(self)
		if self.cb ~= nil then
			self.cb()
		end
	end

	function c.start(self,func,...)
		-- libuv不提供start的接口,脚本我做了一个,仅有一个init不好用
		assert(func ~= nil)
		self.cb = util.functor(func,...)
	end

	function c.stop(self)
		error('libuv不提供stop的接口,脚本我也不提供了')
		--self:setWaiter(nil)
		--networkLib.cAsync.stop(self)
	end

-----------------------------------------------
--假装自己是个watcher一样,拥有stop和pending方法
cCallback=class.create() --是local
local c=cCallback
	function c.__init__(self,func,...)
		self.func=func
		self.lArgs={...}
	end

	function c.getFunc(self)
		return self.func
	end

	function c.getArgs(self)
		return unpack(self.lArgs)
	end

	function c.stop(self)
		self.func = nil
		self.lArgs = nil
	end

	-- def __nonzero__(self):
	--	 # it's nonzero if it's pending or currently executing
	--	 # NOTE: This depends on loop._run_callbacks setting the args property
	--	 # to None.
	--	 return self.args is not None
	-- __bool__ = __nonzero__

	function c.pending(self)
		return self.func~=nil
	end

--[[
	def _format(self):
		return ''

	def __repr__(self):
		result = "<%s at 0x%x" % (self.__class__.__name__, id(self))
		if self.pending:
			result += " pending"
		if self.callback is not None:
			result += " callback=%r" % (self.callback, )
		if self.args is not None:
			result += " args=%r" % (self.args, )
		if self.callback is None and self.args is None:
			result += " stopped"
		return result + ">"
--]]

require('util')
require('except')