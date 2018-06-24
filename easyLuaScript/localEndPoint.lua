--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)

require('class')
local unpack = table.unpack or unpack  --各lua版本兼容

cLocalEndPoint = class.create()
local c = cLocalEndPoint
	function c.__init__(self, sServiceName)
		self.sServiceName = sServiceName
	end

	function c.__index(self,key) --override
		local attr
		local ok,errStack = xpcall(function()
			attr = class.cObject.__index(self,key) --
		end,except.errorHandler)

		if ok and attr ~= nil then--类本身有同名的属性,阻止向下走
			return attr		
		elseif type(key) ~= 'string' or string.sub(key,1,3) ~= 'lpc' then --实例中找不到,又不是lpc命令
			return nil
		end

		--local lpc = util.bindMethod(self.sendMsg,self,key)--这是怎么搞都不对,用下面的这个吧
		local function lpc(self,...)
			assert(type(self)=='table')
			self:sendMsg(key,...)
		end
		self[key] = lpc -- 避免重复触发__index
		return lpc
	end

	function c.sendMsg(self,sMethodName,...)--msg对外接口
		local serviceLib=require('easyLuaLib.service')
		print('sMethodName,...',sMethodName,...)
		local msg,sz = serviceLib.pack(sMethodName, ...)
		--print('pack result',msg,sz)
		local ret = _G.gApp.thisVm:sendByServiceName(self.sServiceName, msg, sz)
		serviceLib.trash(msg)
		msg = nil
	end

	function c.recvMsg(self, sServiceName, iSourceVm, iSession, lpcName, ...)
		print('cLocalEndPoint.recvMsg', sServiceName, iSourceVm, iSession, lpcName, ...)
	end

	function c.__tostring(self)
		return '<EMPTY>'
	end

------------------------------------------------------
require('util')
require('except')