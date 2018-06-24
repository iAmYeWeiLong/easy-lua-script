--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)
require('class')
require('util')
require('routineSub')
local unpack=table.unpack or unpack  --各lua版本兼容
local parse_address

local AF_INET,AF_INET6 = 2,23
local function _handle_and_close_when_done(handle, close, oClientSocket, address)
	local ok,errStack=xpcall(function()
		return handle(oClientSocket, address)
	end,except.errorHandler)
	close(oClientSocket, address)
	assert(ok,errStack)	
end

cBaseServer=class.create()
local c=cBaseServer

	c.min_delay = 0.01
	c.max_delay = 1

	--: Sets the maximum number of consecutive accepts that a process may perform on
	--: a single wake up. High values give higher priority to high connection rates,
	--: while lower values give higher priority to already established connections.
	--: Default is 100. Note, that in case of multiple working processes on the same
	--: listening value, it should be set to a lower value. (pywsgi.WSGIServer sets it
	--: to 1 when environ["wsgi.multiprocess"] is true)
	c.max_accept = 100

	c._spawn = util.bindMethod(routineSub.cRoutineSub.spawn,routineSub.cRoutineSub)  --是类方法,不是实例方法
	--: the default timeout that we wait for the client connections to close in stop()
	c.stop_timeout = 1

	c.fatal_errors = {9,22,10038} --(errno.EBADF, errno.EINVAL, errno.ENOTSOCK)

	-- function c._spawn(self, ...)
	-- 	return _eli_:spawn(...)
	-- end

	function c.__init__(self, listener, handle, spawn)
		-- handle允许为nil
		assert(listener ~= nil)
		if spawn == nil then spawn = 'default' end

		self._stop_event = event.Event()
		self._stop_event:set()
		self._watcher = nil
		self._timer = nil
		self._handle = nil
		-- XXX: FIXME: Subclasses rely on the presence or absence of the
		-- `socket` attribute to determine whether we are open/should be opened.
		-- Instead, have it be nil.
		self.pool = nil
		local ok,errStack=xpcall(function()
			self:set_listener(listener)
			self:set_spawn(spawn)
			self:set_handle(handle)
			self.delay = self.min_delay
			self.loop = _elo_.HUB.oLoop
			if self.max_accept < 1 then
				error(string.format('max_accept must be positive int: %r' ,self.max_accept))
			end

			self.boundStartAcceptingIfStarted = util.bindMethod(self._start_accepting_if_started,self)
		end,except.errorHandler)

		if not ok then
			self:close()
			error(errStack)
		end
	end

	function c.set_listener(self, listener)
		assert(listener ~= nil)
		--暂不支持listener是socket的情况
		if false and util.hasAttr(listener, 'accept') then
			if util.hasAttr(listener, 'do_handshake') then
				error(string.format('Expected a regular socket, not SSLSocket: %s' ,listener))
			end
			self.family = listener.family
			self.address = listener:getsockname()
			self.socket = listener
		else
			self.family, self.address = parse_address(listener)
		end
	end

	function c.set_spawn(self, spawn)
		assert(spawn ~= nil)
		if true or spawn == 'default' then --暂时只支持default
			self.pool = nil
			local f = util.getAttr(self,'_spawn') --取类属性
			--print('type(self._spawn)',type(f))
			if f ~= nil then
				function self._spawn(self,...)
					--print('_spqwn....')
					local xxx = util.bindMethod(routineSub.cRoutineSub.spawn,routineSub.cRoutineSub)
					return xxx(...)
				end
			end
		elseif util.hasAttr(spawn, 'spawn') then
			self.pool = spawn
			function self._spawn(self,...)
				return spawn:spawn(...)
			end	
		elseif type(spawn)=='number' then
			self.pool = pool.cPool(spawn)
			function self._spawn(self,...)
				return self.pool:spawn(...)
			end
		else
			assert(type(spawn) == 'function')
			self.pool = nil
			function self._spawn(self,...)
				return spawn(...)
			end
		end
		if util.hasAttr(self.pool, 'full') then
			function self.full(self)
				return self.pool:full()
			end
		end
		if self.pool ~= nil then
			self.pool._semaphore:rawlink(self.boundStartAcceptingIfStarted) --util.bindMethod(self._start_accepting_if_started,self)
		end
	end

	function c.set_handle(self, h)
		if h ~= nil then
			self.handle = h
		end
		if util.hasAttr(self, 'handle') then
			self._handle = self.handle
		else
			error("'handle' must be provided")
		end
	end

	function c._start_accepting_if_started(self, _event)
		--_event允许为nil
		if self.started then
			self:start_accepting()
		end
	end

	function c.start_accepting(self)
		if self._watcher == nil then
			-- just stop watcher without creating a new one?
			self._watcher = self.loop:createIO(self.socket:fileno(), 1)
			local mt = util.bindMethod(self._do_read,self)
			self._watcher:start(mt)
		end
	end

	function c.stop_accepting(self)
		if self._watcher ~= nil then
			self._watcher:stop()
			self._watcher = nil
		end
		if self._timer ~= nil then
			self._timer:stop()
			self._timer = nil
		end
	end

	function c.do_handle(self, oClientSocket, address)
		local h = self._handle --是成员变量,无需bindMethod
		local close = util.bindMethod(self.do_close,self)

		local ok,errStack=xpcall(function()
			if rawget(self,'_spawn') == nil then --用rawget避免取到类属性
				_handle_and_close_when_done(h, close, oClientSocket, address)
			else
				self:_spawn(_handle_and_close_when_done, h, close, oClientSocket, address)
			end
		end,except.errorHandler)

		if not ok then
			close(oClientSocket, address)
			error(errStack)
		end
	end

	function c.do_close(self, ...)
	end

	function c.do_read(self)
		error('NotImplementedError')
	end

	function c._do_read(self)
		--print('cBaseServer._do_read.. ')
		--for _ in xrange(self.max_accept)
		for _=0,self.max_accept do	
			if self:full() then
				self:stop_accepting()
				return
			end
			local oClientSocket, address
			local ok,errStack=xpcall(function()
				oClientSocket, address = self:do_read()
				self.delay = self.min_delay
			end,except.errorHandler)

			if ok and oClientSocket == nil then
				return nil
			end

			if not ok then
				self.loop:handle_error(self, errStack)
				if self:is_fatal_error(errStack.oError) then
					self:close()
					io.stderr:write(string.format('ERROR: %s failed with %s\n' ,tostring(self), tostring(errStack.oError)))
					return
				end
				if self.delay >= 0 then
					self:stop_accepting()
					self._timer = self.loop:createTimer(self.delay)
					local mt=util.bindMethod(self._start_accepting_if_started,self)
					self._timer:start(mt)
					self.delay = math.min(self.max_delay, self.delay * 2)
				end
				break
			else
				local ok,errStack=xpcall(function()
					self:do_handle(oClientSocket, address)
				end,except.errorHandler)

				if not ok then
					self.loop:handle_error(self, errStack) --(lArgs[1:], self)
					if self.delay >= 0 then
						self:stop_accepting()
						self._timer = self.loop:createTimer(self.delay)
						local mt=util.bindMethod(self._start_accepting_if_started,self)
						self._timer:start(mt)
						self.delay = math.min(self.max_delay, self.delay * 2)
					end
					break
				end
			end
		end--for
	end --function

	function c.full(self)
		-- copied from self.pool
		return false
	end

	--function c.__repr__(self)
	--	return '<%s at %s %s>' % (type(self).__name__, hex(id(self)), self._formatinfo())
	--end
	--[[
	
	function c.__string(self)
		return string.format('<%s %s>',self.__class__.__name__, self:_formatinfo())
	end

	function c._formatinfo(self)
		if util.hasAttr(self, 'socket') then
			try:
				fileno = self.socket:fileno()
			except Exception as ex:
				fileno = str(ex)
			result = 'fileno=%s ' % fileno
		else
			result = ''
		end
		try:
			if isinstance(self.address, tuple) and len(self.address) == 2 then
				result += 'address=%s:%s' % self.address
			else
				result += 'address=%s' % (self.address, )
			end
		except Exception as ex:
			result += str(ex) or '<error>'

		handle = self.__dict__.get('handle')
		if handle ~= nil then
			fself = util.getAttr(handle, '__self__', nil)
			try:
				if fself is self then
					-- Checks the __self__ of the handle in case it is a bound
					-- method of self to prevent recursivly defined reprs.
					handle_repr = '<bound method %s.%s of self>' % (
						self.__class__.__name__,
						handle.__name__,
					)
				else
					handle_repr = repr(handle)
				end

				result += ' handle=' + handle_repr
			except Exception as ex:
				result += str(ex) or '<error>'

		return result
	end
	--]]

	--@property
	function c.server_host(self)
		--IP address that the server is bound to (string).
		if type(self.address) == 'table' then
			return self.address[1]
		end
	end

	--@property
	function c.server_port(self)
		--Port that the server is bound to (an integer).
		if type(self.address) == 'table' then
			return self.address[2]
		end
	end

	function c.init_socket(self)
		--[[If the user initialized the server with an address rather than socket,
		then this function will create a socket, bind it and put it into listening mode.

		It is not supposed to be called by the user, it is called by :meth:`start` before starting
		the accept loop.--]]
	end

	--@property
	function c.started(self)
		return not self._stop_event:is_set()
	end

	function c.start(self)
		--[[Start accepting the connections.

		If an address was provided in the constructor, then also create a socket,
		bind it and put it into the listening mode.
		--]]
		self:init_socket()
		self._stop_event:clear()
		local ok,errStack=xpcall(function()
			self:start_accepting()
		end,except.errorHandler)
		if not ok then
			self:close()
			error(errStack)
		end
	end

	function c.close(self)
		-- Close the listener socket and stop accepting.
		self._stop_event:set()
		local ok1,errStack1=xpcall(function()
			self:stop_accepting()
		end,except.errorHandler)

		
		local ok2,errStack2=xpcall(function()
			if util.getAttr(self,'socket') ~= nil then
				self.socket:close()
			end
		end,except.errorHandler)
		
		self.socket = nil
		self.handle = nil
		self._handle = nil
		self._spawn = nil
		-- self.full = nil
		if self.pool ~= nil then
			self.pool._semaphore:unlink(self.boundStartAcceptingIfStarted) -- util.bindMethod(self._start_accepting_if_started,self)
		end
		local b = ok2 or class.isInstance(errStack2.oError,except.cException)
		assert(b,errStack2)
		assert(ok1,errStack1)
	end

	--@property
	function c.closed(self)
		return not util.hasAttr(self, 'socket')
	end

	function c.stop(self, timeout)
		--[[
		Stop accepting the connections and close the listening socket.

		If the server uses a pool to spawn the requests, then
		:meth:`stop` also waits for all the handlers to exit. If there
		are still handlers executing after *timeout* has expired
		(default 1 second, :attr:`stop_timeout`), then the currently
		running handlers in the pool are killed.

		If the server does not use a pool, then this merely stops accepting connections;
		any spawned greenlets that are handling requests continue running until
		they naturally complete.
		]]
		self:close()
		if timeout == nil then
			timeout = self.stop_timeout
		end
		if self.pool then
			self.pool:join(timeout)
			self.pool:kill(nil, true, 1)
		end
	end

	function c.serve_forever(self, stop_timeout)
		--Start the server if it hasn't been already started and wait until it's stopped.
		-- add test that serve_forever exists on stop()
		
		-- stop_timeout 允许为nil
		if not self:started() then
			self:start()
		end
		local ok,errStack=xpcall(function()
			self._stop_event:wait()
		end,except.errorHandler)

		--为什么在timer回调中有异常就会跳出hub,导致hub协程死掉,要找出来
		if not ok and _elo_.HUB:status()=='dead' then--ywl
			error(errStack) --如果hub死掉了,下面的启动新协程肯定失败的.
		end

		local bm = util.bindMethod(self.stop,self)
		_eli_:spawn(bm, stop_timeout):join()
		assert(ok,errStack)
	end

	function c.is_fatal_error(self,err)
		return class.isInstance(err,except.cSocketError) and util.inList(err.iCode, self.fatal_errors)
	end
----------------------------------------------------------------------------
local function _extract_family(sHost)
	if string.sub(sHost,1,1) == '[' and string.sub(sHost, -1) == ']' then
		sHost = string.sub(sHost, 2, -2)
		return AF_INET6, sHost
	end
	return AF_INET, sHost
end


local function _parse_address(address) -- 可能是list,可能是string,可能是number
	if type(address)=='table' then
		if address[1]=='' or string.find(address[1],':') ~= nil then
			return AF_INET6, address
		end
		return AF_INET, address
	end
	if ((type(address) == 'string' and string.find(address,':') == nil)
		or type(address)=='number') then
		-- Just a port
		return AF_INET6, {'', tonumber(address)}
	end

	if type(address)~='string' then
		error(string.format('Expected list or string, got %s' , type(address)))
	end

	--稍后处理  local host, port = address.rsplit(':', 1)
	local family, host = _extract_family(host)
	if host == '*' then
		host = ''
	end
	return family, {host, tonumber(port)}
end

function parse_address(address) --local 
	do
		return _parse_address(address)
	end

	local ok,errStackOrVal=xpcall(function()
		return _parse_address(address)
	end,except.errorHandler)
	--except ValueError as ex:
	if not ok then
		if except.isInstance(errStackOrVal)==ValueError then
			error(string.format('Failed to parse address %r: %s', address, ex))
		end
		error(errStackOrVal)
	end
end

require('util')
require('event')
-- require('pool')