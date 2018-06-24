--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)

require('class')
local unpack=table.unpack or unpack  --各lua版本兼容


function startClient( ... )
	local socket = require("socket.core")
	 
	local host,port = "127.0.0.1",8383
	--local host,port = "192.168.1.102",8383
	--local port = 8383
	local sock = assert(socket.connect(host, port))
	print('getpeername',sock:getpeername())
	sock:settimeout(0)
	  
	print("Press enter after input something:")
	 
	local input, recvt, sendt, status
	while true do
	    input = io.read()
	    if #input > 0 then
	        assert(sock:send(input .. "\n"))
	    end
	     
	    recvt, sendt, status = socket.select({sock}, nil, 1)
	    while #recvt > 0 do
	        local response, receive_status = sock:receive()
	        if receive_status ~= "closed" then
	            if response then
	                print(response)
	                recvt, sendt, status = socket.select({sock}, nil, 1)
	            end
	        else
	            break
	        end
	    end--while
	end--while
end

require('util')