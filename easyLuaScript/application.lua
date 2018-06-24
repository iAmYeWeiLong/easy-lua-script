--[[	作者:叶伟龙@龙川县赤光镇		
--]]
_ENV=require('base').module(...)
require('class')
local unpack=table.unpack or unpack  --各lua版本兼容

cApplication=class.create()
local c=cApplication
	function c.__init__(self)
		self.dInterface = {
			--函数,动态库里广泛使用
			createCls = class.create,
			isInstance = class.isInstance,
			isSubClass = class.isSubClass,
			--几个异常类,只在socket动态库中使用
			cSocketError = except.cSocketError,
			cSocketGaiError = except.cSocketGaiError,
			cSocketHError = except.cSocketHError,
			cSocketTimeout = except.cSocketTimeout,
		}

		self:printCmdArgs_()
		self:initLoader_()
		self:initEasyLua_()
	end

	function c.printCmdArgs_(self)
		print('-----arg values:----')
		for k,v in pairs(arg) do
			local sText = string.format('\t%s = %s',k,v)
			print(sText)
		end
		print('--------------------')
	end
	function c.initLoader_(self)--为了给动态库传参数.require c模块libuv4lua之前要调用
		local searcher=package.searchers[4] --只能使用第4个一体化加载器,因为一个lib文件里有多个函数入口(第3个加载器不行)

		for _,sModName in ipairs({'easyLuaLib.network','easyLuaLib.socket','easyLuaLib.service'}) do
			local loader,sPath=searcher(sModName) --sModName 'easyLuaLib'
			--print('sPath===',sPath) --类似F:\gitCode\easylua\x64\Debug\easyLuaLib.dll
			assert(type(loader)=='function',type(loader))
			package.preload[sModName]=util.functor(loader,sPath,self.dInterface)
		end
	end

	function c.initEasyLua_(self)
		require('easyLuaAssembly')
		-----------------------------------
		local cls=self:getInstanceCls_(easyLuaAssembly.cInstance)
		_G._elo_=cls() --名字必须叫_elo_

		-------改写这个类的函数,可以同时改变库代码和用户代码的行为------------------
		local publicInterfaceCls=self:getPublicInterfaceCls_(easyLuaAssembly.cInterface)

		-------改写这个类的函数,仅改变库代码的行为------------------
		local cls=self:getLibInterfaceCls_(publicInterfaceCls)
		_G._eli_=cls() --名字必须叫_eli_	--在客户代码定义 _eli_,给机会改写库的行为的机会

		-------改写这个类的函数,仅改变用户代码的行为------------------	
		local cls=self:getUserInterfaceCls_(publicInterfaceCls)	
		_G._gi_=cls() --
	end
	function c.getInstanceCls_(self,cInstance)
		return cInstance
	end
	function c.getPublicInterfaceCls_(self,publicInterfaceCls)
		return publicInterfaceCls
	end

	function c.getLibInterfaceCls_(self,publicInterfaceCls)
		return publicInterfaceCls
	end

	function c.getUserInterfaceCls_(self,publicInterfaceCls)
		return publicInterfaceCls
	end

	function c.startMyself(self,sServiceName)
		assert(type(sServiceName)=='string')
		local asyncWatcher = _elo_.HUB.oLoop:createAsync()
		local onMessage__ = util.bindMethod(self.onMessage__, self)
		asyncWatcher:start(onMessage__)
		local serviceLib=require('easyLuaLib.service')
		self.thisVm = serviceLib.cThisVM(sServiceName,asyncWatcher)
	end --execute

	function c.onMessage__(self) -- 别的service发来的消息
		while true do -- 因为多次唤醒,会表现为一次真正醒来,所以要while True
			local sServiceName,iSourceVm,iSession,iMsgType,msg,sz=self.thisVm:getInternalMsgNonBlock()  -- iReqestId,  # 不阻塞
			if nil == sServiceName then --没有消息
				return
			end
			--_gi_:spawn(test,iSourceVm,iSession,iMsgType,msg)
			self:onInternalMessage_(sServiceName, iSourceVm, iSession, iMsgType, msg, sz)
		end
	end

	function c.onInternalMessage_(self, sServiceName, iSourceVm, iSession, iMsgType, msg, sz)

	end	

require('util')
require('except')