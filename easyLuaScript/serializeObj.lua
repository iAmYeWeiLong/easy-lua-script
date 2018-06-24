--[[	作者:叶伟龙@龙川县赤光镇
		序列化lua内存对象为一个字符串
--]]

local DEFAULT_MAX_DEPTH=10 --默认的最大递归深度

local function inTuple(o,t)
	for idx,v in ipairs(t) do
		if v==o then--元组
			return true
		end
	end
	return false
end

local function serializeKey(oKey,tConfig,iDepth)--处理非string类型的key,需要加上方括号
	local sKey=serializeObj(oKey,tConfig,iDepth)
	-- if type(oKey) == "string" then --非ASCII的key也需要方括号的,稍后处理
	-- 	return sKey
	-- else
	return string.format('[%s]',sKey)
	-- end
end

--对外接口
function serializeObj(o,tConfig,iDepth)
	iDepth = iDepth or 0
	if type(o) == "number" then
		if isInteger(o) then
			return string.format("%d", o)
		else
			return string.format("%.2f", o)
		end
	elseif type(o) == "string" then
		return string.format("%q", o)
	elseif type(o) == "boolean" then
		return tostring(o)
	elseif type(o) == "table" then
		return serializeTable(o,tConfig,iDepth+1)
	else
		return 'nil' --数组部分是可以出现nil的.--error("不支持的类型" .. type(o))
	end
end

-- 对外接口
function serializeTable (t,tConfig,iDepth,iMaxDepth)
	if type(t)~='table' then
		error('只接受table类型')
	end
	local bIsNewLine
	if tConfig==nil then --默认元素之间是换行的
		tConfig={}
		bIsNewLine=false
	else 
		if inTuple(t,tConfig) then
			bIsNewLine=true
		else
			bIsNewLine=false
		end
	end

	if iMaxDepth==nil then iMaxDepth=DEFAULT_MAX_DEPTH end--默认表嵌表最多10层

	if iDepth==nil then
		iDepth = 0
	elseif iDepth>iMaxDepth then 
		error(string.format('表嵌套层次达到%d层,可能是循环引用了',iDepth))
	end

	local sEndTab=string.rep('\t',iDepth)
	local sElmTab = sEndTab .. '\t'

	local lList={}
	for i=1,#t do --数组部分
		local sValue=serializeObj(t[i],tConfig,iDepth)
		local sText
		if bIsNewLine then
			sText=string.format('%s%s',sElmTab,sValue)
		else 
			sText=string.format('%s',sValue)
		end		
		table.insert (lList,sText)
	end

	local sTuple=''
	if next(lList)~=nil then
		if bIsNewLine then
			sTuple=table.concat(lList,',\n')
		else
			sTuple=table.concat(lList,',')
		end
	end
	---------------------------------
	local dHash={}
	for k,v in pairs(t) do
		if type(k)~='number' or k>#t then --hash部分
			local sKey=serializeKey(k,tConfig,iDepth)
			local sValue=serializeObj(v,tConfig,iDepth)

			local sText
			if bIsNewLine then
				sText=string.format('%s%s=%s',sElmTab,sKey,sValue)
			else 
				sText=string.format('%s=%s',sKey,sValue)
			end
			table.insert(dHash,sText)
		end
	end

	local sHash=''
	if next(dHash)~=nil then
		if bIsNewLine then
			sHash=table.concat(dHash,',\n')
		else
			sHash=table.concat (dHash,',')
		end	
	end
	
	if bIsNewLine then
		if sTuple~='' then
			sTuple=sTuple..',\n'--hash与tuple之间必定用换行分开
		end
		sResult=string.format('{\n%s%s\n%s}',sTuple,sHash,sEndTab)
	else
		if sTuple~='' then
			sTuple=sTuple..','--hash与tuple之间必定用换行分开
		end		
		sResult=string.format('{%s%s}',sTuple,sHash)
	end	

	return sResult

end


-- add by dingqitai 
--[[ 主要用于导出服务器表
特殊情况 1
将 
{
	{1,0,0,0,},
	{1,0,0,0,},
	{1,0,0,0,},
	{1,1,0,0,},
}
导出成 
	1,0,0,0,
	1,0,0,0,
	1,0,0,0,
	1,1,0,0,
]]
function serializeTableS1(tab)
	local output = ''
	--这里只用于特殊场景，顺序列表
	for i, v in ipairs(tab) do
		output = string.format('%s%s', output, table.concat(v, ','))
		output = output .. '\n'
	end
	return output
end


--测试数据

local tKey={
		aa=125,
		bb=4399,
		cc=9377,
	}

local t={
	45,345,345,654,645,6456,
	[987]=987,
	[tKey]={
		y=66,
		w=66
	},


	a=1,
 
	d={
		x=77,
		y=88,
		z=99,
		cc={
			aa=125,
			bb=4399,
			cc=9377,
			234,234,242,342342
		},
	},
	
	b=2,
	c=3,	
}

local tConfig={t,t.d,t.d.cc}
--print(serializeTable(t,tConfig))
