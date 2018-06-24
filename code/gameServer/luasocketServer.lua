--[[	作者:叶伟龙@龙川县赤光镇
--]]
_ENV=require('base').module(...)
require('class')
local unpack=table.unpack or unpack  --各lua版本兼容


function startServer( ... )
	local socket_core=require("socket.core")
	local socket=socket_core.tcp()
	local host = "127.0.0.1";
	local port = 8383;

	local server = assert(socket:bind('*', port));
	socket:listen(50)
	local ack = "ack\n";
	while 1 do
		print("server: waiting for client connection...");
		local control = assert(socket:accept());
		print('getsoetname==',control:getsockname())
		while 1 do 
			local command,status = control:receive();
			if status == "closed" then 
				break
			end
			print(command);
			control:send(ack);
		end
	end
end

require('util')