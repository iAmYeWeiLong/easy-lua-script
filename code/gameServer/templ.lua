local sModName=...
local m=setmetatable({},{__index=_ENV}) --_ENV用_G替代可能更容易理解
_ENV[sModName]=m --_ENV用_G替代可能更容易理解
package.loaded[sModName]=m
local _ENV=m
------------上面的用法等价于下面的用法----------------------

function module(sModName)
	local m=setmetatable({},{__index=_G}) -- 如果这个module函数定义在别的模块,这里用_G才行
	_G[sModName]=m -- 如果这个module函数定义在别的模块,这里用_G才行
	package.loaded[sModName]=m
	return m
end


local _ENV=module(...)
