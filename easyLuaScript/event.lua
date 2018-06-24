--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)
require('class')
local unpack=table.unpack or unpack  --各lua版本兼容

local _AbstractLinkable=class.create()
local c=_AbstractLinkable
	-- Encapsulates the standard parts of the linking and notifying protocol
	-- common to both repeatable events and one-time events (AsyncResult).
	c._notifier = nil

	function c.__init__(self)
		-- Also previously, AsyncResult maintained the order of notifications, but Event
		-- did not; this implementation does not. (Event also only call callbacks one
		-- time (set), but AsyncResult permitted duplicates.)

		-- HOWEVER, gevent.queue.Queue does guarantee the order of getters relative
		-- to putters. Some existing documentation out on the net likes to refer to
		-- gevent as "deterministic", such that running the same program twice will
		-- produce results in the same order (so long as I/O isn't involved). This could
		-- be an argument to maintain order. (One easy way to do that while guaranteeing
		-- uniqueness would be with a 2.7+ OrderedDict.)
		self._links = {} --set()
		self.hub = _elo_.HUB -- get_hub()
	end

	function c.ready(self)
		error('NotImplementedError')
	end

	function c._check_and_notify(self)
		-- If this object is ready to be notified, begin the process.
		if self:ready() then
			if next(self._links)~=nil and not self._notifier~=nil then
				local mt=util.bindMethod(self._notify_links,self)
				self._notifier = self.hub.loop:run_callback(mt)
			end
		end
	end

	function c.rawlink(self, callback)
		--[[
		Register a callback to call when this object is ready.

		*callback* will be called in the :class:`Hub <gevent.hub.Hub>`, so it must not use blocking gevent API.
		*callback* will be passed one argument: this instance.
		]]
		if 'function' ~= type(callback) then
			error(string.format('Expected callable: %s' ,callback))
		end
		self._links[#self._links+1]=callback
		self:_check_and_notify()
	end

	function c.unlink(self, callback)
		-- Remove the callback set by :meth:`rawlink`
		-- try:
		-- 	self._links.remove(callback)
		-- except KeyError:
		-- 	pass
		assert(callback ~= nil)
		util.tryRemoveByValue(self._links,callback)	
	end

	function c._notify_links(self)
		-- Actually call the notification callbacks. Those callbacks in todo that are
		-- still in _links are called. This method is careful to avoid iterating
		-- over self._links, because links could be added or removed while this
		-- method runs. Only links present when this method begins running
		-- will be called; if a callback adds a new link, it will not run
		-- until the next time notify_links is activated

		-- We don't need to capture self._links as todo when establishing
		-- this callback; any links removed between now and then are handled
		-- by the `if` below; any links added are also grabbed
		-- todo = set(self._links)
		local todo = util.shallowCopy(self._links)
		for _,link in ipairs(todo) do
			-- check that link was not notified yet and was not removed by the client
			-- We have to do this here, and not as part of the 'for' statement because
			-- a previous link(self) call might have altered self._links
			if util.inList(link,self._links) then
				local ok,errStack=xpcall(function()
					link(self)
				end,except.errorHandler)

				if not ok then
					self.hub:handle_error(tostring(link)..tostring(self), errStack)
					--self.hub:handle_error((link, self), *sys.exc_info())
				end
				if util.getAttr(link, 'auto_unlink', nil) then
					-- This attribute can avoid having to keep a reference to the function
					-- *in* the function, which is a cycle
					self:unlink(link)
				end
			end
		end

		-- save a tiny bit of memory by letting _notifier be collected
		-- bool(self._notifier) would turn to false as soon as we exit this
		-- method anyway.
		todo = nil
		self._notifier = nil
	end

	function c._wait_core(self, fTimeout, catch)
		-- The core of the wait implementation, handling
		-- switching and linking. If *catch* is set to (),
		-- a timeout that elapses will be allowed to be raised.
		-- Returns a true value if the wait succeeded without timing out.

		--timeout可为nil
		if catch==nil then catch=timeout.Timeout end

		local cur=_eli_:getCurrent()
		local switch = util.bindMethod(cur.switch,cur)
		self:rawlink(switch)
		local ok,errStackOrVal=xpcall(function()
			local timer = _eli_:_start_new_or_dummy(fTimeout)

			local ok,errStackOrVal=xpcall(function()
				local ok,errStackOrVal=xpcall(function()
					--assert(_elo_.HUB:status()~='dead')--ywl
					local result = self.hub:switch()
					--assert(_elo_.HUB:status()~='dead')--ywl
					if result ~= self then -- pragma: no cover
						error(string.format('Invalid switch into Event.wait(): %s',result))  --InvalidSwitchError
					end
					return true
				end,except.errorHandler)
				if not ok then
					if class.isInstance(errStackOrVal.oError,catch) then
						if errStackOrVal.oError ~= timer then
							error(errStackOrVal)
						end
						-- test_set_and_clear and test_timeout in test_threading
						-- rely on the exact return values, not just truthish-ness
						return false
					end
					error(errStackOrVal)
				end
				return errStackOrVal
			end,except.errorHandler)
			timer:cancel()
			assert(ok,errStackOrVal)
			return errStackOrVal

		end,except.errorHandler)
		self:unlink(switch)
		assert(ok,errStackOrVal)
		return errStackOrVal

	end

	function c._wait_return_value(self, waited, wait_success)
		return nil
	end

	function c._wait(self, timeout)
		--timeout可为nil
		if self:ready() then
			return self:_wait_return_value(false, false)
		end
		local gotit = self:_wait_core(timeout)
		return self:_wait_return_value(true, gotit)
	end


Event=class.create(_AbstractLinkable)
local c=Event
	--[[ A synchronization primitive that allows one greenlet to wake up one or more others.
	It has the same interface as :class:`threading.Event` but works across greenlets.

	An event object manages an internal flag that can be set to true with the
	:meth:`set` method and reset to false with the :meth:`clear` method. The :meth:`wait` method
	blocks until the flag is true.

	.. note::
		The order and timing in which waiting greenlets are awakened is not determined.
		As an implementation note, in gevent 1.1 and 1.0, waiting greenlets are awakened in a
		undetermined order sometime *after* the current greenlet yields to the event loop. Other greenlets
		(those not waiting to be awakened) may run between the current greenlet yielding and
		the waiting greenlets being awakened. These details may change in the future.
	]]

	c._flag = false

	-- function c.__string(self)
	-- 	return '<%s %s _links[%s]>' % (self.__class__.__name__, (self._flag and 'set') or 'clear', len(self._links))
	-- end	

	function c.is_set(self)
		-- Return true if and only if the internal flag is true.
		return self._flag
	end

	c.isSet = c.is_set  -- makes it a better drop-in replacement for threading.Event
	c.ready = c.is_set  -- override,makes it compatible with AsyncResult and Greenlet (for example in wait())

	function c.set(self)
		--[[
		Set the internal flag to true.

		All greenlets waiting for it to become true are awakened in
		some order at some time in the future. Greenlets that call
		:meth:`wait` once the flag is true will not block at all
		(until :meth:`clear` is called).
		]]
		self._flag = true
		self:_check_and_notify()
	end

	function c.clear(self)
		--[[
		Reset the internal flag to false.

		Subsequently, threads calling :meth:`wait` will block until
		:meth:`set` is called to set the internal flag to true again.
		]]
		self._flag = false
	end

	function c._wait_return_value(self, waited, wait_success) -- override
		-- To avoid the race condition outlined in http://bugs.python.org/issue13502,
		-- if we had to wait, then we need to return whether or not
		-- the condition got changed. Otherwise we simply echo
		-- the current state of the flag (which should be true)

		assert(waited ~= nil)
		assert(wait_success ~= nil)
		if not waited then
			flag = self._flag
			if not flag then
				error("if we didn't wait we should already be set")
			end
			return flag
		end
		return wait_success
	end

	function c.wait(self, timeout)
		-- timeout 可以为nil
		--[[
		Block until the internal flag is true.

		If the internal flag is true on entry, return immediately. Otherwise,
		block until another thread (greenlet) calls :meth:`set` to set the flag to true,
		or until the optional timeout occurs.

		When the *timeout* argument is present and not ``nil``, it should be a
		floating point number specifying a timeout for the operation in seconds
		(or fractions thereof).

		:return: This method returns true if and only if the internal flag has been set to
			true, either before the wait call or after the wait starts, so it will
			always return ``true`` except if a timeout is given and the operation
			times out.

		.. versionchanged:: 1.1
			The return value represents the flag during the elapsed wait, not
			just after it elapses. This solves a race condition if one greenlet
			sets and then clears the flag without switching, while other greenlets
			are waiting. When the waiters wake up, this will return true; previously,
			they would still wake up, but the return value would be false. This is most
			noticeable when the *timeout* is present.
		]]
		return self:_wait(timeout)
	end

	function c._reset_internal_locks(self) -- pragma: no cover
		-- for compatibility with threading.Event (only in case of patch_all(Event=true), by default Event is not patched)
		--  Exception AttributeError: AttributeError("'Event' object has no attribute '_reset_internal_locks'",)
		-- in <module 'threading' from '/usr/lib/python2.7/threading.pyc'> ignored
	end
---------------------------------------------------------------
--[==[
AsyncResult=class.create(_AbstractLinkable)
local c = AsyncResult
	--[[ A one-time event that stores a value or an exception.

	Like :class:`Event` it wakes up all the waiters when :meth:`set` or :meth:`set_exception`
	is called. Waiters may receive the passed value or exception by calling :meth:`get`
	instead of :meth:`wait`. An :class:`AsyncResult` instance cannot be reset.

	To pass a value call :meth:`set`. Calls to :meth:`get` (those that are currently blocking as well as
	those made in the future) will return the value:

		>>> result = AsyncResult()
		>>> result.set(100)
		>>> result.get()
		100

	To pass an exception call :meth:`set_exception`. This will cause :meth:`get` to raise that exception:

		>>> result = AsyncResult()
		>>> result.set_exception(RuntimeError('failure'))
		>>> result.get()
		Traceback (most recent call last):
		 ...
		RuntimeError: failure

	:class:`AsyncResult` implements :meth:`__call__` and thus can be used as :meth:`link` target:

		>>> import gevent
		>>> result = AsyncResult()
		>>> gevent.spawn(lambda : 1/0).link(result)
		>>> try:
		...	 result.get()
		... except ZeroDivisionError:
		...	 print('ZeroDivisionError')
		ZeroDivisionError

	.. note::
		The order and timing in which waiting greenlets are awakened is not determined.
		As an implementation note, in gevent 1.1 and 1.0, waiting greenlets are awakened in a
		undetermined order sometime *after* the current greenlet yields to the event loop. Other greenlets
		(those not waiting to be awakened) may run between the current greenlet yielding and
		the waiting greenlets being awakened. These details may change in the future.

	.. versionchanged:: 1.1
	   The exact order in which waiting greenlets are awakened is not the same
	   as in 1.0.
	.. versionchanged:: 1.1
	   Callbacks :meth:`linked <rawlink>` to this object are required to be hashable, and duplicates are
	   merged.
	]]

	c._value = _NONE
	c._exc_info = ()
	c._notifier = nil

	--@property
	function c._exception(self)
		return self._exc_info[1] if self._exc_info else _NONE
	end

	--@property
	function c.value(self)
		--[[
		Holds the value passed to :meth:`set` if :meth:`set` was called. Otherwise,
		``nil``
		]]
		if self._value is not _NONE
			return self._value  
		else 
			return nil
		end
	end

	--@property
	function c.exc_info(self)		
		-- The three-tuple of exception information if :meth:`set_exception` was called.
		
		if self._exc_info then
			return (self._exc_info[0], self._exc_info[1], load_traceback(self._exc_info[2]))
		end
		return ()
	end

	--[[
	function c.__string(self)
		result = '<%s ' % (self.__class__.__name__, )
		if self.value is not nil or self._exception is not _NONE:
			result += 'value=%r ' % self.value
		if self._exception is not nil and self._exception is not _NONE:
			result += 'exception=%r ' % self._exception
		if self._exception is _NONE:
			result += 'unset '
		return result + ' _links[%s]>' % len(self._links)
	end
	--]]

	function c.ready(self)
		-- Return true if and only if it holds a value or an exception
		return self._exc_info or self._value is not _NONE
	end

	function c.successful(self)
		-- Return true if and only if it is ready and holds a value
		return self._value is not _NONE
	end

	--@property
	function c.exception(self)
		--[[ Holds the exception instance passed to :meth:`set_exception` if :meth:`set_exception` was called.
		Otherwise ``nil``.]]
		if self._exc_info then
			return self._exc_info[1]
		end
	end

	function c.set(self, value=nil)
		--[[ Store the value and wake up any waiters.

		All greenlets blocking on :meth:`get` or :meth:`wait` are awakened.
		Subsequent calls to :meth:`wait` and :meth:`get` will not block at all.
		]]
		self._value = value
		self:_check_and_notify()
	end

	function c.set_exception(self, exception, exc_info=nil)
		--[[Store the exception and wake up any waiters.

		All greenlets blocking on :meth:`get` or :meth:`wait` are awakened.
		Subsequent calls to :meth:`wait` and :meth:`get` will not block at all.

		:keyword tuple exc_info: If given, a standard three-tuple of type, value, :class:`traceback`
			as returned by :func:`sys.exc_info`. This will be used when the exception
			is re-raised to propagate the correct traceback.
		]]
		if exc_info then
			self._exc_info = (exc_info[0], exc_info[1], dump_traceback(exc_info[2]))
		else
			self._exc_info = (type(exception), exception, dump_traceback(nil))
		end

		self:_check_and_notify()
	end

	function c._raise_exception(self)
		reraise(*self.exc_info)
	end

	function c.get(self, block=true, timeout=nil)
		--[[ Return the stored value or raise the exception.

		If this instance already holds a value or an exception, return  or raise it immediatelly.
		Otherwise, block until another greenlet calls :meth:`set` or :meth:`set_exception` or
		until the optional timeout occurs.

		When the *timeout* argument is present and not ``nil``, it should be a
		floating point number specifying a timeout for the operation in seconds
		(or fractions thereof). If the *timeout* elapses, the *Timeout* exception will
		be raised.

		:keyword bool block: If set to ``false`` and this instance is not ready,
			immediately raise a :class:`Timeout` exception.
		]]
		if self._value is not _NONE then
			return self._value
		end
		if self._exc_info then
			return self._raise_exception()
		end

		if not block then
			-- Not ready and not blocking, so immediately timeout
			raise Timeout()
		end

		-- Wait, raising a timeout that elapses
		self._wait_core(timeout, ())

		-- by definition we are now ready
		return self.get(block=false)
	end

	function c.get_nowait(self)
		--[[
		Return the value or raise the exception without blocking.

		If this object is not yet :meth:`ready <ready>`, raise
		:class:`gevent.Timeout` immediately.
		]]
		return self.get(block=false)
	end

	function c._wait_return_value(self, waited, wait_success)
		-- pylint:disable=unused-argument
		-- Always return the value. Since this is a one-shot event,
		-- no race condition should reset it.
		return self.value
	end

	function c.wait(self, timeout=nil)
		--[[Block until the instance is ready.

		If this instance already holds a value, it is returned immediately. If this
		instance already holds an exception, ``nil`` is returned immediately.

		Otherwise, block until another greenlet calls :meth:`set` or :meth:`set_exception`
		(at which point either the value or ``nil`` will be returned, respectively),
		or until the optional timeout expires (at which point ``nil`` will also be
		returned).

		When the *timeout* argument is present and not ``nil``, it should be a
		floating point number specifying a timeout for the operation in seconds
		(or fractions thereof).

		.. note:: If a timeout is given and expires, ``nil`` will be returned
			(no timeout exception will be raised).

		]]
		return self._wait(timeout)
	end

	-- link protocol
	function c.__call__(self, source)
		if source:successful() then
			self:set(source.value)
		else
			self:set_exception(source.exception, getattr(source, 'exc_info', nil))
		end
	end

	-- Methods to make us more like concurrent.futures.Future

	function c.result(self, timeout=nil)
		return self.get(timeout=timeout)
	end

	set_result = set

	function c.done(self)
		return self:ready()
	end

	-- we don't support cancelling
	function c.cancel(self)
		return false
	end

	function c.cancelled(self)
		return false
	end

	-- exception is a method, we use it as a property
]==]	

require('util')
require('timeout')