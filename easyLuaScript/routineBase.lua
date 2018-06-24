--[[	作者:叶伟龙@龙川县赤光镇
		协程基类
--]]
_ENV=require('base').module(...)
require('class')

local unpack=table.unpack or unpack  --各lua版本兼容
local remove = table.remove
local yield = coroutine.yield
local dRealJobMapSelf=setmetatable({},{__mode='kv'})

function getCurrent(self) --对外接口
	--coroutine.running()
	--5.3 返回当前正在运行的协程加一个布尔量。 如果当前运行的协程是主线程，其为真
	--5.1 返回当前协程,如果当前是主协程,则为nil
	local job
	if _VERSION=='Lua 5.1' then
		job=coroutine.running()
		if job==nil then
			job = _elo_.MAIN
		end		
	else
		local bIsMain
		job,bIsMain=coroutine.running()
	end
	local obj = dRealJobMapSelf[coroutine.running()]
	return obj
end

local I_AM_EXCEPT = class.cObject()

cRoutineBase=class.create()
local c=cRoutineBase
	function c.switch(self,...)-- 把控制权及指定的数据...传给协程self
		local lRet = {self:switch_(...)}
		-- error能快速向上返回,不用层层return
		if lRet[1]==I_AM_EXCEPT then
			error(lRet[2],0) --必须传参为0,如果msg是string的情况下会自动加上路径,有路径后面不好比较
		end
		return unpack(lRet)
	end

	function c.switch_(self,...)-- 把控制权及指定的数据...传给协程self
		assert(self:status()~='dead')--ywl

		local lArgs={...}
		local MAIN, HUB = _elo_.MAIN, _elo_.HUB
		if _eli_:isMainRoutine() then --当前是MAIN协程
			if self ~= HUB and self ~= MAIN then --从MAIN切到MAIN是允许的,比如_eli_:getCurrent():throw(cExit.cInterrupt())
				error('MAIN协程只能swithch到HUB协程')
			end
			-- 控制权分派循环
			local destJob=self
			while destJob~=nil do
				if destJob == MAIN then --在主协程里切到主协程,相当于switch只是一个普通的函数调用
					return unpack(lArgs)
				end
				--print('switch  destJob==',tostring(destJob))
				lArgs = {destJob:resume(unpack(lArgs))} --在destJob的func里面必须return回或yield回下一个目标job 和job接收的参数
				local bResult=remove(lArgs,1)--true or false的状态标志
				if not bResult then--出错了,不允许出现的,一旦出现整个调度系统都无法工作了
					-- print('isInstance===',class.isInstance(lArgs[1],except.cErrorAndStack))
					-- print(lArgs[1])

					--上面的resume相当于pcall,只有错误信息和一行出错位置,没有调用栈
					error(lArgs[1])
				end
				destJob=remove(lArgs,1)
				assert(type(destJob.realJob)=='thread') --ywl
				assert(destJob:status()~='dead')--ywl
			end
			error("coroutine ended without switching control")
		else --当前是非MAIN协程
			if _eli_:getCurrent() ~= HUB then --当前非MAIN非HUB,则是子协程
				if self ~= HUB then
					--print('running',_eli_:getCurrent())
					--print('target',self)
					error('子协程只能swithch到HUB协程')
				end
			else

			end
			return yield(self,unpack(lArgs))--把self yield给MAIN,从MAIN再resume到self
		end
	end
	
	function c.throw(self,...)
		return self:switch(I_AM_EXCEPT,...)
	end

	function c.createWaiter_(self,dArgs)
		return waiter.cWaiter()
	end

	function c.createJob_(self)--
		error('子类必须实现')
	end

	function c.__init__(self)--
		self.realJob=self:createJob_()
		dRealJobMapSelf[self.realJob]=self --
	end
	---------------对自带函数的包装 开始-------------

	function c.resume(self,...) --
		return coroutine.resume(self.realJob,...)
	end

	function c.status(self) --
		return coroutine.status(self.realJob)
	end

	-- function c.running(self) --不应是成员函数
	-- end

	-- function c.isyieldable (self) --包装了也没有什么卵用
	-- 	return coroutine.isyieldable()
	-- end

	--function c.create(self,f) --包装了也没有什么卵用
	--	return coroutine.create(f)
	--end
	
	--function c.wrap(self,f) --包装了也没有什么卵用
	--	return coroutine.wrap(f)
	--end
	
	-- function c.yield(self,...) --包装了也没有什么卵用
	-- 	return coroutine.yield(...)
	-- end
	---------------对自带函数的包装 结束-------------

require('waiter')
require('util')
