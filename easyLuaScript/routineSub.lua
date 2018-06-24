--[[	作者:叶伟龙@龙川县赤光镇
		子协程
--]]
local _ENV=require('base').module(...)
local class = require('class')
require('routineBase')

local unpack=table.unpack or unpack  --各lua版本兼容

local FLAG=class.cObject()
local _kill
--------------------------------------------------------------------------------
local _dummy_event=class.create()
local c=_dummy_event
	--c.pending=false
	--c.active = false

	function c.pending(self)
		return false
	end

	function c.active(self)
		return false
	end

	function c.stop(self)
	end

	function c.start(self, cb)
		error("Cannot start the dummy event")
	end

local _cancelled_start_event = _dummy_event()
local _start_completed_event = _dummy_event()
_dummy_event=nil
--------------------------------------------------------------------------------
local RE_USE_COROUTINE=false

--------------------------------------------------------------------------------
cRoutineSub=class.create(routineBase.cRoutineBase)
local c=cRoutineSub
	c.lUsingRoutinePool = setmetatable({},{__mode='v'}) --空闲的协程,弱引用
	c.lFreeRoutinePool = {} --空闲的协程,强引用
	c.lValue = {}
	c.iAmount = 0 --协程总数,包括空闲的,在使用的
	
	c._exc_info = {} --错误信息
	c._start_event = nil
	c._notifier = nil
	c.fakeDead = false --装死

	function c.__init__(self,func,...) --override
		assert(func ~= nil)
		assert(type(func)=='function')
		routineBase.cRoutineBase.__init__(self)
		self.parent=_elo_.HUB
		self.loop=_elo_.HUB.oLoop --needed by killall
		
		self.func=func
		self.lArgs={...}
		self._links={}
	end

	function c.createJob_(self)--override 创建一个新的协程
		local job=nil
		if RE_USE_COROUTINE and  #self.lUsingRoutinePool>0 then --没有空闲的协程
			job = table.remove(self.lFreeRoutinePool) --从尾部拿效率高
			job:clearAttr()
			print('have idle job')
		else
			local ft = util.bindMethod(self.routineEntry,self)			
			-- local ft = util.forceBindMethod(self.routineEntry,self )
			job=coroutine.create(ft)
			self.iAmount=self.iAmount+1 --协程总数
			self.lUsingRoutinePool[#self.lUsingRoutinePool]=job
		end
		return job
	end

	if RE_USE_COROUTINE then
		function c.__gc(self)
			print ('in cRoutineSub.__gc') --
			self:clearAttr()
			local lFreeRoutinePool=self.lFreeRoutinePool
			lFreeRoutinePool[#lFreeRoutinePool]=self --复活 (估计只能复用coroutine对象,不能复用整个外壳)
			--要搜一下dRealJobMapSelf,注意这个变量对复活逻辑的影响
			--print ('in cRoutineSub.__gc len=',#lFreeRoutinePool) --用table当coroutine测试,当场打印数量,竟然不会增加!!!!后面再找发现表里面又有
		end
	end

	function c.routineEntry(self,hubJob,beRunJob)--srcJob参数没啥用,只是确保是从HUB切过来的,这3个参数与下面的 yield 得到3个变量是一样的意思	
		--因为外面是resume进这里的,出错就要把栈信息想办法给到外面.未经包装的错误信息没有调用栈,只有一行的出错位置
		local function lf()
			local iReUseCount=0
			local lResult
			while true do --死循环的目的是为了复用协程,不想频繁地create协程
				assert(beRunJob==_eli_:getCurrent())
				--print ('hubJob,hub===',hubJob,routineHub.getHub())
				if hubJob~=_elo_.HUB then
					error('只能从hub协程切到子协程')
				end
				lResult=beRunJob:run()--打死不能有error,run内部已经捕捉error
				if not RE_USE_COROUTINE then
					break
				end
				beRunJob.fakeDead=true --因为复用coroutine,所以完成任务后是yield走,coroutine没有死的,是永远活着的,所以需要装死
				hubJob,beRunJob=coroutine.yield(_elo_.HUB,unpack(lResult))--父协程是HUB,func的执行结果yield给HUB,结果yield回去好像也没有啥用
				beRunJob.fakeDead=false

				iReUseCount=iReUseCount+1
				print('iReUseCount=',iReUseCount)
			end
			return {_elo_.HUB,unpack(lResult)} --如果是重用协程,走不到这里的,因为上面是死循环
		end
		local ok,errStackOrVal=xpcall(lf,except.errorHandler)
		assert(ok,errStackOrVal)
		return unpack(errStackOrVal)
	end

	function c.recycle(self) --回收重用
		self:clearAttr()
		lFreeRoutinePool[#lFreeRoutinePool+1] = self --放回池子里
	end

	function c._has_links(self)
		return #self._links>0
	end

	function c._raise_exception(self)
		error(self._exc_info)
	end

	function c.dead(self)
		return self:status()=='dead' or self.fakeDead --真死假死都算死
	end

	function c.__cancel_start(self)
		if self._start_event == nil then
			self._start_event = _cancelled_start_event
		end
		self._start_event:stop()
	end
	function c.__handle_death_before_start(self, exception)
		if self._exc_info == c._exc_info and self:dead() then
			local errStack = except.cErrorAndStack(exception,'')
			self:_report_error(errStack)
		end
	end
	function c.run(self)
		--print('c.run.............')
		local ok,errStackOrVal=xpcall(function()
			self:__cancel_start()
			self._start_event = _start_completed_event

			local ok,errStackOrVal=xpcall(function()
				return {self.func(unpack(self.lArgs))}--执行函数
			end,except.errorHandler)

			if ok then
				self:_report_result(errStackOrVal)
			else
				self:_report_error(errStackOrVal)
			end
			return errStackOrVal
		end,except.errorHandler)

		self.func=nil
		self.lArgs=nil
		
		assert(ok,errStackOrVal)
		return errStackOrVal
	end

	function c.unlink(self, callback)
		assert(callback ~= nil)
		for pos,cb in ipairs(self._links) do
			if cb==callback then
				table.remove(self._links,pos)
				break
			end
		end
	end

	function c._report_result(self, lResult)
		self._exc_info = {FLAG,FLAG}
		self.lValue = lResult
		if self:_has_links() and self._notifier==nil then
			--print('c._report_result')
			local cb = util.functor(self._notify_links,self)
			self._notifier = self.parent.oLoop:run_callback(cb)
		end
	end

	function c._report_error(self, errStack)
		if class.isInstance(errStack.oError,except.cInterrupt) then
			self:_report_result({errStack.oError})
			return
		end
		self._exc_info = {errStack:getInfo()}

		if self:_has_links() and self._notifier==nil then
			local ft = util.functor(self._notify_links,self)
			self._notifier = self.parent.oLoop:run_callback(ft)
		end
		self.parent:handle_error(self, errStack)
	end

	function c.getValue(self)
		return unpack(self.lValue)
	end

	function c.spawn(cls,func,...)--类方法
		--print('routineSub.spawn....')
		local job=cls(func,...)
		job:start()
		return job
	end

	function c.throw(self,...) -- override
		assert(_eli_:getCurrent()==_elo_.HUB) --ywl
		local lArgs={...} --必须,不然下面throw三个点时会报错误:cannot use '...' outside a vararg function near '...'
		self:__cancel_start()
		local ok,errStack=xpcall(function()
			if not self:dead() then
				routineBase.cRoutineBase.throw(self,unpack(lArgs))
			end
		end,except.errorHandler)

		self:__handle_death_before_start(...)
		assert(ok,errStack)
	end

	function c.start(self)
		if self._start_event==nil then
			local ft=util.functor(self.switch,self,self.parent,self)--self是目标协程.后2个参数会传递到 routineEntry
			self._start_event = self.parent.oLoop:run_callback(ft)
		end
	end
	
	function c.started(self)
		-- DEPRECATED
		return bool(self)
	end

	function c.ready(self)
		return self:dead() or #self._exc_info>0
	end

	function c.successful(self)
		--[["""Return true if and only if the greenlet has finished execution successfully,
		that is, without raising an error."""]]

		return #self._exc_info>0 and self._exc_info[1]==FLAG
	end

	function c.exception(self)
		if #self._exc_info>0 then
			return self._exc_info[1]
		end
		return nil
	end

	function c.__tosring(self)
		return '<sub coroutine>'
	end

	function c.rawlink(self, callback)
		if type(callback)~='function' then
			error('必须是function')
		end
		table.insert(self._links,callback)

		if self:ready() and #self._links>0 and self._notifier==nil then
			local method=util.bindMethod(self._notify_links,self)
			self._notifier = self.parent.oLoop:run_callback(method)
		end
	end

	function c._notify_links(self)
		local lLinks=self._links
		self._links={} --目的是重用coroutine时
		while next(lLinks)~=nil do
			local link=table.remove(lLinks,1)
			local ok,errStack=xpcall(function()
				link(self)
			end,except.errorHandler)

			if not ok then
				self.parent:handle_error(self,errStack)
			end
		end
	end

	function c.get(self, block, timeout)
		if block==nil then block=true end
		if timeout==nil then timeout=nil end

		if self:ready() then
			if self:successful() then
				return unpack(self.lValue)
			end
			self:_raise_exception()
		end
		if not block then
			error('TIMEOUT',0)
		end	

		local curJob=_eli_:getCurrent()
		local switch = util.bindMethod(curJob.switch,curJob)
		self:rawlink(switch)

		local to = _eli_:_start_new_or_dummy(timeout)
		
		local ok,errStack=xpcall(function()
			local ok,errStack=xpcall(function()
				local result =self.parent:switch()
				if result~=self then--正常切回,带的参数却是错的				
					error(string.format('Invalid switch into Greenlet.get(): %s',result))
				end
			end,except.errorHandler)

			to:cancel()
			assert(ok,errStack)
		end,except.errorHandler)

		if not ok then
			self:unlink(switch)
			error(errStack)
		end
		if self:ready() then
			if self:successful() then
				return self:getValue()
			end
			self:_raise_exception()
		end
		return nil
	end

	function c.join(self, timeout)
		--[[Wait until the greenlet finishes or *timeout* expires.
		Return ``None`` regardless.
		]]
		-- timeout 可以为nil
		if self:ready() then
			return
		end
		local curJob=_eli_:getCurrent()
		local switch = util.bindMethod(curJob.switch,curJob)
		self:rawlink(switch)
		local to
		local ok,errStack=xpcall(function()
			to = _eli_:_start_new_or_dummy(timeout)
			local ok,errStack=xpcall(function()
				--assert(coroutine.status(self.parent.realJob)~='dead') --ywl
				local result = self.parent:switch()
				if result ~= self then
					error(string.format('Invalid switch into Greenlet.join(): %s',result))
				end
			end,except.errorHandler)
			to:cancel()
			assert(ok, errStack)
		end,except.errorHandler)
		if not ok then
			self:unlink(switch)
			if errStack.oError ~= to then
				error(errStack)
			end
		end
	end

	--只有子协程才有kill的需求
	function c.kill(self, exception, block, timeout,dArgs)
		if exception==nil then exception = except.cInterrupt() end
		if block==nil then block = true end
		if timeout==nil then timeout = nil end

		self:__cancel_start()
		if self:dead() then
			self:__handle_death_before_start(exception)
		else
			local waiter=nil
			if block then
				waiter = self:createWaiter_(dArgs)
			end
			local ft = util.functor(_kill, self, exception, waiter)
			self.parent.oLoop:run_callback(ft)
			if block then
				waiter:get()
				self:join(timeout)
			end
		end
	end

function _kill(job, exception, waiter)--从hub协程中调用
	assert(_eli_:getCurrent()==_elo_.HUB) --ywl
	
	local ok,errStack=xpcall(function()
		job:throw(exception)
	end,except.errorHandler)
	
	if not ok then
		job.parent:handle_error(job, errStack)
	end

	if waiter~=nil then
		waiter:switch()
	end
end

---[=[
cInterface=class.create()
local c=cInterface
	--未经过测试
	function c.joinall(self,greenlets, timeout, raise_error, count)
		assert(greenlets ~= nil)
		if raise_error == nil then raise_error = false end
		-- timeout,count可以为nil

		--[[
		Wait for the ``greenlets`` to finish.

		:param greenlets: A sequence (supporting :func:`len`) of greenlets to wait for.
		:keyword float timeout: If given, the maximum number of seconds to wait.
		:return: A sequence of the greenlets that finished before the timeout (if any)
			expired.
		--]]

		if not raise_error then
			return wait(greenlets, timeout, count)
		end

		local done = {}
		for obj in _eli_:iwait(greenlets, timeout, count) do
			if util.getAttr(obj, 'exception', nil) ~= nil then
				if util.hasAttr(obj, '_raise_exception') then
					obj:_raise_exception()
				else
					error(obj:exception())
				end
			end
			table.insert(done,obj)
		end
		return done
	end
--]=]

require('util')
require('except')
require('waiter')
require('routineUtil')
require('routineHub')