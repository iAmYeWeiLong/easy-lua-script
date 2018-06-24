--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)

require('class')
local unpack = table.unpack or unpack  --各lua版本兼容

local cEmpty = class.create()
	function cEmpty.__tostring(self)
		return '<EMPTY>'
	end

local EMPTY = cEmpty()
cEmpty = nil

cWaiter = class.create()
local c = cWaiter
	function c.__init__(self, hub)
		if hub == nil then
			self.hub = _elo_.HUB
		else
			self.hub = hub
		end
		self.greenlet = nil
		self.value = nil
		self._exception = EMPTY
	end

	function c.clear(self)
		self.greenlet = nil
		self.value = nil
		self._exception = EMPTY
	end

	function c.__tostring(self) --元方法
		-- if self._exception is EMPTY then
		-- 	return '<%s greenlet=%s>' % (type(self).__name__, self.greenlet)
		-- else if self._exception is nil then
		-- 	return '<%s greenlet=%s value=%r>' % (type(self).__name__, self.greenlet, self.value)
		-- else
		-- 	return '<%s greenlet=%s exc_info=%r>' % (type(self).__name__, self.greenlet, self.exc_info)
		-- end
		return '<cWaiter instance>'
	end

	function c.ready(self)
		--Return true if and only if it holds a value or an exception--
		return self._exception ~= EMPTY
	end

	function c.successful(self)
		--Return true if and only if it is ready and holds a value--
		return self._exception == nil
	end
	
	function c.exc_info(self)
		--"Holds the exception info passed to :meth:`throw` if :meth:`throw` was called. Otherwise ``nil``."
		if self._exception ~= EMPTY then
			return self._exception
		end
	end

	function c.switch(self, value)
		--Switch to the greenlet if one's available. Otherwise store the value.--
		local greenlet = self.greenlet
		if greenlet == nil then
			self.value = value
			self._exception = nil
		else
			if _eli_:getCurrent() ~= self.hub then
				error("Can only use Waiter.switch method from the Hub greenlet")
			end
			local switch = greenlet.switch

			--实现try except语义
			local ok,errStack = xpcall(function()
				switch(greenlet,value)
			end,except.errorHandler)

			if not ok then--
				self.hub:handle_error(switch, errStack)
			end
		end
	end

	function c.switch_args(self,...)
		local lArgs = {...}
		return self:switch(lArgs)
	end

	function c.throw(self,...) --*throw_args
		local throw_args={...}
		--Switch to the greenlet with the exception. If there's no greenlet, store the exception.--
		local greenlet = self.greenlet
		if greenlet == nil then
			self._exception = throw_args
		else
			if _eli_:getCurrent() ~= self.hub then
				error("Can only use Waiter.switch method from the Hub greenlet")
			end
			local throw = util.bindMethod(greenlet.throw,self)
			--实现try except语义
			local ok,errStack=xpcall(function()
				throw(unpack(throw_args))
			end,except.errorHandler)

			if not ok then--
				self.hub:handle_error(throw, errStack)
			end
		end
	end

	function c.get(self)
		--If a value/an exception is stored, return/raise it. Otherwise until switch() or throw() is called.--
		assert(_eli_:getCurrent() ~= self.hub) --ywl
		if self._exception ~= EMPTY then
			if self._exception == nil then
				return self.value
			else
				_eli_:getCurrent():throw(unpack(self._exception))
			end
		else
			if self.greenlet ~= nil then
				error(string.format('This Waiter is already used by %s',tostring(self.greenlet)))
			end
			self.greenlet = _eli_:getCurrent()

			--实现try finally语义
			local ok,errStackOrVal=xpcall(function()
				return self.hub:switch()
			end,except.errorHandler)

			self.greenlet = nil
			assert(ok,errStackOrVal)
			return errStackOrVal
		end
	end

	function c.__call(self, source) --元方法
		if source.exception==nil then
			self:switch(source.value)
		else
			self:throw(source.exception)
		end
	end

require('util')
require('except')