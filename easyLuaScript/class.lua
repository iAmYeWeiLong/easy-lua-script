--[[	作者:叶伟龙@龙川县赤光镇
		lua的类实现
--]]

-- local setmetatable=setmetatable

_ENV=require('base').module(...)

local newIndexOfClass_,createInstance_,newIndexOfInstance_,indexOfInstance_,hasDefineIncls_
local searchAttr_
function create(...)--创建一个class
	local lBases={...}--lua 5.2 之后局部空间内不再自动生成arg,所以要手工生成一个
	if next(lBases)==nil then --没有父类
		lBases={cObject}--给个默认父类
	else
		for i,super in ipairs(lBases) do
			-- if super[".isclass"]~=nil then  --cocos2d-x里面有的特征
			-- 	error(string.format('要想从引擎继承%s,请自行实现__new__方法',tostring(super)),0)
			-- end
			if not rawget(super,'__isClass__') then
				error('父类有误')
			end
		end
	end
	local function __tostring(cls) 
		local name=rawget(cls,'__name__')
		if name==nil then
			return '<no name class>'
		end
		return name
	end
	local cls=nil
	local iParentCount=#lBases
	if iParentCount<=1 then--有一个父类
		cls=setmetatable({}, {__newindex=newIndexOfClass_,__call=createInstance_,__index=lBases[1]})--,__tostring=__tostring
	else--是子类,有多个父类
		cls=setmetatable({}, {__newindex=newIndexOfClass_,__call=createInstance_,__index=function(t, key)return searchAttr_(key,lBases)end})--,__tostring=__tostring
	end
	--复制父类的元方法,双下划线开头且不是双下划线结尾的都认为是元方法
	--为了速度,按理应该全部方法都要复制的,据说每次触发到__index方法是较慢的
	for idx,superCls in pairs(lBases) do
		for k,v in pairs(superCls) do --type(v)=='function' and
			if type(v)=='function' and type(k)=='string' and string.sub(k,1,2)=='__' and string.sub(k,-2,-1)~='__' then
				cls[k]=v
			end
		end
	end
	--按理只需要上面的for循环进行赋值就足已,但是有些类不是从这里创建出来的(不规范的class).有可能没有__newindex,__index
	--只能手工赋值一下.若是基类本身有这2个方法,就覆盖掉而已
	cls.__newindex=newIndexOfInstance_
	cls.__index=indexOfInstance_ -- cls.__index=cls

	cls.__bases__=lBases --保存这个属性只是为了用于判断类与类,实例与类之间的关系
	cls.__isClass__=true --方便检查一个表是不是类,获取时要用rawget,否则实例也会返回true
	return cls
end

function isInstance(obj,cls)--判断一个实例是不是某个类的对象(有面向对象语义,奶牛也是牛)
	if util.getAttr(obj,'__class__')==nil then
		return false --error('obj 不是实列',0)
	end
	if not rawget(cls,'__isClass__') then
		return false --error('cls 不是类',0)
	end
	if obj.__class__==cls then
		return true
	end
	return isSubClass(obj.__class__,cls)
end

function isSubClass(cls,superCls)--判断1个类是否为另1个类的子类
	if not rawget(cls,'__isClass__') then
		return false --error('cls 不是类',0)
	end
	if not rawget(superCls,'__isClass__') then
		return false --error('superCls 不是类',0)
	end

	if cls==superCls then--这个有争议.
		return true
	end
	for i,tempCls in ipairs(cls.__bases__) do
		if tempCls==superCls then
			return true		
		end
	end

	for i,tempCls in ipairs(cls.__bases__) do
		if isSubClass(tempCls,superCls) then
			return true
		end
	end
	return false
end

------以下函数全是模块私有的----------------------------------------------------

function searchAttr_(sAttrName,clses)--是深度搜索
	for i,cls in ipairs(clses) do
		local attr = cls[sAttrName]--这里有多态行为,可能拿到的是父类的属性
		if attr~=nil then
			return attr
		end
	end
	return nil
end


local dInstanceMapAttrs=setmetatable({},{__mode='k'}) --实例映射属性表(除了table,其他实例是无法存储属性,只能用实例关联一个属性表)
local dDefine4obj=setmetatable({},{__mode='k'})
function indexOfInstance_(self, key)--实例上找不到了,到类里去找
	local tValues=nil
	if type(self)~='table' then
		local tAttrs=dInstanceMapAttrs[self]
		if tAttrs==nil then
			error(string.format('不可能,key=%s',key))
		end
		local attr=tAttrs[key]
		if attr~=nil then
			return attr
		end
		tValues=tAttrs
	else
		tValues=self
	end
	local cls=tValues.__class__ --local cls=self.__class__
	local attr=cls[key]--这里有多态行为,可能拿到的是父类的属性
	if attr~=nil then
		--优化,只有首次调用函数时触发__index,然后再也不触发了
		if type(attr)=='function' and type(self)=='table' then
			self[key]=attr
		end
		return attr
	end
	--实例中没有找到,类中也没有找到
	if not hasDefineIncls_(cls,key) and dDefine4obj[self]~=nil and dDefine4obj[self][key]~=true and string.sub(key,1,3)~='rpc'then
		--error(cAttributeError(string.format("AttributeError: %s instance has no attribute '%s'",tostring(self),key)))
		error(string.format('没有定义的成员变量 "%s"',key), 2)
	end
	return nil
end

function newIndexOfInstance_(self,k,v)
	if type(self)=='table' then
		rawset(self,k,v) --用rawset避免死递归
	else --userdata或thread之类的
		--local tAttrs=util.setDefault(dInstanceMapAttrs,self,{})
		local tAttrs=dInstanceMapAttrs[self]--肯定存在,创建实例时已经设好
		tAttrs[k]=v
	end
	local d=util.setDefault(dDefine4obj,self,{})
	d[k]=true --标识已经声明过的实例属性
end

local dDefine4cls=setmetatable({},{__mode='k'})
function newIndexOfClass_(cls,k,v)
	-- 用于检查函数调用经常把该用冒号错写成点的情况
	if type(v)=='function' then
		local __funcAlias__=v --起个别名,方便被debug.getupvalue()查找.
		local function method(selfOrCls,...)
			local sType=type(selfOrCls)
			if sType~='table' and sType~='userdata' and sType~='thread' then
				error(string.format('不是一个实例,有可能调用函数时你用了点,而不是冒号.总之参数错了'),2)
			end
			return __funcAlias__(selfOrCls,...)
		end		
		rawset(cls,k,method) --用rawset避免死递归
	else		
		rawset(cls,k,v) --用rawset避免死递归
	end	
	local tAttrs=util.setDefault(dDefine4cls,cls,{})
	tAttrs[k]=true --标识已经声明过的类属性
end

function createInstance_(cls,...)--生成类的实例
	if not rawget(cls,'__isClass__') then
		error('cls竟然不是一个类',1)
	end
	local self
	local __new__=cls.__new__ --获取cls.__new__有多态行为
	if __new__~=nil then
		self=__new__(cls,...)
		local sType=type(self)
		if sType~='table' and sType~='userdata' and sType~='thread' then
			error(string.format('__new__函数必须返回一个table或userdata,你返回的是%s',type(self)),1)
		end
		if sType~='table' then
			util.setDefault(dInstanceMapAttrs,self,{})
		end
	else --已经不可能进这里了,因为全部类的父类object有__new__方法
		self={}
	end
	if type(self)=='table' then		
		--调用成员方法时触发__index元方法是邪恶的,据说性能会差很多
		--为了加速是不是可以把类方法全部复制到实例上???
		--算了,这事交给客户在__new__自行实现吧
		--或者首次触发到__index时把函数缓存到实例,这样下一次就不会触发__index.
		setmetatable(self,cls)
	elseif type(self)=='userdata' then --userdata已经在c层设过metatable的了
		if getmetatable(self)~=cls then
			error('设的元表是错的')
		end
	elseif type(self)=='thread' then
		if getmetatable(self)==nil then
			ywlSetMetaTable(self,cls)--设用c层封装的,因为脚本层只能对table设setmetatable,无法对userdata等设metatable
		end
	else
		error('什么玩意啊')
	end	
	--setMetaTable_(self,cls)

	self.__class__=cls --标识这个实例所对应的类(若是userdata,无法赋值)
	local __init__=cls.__init__ --获取cls.__init__有多态行为
	if __init__~=nil then
		__init__(self,...)
	end
	return self
end

function hasDefineIncls_(cls,sAttrName) --递归地检查有没有定义过的属性
	local d=dDefine4cls[cls]
	if d~=nil and d[sAttrName]==true then
		return true
	end
	for _,baseCls in ipairs(cls.__bases__) do
		if hasDefineIncls_(baseCls,sAttrName) then
			return true
		end
	end
	return false
end

local dInstanceMapClass=setmetatable({},{__mode='k'}) --实例映射class

local function setMetaTable_(oInstance,cls)
	local tOldMetaTable=getmetatable(oInstance)
	if tOldMetaTable==nil then
		setmetatable(oInstance, cls) --直接把cls设为实例的元表,设这个{__index=cls}为实例的元表也行,就是其他的元方法不会工作
		return
	end
	local __index=tOldMetaTable.__index
	if __index==nil then
		error('作为一个别人的元表,竟然没有__index属性',1)
	end
	dInstanceMapClass[oInstance]=cls --不用担心实例的生命期被延长,因为是弱表
	if rawget(tOldMetaTable,'__bChangeIndex__') then --说明__index已经被动过手脚
		return
	end
	local func
	if type(__index)=='function' then --引擎创建的实例的元表的__index竟然是一个function,脚本创建的实例的元表肯定是一个table
		func=function(t,key)
			local cls=dInstanceMapClass[t]
			if cls~=nil then
				local attr=cls[key]--一定要优先搜索cls,然后才是原来的类,因为cls可能override了方法,
				if attr then
					return attr
				end
			end
			return __index(t,key) --在用原来的__index函数找
		end
	elseif type(__index)=='table' then
		func=function(t,key)
			local cls=dInstanceMapClass[t]
			if cls~=nil then
				return searchAttr_(key,{cls,__index})--注意cls与__index的顺序,一定要优先搜索cls,然后才是原来的类
			else
				return __index[key]
			end
		end
	else
		error(string.format('元表的__index只能是function或table,不能是%s',type(__index)),1)
	end
	rawset(tOldMetaTable,'__bChangeIndex__',true) --基类竟然给元表设了元表
	tOldMetaTable.__index=func --引擎的类产生的每个实例是指向同一个metatable的,这里危险
	--setmetatable(oInstance, {__index=func})--不能这么做,因为有可能丢掉原来元表上已有的属性
	--另外,如果实例oInstance是引擎创建的,则oInstance是一个userdata,setmetatable的第一个参数必面是table,就是根本无法做到
end

--是全部类的父类
cObject=setmetatable({},{__call=createInstance_})
cObject.__index=indexOfInstance_
cObject.__newindex=newIndexOfInstance_
cObject.__new__=function (cls,...) return {} end
cObject.__bases__={}
cObject.__isClass__=true

function cObject.clearAttr(self)--清除成员变量,主要用于可以复用的对象,比如thread
	if type(self)=='table' then
		for k,v in pairs(self) do
			rawset(self,k,nil)
		end
	else
		local dAttrs=dInstanceMapAttrs[self]
		if dAttrs~=nil then
			dInstanceMapAttrs[self]={} --比起下面这个,这样来得快
			-- for k,v in pairs(dAttrs) do
			-- 	self[k]=nil
			-- end
		end
	end
end

require('util')
