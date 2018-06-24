--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)

require('class')
require('baseServer')
local unpack=table.unpack or unpack  --各lua版本兼容
local EWOULDBLOCK = 10035 --"Resource temporarily unavailable"
local AF_INET,AF_INET6=2,23
local _tcp_listener

cStreamServer=class.create(baseServer.cBaseServer)
local c=cStreamServer

	c.backlog = 256
	c.reuse_addr = nil --DEFAULT_REUSE_ADDR 稍后处理

	function c.__init__(self, listener, handle, backlog, spawn, dSslArgs)
		assert(listener ~= nil)
		-- handle可为nil
		-- backlog可为nil
		if spawn == nil then spawn = 'default' end
		-- dSslArgs可为nil
		
		baseServer.cBaseServer.__init__(self, listener, handle, spawn)
		local ok,errStack=xpcall(function()
			if dSslArgs ~= nil then
				util.setDefault(dSslArgs,'server_side', true)
				if dSslArgs.ssl_context ~= nil then
					local ssl_context = dSslArgs.ssl_context
					dSslArgs.ssl_context = nil
					self.wrap_socket = ssl_context.wrap_socket
					self.dSslArgs = dSslArgs
				else
					--from gevent.ssl import wrap_socket
					self.wrap_socket = wrap_socket
					self.dSslArgs = dSslArgs
				end
			else
				self.dSslArgs = nil
			end
			if backlog ~= nil then
				if util.hasAttr(self, 'socket') then
					error('backlog must be nil when a socket instance is passed')
				end
				self.backlog = backlog
			end
		end,except.errorHandler)
		if not ok then
			self:close()
			error(errStack)
		end
	end

	--@property
	function c.ssl_enabled(self)
		return self.dSslArgs ~= nil
	end

	--[[暂不支持listener是socket的情况
	function c.set_listener(self, listener)--override
		baseServer.cBaseServer.set_listener(self, listener)
		try:
			self.socket = self.socket._sock
		except AttributeError:
			pass
	end
	--]]

	function c.init_socket(self)--implements
		if not util.hasAttr(self, 'socket') then
			-- FIXME: clean up the socket lifetime
			self.socket = self.__class__:get_listener(self.address, self.backlog, self.family)
			self.address = self.socket:getsockname()
		end
		if self.dSslArgs ~= nil then
			self._handle = util.bindMethod(self.wrap_socket_and_handle,self)
		else
			self._handle = self.handle
		end
	end

	--classmethod
	function c.get_listener(cls, address, backlog, family)
		if backlog == nil then backlog = cls.backlog end
		return _tcp_listener(address, backlog, cls.reuse_addr, family)
	end
	
	function c.do_read(self) -- implements
		local oClientSocket, address

		local ok,errStack=xpcall(function()
			--print('server.11111111111 begin accept')
			oClientSocket, address = self.socket:accept()
			--print('server.22222222222 ok,ok accept')
			--print('do_read..oClientSocket, address==',oClientSocket, address)
		end,except.errorHandler)

		if not ok then
			--print('server.333333333...excep ,errStack.oError=',errStack.oError)
			if class.isInstance(errStack.oError,except.cSocketError) and errStack.oError.iCode == EWOULDBLOCK then
				return nil,nil
			end
			error(errStack)
		end
		--这里与gevent不同,不再包装多一次.没有这个必要
		-- local sockobj = socket.cSocket(nil,nil,nil,oClientSocket)
		return oClientSocket, address
	end

	function c.do_close(self, sock, ...)
		assert(sock ~= nil)
		sock:close()
	end

	function c.wrap_socket_and_handle(self, oClientSocket, address)
		-- used in case of ssl sockets
		local ssl_socket = self.wrap_socket(oClientSocket, self.dSslArgs)
		return self:handle(ssl_socket, address)
	end


function _tcp_listener(address, backlog, reuse_addr, family) -- local
	--A shortcut to create a TCP socket, bind it and put it into listening state.
	if backlog==nil then backlog=50 end
	if family==nil then family=AF_INET end
	--reuse_addr允许为nil
	local sHost,iPort = address[1],address[2]
	local sock = socket.cSocket(family) --这个不能定制,要改
	if reuse_addr ~= nil then
		sock:setsockopt('reuseaddr')
	end
	local ok,errStack=xpcall(function()
		sock:bind(address)
	end,except.errorHandler)

	if not ok then
		errStack:attachMsg(string.format('host:%s,port:%s',sHost,iPort))
		error(errStack)
	end
	sock:listen(backlog)
	sock:setblocking(false)  --gevent是设0
	return sock
end

require('util')
require('except')
require('socket')