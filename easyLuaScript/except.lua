--[[	作者:叶伟龙@龙川县赤光镇
		异常,错误处理相关
--]]

_ENV=require('base').module(...)
local class = require('class')

function err(sText,...)--包装一下,少敲键盘
	error(string.format(sText,...))
end

function reRaise(oErrorAndStack,sErrText)--重新抛出异常
	if class.isInstance(oErrorAndStack,cErrorAndStack) then
		error('参数lError必须是cErrorAndStack的实例,只能对xpcall返回的obj进行再次抛出',1)
	end
	oErrorAndStack:attachMsg(sErrText) --加上更为高层的错误信息
	error(oErrorAndStack,0)
end

function newError(sText)
	local sTraceBack = debug.traceback('',2)
	return {sText,sTraceBack}
end

--返回的是cErrorAndStack的实例
function errorHandler(uError)--xpcall得到的一定是一个table
	--注意:debug.traceback()返回字串第1个字节是换行符!!!	
	--有空要全部去掉调用栈上的 (...tail calls...)
	if type(uError)=='string' then
		--要判断出是不是系统抛出的,去掉行号 ,文件 C:\Users\yeWeiLong\Desktop\error.lua:6: attempt to index local 'i' (a number value)
		local iLevel
		if true then --系统检测到的错误
			iLevel=2
		else --用户主动调用error抛出的
			iLevel=3
		end		
		return cErrorAndStack(uError,debug.traceback('',iLevel))
		--向外返回调用栈,出了本函数,外面的xpcall就无法拿到调用栈了
	elseif type(uError)=='table' then --中间路径xpcall得到的再次抛出的
		if class.isInstance(uError,cBaseException) then --
			return cErrorAndStack(uError,debug.traceback('',3))
		elseif class.isInstance(uError,cErrorAndStack) then
			return uError
		else
			error('什么鬼')
		end
	else --一般是error函数第一个参数填错了,比如填了nil
		if type(uError) == 'nil' then
			uError = tostring(nil)
		end
		return cErrorAndStack(uError,debug.traceback('',3))
	end	
end
----------------------------------------------------------
cErrorAndStack=class.create() --异常and栈
local c=cErrorAndStack
	function c.__init__(self, err, sStack)
		self.oError=err
		self.sStack=sStack
		self.lErrMsg={tostring(err)}
	end

	function c.__tostring(self)
		--因为traceback首字符是回车,所以直接连接起来就好了
		return table.concat(self.lErrMsg,';')  .. self.sStack
	end

	function c.attachMsg(self,sMsg) --加上更为高层的错误信息
		self.lErrMsg[#self.lErrMsg+1]=sMsg
	end

	function c.getInfo(self)
		return self.oError,self.sStack
	end

----------------------------------------------------------
cBaseException=class.create() --异常的基类
local c=cBaseException
	function c.__init__(self,sText,iCode)
		if sText == nil then
			self.sText = ''
		else
			self.sText = sText
		end
		if iCode == nil then
			self.iCode = 0
		else
			self.iCode = iCode
		end

	end
	--有__tostring元方法的table抛给解析器,5.3会调用tostring,没有__tostring元方法则显示(error object is a table value)
	--5.1 有没有__tostring元方法都显示 (error object is not a string)
	function c.__tostring(self)
		return string.format('<cBaseException instance,%s>',self:textAndCode_())
	end

	function c.textAndCode_(self)
		return string.format('text="%s",code=%s',self.sText,self.iCode)
	end


cException=class.create(cBaseException) --
local c=cException
	--有__tostring元方法的table抛给解析器,5.3会调用tostring,没有__tostring元方法则显示(error object is a table value)
	--5.1 有没有__tostring元方法都显示 (error object is not a string)
	function c.__tostring(self) --override
		return string.format('<cException instance,%s>',self:textAndCode_())		
	end

cInterrupt=class.create(cBaseException) --主动退出协程的异常
local c=cInterrupt
	function c.__tostring(self) --override
		return string.format('<cInterrupt instance>')
	end

------------------------------------------
cSocketError=class.create(cException) --socket异常
local c=cSocketError
	function c.__tostring(self) --override
		return string.format('<cSocketError instance,%s>',self:textAndCode_())		
	end

cSocketGaiError =class.create(cException) --get address info error缩写.从python中抄来的 -- This exception is raised for address-related errors, for getaddrinfo() and getnameinfo(). 
local c=cSocketGaiError
	function c.__tostring(self) --override
		return string.format('<cSocketGaiError instance,%s>',self:textAndCode_())		
	end

cSocketHError=class.create(cException)
local c=cSocketHError
	function c.__tostring(self) --override
		return string.format('<cSocketHError instance,%s>',self:textAndCode_())		
	end

cSocketTimeout=class.create(cException)
local c=cSocketTimeout
	function c.__tostring(self) --override
		return string.format('<cSocketTimeout instance,%s>',self:textAndCode_())		
	end
------------------------------------------



-- cTimeOut=class(cException) --超时的异常
-- 	function cTimeOut.__tostring(self)
-- 		return 'cTimeOut instance'
-- 	end

-- cAttributeError=class(cException) --找不到属性的异常
-- 	function cAttributeError.__tostring(self)
-- 		return 'cAttributeError instance'
-- 	end
