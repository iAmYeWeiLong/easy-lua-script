module('LoginPanel', package.seeall)
require('promise')
--空间公有变量声明-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
--空间私有变量声明-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
--空间辅助函数声明-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------

--类构造及初始化---------------------------------------------------------------------------------------------------------------

cLoginPanel = class.create(PanelView.cPanelView)
    -- cLoginPanel.PRINT_WIDGET_NAME=true --打印控件名(变量名),方便写代码用,用完要设为false,否则打印得眼花

   function cLoginPanel.onCreate(self,tArgs)
        self:addTextChangeListener()
        local account = cc.UserDefault:getInstance():getStringForKey("account", '')
        self.bRemember = cc.UserDefault:getInstance():getBoolForKey("rememberAll",true)
        self.accountTf:setString(account)
        if self.bRemember then
            local psw = cc.UserDefault:getInstance():getStringForKey("psw",'')
            self.pswTf:setString(psw)
        end
        if CC_OUTER_SERSER then
            self.serverBtn:setVisible(false)
        end
        self:refreshInputBox()
        self:refreshServerBtn()
        -- gSystemControl:connectServer()
    end
-------------------------------------------------------------------------------------------------------------------------------
--类事件响应部分---------------------------------------------------------------------------------------------------------------
    function cLoginPanel.onEnter( self )
        self:playBgMusic()
        gSignalMgr:addEventListener(GameEvent.EVENT_SWITCH_SERVER, 1, false, self, cLoginPanel.onCustomEvent)
    end

    function cLoginPanel.onExit(self)
        gSignalMgr:removeEventListener(GameEvent.EVENT_SWITCH_SERVER, 1, self, cLoginPanel.onCustomEvent)
    end

    --系统内部消息
    function cLoginPanel.onCustomEvent(self, event)
        if GameEvent.EVENT_SWITCH_SERVER == event.name then
            self:refreshServerBtn()
        end
    end

local function asynchronous(resolve, reject,sFlag)
    error('[error from asynchronous]')
    local iSchedulerId
    local function timeout()
        --error('[error from timeout]')
        --print('timeout..',sFlag)
        cc.Director:getInstance():getScheduler():unscheduleScriptEntry(iSchedulerId)
        resolve(sFlag)
    end
    iSchedulerId=cc.Director:getInstance():getScheduler():scheduleScriptFunc(timeout,3,false)   
end

local function func1(...)
    print('func1 recv=',...)
    --local oPromise=promise.cPromise(util.functor(asynchronous,'func1_return_value1'),'func1_return_value2') --local
    --error('aaaa')
    --return oPromise
    return 'func1_return_value1','func1_return_value2'
end
local function func2(...)
    print('func2 recv=',...)
    -- local oPromise=promise.cPromise(util.functor(asynchronous,'func2_return_value'),'func2_return_value2') --local   
    -- return oPromise

   --return 'func2_return_value1','func2_return_value2'
end

local function func3(...)
    print('func3 recv=',...)
    --local oPromise=promise.cPromise(util.functor(asynchronous,'func3_return_value')) --local   
    --return oPromise    
    return 'func3_return_value1'
end

local function errorRecv(...)
    local tError=...
    --u.reRaise(tError,'[errorRecv error]')
   -- print('in errorRecv')
    --u.reRaise(tError)
    --error('error from errorRecv')
    --print('errorRecv =',...)
    
    print(string.format('errorRecv =%s  %s',tError[1],tError[2]))
end
local function errorRecv2(...)
    local tError=...
    --error('[error from errorRecv2]')

    --print('errorRecv2 =',...)
    
    print(string.format('errorRecv2 =%s  %s',tError[1],tError[2]))
end

local function errorRecv3(...)
    --error('error from errorRecv3')

    --print('errorRecv3 =',...)
    local tError=...
    print(string.format('errorRecv3 =%s  %s',tError[1],tError[2]))
end

local function throwFunc()
    --print('in throwFunc')
    error('fuck')

end

local function newPromise(...)
    local oPromise=promise.cPromise(...)
    return oPromise:catch(errorRecv)

end
    function cLoginPanel.onClicked(self, sender)
        print('--------------------------------')
        if sender  == self.loginBtn then
            if nil==u.getAttr(_G,'oPromise') then
                _G.oPromise=promise.cPromise(util.functor(asynchronous,'self.loginBtn '),'extra value'):next(func1,errorRecv):next(func2,errorRecv2):next(func3,errorRecv3) --local
                --_G.oPromise=newPromise(util.functor(asynchronous,'self.loginBtn '),'extra value1','extra value2')
            --else
                
            end
            --oPromise:next(func1)
            --oPromise:catch(errorRecv)
            -- 
            --:next():next()
            --oPromise:next(func1):next(func2):next(func3):catch(errorRecv) --:catch(errorRecv) --
            --oPromise:next(throwFunc):catch(errorRecv):catch(errorRecv2):catch(errorRecv3)--
            --oPromise:next(func1):next(func2):next(func3):catch(errorRecv) --:catch(errorRecv) --
            
            --oPromise:next(func2)--:catch(errorRecv) --:next(func3)
            --oPromise:next(func2)

            do
                return
            end


            local account = self.accountTf:getString() ~= '' and self.accountTf:getString() or cc.UserDefault:getInstance():getStringForKey("account", '')            
            local psw = self.pswTf:getString() ~= '' and self.pswTf:getString() or  cc.UserDefault:getInstance():getStringForKey("psw",'')
            if self.bRemember then
                cc.UserDefault:getInstance():setStringForKey("account", account)
                cc.UserDefault:getInstance():setStringForKey("psw", psw)
            end
            gSystemControl:connectServer()
			--gShowLoadingPanel('Loading', true)
            gEndPoint.rpcAccountLogin(account ,'1000',2,'123','adf','asdf'):openIndicator()
        elseif sender == self.serverBtn then
            
            -- _G.oPromise=promise.cPromise(util.functor(asynchronous,'self.serverBtn '))--local
            
            -- _G.oPromise:next(func1):next(func2)--:catch(catch)


            do
                return
            end


            local clsNode = ViewManager:createPanel('ServerPanel')     
            ViewManager:addPanel(display.getRunningScene(), clsNode, true)
        end
    end

    function cLoginPanel.onTextChange(self, event)
        if event.name == 'changed' then
            self:refreshInputBox(event.sender)
        end
    end
-------------------------------------------------------------------------------------------------------------------------------

--类数据操作部分---------------------------------------------------------------------------------------------------------------
    function cLoginPanel.addTextChangeListener( self )
        self.accountTf:onEditHandler(u.bindMethod(cLoginPanel.onTextChange, self))
        self.pswTf:onEditHandler(u.bindMethod(cLoginPanel.onTextChange, self))
    end

-------------------------------------------------------------------------------------------------------------------------------

--类显示部分-------------------------------------------------------------------------------------------------------------------
    function cLoginPanel.refreshInputBox( self)
        local text = self.pswTf:getString()
        if text == '' then
            self.mmtishiTxt:setVisible(true)
        else
            self.mmtishiTxt:setVisible(false)
        end
        text = self.accountTf:getString()
        if text == '' then
            self.zhtishiTxt:setVisible(true)
        else
            self.zhtishiTxt:setVisible(false)
        end
    end

    function cLoginPanel.refreshServerBtn(self)
        self.serverTxt:setString(currentServer.name)
    end
-------------------------------------------------------------------------------------------------------------------------------

--类辅助函数-------------------------------------------------------------------------------------------------------------------
    function cLoginPanel.playBgMusic( self )
        gSignalMgr:dispatchEvent(zfm.audioEvent(GameEvent.EVENT_AUDIO_PLAY_MUSIC, 'login', true))
    end
-------------------------------------------------------------------------------------------------------------------------------

--类的协议回调部分-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------

--类的服务器下行数据处理部分---------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
