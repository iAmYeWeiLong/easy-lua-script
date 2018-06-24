--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)

require('class')
local unpack=table.unpack or unpack  --各lua版本兼容

local cFakeTimer=class.create()
local c=cFakeTimer
	--c.pending=false
	--c.active = false
	function c.pending(self)
		return false
	end

	function c.isActive(self)
		return false
	end

	function c.start(self, ...)
		error("non-expiring timer cannot be started")
	end
	
	function c.stop(self)
	end

	function c.cancel(self)
	end

local _FakeTimer = cFakeTimer()
cFakeTimer=nil
--------------------------------------------------------------------------------
require('except')
Timeout=class.create(except.cException)--BaseException
local c=Timeout
	function c.__init__(self, seconds ,exception)
		except.cException.__init__(self)
		self.seconds = seconds --允许为nil
        self.exception = exception --允许为nil
		if seconds == nil then
			self.timer = _FakeTimer
		else
			self.timer = _elo_.HUB.oLoop:createTimer(seconds)
		end
	end

	function c.start(self)
		--Schedule the timeout.
		if self:pending() then
			error(string.format('%s is already started; to restart it, cancel it first', self))
		end
		if self.seconds == nil then
			return
		end
		
		local job=_eli_:getCurrent()
		local throw=util.bindMethod(job.throw,job) -- 'TIMEOUT'

		if self.exception == nil or self.exception == false or type(self.exception)=='string' then
			self.timer:start(throw, self)
		else
			self.timer:start(throw, self.exception)
		end
	end

	--类方法
	function c.start_new(cls, timeout, exception)
		--timeout 允许为nil
		--exception 允许为nil

		if timeout ~= nil and util.isInstance(timeout, Timeout) then
			if not timeout:pending() then
				timeout:start()
			end
			return timeout
		end
		local o = cls(timeout,exception)
		o:start()
		return o
	end

	--@property
	function c.pending(self)--Return True if the timeout is scheduled to be raised.		
		return self.timer:isActive() --self.timer.pending or 
	end

	function c.cancel(self)--If the timeout is pending, cancel it. Otherwise, do nothing.		
		self.timer:stop()
	end

	--[[
	function c.__repr__(self)
		classname = type(self).__name__
		if self:pending() then
			pending = ' pending'
		else
			pending = ''
		end

		if self.exception == nil then
			exception = ''
		else:
			exception = ' exception=%r' % self.exception
		end
		return string.format('<Timeout obj ,seconds=%s,pending=%s>', self.seconds, pending)
	end
	--]]

	function c.__tostring(self)
		if self.seconds == nil then
			return ''
		end
		local suffix
		if self.seconds == 1 then
			suffix = ''
		else
			suffix = 's'
		end

		if self.exception == nil then
			return string.format('%s second%s',self.seconds, suffix)
		end
		if self.exception == false then
			return string.format('%s second%s (silent)', self.seconds, suffix)
		end
		return string.format('%s second%s ' ,self.seconds, suffix, self.exception)--, self.exception
	end

	--[[
	function c.__enter__(self)
		if not self:pending() then
			self.start()
		end
		--return self
	end

	function c.__exit__(self, typ, value, tb)
		self.cancel()
		-- if value == self and self.exception == false then
		-- 	return True
		-- end
	end
	--]]

cInterface=class.create()
local c=cInterface

	--[[ 暂不实现
	function c.with_timeout(self,seconds, function, *args, **kwds)	
		timeout_value = kwds.pop("timeout_value", _NONE)
		timeout = Timeout.start_new(seconds)
		try:
			try:
				return function(*args, **kwds)
			except Timeout as ex:
				if ex is timeout and timeout_value is not _NONE:
					return timeout_value
				raise
		finally:
			timeout.cancel()
	end
	--]]
	
	function c._start_new_or_dummy(self,timeout, exception)
		-- timeout 允许为nil
		-- exception 可以为nil
		if timeout == nil then
			return _FakeTimer
		end
		return Timeout:start_new(timeout, exception)
	end

require('util')
require('except')