--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)

require('class')
local unpack = table.unpack or unpack  --各lua版本兼容


--对象管理器

--key映射obj
--作用是当调用getObj拿到是proxy
--确保obj的ownership是属于这个keeper,不会发生ownership转移或被共享
cManager = class.create()
local c = cManager
	function c.__init__(self)
		self.dProxy = DICT()--实例的代理
		self.dObjs = DICT()--实例的强引用
	end

	function c.getObj(self, key)--返回proxy
		assert(key ~= nil)
		--据说proxy的使用有一点性能问题.外网就直接返回真实的对象	
		if true then --config.IS_INNER_SERVER
			return util.getAttr(self.dProxy, key)
		else
			return util.getAttr(self.dObjs, key)
		end
	end

	function c.addObj(self, key, obj)
		assert(key ~= nil)
		assert(obj ~= nil)
		if util.getAttr(self.dObjs, key) ~= nil then
			--raise Exception,'{}为key的对象已在管理器中了{}.'.format(key,obj)
			return
		end			
		self.dProxy[key]=util.proxy(obj)
		self.dObjs[key]=obj
	end

	function c.removeObj(self, key)
		assert(key ~= nil)
		--下面两句有顺序的,先从proxy弹出,避免从dObjs弹出进引起的析构函数访问dProxy里面的元素,
		--引起ReferenceError: weakly-referenced object no longer exists			
		self.dProxy[key] = nil
		self.dObjs[key] = nil
	end

	function c.removeAllObj(self)
		self.dProxy = DICT()
		self.dObjs = DICT()
	end
				
	function c.amount(self)
		return #self.dObjs
	end

	-- function c.getItems(self)
	-- 	return self.dProxy.items()
	-- end

	-- function c.getKeys(self)
	-- 	return self.dProxy.keys()
	-- end

	-- function c.getValues(self)
	-- 	return self.dProxy.values()
	-- end

	-- function c.getIterItems(self)
	-- 	return self.dProxy.iteritems()
	-- end

	-- function c.getIterKeys(self)
	-- 	return self.dProxy.iterkeys()
	-- end

	-- function c.getIterValues(self)
	-- 	return self.dProxy.itervalues()
	-- end

require('util')
require('except')