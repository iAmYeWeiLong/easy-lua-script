--[[	作者:叶伟龙@龙川县赤光镇
		用lua实现和python类似的装饰器
--]]
local function decorator(x)  --x参数可要可不要,看实际需求
	local function __concat(_,f)
		return function(n,y) --对外表现函数,装饰成了接受2个参数了
			return f(n+x+y)--被装饰的函数,实际只有1个参数
		end
	end
	return setmetatable({}, {__concat =__concat})
end


local dDocString=setmetatable({},{__mode='k'})
local function docStr(str)
	local function __concat(_,f)
		dDocString[f]=str
		return f
	end
	return setmetatable({}, {__concat =__concat})
end

local function functionHelp(f)
	local str=dDocString[f]
	if str==nil then
		return ''
	end
	return str
end


local random =
	docStr('whf')..
	decorator(1)..	
	function(n) 
		return math.random(n)
	end


print('random docstring',functionHelp(random))
print('random',random(3,2))
