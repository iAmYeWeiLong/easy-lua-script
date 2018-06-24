--作者:叶伟龙@龙川县赤光镇
--[[
用来解决callback hell的.
我费了一生的精力，集合十种杀人武器于一身的超级武器霸王，名字就叫做要你命3000，终于研究成功了.
阿漆，靠边一点，远一点，再远一点。
--]]


module('promise',package.seeall)
module(...,package.seeall)

local REJECTED,FULFILLED,PENDING = {'REJECTED'},{'FULFILLED'},{'PENDING'}

local safelyResolveNextAble,unwrap,localResolve,localReject,defaultCatch --前向声明函数
local cQueueItem,cPromise--前向声明类
-----------------------------------------------------------
function create(resolver,...)--对外接口
	local o=cPromise(resolver,...)
	--附加一个error处理函数,免去用户catch的麻烦
	--若是后面发现用户有catch,再remove掉
	o:catch(defaultCatch)
	return o
end

cPromise=class.create() --local类
local c=cPromise
	function c.__init__(self,resolver,...)
		if resolver~=nil and type(resolver) ~= 'function' then
			error('resolver must be a function or nil')
		end
		self.state = PENDING
		self.queue = {}
		self.tOutcome = {} --void 0
		self.tCarryVal={...}--携带的值
		if resolver ~= nil then
			safelyResolveNextAble(self, resolver)
		end
	end

	function c.__tostring(self)
		return '<promise>'
	end
	function c.catch(self,onRejected)
		return self:next(nil, onRejected)
	end

	function c.next(self,onFulfilled, onRejected)
		-- if type(onFulfilled) ~= 'function' and self.state == FULFILLED or
		-- 	type(onRejected) ~= 'function' and self.state == REJECTED then
		-- 	return self
		-- end
		if onFulfilled~=nil and type(onFulfilled) ~= 'function' or
			onRejected~=nil and type(onRejected) ~= 'function' then
			error('onFulfilled,onRejected只能是function或nil',2)
		end
		if onFulfilled==nil and onRejected==nil then
			error('onFulfilled,onRejected不能同时是nil',2)
		end
		if onFulfilled == nil and self.state == FULFILLED or
			onRejected == nil and self.state == REJECTED then
			return self
		end
		
		if next(self.queue)~=nil and self.queue[1]:isDefaultCatch() then--是默认catch,remove掉
			--一般此时queue里面只有一个元素,remove不会引起后面的元素移动
			table.remove(self.queue,1)
		end
		
		local newPromise=cPromise() 
		if onRejected~=defaultCatch then --不是调用promise:catch(defaultCatch)进来的. and self.state ~= PENDING then
			--因为不是defaultCatch,即使是用户提供的errorHandler也可能抛出新的错误,所以得追加一个defaultCatch
			newPromise:catch(defaultCatch)
		end
		if self.state ~= PENDING then
			--local resolver
			if self.state == FULFILLED then
				--resolver=onFulfilled
				local t=util.mergeList(self.tOutcome,self.tCarryVal)
				unwrap(newPromise, onFulfilled, unpack(t))--
			else
				--resolver=onRejected
				unwrap(newPromise, onRejected, self.tOutcome)--
			end
		else
			table.insert(self.queue,cQueueItem(newPromise, onFulfilled, onRejected))
		end
		return newPromise
	end
-----------------------------------------------------------
cQueueItem=class.create() --local类
local c=cQueueItem
	function c.__init__(self,promise, onFulfilled, onRejected)
		self.promise = promise
		if type(onFulfilled) == 'function' then
			self.onFulfilled = onFulfilled
			self.callFulfilled = self.otherCallFulfilled
		end
		if type(onRejected) == 'function' then
			self.onRejected = onRejected
			self.callRejected = self.otherCallRejected
		end
	end

	function c.isDefaultCatch(self)
		return self.onFulfilled==nil and self.onRejected==defaultCatch
	end

	function c.callFulfilled(self,...)--value  onFulfilled为nil时
		localResolve(self.promise, ...)--value 坠落现象
	end

	function c.otherCallFulfilled(self,...)--value
		unwrap(self.promise, self.onFulfilled, ...)--value
	end

	function c.callRejected(self,value)--onRejected为nil时
		localReject(self.promise, value)-- 坠落现象
	end

	function c.otherCallRejected(self,value)
		unwrap(self.promise, self.onRejected, value)
	end
-----------------------------------------------------------
function unwrap(promise, func, ...)--local函数 ,value
	local lArgs={...}
	local tReturnValue	
	local bRet,errStack=xpcall(function()
		tReturnValue = {func(unpack(lArgs))} --value
	end,util.errorHandler)

	if not bRet then
		return localReject(promise, errStack)
	end

	if tReturnValue[1] == promise then
		local bRet,errStack=xpcall(function()error('Cannot resolve promise with itself')end,util.errorHandler)
		localReject(promise,errStack) --new TypeError('Cannot resolve promise with itself')
	else
		localResolve(promise, unpack(tReturnValue))
	end	
end

function localResolve(promise, ...)--local函数. value是用户的回调函数返回的值,有可能是nil值.value
	--print('localResolve===',tostring(value))
	-- local result = tryCatch(getNext, value)
	-- if result.status == 'error' then
	-- 	return localReject(promise, result.value)
	-- end	
	-- local nextAble = result.value --是一个函数
	--if nextAble then --调用用户提供的回调函数后,得到的返回值是一个promise
	local lArgs={...}
	if #lArgs==1 and class.isInstance(lArgs[1],cPromise) then --是一个promise, value
		safelyResolveNextAble(promise,util.bindMethod(lArgs[1].next,lArgs[1]))--nextAble value
	else --调用用户提供的回调函数后,得到的返回值是一个普通值
		promise.state = FULFILLED
		promise.tOutcome = {...} --value

		local t=util.mergeList(promise.tOutcome,promise.tCarryVal)
		for i=1,#promise.queue do
			promise.queue[i]:callFulfilled(unpack(t))--value
		end
	end
	return promise
end

function localReject(promise, error)--local函数
	promise.state = REJECTED
	promise.tOutcome = error
	for i=1,#promise.queue do
		promise.queue[i]:callRejected(error)
	end
	return promise
end

--[[
local function getNext(obj)--返回一个函数
	-- Make sure we only access the accessor once as required by the spec
	local fNext = obj and obj.next
	if obj and type(obj) == 'object' and type(fNext) == 'function' then
		return function (...) --appyThen
			fNext(obj,...)
			--fNext.apply(obj, arguments)
		end
	else
		return nil
	end
end
--]]

function safelyResolveNextAble(promise, nextAble)--local函数
	-- Either fulfill, reject or reject with error
	local called = false
	local function onError(value)
		if called then
			return
		end
		called = true
		localReject(promise, value)
	end

	local function onSuccess(...)--value ,允许用户回调传多个值过来
		if called then
			return
		end
		called = true
		localResolve(promise, ...)--value,允许用户回调传多个值过来
	end

	local bRet,errStack=xpcall(util.functor(nextAble,onSuccess, onError),util.errorHandler)--tryToUnwrap
	if not bRet then
		onError(errStack)
	end
end

function resolve(...)--对外接口 value
	--if (value instanceof this) then
	local lArgs={...}
	if #lArgs==1 and util.isInstance(lArgs[1],cPromise) then --是一个promise, value
		return ...
	end
	return localResolve(cPromise(), ...)
end

function reject(reason)--对外接口
	local promise = cPromise()
	return localReject(promise, reason)
end

function defaultCatch(errStack) --local
	print(string.format('%s%s',tostring(errStack)))
	--util.reRaise(errStack)--这里不必reRaise,因为外部无法对使用本函数的promise进行next()
end

--[[未经过测试
function all(...)--对外接口
	local lArgs={...}
	-- if (Object.prototype.toString.call(iterable) ~= '[object Array]') {
	-- 	return this.reject(new TypeError('must be an array'))
	-- }
	local len = #lArgs
	local called = false
	if len==0 then
		return resolve(...)
	end

	local values = {}
	local resolved = 0
	
	local promise = cPromise()

	local function allResolver(value, i)
		local function __ (error)
			if not called then
				called = true
				localReject(promise, error)
			end
		end

		local function resolveFromAll(outValue)
			values[i] = outValue
			resolved=resolved+1
			if resolved == len and not called then
				called = true
				localResolve(promise, values)
			end
		end
		resolve(value):next(resolveFromAll, __) --self.
	end

	for i,v in ipairs(lArgs) do
		allResolver(v, i)
	end
	return promise
end

function race(...) --对外接口
	local lArgs={...}
	--local self = this
	-- if (Object.prototype.toString.call(lArgs) ~= '[object Array]') {
	-- 	return this.reject(new TypeError('must be an array'))
	-- }
	local len = #lArgs
	local called = false
	if 0==len then
		return resolve(...)
	end

	local promise = cPromise()
	local function resolver(value)
		local function __1(...)
			if not called then
				called = true
				localResolve(promise, ...)
			end
		end

		local function __2(...)
			if not called then
				called = true
				localReject(promise, ...)
			end
		end
		resolve(value):next(__1, __2)
	end
	
	for _,oPromise in ipairs(lArgs) do
		resolver(oPromise)
	end
	return promise
end
--]]

require('util')
require('class')