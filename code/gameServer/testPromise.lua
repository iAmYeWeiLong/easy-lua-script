local function asynchronous(resolve, reject,f)--promise callback
    
    local function __(sResult)
        resolve(sResult)        --reject(sFlag)
    end
    zfm.MovieClip:createAsyncWithFile(plist, __)
end

local function asynchronous(resolve, reject,plist)--promise callback    
    local function __(sResult)        
        resolve(sResult)        --reject(sFlag)
    end
    zfm.MovieClip:createAsyncWithFile(plist, __)
end

function createEntity(id)--promise
	local function __(sResult,id)--proc过程
		obj=cEntity(sResult,id)
		return obj
	end		
	return promise.cPromise(asynchronous,id):next(__)
end

function createOrGetEntity(id)--proc过程  no,no promise
	local function __()
		if ttt[id]~=nil then
			return ttt[id]
		end
		return createEntity(id)		
	end
	return promise.resolve():next(__)
end
createOrGetEntity(id):next(useEntity)

function useEntity(ett)
	-- body
end

function c.__new__(cls,sResult)

end

function test(obj,x,y,z)
	local r=obj.a+x+y+z
	if true then
		return cFoo(r)
	else
		return Promise.resolve():next()
	end
end

local obj=getObject(id)
foo=test(obj,x,y,z)
foo:bar(a,b,c)
foo:haha(a,b,c)
--============================
local pObj=pGetObject(id)-- promise函数
pFoo=pObj:next(util.functor(test,x,y,z))
pFoo=pObj:next(test)


pFoo=pObj:next(util.functor(test,x,y,z))

pFoo:next(util.functor(foo.bar,a,b,c))
pFoo:next(util.functor(foo.haha,a,b,c))

---------------

local f(obj)
	obj:bar(a,b,c)
	obj:haha(a,b,c)
end
pFoo:next(f)
-------------------
pFoo:next(util.functor(f,a,b,c))
local f(obj,a,b,c)
	obj:bar(a,b,c)
	obj:haha(a,b,c)
end


