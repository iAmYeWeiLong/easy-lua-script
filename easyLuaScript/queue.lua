--[[    作者:叶伟龙@龙川县赤光镇
        各种队列
--]]
_ENV=require('base').module(...)
require('class')
-- require('reflection')
-- require('routineHub')
-- require('timeout')

-- Copyright (c) 2009-2012 Denis Bilenko. See LICENSE for details.
--[[Synchronized queues.

The :mod:`gevent.queue` module implements multi-producer, multi-consumer queues
that work across greenlets, with the API similar to the classes found in the
standard :mod:`Queue` and :class:`multiprocessing <multiprocessing.Queue>` modules.

The classes in this module implement iterator protocol. Iterating over queue
means repeatedly calling :meth:`get <Queue.get>` until :meth:`get <Queue.get>` returns ``StopIteration``.

	>>> queue = gevent.queue.Queue()
	>>> queue.put(1)
	>>> queue.put(2)
	>>> queue.put(StopIteration)
	>>> for item in queue:
	...	print(item)
	1
	2

.. versionchanged:: 1.0
	   ``Queue(0)`` now means queue of infinite size, not a channel. A :exc:`DeprecationWarning`
	   will be issued with this argument.
]]

-- from __future__ import absolute_import
-- import sys
-- import heapq
-- import collections

-- if sys.version_info[0] == 2:
--	 import Queue as __queue__
-- else:
--	 import queue as __queue__ -- python 2: pylint:disable=import-error
-- Full = __queue__.Full
-- Empty = __queue__.Empty

-- from gevent.timeout import Timeout
-- from gevent.hub import get_hub, Waiter, getcurrent
-- from gevent.hub import InvalidSwitchError


--__all__ = ['Queue', 'PriorityQueue', 'LifoQueue', 'JoinableQueue', 'Channel']


local function _safe_remove(deq, item)
	-- For when the item may have been removed by
	-- Queue._unlock
    for i = 1,#deq do
        if dep[i] == item then
            table.remove(deq,i)
            return
        end
    end    
	-- try:
	-- 	deq.remove(item)
	-- except ValueError:
	-- 	pass
end

Queue = class.create()
local c = Queue
	--[[
	Create a queue object with a given maximum size.

	If *maxsize* is less than or equal to zero or ``nil``, the queue
	size is infinite.

	.. versionchanged:: 1.1b3
	   Queues now support :func:`len`; it behaves the same as :meth:`qsize`.
	.. versionchanged:: 1.1b3
	   Multiple greenlets that block on a call to :meth:`put` for a full queue
	   will now be woken up to put their items into the queue in the order in which
	   they arrived. Likewise, multiple greenlets that block on a call to :meth:`get` for
	   an empty queue will now receive items in the order in which they blocked. An
	   implementation quirk under CPython *usually* ensured this was roughly the case
	   previously anyway, but that wasn't the case for PyPy.
	]]

	function c.__init__(self, maxsize, items)
        assert(maxsize ~= nil)
		-- maxsize, items允许为nil
		if maxsize ~= nil and maxsize <= 0 then
			self.maxsize = nil
			if maxsize == 0 then
				-- import warnings
				-- warnings.warn('Queue(0) now equivalent to Queue(nil); if you want a channel, use Channel',
				-- 			  DeprecationWarning, stacklevel=2)
			end
		else
			self.maxsize = maxsize
		end
		-- Explicitly maintain order for getters and putters that block
		-- so that callers can consistently rely on getting things out
		-- in the apparent order they went in. This was once required by
		-- imap_unordered. Previously these were set() objects, and the
		-- items put in the set have default hash() and eq() methods;
		-- under CPython, since new objects tend to have increasing
		-- hash values, this tended to roughly maintain order anyway,
		-- but that's not true under PyPy. An alternative to a deque
		-- (to avoid the linear scan of remove()) might be an
		-- OrderedDict, but it's 2.7 only; we don't expect to have so
		-- many waiters that removing an arbitrary element is a
		-- bottleneck, though.
		self.getters = {} --collections.deque()
		self.putters = {} --collections.deque()
		self.hub = _elo_.HUB
		self._event_unlock = nil
		if items ~= nil then
			self:_init(maxsize, items)
		else
			self:_init(maxsize)
		end
	end
	-- QQQ make maxsize into a property with setter that schedules unlock if necessary

	-- function c.copy(self)
	-- 	return type(self)(self.maxsize, self.queue)
	-- end

	function c._init(self, maxsize, items)
        assert(maxsize ~= nil)
        -- items可为nil
		-- FIXME: Why is maxsize unused or even passed?
		-- pylint:disable=unused-argument
		if items ~= nil then
			self.queue = items --collections.deque(items)
		else
			self.queue = {} --collections.deque()
		end
	end

	function c._get(self)
		return table.remove(self.queue, 1) --.popleft()
	end

	function c._peek(self)
		return self.queue[1]
	end

	function c._put(self, item)
		table.insert(self.queue, item)
	end

	-- function c.__repr__(self)
	-- 	return '<%s at %s%s>' % (type(self).__name__, hex(id(self)), self:_format())
	-- end

	function c.__str__(self)
        -- return '<%s%s>' % (type(self).__name__, self:_format())
		return string.format('<%s%s>', type(self), self:_format())
	end

	function c._format(self)
		local result = {}
		if self.maxsize ~= nil then
			table.insert(result, string.format('maxsize=%s' ,self.maxsize))  --%r
		end
		if util.getAttr(self, 'queue') ~= nil then
			table.insert(result, string.format('queue=%s',self.queue)) -- %r
		end
		if #self.getters ~= 0 then
			table.insert(result, string.format('getters[%s]' , #self.getters))
		end
		if #self.putters ~= 0 then
			table.insert(result, string.format('putters[%s]' , #self.putters))
		end
		if #result ~= 0 then
			return ' ' + table.concat(result, ' ')
		end
		return ''
	end

	function c.qsize(self)
		-- Return the size of the queue.
		return #self.queue
	end
    
    --[=[
	function c.__len__(self)
		--[[
		Return the size of the queue. This is the same as :meth:`qsize`.

		.. versionadded: 1.1b3

			Previously, getting len() of a queue would raise a TypeError.
		]]

		return self:qsize()
	end
    ]=]

    --[=[
	function c.__bool__(self)
		--[[
		A queue object is always true.

		.. versionadded: 1.1b3

		   Now that queues support len(), they need to implement ``__bool__``
		   to return true for backwards compatibility.
		]]
		return true
	end
    ]=]
	-- __nonzero__ = __bool__

	function c.empty(self)
		--- Return ``true`` if the queue is empty, ``false`` otherwise.
		return 0 == self:qsize()
	end

	function c.full(self)
		--[[Return ``true`` if the queue is full, ``false`` otherwise.

		``Queue(nil)`` is never full.
		]]
		return self.maxsize ~= nil and self:qsize() >= self.maxsize
	end

	function c.put(self, item, block, timeout)
        assert(item ~= nil)
		if block == nil then block = true end
		-- timeout允许为nil
		
		--[[Put an item into the queue.

		If optional arg *block* is true and *timeout* is ``nil`` (the default),
		block if necessary until a free slot is available. If *timeout* is
		a positive number, it blocks at most *timeout* seconds and raises
		the :class:`Full` exception if no free slot was available within that time.
		Otherwise (*block* is false), put an item on the queue if a free slot
		is immediately available, else raise the :class:`Full` exception (*timeout*
		is ignored in that case).
		]]
		if self.maxsize == nil or self:qsize() < self.maxsize then
			-- there's a free slot, put an item right away
			self:_put(item)
			if #self.getters ~= 0 then
				self:_schedule_unlock()
			end
		elseif self.hub == _eli_:getCurrent() then
			-- We're in the mainloop, so we cannot wait; we can switch to other greenlets though.
			-- Check if possible to get a free slot in the queue.
			while #self.getters ~= 0 and self:qsize() and self:qsize() >= self.maxsize do
				local getter = table.remove(self.getters, 1) --.popleft()
				getter:switch(getter)
			end
			if self:qsize() < self.maxsize then
				self:_put(item)
				return
			end
			error('full') --raise Full
		elseif block then
			local waiter = ItemWaiter(item, self)
			table.insert(self.putters,waiter) --.append(waiter)
			local timeout = _eli_:_start_new_or_dummy(timeout) --, Full
			local ok,errStack=xpcall(function()
				if #self.getters ~= 0 then
					self:_schedule_unlock()
				end
				local result = waiter:get()
				if result ~= waiter then
					error(string.format("Invalid switch into Queue.put: %s" ,result)) --raise InvalidSwitchError
				end
			end,except.errorHandler)
			timeout:cancel()
			_safe_remove(self.putters, waiter)
            assert(ok, errStack)
		else
			error('full') --raise Full
		end
	end

	function c.put_nowait(self, item)
        assert(item ~= nil)
		--[[Put an item into the queue without blocking.

		Only enqueue the item if a free slot is immediately available.
		Otherwise raise the :class:`Full` exception.
		]]
		self:put(item, false)
	end

	function c.__get_or_peek(self, method, block, timeout)
        assert(method ~= nil)
        assert(block ~= nil)
        assert(timeout ~= nil)
		-- Internal helper method. The `method` should be either
		-- self._get when called from self.get() or self._peek when
		-- called from self.peek(). Call this after the initial check
		-- to see if there are items in the queue.

		if self.hub == _eli_:getCurrent() then
			-- special case to make get_nowait() or peek_nowait() runnable in the mainloop greenlet
			-- there are no items in the queue; try to fix the situation by unlocking putters
			while #self.putters ~= 0 do
				-- Note: get() used popleft(), peek used pop(); popleft
				-- is almost certainly correct.
				table.remove(self.putters, 1):put_and_switch() -- popleft
				if self:qsize() then
					return method()
				end
			end
			error('empty') --raise Empty()

		if not block then
			-- We can't block, we're not the hub, and we have nothing
			-- to return. No choice...
			error('empty') --raise Empty()
		end

		local waiter = Waiter()
		timeout = _eli_:start_new_or_dummy(timeout) --, Empty
		local ok, errStack = xpcall(function ()
			table.insert(self.getters, waiter) --:append(waiter)
			if #self.putters ~= 0 then
				self:_schedule_unlock()
			end
			local result = waiter:get()
			if result ~= waiter then
				error(string.format('Invalid switch into Queue.get: %s', result))  -- %r raise InvalidSwitchError
			end
			return method()
        end,except.errorHandler)
		
		timeout:cancel()
		_safe_remove(self.getters, waiter)
        assert(ok ,errStack)
	end

	function c.get(self, block, timeout)
        if block == nil then block = true end
        -- timeout可为nil

		--[[Remove and return an item from the queue.

		If optional args *block* is true and *timeout* is ``nil`` (the default),
		block if necessary until an item is available. If *timeout* is a positive number,
		it blocks at most *timeout* seconds and raises the :class:`Empty` exception
		if no item was available within that time. Otherwise (*block* is false), return
		an item if one is immediately available, else raise the :class:`Empty` exception
		(*timeout* is ignored in that case).
		]]
		if self:qsize() then
			if #self.putters ~= 0 then
				self:_schedule_unlock()
			end
			return self:_get()
		end

		return self:__get_or_peek(self._get, block, timeout)
	end

	function c.get_nowait(self)
		--[[Remove and return an item from the queue without blocking.

		Only get an item if one is immediately available. Otherwise
		raise the :class:`Empty` exception.
		]]
		return self:get(false)
	end

	function c.peek(self, block, timeout)
        if block == nil then block = true end
        -- timeout可为nil

		--[[Return an item from the queue without removing it.

		If optional args *block* is true and *timeout* is ``nil`` (the default),
		block if necessary until an item is available. If *timeout* is a positive number,
		it blocks at most *timeout* seconds and raises the :class:`Empty` exception
		if no item was available within that time. Otherwise (*block* is false), return
		an item if one is immediately available, else raise the :class:`Empty` exception
		(*timeout* is ignored in that case).
		]]
		if self:qsize() then
			-- XXX: Why doesn't this schedule an unlock like get() does?
			return self:_peek()
		end

		return self:__get_or_peek(self._peek, block, timeout)
	end

	function c.peek_nowait(self)
		--[[Return an item from the queue without blocking.

		Only return an item if one is immediately available. Otherwise
		raise the :class:`Empty` exception.
		]]
		return self:peek(false)
	end

	function c._unlock(self)
		while true do
			local bRepeat = false
			if #self.putters ~= 0 and (self.maxsize == nil or self:qsize() < self.maxsize) then
				bRepeat = true
                local putter
				local ok ,errStack = xpcall(function()
					putter = table.remove(self.putters, 1) --:popleft()
					self:_put(putter.item)
				end, except.errorHandler)
                if not ok then
					putter:throw(errStack.oError, errStack.sStack) -- *sys.exc_info()
				else
					putter:switch(putter)
				end
            end
			if #self.getters ~= 0 and self:qsize() then
				bRepeat = true
				local getter = table.remove(self.getters, 1) --:popleft()
				getter.switch(getter)
			end
			if not bRepeat then
				return
			end
		end -- while
	end

	function c._schedule_unlock(self)
		if self._event_unlock == nil then
			self._event_unlock = self.hub.oLoop:run_callback(self._unlock)
		end
	end

	-- function c.__iter__(self)
	-- 	return self
	-- end

	-- function c.next(self)
	-- 	local result = self:get()
	-- 	if result == StopIteration then
	-- 		raise result
	-- 	end
	-- 	return result
	-- end

	-- __next__ = next


require('waiter')
ItemWaiter = class.create(waiter.cWaiter)
local c = ItemWaiter
	-- __slots__ = ['item', 'queue']

	function c.__init__(self, item, queue)
        assert(item ~= nil)
        assert(queue ~= nil)
		waiter.cWaiter.__init__(self)
		self.item = item
		self.queue = queue
	end

	function c.put_and_switch(self)
		self.queue:_put(self.item)
		self.queue = nil
		self.item = nil
		return self:switch(self)
	end

--[===[
PriorityQueue = class.create(Queue)
local c = PriorityQueue
	--[[A subclass of :class:`Queue` that retrieves entries in priority order (lowest first).

	Entries are typically tuples of the form: ``(priority number, data)``.

	.. versionchanged:: 1.2a1
	   Any *items* given to the constructor will now be passed through
	   :func:`heapq.heapify` to ensure the invariants of this class hold.
	   Previously it was just assumed that they were already a heap.
	]]

	function c._init(self, maxsize, items)
        assert(maxsize ~= nil)
        -- items可为nil
		if items then
			self.queue = list(items)
			heapq.heapify(self.queue)
		else
			self.queue = []
		end
	end

	function c._put(self, item, heappush)
        assert(item ~= nil)
        if heappush == nil then heappush = heapq.heappush end
		-- pylint:disable=arguments-differ
		heappush(self.queue, item)
	end

	function c._get(self, heappop)
        if heappop == nil then heappop = heapq.heappop end

		-- pylint:disable=arguments-differ
		return heappop(self.queue)
	end
]===]


--[==[
LifoQueue = class.create(Queue)
local c = LifoQueue
	-- A subclass of :class:`Queue` that retrieves most recently added entries first.

	function c._init(self, maxsize, items)
        assert(maxsize ~= nil)
        -- items可为nil
		if items then
			self.queue = list(items)
		else
			self.queue = []
		end
	end

	function c._put(self, item)
		self.queue.append(item)
	end

	function c._get(self)
		return self.queue.pop()
	end

	function c._peek(self)
		return self.queue[-1]
	end
]==]


--[====[
JoinableQueue = class.create(Queue)
local c= JoinableQueue
	--[[
	A subclass of :class:`Queue` that additionally has
	:meth:`task_done` and :meth:`join` methods.
	]]

	function c.__init__(self, maxsize, items, unfinished_tasks)
        assert(maxsize ~= nil)
        assert(items ~= nil)
        assert(unfinished_tasks ~= nil)
        -- maxsize, items, unfinished_tasks 皆可为nil
		--[[

		.. versionchanged:: 1.1a1
		   If *unfinished_tasks* is not given, then all the given *items*
		   (if any) will be considered unfinished.

		]]
		-- from gevent.event import Event
		Queue.__init__(self, maxsize, items)
		self._cond = Event()
		self._cond:set()

		if unfinished_tasks then
			self.unfinished_tasks = unfinished_tasks
		elseif items then
			self.unfinished_tasks = #items
		else
			self.unfinished_tasks = 0
		end

		if self.unfinished_tasks then
			self._cond.clear()
		end
	end

	function c.copy(self)
		return type(self)(self.maxsize, self.queue, self.unfinished_tasks)
	end

	function c._format(self)
		result = Queue._format(self)
		if self.unfinished_tasks then
			result += ' tasks=%s _cond=%s' % (self.unfinished_tasks, self._cond)
		end
		return result
	end

	function c._put(self, item)
        assert(item ~= nil)
		Queue._put(self, item)
		self.unfinished_tasks += 1
		self._cond.clear()
	end

	function c.task_done(self)
		--[[Indicate that a formerly enqueued task is complete. Used by queue consumer threads.
		For each :meth:`get <Queue.get>` used to fetch a task, a subsequent call to :meth:`task_done` tells the queue
		that the processing on the task is complete.

		If a :meth:`join` is currently blocking, it will resume when all items have been processed
		(meaning that a :meth:`task_done` call was received for every item that had been
		:meth:`put <Queue.put>` into the queue).

		Raises a :exc:`ValueError` if called more times than there were items placed in the queue.
		]]
		if self.unfinished_tasks <= 0 then
			raise ValueError('task_done() called too many times')
		end
		self.unfinished_tasks -= 1
		if self.unfinished_tasks == 0 then
			self._cond.set()
		end
	end

	function c.join(self, timeout)
        -- timeout可为nil
		--[[
		Block until all items in the queue have been gotten and processed.

		The count of unfinished tasks goes up whenever an item is added to the queue.
		The count goes down whenever a consumer thread calls :meth:`task_done` to indicate
		that the item was retrieved and all work on it is complete. When the count of
		unfinished tasks drops to zero, :meth:`join` unblocks.

		:param float timeout: If not ``nil``, then wait no more than this time in seconds
			for all tasks to finish.
		:return: ``true`` if all tasks have finished; if ``timeout`` was given and expired before
			all tasks finished, ``false``.

		.. versionchanged:: 1.1a1
		   Add the *timeout* parameter.
		]]
		return self._cond.wait(timeout=timeout)
	end
]====]


--[===[
Channel = class.create(object)
local c = Channel
	function c.__init__(self)
		self.getters = {} --collections.deque()
		self.putters = {} --collections.deque()
		self.hub = _eli_:getCurrent()
		self._event_unlock = nil
	end

	function c.__repr__(self)
		return '<%s at %s %s>' % (type(self).__name__, hex(id(self)), self:_format())
	end

	function c.__str__(self)
		return '<%s %s>' % (type(self).__name__, self:_format())
	end

	function c._format(self)
		local result = ''
		if #self.getters ~= 0 then
			result = result .. string.format(' getters[%s]' , #self.getters)
		end
		if #self.putters ~= 0 then
			result = result .. string.format(' putters[%s]' , #self.putters)
		end
		return result
	end

	-- @property
	function c.balance(self)
		return #self.putters - #self.getters
	end

	function c.qsize(self)
		return 0
	end

	function c.empty(self)
		return true
	end

	function c.full(self)
		return true
	end

	function c.put(self, item, block, timeout)
        if block == nil then block = true end
        -- timeout可为nil
		if self.hub == _eli_:getCurrent() then
			if #self.getters ~= 0 then
				local getter = table.remove(self.getters, 1) --.popleft()
				getter:switch(item)
				return
			end
			raise Full
		end

		if not block then
			timeout = 0
		end

		local waiter = Waiter()
		item = (item, waiter)
		table.insert(self.putters, item) --.append(item)
		timeout = Timeout._start_new_or_dummy(timeout, Full)
		try
			if #self.getters ~= 0 then
				self:_schedule_unlock()
			end
			local result = waiter:get()
			if result ~= waiter then
				raise InvalidSwitchError("Invalid switch into Channel.put: %r" % (result, ))
			end
		except
			_safe_remove(self.putters, item)
			raise
		finally
			timeout:cancel()
	end

	function c.put_nowait(self, item)
        assert(item ~= nil)
		self:put(item, false)
	end

	function c.get(self, block, timeout)
        if block == nil then block = true end
        -- timeout可为nil
		if self.hub == _eli_:getCurrent() then
			if #self.putters ~= 0 then
				local item, putter = table.remove(self.putters, 1) --:popleft()
				self.hub.oLoop:run_callback(putter.switch, putter)
				return item
			end
		end

		if not block then
			timeout = 0
		end

		local waiter = Waiter()
		timeout = Timeout._start_new_or_dummy(timeout, Empty)
		try
			table.insert(self.getters, waiter) --:append(waiter)
			if #self.putters ~= 0 then
				self:_schedule_unlock()
			end
			return waiter:get()
		except
			self.getters.remove(waiter)
			raise
		finally
			timeout:cancel()
	end

	function c.get_nowait(self)
		return self:get(false)
	end

	function c._unlock(self)
		while #self.putters ~= 0 and #self.getters ~= 0 do
			local getter = table.remove(self.getters, 1) --.popleft()
			local item, putter = table.remove(self.putters, 1) --.popleft()
			getter:switch(item)
			putter:switch(putter)
		end
	end

	function c._schedule_unlock(self)
		if not self._event_unlock then
			self._event_unlock = self.hub.oLoop:run_callback(self._unlock)
		end
	end

	-- function c.__iter__(self)
	-- 	return self
	-- end

	-- function c.next(self)
	-- 	local result = self:get()
	-- 	if result == StopIteration then
	-- 		raise result
	-- 	end
	-- 	return result
	-- end

	-- __next__ = next -- py3
]===]