package.path = package.path .. ';easyLuaScript/?.lua'
package.path = package.path .. ';easyLuaScript/?/init.lua'

package.path = package.path .. ';code/simulator/?.lua'
package.path = package.path .. ';code/simulator/?/init.lua'





local THIS_NAME='main'
_ENV=require('base').module(THIS_NAME)

require('class')
require('application')

local cApplication=class.create(application.cApplication)
local c=cApplication
	function c.execute(self)
		require("luasocketClient")
		luasocketClient.startClient()
	end --execute

_G.app=cApplication()
_G.app:execute()


require('util')