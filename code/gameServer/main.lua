--[[	作者:叶伟龙@龙川县赤光镇
--]]
local THIS_NAME='main'
--查找路径,目录分隔符用\\也行;开始部分可以不要./
package.path = package.path .. ';easyLuaScript/?.lua'
package.path = package.path .. ';easyLuaScript/?/init.lua'

package.path = package.path .. ';code/gameServer/?.lua'
package.path = package.path .. ';code/gameServer/?/init.lua'

package.path = package.path .. ';code/serverShare/?.lua'
package.path = package.path .. ';code/serverShare/?/init.lua'
--print('package.path=',package.path)--查找路径	

package.cpath = package.cpath .. ';./dll_so/?.dll'
--print('package.cpath=',package.cpath)--查找路径

_ENV=require('base').module(THIS_NAME)
require('class')
require('application')

local cApplication=class.create(application.cApplication)
local c=cApplication

	function c.execute(self)
		local asyncWatcher = _elo_.HUB.oLoop:createAsync()
		asyncWatcher:start(function() end)

		local serviceLib=require('easyLuaLib.service')
		local sServiceName = '[i_am_logService]'
		local sCmdLine = string.format([[code\gameServer\logService\entry.lua %s ]],sServiceName)

		local vmId1,serviceId1 = serviceLib.startService(sCmdLine) --阻塞接口
		--local vmId2,serviceId2 = serviceLib.startService(sCmdLine) --阻塞接口
		print('vmId1,serviceId1===',vmId1,serviceId1)
		--print('vmId2,serviceId2===',vmId2,serviceId2)
		local thisService = serviceLib.cThisVM('thisService',asyncWatcher)
		thisService:sendByVmId(vmId1,"is a fucker msg")


		local function test( ... )
			local i = 1
			while true do
				--print('sleep.....')
				_eli_:sleep(2)
				thisService:sendByVmId(vmId1,string.format("is a fucker msg %d",i))
				i = i + 1
				thisService:sendByVmId(vmId1,string.format("is a fucker msg %d",i))
				i = i + 1
			end
		end
		local job = _eli_:spawn(test)
		job:join()
		-- collectgarbage('collect')
		 --_elo_.HUB:join()
		print('execute end')
		do return end
		----------------------------------
		local networkLib=require('easyLuaLib.network')

		--最容易理解的一种,文件名就叫socket_core.dll,在多个目录下查找(当然可以在文件名上玩杠)
		local socketLib=require("easyLuaLib.socket")

		--加目录,文件名上一定要有杠,不然会找得到文件,但找不到入口函数,杠前面可以乱加字符
		-- local socketLib=require("fuck.-socket_core") --新建目录fuck,文件叫-socket_core.dll()
		-- local socketLib=require("fuck.windows-socket_core") --ok,新建目录fuck,文件叫windows-socket_core.dll

		--加目录,不能在文件名上玩杠了,但可以在目录名上玩杠
		-- local socketLib=require("socket.core") --ok,新建目录socket,文件名叫core.dll
		-- local socketLib=require("windows-socket.core") --ok,新建目录windows-socket,文件名叫core.dll

		--不加目录,只在文件名上搞杠.书上说为了一个文件可以有多个入口(模块)
		--local socketLib=require("socket.core") --文件名叫socket.dll
		--local socketLib=require("windows-socket.core") --文件名叫windows-socket.dll

		--require("loop")
		require("routineHub")
		require("luasocketServer")
		require("socket")
		require("baseServer")
		require("server")

		--[[
		local oLoop=networkLib.cLoop()
		local _sock = socketLib.tcp()
		local fd = _sock:getfd()
		local oPoll = networkLib.cPoll(oLoop,fd)
		]]

		---[[
		gCount = 0
		local s = '_______________________________________________________0123456789\r\n'
		local function sendProc(sock ,address)
			gCount =gCount + 1

			local sCount = tostring(gCount)

			sCount = string.rep(sCount,1) -- .. '\r\n'

			local calc = 0
			while true do
				
				sock:sendall(sCount)
				--print(string.rep(sCount,10) )
				--print('recv=',s)
				calc =calc +1
				if calc >=100 then
					_eli_:sleep(0)
					calc = 0
				end
			end
		end
		
		local function recvProc(sock ,address)--iCount			
			while true do				
				local s = sock:recv(1024)
				--print( string.sub(s,-10))
			end
			
		end
		--local s = string.rep('a',10)
		local xxxx = 0
		
		local function echo(sock, address)

			gCount = gCount + 1
			print('connection come in')
			--local job1=_eli_:spawn(sendProc,sock,gCount)
			local job2=_eli_:spawn(recvProc,sock,gCount)
			--job1:join()
			job2:join()
			print ('echo...end')
		end

		print('main....start')
		local oServer1 = server.cStreamServer({'0.0.0.0', 16000}, recvProc) --recvProc sendProc echo
		-- local oServer2 = server.cStreamServer({'0.0.0.0', 16001}, sendProc) --recvProc echo
		assert(_elo_.HUB:status()~='dead')

		local f1 = util.bindMethod(oServer1.serve_forever,oServer1)
		local job1 = _eli_:spawn(f1)

		-- local f2 = util.bindMethod(oServer2.serve_forever,oServer2)
		-- local job2 = _eli_:spawn(f2)
		_elo_.HUB:join()
		
		print('main....end')

		do 
			return
		end

		--]]


		--[[
		luasocketServer.startServer()

		local oSocket=socket_core.tcp()
		print('socket_core.tcp().getfd=== ',oSocket:getfd())
		print('socket_core._VERSION=== ',socket_core._VERSION)
		--]]


		--[[
		local oLoop=networkLib.cLoop()
		local oTimer=networkLib.cTimer(oLoop)


		local xyz=0
		local function timer_cb( ... )
			print('timer_cb')
			xyz=xyz+1
			if xyz>4 then
				oTimer:stop()
			end
		end
		oTimer:start(timer_cb,1,1)

		while true do
			print '------------------------'
			local lCallback,alive=oLoop:run(networkLib.UV_RUN_ONCE) --UV_RUN_ONCE UV_RUN_NOWAIT
			print('#lCallback=',#lCallback,'alive==',alive)
			if not alive and #lCallback==0 then
				break
			end		
			while #lCallback>0 do 
				local cb=table.remove(lCallback,1)
				cb()
			end
		end

		--]]
		-- print('_elo_.HUB==',_elo_.HUB)
		-- print('_elo_.MAIN==',_elo_.MAIN)
		local mainJob,bIsMain=coroutine.running()

		assert(_elo_.HUB~=_elo_.MAIN)
		assert(bIsMain)
		assert(mainJob==_elo_.MAIN.realJob)


		--_eli_:getCurrent():throw(except.cInterrupt())

		-- local icount=0
		-- local clock=os.clock()
		-- local idler 
		-- local function idler_cb()
		-- 	--print('idler_cb..')
		-- 	icount=icount+1
		-- 	if icount>=100000 then
		-- 		print ('cost:',os.clock()-clock)
		-- 		idler:stop()
		-- 	end

		-- end	

		-- idler = _elo_.HUB.oLoop:createIdle()
		-- idler:start(idler_cb)
		-- _elo_.HUB:switch()




		-- local function sub( name)
		-- 	while true do
		-- 		print('in sub,values 111=',name)
		-- 		_eli_:sleep(1)
		-- 		--print('in sub,values 222=',name)
		-- 	end
		-- 	return 191
		-- end

		-- local function killer( job1)
		-- 	print('killer begin....')
		-- 	job1:get()
		-- 	print('killer end....')

		-- end


		-- local job1=_eli_:spawn(sub,'fuck')
		--local job2=_eli_:spawn(killer,job1)

		-- print('job2:get()===',job2:get())
		--print('job1:get()===',job1:get(true,5))
		-- local oTimer = _elo_.HUB.oLoop:createTimer(10,10)
		-- local ret=oTimer:start(function ( ... ) end)
		-- print('test. oTimer:start  .. ret=',ret)

		--_elo_.HUB:switch()
		--[[
		while true do
			print('||||---------------------------------------|||')
			_eli_:sleep(5)
			job1:kill()
		end

		--]]
		--[[--]]


		--[[

		local oLoop=networkLib.cLoop()
		print('coroutine.running in mian ==',coroutine.running())


		local oTimer
		local count=0
		local function timer_callback()
			count=count+1
			print('coroutine.running in callback ==',coroutine.running())
			if count>7 then
				oTimer:stop()
			end
		end



		local function createFunc()
			print('createFunc--')

			oTimer:start(timer_callback,1,0.5)
		end

		oTimer=networkLib.cTimer(oLoop)
		local co1=coroutine.create(createFunc)
		coroutine.resume(co1)
		-- createFunc()

		oLoop:run(networkLib.UV_RUN_DEFAULT)
		--]]

		-- local oLoop=loop.cLoop()

		-- local function norman_callback()
		-- 	print('norman_callback')	
		-- end
		-- oLoop:run_callback(norman_callback)


		-- local function idle_callback()
		-- 	print('idle_callback')	
		-- end

		-- local idler=oLoop:createIdle()
		-- idler:start(idle_callback)

		-- local function timer_callback(i,j)
		-- 	print('timer_callback',i,j)	
		-- end

		-- local oTimer=oLoop:createTimer(0.001,0.0001)
		-- oTimer:start(timer_callback,4,5)

		--collectgarbage('collect')
		--collectgarbage('stop')
		-- oLoop:run() --networkLib.UV_RUN_ONCE UV_RUN_NOWAIT UV_RUN_DEFAULT




		-- print('package.path==',package.path)

		-- print('package.cpath==',package.cpath)

		-- local oStudent=networkLib.cStudent()
		-- oStudent:setAge(456)
		-- oStudent.age=987
		-- print('oStudent.getAge==',oStudent:getAge())
		-- print('oStudent==',oStudent,'type(oStudent)==',type(oStudent),'networkLib.cStudent==',networkLib.cStudent)
		-- oStudent=nil
		-- collectgarbage('collect')


		-- cMyStudent=class.create(networkLib.cStudent)
		-- print('cMyStudent==',cMyStudent)
		-- print('cStudent==',networkLib.cStudent)
		-- local c=cMyStudent
		-- 	function c.__init__(self)
		-- 		self.abc=234
		-- 	end

		-- 	function c.newFunc(self)
		-- 		print('getmetatable(self)==',getmetatable(self))
		-- 		print('cMyStudent==',cMyStudent)
		-- 		print('networkLib.cStudent==',networkLib.cStudent)
		-- 		print('call newFunc')
		-- 	end	
		-- local oMyStudent = cMyStudent()

		--print('oMyStudent.newFunc==',oMyStudent.newFunc)
		--[[
		oMyStudent:newFunc()

		print('oMyStudent==',oMyStudent,type(oMyStudent))
		--print('oMyStudent.getAge==',oMyStudent:getAge())
		--]]
		-- print('uv_version==',networkLib.uv_version())
		-- print('uv_version_string==',networkLib.uv_version_string())
		--[[--]]
	end --execute

_G.gApp=cApplication()
_G.gApp:execute()


require('util')