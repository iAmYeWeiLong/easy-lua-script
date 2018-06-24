--[[	作者:叶伟龙@龙川县赤光镇
		hub协程
--]]
_ENV=require('base').module(...)
require('class')
require('routineBase')

----------------------------------
local unpack=table.unpack or unpack  --各lua版本兼容
local BLOCK_FOREVER = 'This operation would block forever'

require('except')
local LoopExit = class.create(except.cException)

cHubRoutine=class.create(routineBase.cRoutineBase)--单例,只有一个HUB协程的
local c=cHubRoutine
	function c.createJob_(self)--override
		local ft = util.bindMethod(self.hubProc,self)
		return coroutine.create(ft)
	end

	function c.__init__(self,dArgs) --override
		routineBase.cRoutineBase.__init__(self)
		--self.parent=_elo_.MAIN --时机无法控制
		self.oLoop=self:createLoop_(dArgs)
	end

	function c.createLoop_(self,dArgs) --override
		return loop.cLoop(self.realJob)
	end

	function c.__tostring(self)
		return '<hub coroutine>'
	end

	function c.cancel_wait(self, watcher, error)
		--[[
		Cancel an in-progress call to :meth:`wait` by throwing the given *error*
		in the waiting greenlet.
		--]]
		assert(watcher~=nil)
		--assert(error~=nil)
		if watcher.oWaiter ~= nil then
			local mt=util.bindMethod(self._cancel_wait, self, watcher, error)
			self.oLoop:run_callback(mt)
		end
	end

	function c._cancel_wait(self, watcher, error)
		if watcher:isActive() then
			local oWaiter = watcher.oWaiter
			if oWaiter ~= nil then
				oWaiter:throw(error)
			end
		end
	end

	function c.hubProc(self,...)--别的协程switch到HUB时带来的... ,没有啥作用.
		--因为外面是resume进这里的,出错就要把栈信息想办法给到外面.未经包装的错误信息没有调用栈,只有一行的出错位置
		local function lf()
			assert(_eli_:getCurrent()==self)
			local hub=_elo_.HUB
			assert(hub==self)
			local oLoop=hub.oLoop
			local run=oLoop.run
			local networkLib=require('easyLuaLib.network')
			local UV_RUN_ONCE=networkLib.UV_RUN_ONCE --,networkLib.UV_RUN_DEFAULT,networkLib.UV_RUN_NOWAIT

			oLoop.error_handler = self
			while true do
				--print('========================= begin')
				local lCallback,alive=run(oLoop,networkLib.UV_RUN_ONCE) --如果是UV_RUN_DEFAULT,进去就再也不出来了,即使回调里面发生了yield
				--print('========================= end,#Callback=',#lCallback)
				--assert(#lCallback~=0)
				
				-- print('hubProc',#lCallback,alive)
				if not alive and #lCallback==0 then --因为有callback的话,可能就会在callback又使得alive为真
					break
				end
				--改为for i=1,len do,不做remove,C层直接覆盖
				while #lCallback>0 do 
					local cb=table.remove(lCallback,1)
					cb()
				end
			end
			_elo_.MAIN:throw(LoopExit(BLOCK_FOREVER))--到这里,HUB协程结束了,下面的代码走不到的		
			return {_elo_.MAIN,unpack({})}--返回值到MAIN协程(父协程是MAIN),结果return给父协程好像没有啥作用.
		end -- lf

		local ok,errStackOrVal=xpcall(lf,except.errorHandler)
		assert(ok,errStackOrVal)
		return unpack(errStackOrVal)
	end
	
	function c.switch(self,...)--override
		local currentJob= _eli_:getCurrent()
		local switchOut = util.getAttr(currentJob,'switchOut')
		if switchOut~=nil then
			currentJob:switchOut(currentJob)
		end
		return routineBase.cRoutineBase.switch(self,...)
		--[[
		走到这里,已经回到了非HUB协程
		]]		
	end

	function c.switchOut(self)
		--全部的block的job都需要switch到HUB的,当从hub协程switch到hub时,说明在在hub协程中调用了block的function
		error('Impossible to call blocking function in the event loop callback')
	end
	function c.wait(self, watcher,dArgs)
		assert(watcher ~= nil)
		local oWaiter = self:createWaiter_(dArgs)
		local unique = class.cObject()
		--强绑方法,避免当前协程死掉.外部某处持有watcher,watcher通过start函数持用oWaiter,waiter通过get函数持有当前协程
		local method=util.forceBindMethod(oWaiter.switch,oWaiter)
		watcher:start(method, unique)
		watcher:setWaiter(oWaiter)
		--以下实现的是try finally语义
		local ok,errStack=xpcall(function()
			local result = oWaiter:get()
			if result ~= unique then
				--raise InvalidSwitchError('Invalid switch into %s: %r (expected %r)' % (getcurrent(), result, unique))
				error('Invalid switch into')
			end
		end,except.errorHandler)
		watcher:stop()
		assert(ok,errStack)
	end

	function c.handle_error(self, context,errStack)
		io.stderr:write('----------------------------------------------------------------------------------------------------------------------------\n')
		io.stderr:write(string.format('error message:\n\t%s\n',tostring(errStack)))
		io.stderr:write(string.format('context:\n\t%s\n',tostring(context)))
		io.stderr:write('----------------------------------------------------------------------------------------------------------------------------\n')
	end

	function c.join(self, timeout)--timeout允许为nil
		if _eli_:getCurrent()~=_elo_.MAIN then
			error("only possible from the MAIN greenlet")
		end
		if self:status()=='dead' then
			return true
		end
		local waiter = self:createWaiter_()

		if timeout ~=nil then
			timeout = self.oLoop:createTimer(timeout)
			local switch=util.bindMethod(waiter.switch,waiter)
			timeout:start(switch)
		end
		local ok,errStackOrVal=xpcall(function()
			local ok,errStack=xpcall(function()
				waiter:get()
			end,except.errorHandler)

			if ok then
				return false
			end
			if class.isInstance(errStack.oError,LoopExit) then
				return true
			else
				error(errStack)
			end
		end,except.errorHandler)

		if timeout ~= nil then
			timeout:stop()
		end
		assert(ok,errStackOrVal)
		return errStackOrVal
	end	
--父协程是MAIN,hubProc的返回值要不要都无所谓
--------------------------------------------------------------------------------
require('waiter')
--未经过测试
local _MultipleWaiter = class.create(waiter.cWaiter)
local c = _MultipleWaiter
	--[[
	An internal extension of Waiter that can be used if multiple objects
	must be waited on, and there is a chance that in between waits greenlets
	might be switched out. All greenlets that switch to this waiter
	will have their value returned.

	This does not handle exceptions or throw methods.
	]]	

	function c.__init__(self, ...)
		waiter.cWaiter.__init__(self, ...)
		-- we typically expect a relatively small number of these to be outstanding.
		-- since we pop from the left, a deque might be slightly
		-- more efficient, but since we're in the hub we avoid imports if
		-- we can help it to better support monkey-patching, and delaying the import
		-- here can be impractical (see https://github.com/gevent/gevent/issues/652)
		self._values = {} -- list()
	end

	function c.switch(self, value)
		table.insert(self._values,value)
		waiter.cWaiter.switch(self, True)
	end

	function c.get(self)
		if #self._values == 0 then
			waiter.cWaiter.get(self)
			self:clear(self) --此处代码与gevent不同,gevent不知为什么要调用父类的,我认为它是不小心写错了
		end
		return table.remove(self._values,1)
	end
--------------------------------------------------------------------------------

cInterface=class.create()
local c=cInterface
	function c.sleep(self,seconds,dArgs)
		if seconds==nil then seconds=0 end

		local oHub = _elo_.HUB
		local oLoop = oHub.oLoop
		
		if seconds <= 0 then
			local oWaiter = self:createWaiter_(dArgs)
			local method=util.bindMethod(oWaiter.switch,oWaiter)
			oLoop:run_callback(method)
			oWaiter:get()
		else
			local oTimer = oLoop:createTimer(seconds,0,dArgs)
			oHub:wait(oTimer)
		end
	end

	function c.createWaiter_(self,dArgs)
		return waiter.cWaiter()
	end

--未经过测试
	function c.iwait(self,objects, timeout, count)
		-- objects,timeout,count 都可为nil

		--[[
		Iteratively yield *objects* as they are ready, until all (or *count*) are ready
		or *timeout* expired.

		:param objects: A sequence (supporting :func:`len`) containing objects
			implementing the wait protocol (rawlink() and unlink()).
		:keyword int count: If not `nil`, then a number specifying the maximum number
			of objects to wait for. If ``nil`` (the default), all objects
			are waited for.
		:keyword float timeout: If given, specifies a maximum number of seconds
			to wait. If the timeout expires before the desired waited-for objects
			are available, then this method returns immediately.

		.. seealso:: :func:`wait`

		.. versionchanged:: 1.1a1
		   Add the *count* parameter.
		.. versionchanged:: 1.1a2
		   No longer raise :exc:`LoopExit` if our caller switches greenlets
		   in between items yielded by this function.
		]]

		-- QQQ would be nice to support iterable here that can be generated slowly (why?)		

		local NONE = _elo_.NONE
		if objects == nil then
			coroutine.yield(_elo_.HUB:join(timeout))
			return
		end
		if count == nil then
			count = #objects
		else
			count = math.min(count, #objects)
		end

		local waiter = _MultipleWaiter()
		local switch = util.bindMethod(waiter.switch,waiter)

		if timeout ~= nil then
			timer = _elo_.HUB.loop:createTimer(timeout)
			timer:start(switch, NONE)
		end

		local ok,errStack = xpcall(function()
			for _,obj in ipairs(objects) do
				obj:rawlink(switch)
			end

			for _ = 1,#count do
				item = waiter:get()
				waiter:clear()
				if item == NONE then
					return
				end
				coroutine.yield(item)
			end
		end,except.errorHandler)
		
		if timeout ~= nil then
			timer:stop()
		end
		for _,aobj in ipairs(objects) do
			local unlink = util.getAttr(aobj, 'unlink', nil)
			if unlink ~= nil then
				local ok,errStack = xpcall(unlink,aobj,switch)
				if not ok then
					print(errStack) --traceback.print_exc()
				end
			end
		end
		assert(ok,errStack)
	end
--未经过测试
	function c.wait(self,objects, timeout, count)
		-- objects,timeout,count都可以为nil
		--[[
		Wait for ``objects`` to become ready or for event loop to finish.

		If ``objects`` is provided, it must be a list containing objects
		implementing the wait protocol (rawlink() and unlink() methods):

		- :class:`gevent.Greenlet` instance
		- :class:`gevent.event.Event` instance
		- :class:`gevent.lock.Semaphore` instance
		- :class:`gevent.subprocess.Popen` instance

		If ``objects`` is ``nil`` (the default), ``wait()`` blocks until
		the current event loop has nothing to do (or until ``timeout`` passes):

		- all greenlets have finished
		- all servers were stopped
		- all event loop watchers were stopped.

		If ``count`` is ``nil`` (the default), wait for all ``objects``
		to become ready.

		If ``count`` is a number, wait for (up to) ``count`` objects to become
		ready. (For example, if count is ``1`` then the function exits
		when any object in the list is ready).

		If ``timeout`` is provided, it specifies the maximum number of
		seconds ``wait()`` will block.

		Returns the list of ready objects, in the order in which they were
		ready.

		.. seealso:: :func:`iwait`
		]]
		
		if objects == nil then
			return _elo_.HUB:join(timeout)
		end
		return list(self:iwait(objects, timeout, count))
	end


require('util')
require('except')
require('loop')
require('waiter')