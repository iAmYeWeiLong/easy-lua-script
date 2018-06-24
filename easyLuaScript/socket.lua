--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)
require('class')
require('except')
local socketLib=require('easyLuaLib.socket')

local unpack=table.unpack or unpack  --各lua版本兼容

local EWOULDBLOCK = 10035 --"Resource temporarily unavailable" --errno代码为11;在VxWorks和Windows上，EAGAIN的名字叫做EWOULDBLOCK.
local EAGAIN = "Nonauthoritative host not found"
local AF_INET,AF_INET6 = 2,23
-----------------------------------------------------------
local cClosedsocket=class.create()
local c=cClosedsocket

	function c._dummy(...)
		error('Bad file descriptor') --EBADF,
	end

	-- All _delegate_methods must also be initialized here.
	for _,s in ipairs({'send','recv','recv_into','sendto','recvfrom','recvfrom_into'}) do
		c[s]=c._dummy
	end

	c.__index = c._dummy
-----------------------------------------------------------
local cCancel_wait_ex=class.create(except.cException)
local c=cCancel_wait_ex
	function c.__init__(self)
		except.cException.__init__(self,'File descriptor was closed in another greenlet') --EBADF
	end

-----------------------------------------------------------
local SOCK_STREAM = 1
cSocket=class.create()
local c=cSocket

	function c.__init__(self, iFamily, iType, proto, _sock)
		if iFamily==nil then iFamily=AF_INET end --默认ipv4
		if iType==nil then iType=SOCK_STREAM end
		if proto==nil then proto=0 end
		
		self.hub = _elo_.HUB

		if _sock == nil then --_sock可以为nil (监听socket走这个分支)
			self._sock = socketLib.cSocket(iFamily, iType, proto)
			self._sock:setblocking(0) --不阻塞  setblocking(0)
			self.timeout = nil --_socket:getdefaulttimeout() python中拿到是None
		else
			if util.hasAttr(_sock, '_sock') then
				error('与gevent实现不同.没有走这个分支的需求')
				--print('fake socket....',type(_sock._read_event))
				self._sock = _sock._sock
				self.timeout = util.getAttr(_sock, 'timeout', false)
				if self.timeout == false then
					self.timeout = nil --_socket:getdefaulttimeout()
				end
				
				--下面2行与gevent不同,我想重用2个event,不然会这2个event会__gc ,然后close掉相应的socket
				self._read_event = _sock._read_event
				self._write_event = _sock._write_event
			else -- (下面accept成员函数走这个分支)
				--print('real  socket...')
				self._sock = _sock
				self.timeout = nil --_socket:getdefaulttimeout()

				self._sock:setblocking(0) --不阻塞  setblocking(0)
				local fileno = self._sock:fileno() --fileno()
				
				local oLoop = self.hub.oLoop
				self._read_event = oLoop:createIO(fileno, 1)
				self._write_event = oLoop:createIO(fileno, 2)
			end
		end
	end

	function c._wait(self, watcher, timeout_exc)
		--[[Block the current greenlet until *watcher* has pending events.

		If *timeout* is non-negative, then *timeout_exc* is raised after *timeout* second has passed.
		By default *timeout_exc* is ``socket.timeout('timed out')``.

		If :func:`cancel_wait` is called, raise ``socket.error(EBADF, 'File descriptor was closed in another greenlet')``.
		--]]
		assert(watcher ~= nil)
		if timeout_exc == nil then
			timeout_exc = except.cException('timed out') --timeout('timed out')
		end

		if watcher.oWaiter ~= nil then -- .callback
			error(string.format('This socket is already used by another greenlet: %s',watcher.oWaiter ))
		end
		local timeout
		if self.timeout ~= nil then
			timeout = timeout.Timeout:start_new(self.timeout, timeout_exc)
		else
			timeout = nil
		end	
		local ok,errStack=xpcall(function()
			--print('c.recv....aaa')
			self.hub:wait(watcher)
			--print('c.recv....bbb')

		end,except.errorHandler)
		if timeout ~= nil then
			timeout:cancel()
		end
		assert(ok,errStack)
	end

	function c.accept(self)
		local sock = self._sock
		local oClientSocket, address
		while true do
			local ok,errStack=xpcall(function()
				oClientSocket, address = sock:accept()
			end,except.errorHandler)
			if ok then
				break
			end
			if not class.isInstance(errStack.oError,except.cSocketError) or errStack.oError.iCode ~= EWOULDBLOCK or self.timeout == 0.0 then
				error(errStack,0) --传0避免错误msg带上了路径
			else
				self:_wait(self._read_event)
			end			
		end --while		
		local sockobj = cSocket(nil,nil,nil,oClientSocket)
		return sockobj, address
	end

	function c.close(self, _closedsocket, cancel_wait_ex)
		-- This function should not reference any globals. See Python issue --808164.
		if _closedsocket==nil then _closedsocket=cClosedsocket end
		if cancel_wait_ex==nil then cancel_wait_ex=cCancel_wait_ex end
		self.hub:cancel_wait(self._read_event, cancel_wait_ex)
		self.hub:cancel_wait(self._write_event, cancel_wait_ex)
		self._sock = _closedsocket()
	end

	--@property
	function c.closed(self)
		return util.isInstance(self._sock, cClosedsocket)
	end



	--[[先不实现吧
	function c.connect(self, address)
		assert(address ~= nil and #address==2)
		local sHost, iPort = unpack(address)
		if self.timeout == 0.0 then
			return assert(self._sock:connect(sHost, iPort))
		end	
		local sock = self._sock
		if type(address)=='table' then
			r = getaddrinfo(address[1], address[2], sock.family)
			address = r[0][-1]
		end
		local timer
		if self.timeout ~= nil then
			timer = timeout.Timeout:start_new(self.timeout, except.cException('timed out')) --timeout('timed out')
		else
			timer = nil
		end	
		local ok,errStack=xpcall(function()
			while true do
				local err = sock:getsockopt(SOL_SOCKET, SO_ERROR)
				if err then
					raise error(err, strerror(err))
				end
				local result = sock:connect_ex(address)
				if not result or result == EISCONN then
					break
				elseif (result in (EWOULDBLOCK, EINPROGRESS, EALREADY)) or (result == EINVAL and is_windows) then
					self:_wait(self._write_event)
				else
					raise error(result, strerror(result))
				end
			end
		end,except.errorHandler)
		if timer ~= nil then
			timer:cancel()
		end
		assert(ok,errStack)
	end
	--]]

	--[[ 暂时不实现
	function c.connect_ex(self, address)
		try:
			return self:connect(address) or 0
		except timeout:
			return EAGAIN
		except error as ex:
			if type(ex) is error then
				return ex.args[0]
			else
				raise  -- gaierror is not silenced by connect_ex
			end
	end
	--]]

	--[=[
	function c.dup(self)
		--[[dup() -> socket object

		Return a new socket object connected to the same system resource.
		Note, that the new socket does not inherit the timeout.--]]
		return socket(_sock=self._sock)
	end	

	function c.makefile(self, mode='r', bufsize=-1)
		-- Two things to look out for:
		-- 1) Closing the original socket object should not close the
		--	socket (hence creating a new instance)
		-- 2) The resulting fileobject must keep the timeout in order
		--	to be compatible with the stdlib's socket.makefile.
		-- Pass self as _sock to preserve timeout.
		local fobj = _fileobject(type(self)(_sock=self), mode, bufsize)
		return fobj
	end	
	--]=]

	function c.recv(self, iBufSize,iFlags)
		if iFlags == nil then  iFlags = 0 end -- 
		local sock = self._sock  -- keeping the reference so that fd is not closed during waiting
		local _read_event = self._read_event
		while true do
			local sData
			local ok,errStack=xpcall(function()
				--print('c.recv....111')
				sData = sock:recv(iBufSize,iFlags)
				--print('c.recv....222')
			end,except.errorHandler)
			if ok then
				if sData=='' then
					print('socket.recv aaa 111 -->',sData)
				end
				--print('socket.recv aaa-->',sData)
				return sData
			end
			if not class.isInstance(errStack.oError,except.cSocketError) or errStack.oError.iCode ~= EWOULDBLOCK or timeout == 0.0 then
				print('socket.recv bbb    111111')
				error(errStack,0) --传0避免错误msg带上了路径
			else
				--print('socket.recv bbb    222222')
			end
			--_eli_:sleep(0.0000000000000000000000001)
			--print('c.recv....333')
			self:_wait(_read_event)
			--print('c.recv....444')

		end -- while
	end

	--[===[
	function c.recvfrom(self, ...)
		local sock = self._sock
		while true do
			try:
				return sock:recvfrom(...)
			except error as ex:
				if ex.args[0] != EWOULDBLOCK or self.timeout == 0.0:
					raise
				sys.exc_clear()
			self:_wait(self._read_event)
		end
	end

	function c.recvfrom_into(self, ...)
		local sock = self._sock
		while true do
			try:
				return sock.recvfrom_into(...)
			except error as ex:
				if ex.args[0] != EWOULDBLOCK or self.timeout == 0.0 then
					raise
				end
				sys.exc_clear()
			self:_wait(self._read_event)
		end
	end

	function c.recv_into(self, ...)
		sock = self._sock
		while true
			try:
				return sock.recv_into(...)
			except error as ex:
				if ex.args[0] != EWOULDBLOCK or self.timeout == 0.0:
					raise
				sys.exc_clear()
			self:_wait(self._read_event)
		end
	end
	--]===]

	function c.send(self, data,iFlags, timeout, i, j)
		assert(data ~= nil)
		if timeout == nil then timeout = self.timeout end
		if iFlags == nil then iFlags = 0 end
		-- if i == nil then i = 1 end
		-- if j == nil then j = #data end

		local sock = self._sock
		local iSend = 0
		--------------------
		--print('send.......111111')
		local ok,errStack=xpcall(function()
			iSend = sock:send(data,iFlags)
		end,except.errorHandler)
		--print('send.......2222222  ',iSend)

		if ok then
			return iSend
		end
		--print('send.......3333333')

		-------------------------
		--print('errStack.oError====',errStack.oError,type(errStack.oError))
		if not class.isInstance(errStack.oError,except.cSocketError) or errStack.oError.iCode ~= EWOULDBLOCK or timeout == 0.0 then
			error(errStack,0) --传0避免错误msg带上了路径
		end
		--print('send.......44444444')
		
		self:_wait(self._write_event)
		--重试一次
		local ok,errStack=xpcall(function()
			iSend = sock:send(data,iFlags)
		end,except.errorHandler)
		--print('send.......55555555')

		if ok then
			return iSend
		end
		--print('send.......66666666')

		if class.isInstance(errStack.oError,except.cSocketError) and errStack.oError.iCode == EWOULDBLOCK then
			--print('send.......7777')
			
			return 0
		else
			--print('send.......888888')

			error(errStack,0) --传0避免错误msg带上了路径
		end
	end

	--[[
	Send the complete contents of ``data_memory`` before returning.
	This is the core loop around :meth:`send`.

	:param timeleft: Either ``None`` if there is no timeout involved,
	   or a float indicating the timeout to use.
	:param fEnd: Either ``None`` if there is no timeout involved, or
	   a float giving the absolute end time.
	:return: An updated value for ``timeleft`` (or None)
	:raises timeout: If ``timeleft`` was given and elapsed while
	   sending this chunk.
	]]

	function c.__send_chunk(self, sChunk, iFlags, timeleft, fEnd)
		assert(sChunk~=nil)
		-- timeleft允许为nil
		-- fEnd允许为nil

		local data_sent = 0
		local len = #sChunk
		local started_timer = false
		while data_sent < len do
			local sRemain = string.sub(sChunk,-(len-data_sent)) --[data_sent:]
			if timeleft == nil then
				data_sent = data_sent + self:send(sRemain,iFlags)
			elseif started_timer and timeleft <= 0 then
				-- Check before sending to guarantee a check
				-- happens even if each sRemain successfully sends its data
				-- (especially important for SSL sockets since they have large
				-- buffers). But only do this if we've actually tried to
				-- send something once to avoid spurious timeouts on non-blocking
				-- sockets.

				--raise timeout('timed out')
				error('timed out')
			else
				started_timer = true
				data_sent = data_sent + self:send(sRemain, iFlags, timeleft)
				timeleft = fEnd - os.time()
			end
		end
		return timeleft
	end

	function c.sendall(self, sData, iFlags)
		assert(sData~=nil)
		if iFlags == nil then iFlags = 0 end
		-- this sendall is also reused by gevent.ssl.SSLSocket subclass,
		-- so it should not call self._sock methods directly
		local len = #sData -- len(data_memory)
		if len==0 then
			-- Don't send empty data, can cause SSL EOFError.
			-- See issue 719
			return 0
		end

		-- On PyPy up through 2.6.0, subviews of a memoryview() object
		-- copy the underlying bytes the first time the builtin
		-- socket.send() method is called. On a non-blocking socket
		-- (that thus calls socket.send() many times) with a large
		-- input, this results in many repeated copies of an ever
		-- smaller string, depending on the networking buffering. For
		-- example, if each send() can process 1MB of a 50MB input, and
		-- we naively pass the entire remaining subview each time, we'd
		-- copy 49MB, 48MB, 47MB, etc, thus completely killing
		-- performance. To workaround this problem, we work in
		-- reasonable, fixed-size chunks. This results in a 10x
		-- improvement to bench_sendall.py, while having no measurable impact on
		-- CPython (since it doesn't copy at all the only extra overhead is
		-- a few python function calls, which is negligible for large inputs).

		-- See https://bitbucket.org/pypy/pypy/issues/2091/non-blocking-socketsend-slow-gevent

		-- Too small of a chunk (the socket's buf size is usually too
		-- small) results in reduced perf due to *too many* calls to send and too many
		-- small copies. With a buffer of 143K (the default on my system), for
		-- example, bench_sendall.py yields ~264MB/s, while using 1MB yields
		-- ~653MB/s (matching CPython). 1MB is arbitrary and might be better
		-- chosen, say, to match a page size?

		-- local chunk_size = math.max(self.getsockopt(SOL_SOCKET, SO_SNDBUF), 1024 * 1024)
		local chunk_size = 5 --1024 * 1024
		local data_sent = 0
		local fEnd = nil
		local timeleft = nil
		if self.timeout ~= nil then
			timeleft = self.timeout
			fEnd = os.time() + timeleft
		end

		while data_sent < len do
			local chunk_end = math.min(data_sent + chunk_size, len)
			local sChunk = string.sub(sData,data_sent + 1,chunk_end)

			timeleft = self:__send_chunk(sChunk, iFlags, timeleft, fEnd)
			data_sent = data_sent + #sChunk -- Guaranteed it sent the whole thing
		end
	end
	--[[
	function c.sendto(self, ...)
		local sock = self._sock
		try:
			return sock:sendto(...)
		except error as ex:
			if ex.args[0] != EWOULDBLOCK or self.timeout == 0.0:
				raise
			sys.exc_clear()
			self:_wait(self._write_event)
			try:
				return sock:sendto(...)
			except error as ex2:
				if ex2.args[0] == EWOULDBLOCK:
					return 0
				raise
	end
	--]]

	function c.setblocking(self, flag)
		assert(flag~=nil)
		if flag then
			self.timeout = nil
		else
			self.timeout = 0.0
		end
	end

	function c.settimeout(self, howlong)
		-- howlong可以为nil
		if howlong ~= nil then
			if type(howlong)~='number' then
				error('a float is required')
			end
			if howlong < 0.0 then
				error('Timeout value out of range')
			end
		end
		self.timeout=howlong
	end

	function c.gettimeout(self)
		return self.timeout
		-- return self.__dict__['timeout'] -- avoid recursion with any property on self.timeout
	end

	function c.shutdown(self, how)
		assert(how~=nil)
		if how == 'receive' then  -- 读
			self.hub:cancel_wait(self._read_event, cCancel_wait_ex)
		elseif how == 'send' then  -- 写
			self.hub:cancel_wait(self._write_event, cCancel_wait_ex)
		elseif how == 'both' then -- both
			self.hub:cancel_wait(self._read_event, cCancel_wait_ex)
			self.hub:cancel_wait(self._write_event, cCancel_wait_ex)
		else
			error('什么鬼')
		end
		self._sock:shutdown(how)
	end

	-- family = property(lambda self: self._sock.family)
	-- type = property(lambda self: self._sock.type)
	-- proto = property(lambda self: self._sock.proto)

	function c.fileno(self)
		return self._sock:fileno() --fileno()
	end

	function c.getsockname(self)
		return self._sock:getsockname()
	end

	function c.getpeername(self)
		return self._sock:getpeername()
	end
	-----------我手工加的----------
	function c.setsockopt(self, sOption, value)
		return self._sock:setsockopt(sOption, value)
	end

	function c.bind(self,address)
		return self._sock:bind(address)
	end

	function c.listen(self, backlog)
		return self._sock:listen(backlog)
	end

require('util')
require('except')
require('timeout')