-- m7md e
---
--- Created by Jimmy.
--- DateTime: 2018/10/9 0009 15:02
---
function onChatHandler(name, ...)

end

function onNotificationHandler(notificationData)
    local notification = json.decode(notificationData)
    Events.OnNotificationHandlerEvent:invoke(notification)
end

function onAdLoaded(adUnitId, status)

end

function onShowAdResult(adUnitId, result)

end

require "engine_base.Base"
require "engine_client.define.CDefine"
require "engine_client.define.GUIDefine"
require "engine_client.util.ClientHelper"
require "engine_client.util.DynamicCast"
require "engine_client.util.MemoryPool"
require "engine_client.util.MsgSender"
require "engine_client.util.PayHelper"
require "engine_client.util.SoundUtil"
require "engine_client.util.Lang"
require "engine_client.util.DressUtil"
require "engine_client.util.CameraUtil"
require "engine_client.util.RecorderUtil"
require "engine_client.util.Quality"
require "engine_client.entity.IEntity"
require "engine_client.entity.EntityCache"
require "engine_client.event.CommonDataEvents"
require "engine_client.event.GameEvents"
require "engine_client.analytics.GameAnalytics"
require "engine_client.analytics.GameAnalyticsCache"
require "engine_client.web.WebService"
require "engine_client.listener.Listener"
require "engine_client.listener.BaseListener"
require "engine_client.data.EngineWorld"
require "engine_client.data.PlayerWallet"
require "engine_client.data.BasePlayer"
require "engine_client.data.BaseProperty"
require "engine_client.ui.UIHelper"
require "engine_client.ui.UIAnimation"
require "engine_client.ui.GUIManager"
require "engine_client.ui.IGUIBase"
require "engine_client.ui.IGUIWindow"
require "engine_client.ui.IGUILayout"
require "engine_client.ui.IGUIDataView"
require "engine_client.ui.IGUIGridView"
require "engine_client.ui.IGUIListView"
require "engine_client.ui.adapter.IDataAdapter"
require "engine_client.Game"
require "engine_client.packet.PacketSender"
require "engine_client.packet.PidPacketHandler"
require "engine_client.packet.PidPacketSender"
require "engine_client.manager.PlayerManager"
require "engine_client.manager.ClickAreaMgr"
require "engine_client.helper.MaxRecordHelper"
require "engine_client.helper.FollowPlayerHelper"
require "engine_client.helper.GMHelper"
require "engine_client.cache.SharePreferences"

BaseListener:init()
WebService:init()

BaseMain = {}
BaseMain.GameType = "g1001"

function BaseMain:setGameType(GameType)
    self.GameType = GameType
end

function BaseMain:getGameType()
    return self.GameType
end

CommonDataEvents:registerCallBack("ServerInfo", function(data)
    PacketSender:init()
    isStaging = data:getBoolParam("isStaging")
    local isChina = data:getBoolParam("isChina")
    local regionId = data:getNumberParam("regionId")
    local gameId = data:getParam("gameId")
    local serverOsTime = data:getNumberParam("serverOsTime")
    Root.Instance():setChina(isChina)
    Game:setRegionId(regionId)
    Game:setGameId(gameId)
    if serverOsTime > 0 then
        BaseMain:fixOsTime(serverOsTime - os.time())
    end
end, DataBuilderProcessor)

CommonDataEvents:registerCallBack("SyncPlayerName", function(data)
    local trySetName
    trySetName = function(userId, name, times)
        times = times or 60
        if times <= 0 then
            return
        end
        local user = UserManager.Instance():findUser(userId)
        if user then
            UserInfoCache:UpdateUserInfos({ { userId = userId, nickName = name } })
            user.userName = name
        else
            LuaTimer:schedule(function()
                trySetName(userId, name, times - 1)
            end, 1000)
        end
    end
    trySetName(data.userId, data.name, 60)
end, JsonBuilderProcessor)

function BaseMain:fixOsTime(serverTs)
    print("fixOsTime, serverTs =", serverTs)
    if math.abs(serverTs) < 10 then
        return
    end
    local oldOsTime = os.time
    os.time = function(table)
        if table then
            return oldOsTime(table)
        end
        return oldOsTime() + serverTs
    end
end

local oldSetImage = GUIStaticImage.SetImage
local oldSetDefaultImage = GuiUrlImage.setDefaultImage
local oldGetSkillTimeLength = ActorObject.GetSkillTimeLength
local oldActorWndSetActor1 = GuiActorWindow.SetActor1

GUIStaticImage.hasReportErrorSetImage = false
GuiUrlImage.hasReportErrorsetDefaultImage = false
ActorObject.hasReportNullObject = false


local function newActorWndSetActor1(actorWnd, actorName, actionName, rotate)
    local oldActorName = actorWnd:GetActorName()
    if actorName == oldActorName then
         local oldActor = actorWnd:GetActor()
         if oldActor and not oldActor:getHasInited() then -- 防止actor没有init 就调用skill
            print("play skill use set actor find invalid actor: "..actorName)
            return
         end
    end
    oldActorWndSetActor1(actorWnd, actorName, actionName, rotate)
end

local function newGetSkillTimeLength(actor, param)
    if not actor then
        if not ActorObject.hasReportNullObject  then 
            local reportContent = "GetSkillTimeLength has null actor "..debug.traceback("Stack trace")
            HostApi.reportError(reportContent)
            local reportData = {}
            reportData["no_download_res"] = reportContent
            reportData["download_not_suc_res"] = ""
            reportData["download_result"] = 0
            local strReportData = json.encode(reportData)
            HostApi.dataReport("important_res_download_info", strReportData)
            ActorObject.hasReportNullObject = true
        end

        return 3000
    end

    if not actor:getHasInited() then
        return 3000
    end

    local time = oldGetSkillTimeLength(actor, param)
    return time
end

local function newSetImage(imgGui, param)
    if  BaseListener:GetIsDestroyed()  then
        if  not GUIStaticImage.hasReportErrorSetImage then
            local reportContent = "SetImage Destroy "..debug.traceback("Stack trace")
            HostApi.reportError(reportContent)
            local reportData = {}
            reportData["no_download_res"] = reportContent
            reportData["download_not_suc_res"] = ""
            reportData["download_result"] = 0
            local strReportData = json.encode(reportData)
            HostApi.dataReport("important_res_download_info", strReportData)
            GUIStaticImage.hasReportErrorSetImage = true
        end
        return
    else 
     oldSetImage(imgGui, param)
    end
end

local function newSetDefaultImage(imgGui, param)
    if  BaseListener:GetIsDestroyed()  then
        if not GuiUrlImage.hasReportErrorsetDefaultImage  then 
            local reportContent = "setDefaultImage Destroy "..debug.traceback("Stack trace")
            HostApi.reportError(reportContent)
            local reportData = {}
            reportData["no_download_res"] = reportContent
            reportData["download_not_suc_res"] = ""
            reportData["download_result"] = 0
            local strReportData = json.encode(reportData)
            HostApi.dataReport("important_res_download_info", strReportData)
            GuiUrlImage.hasReportErrorsetDefaultImage = true
        end
        return
    else 
        oldSetDefaultImage(imgGui, param)
    end
end

GUIStaticImage.SetImage = newSetImage
GuiUrlImage.setDefaultImage = newSetDefaultImage
ActorObject.GetSkillTimeLength =  newGetSkillTimeLength
GuiActorWindow.SetActor1 = newActorWndSetActor1

require "engine_client.connector.ConnectorCenter"












UIGMControlPanel = require("engine_client.ui.layout.GUIGMControlPanel")
	


function Game:init()
local Color = {}
Color.RED = {1, 0, 0, 0.7}

local button0098Button = GUIManager:getWindowByName("Main-Attack-Btn")
            button0098Button:SetWidth({ 0, 150 })
            button0098Button:SetHeight({ 0, 150 })
            button0098Button:SetXPosition({ 0, -1240 })
            button0098Button:SetYPosition({ 0, -370 })
            button0098Button:registerEvent(GUIEvent.TouchMove, function()
            LuaTimer:scheduleTimer(function()
            CGame.Instance():handleTouchClick(1204, 540)
            end, 40, 10)
            end)
local x = {0.1, 0}
          local y = {0, 0}
          LuaTimer:scheduleTimer(function()
          PlayerManager:getClientPlayer().Player.noClip = false
          end, 1000, -1)
       



    
    

        
   
  
    
      
    
 
        
     
     
        
    
 

local raketButton = GUIManager:createGUIWindow(GUIType.Button, "RaketButton")
raketButton:SetHorizontalAlignment(HorizontalAlignment.Left) 
raketButton:SetVerticalAlignment(VerticalAlignment.Center)   
raketButton:SetHeight({ 0, 50 })    
raketButton:SetWidth({ 0, 180 })    
raketButton:SetTextColor({ 0, 0, 0 }) 
raketButton:SetText("^000000Raket") 
raketButton:SetTouchable(true)


raketButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local function toggleRaketVisibility()
    local raketWindow = GUIManager:getWindowByName("Main-BuildWar-Block")
    if raketWindow then
        local isVisible = raketWindow:IsVisible()
        raketWindow:SetVisible(not isVisible) 

        
        if isVisible then
            
            raketButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
            raketButton:SetText("^000000Raket") 
            UIHelper.showToast("^FF0000Raket Hidden")
        else
            
            raketButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
            raketButton:SetText("^000000Raket") 
            UIHelper.showToast("^00FF00Raket Visible")
        end
    end
end


raketButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleRaketVisibility()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(raketButton)


raketButton:SetVisible(false)  
raketButton:SetXPosition({ 0, 620 }) 
raketButton:SetYPosition({ 0, -80 }) 


          
local DpadJumpButton = GUIManager:createGUIWindow(GUIType.Button, "DpadJumpButton")
DpadJumpButton:SetHorizontalAlignment(HorizontalAlignment.Left)
DpadJumpButton:SetVerticalAlignment(VerticalAlignment.Center)
DpadJumpButton:SetHeight({ 0, 50 })
DpadJumpButton:SetWidth({ 0, 180 })
DpadJumpButton:SetTextColor({ 0, 0, 0 })
DpadJumpButton:SetText("^000000DpadJump")
DpadJumpButton:SetTouchable(true)

DpadJumpButton:SetBackgroundColor({ 0, 0, 0, 0.7 })

local dpadJumpActive = false


local function toggleDpadJump()
    if dpadJumpActive then
        
        ClientHelper.putBoolPrefs("UseCenterJumpButton", false)
        DpadJumpButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        DpadJumpButton:SetText("^000000DpadJump")
    else
        
        ClientHelper.putBoolPrefs("UseCenterJumpButton", true)
        DpadJumpButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        DpadJumpButton:SetText("^000000DpadJump")
    end
    dpadJumpActive = not dpadJumpActive
end

DpadJumpButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleDpadJump()
end)

GUISystem.Instance():GetRootWindow():AddChildWindow(DpadJumpButton)

DpadJumpButton:SetVisible(false)
DpadJumpButton:SetXPosition({ 0, 620 })
DpadJumpButton:SetYPosition({ 0, -140 })  


local AutoBridgeButton = GUIManager:createGUIWindow(GUIType.Button, "AutoBridgeButton")
AutoBridgeButton:SetHorizontalAlignment(HorizontalAlignment.Left) 
AutoBridgeButton:SetVerticalAlignment(VerticalAlignment.Center)   
AutoBridgeButton:SetHeight({ 0, 50 })    
AutoBridgeButton:SetWidth({ 0, 180 })    
AutoBridgeButton:SetTextColor({ 0, 0, 0 }) 
AutoBridgeButton:SetText("^000000AutoBridge") 
AutoBridgeButton:SetTouchable(true)


AutoBridgeButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local autoBridgeActive = false
local bridgeTimer = nil 


local function startAutoBridge()
    if bridgeTimer then
        LuaTimer:cancel(bridgeTimer) 
    end

    bridgeTimer = LuaTimer:scheduleTimer(function()
        local clientPlayer = PlayerManager:getClientPlayer()
        if not clientPlayer then return end

        
        local heldBlock = clientPlayer.Player:getHeldItemId()
        if heldBlock == nil or heldBlock == 0 then
            LuaTimer:cancel(bridgeTimer) 
            UIHelper.showToast("^FF0000You must hold a block!")
            return
        end

        local pos = clientPlayer:getPosition()
        local yaw = clientPlayer.Player:getYaw() * math.pi / 180 

        
        local dx = math.abs(math.sin(yaw)) > math.abs(math.cos(yaw)) and -math.sin(yaw) or 0
        local dz = math.abs(math.cos(yaw)) >= math.abs(math.sin(yaw)) and math.cos(yaw) or 0

        
        dx = dx ~= 0 and (dx > 0 and 1 or -1) or 0
        dz = dz ~= 0 and (dz > 0 and 1 or -1) or 0

        
        local belowPlayerPos = VectorUtil.newVector3(
            math.floor(pos.x),
            math.floor(pos.y - 2),
            math.floor(pos.z)
        )
        EngineWorld:setBlock(belowPlayerPos, heldBlock)

        
        for i = 1, 3 do 
            local targetPos = VectorUtil.newVector3(
                math.floor(pos.x + dx * i),
                math.floor(pos.y - 2),
                math.floor(pos.z + dz * i)
            )
            EngineWorld:setBlock(targetPos, heldBlock)
            
        end
    end, 10, -1) 
end


local function toggleAutoBridge()
    if autoBridgeActive then
        
        if bridgeTimer then LuaTimer:cancel(bridgeTimer) end
        AutoBridgeButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        AutoBridgeButton:SetText("^000000AutoBridge") 
    else
        
        startAutoBridge()
        AutoBridgeButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        AutoBridgeButton:SetText("^000000AutoBridge") 
    end
    autoBridgeActive = not autoBridgeActive
end


AutoBridgeButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleAutoBridge()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(AutoBridgeButton)


AutoBridgeButton:SetVisible(false)  
AutoBridgeButton:SetXPosition({ 0, 620 }) 
AutoBridgeButton:SetYPosition({ 0, -200 }) 


local FastClickerButton = GUIManager:createGUIWindow(GUIType.Button, "FastClickerButton")
FastClickerButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
FastClickerButton:SetVerticalAlignment(VerticalAlignment.Center)    
FastClickerButton:SetHeight({ 0, 50 })    
FastClickerButton:SetWidth({ 0, 180 })    
FastClickerButton:SetText("SkyroyalePoints")  
FastClickerButton:SetTextColor({ 0, 0, 0, 1 }) 
FastClickerButton:SetTouchable(true)


FastClickerButton:SetBackgroundColor({ 0, 0, 0, 0.7 })


local packetCount = 0
local fastClickerTimer = nil
local isFastClickerActive = false


local function executeFastClicker()
    if isFastClickerActive then
        UIHelper.showToast("FastClicker já está ativo!")
        return
    end

    packetCount = 0 
    isFastClickerActive = true

    fastClickerTimer = LuaTimer:scheduleTimer(function()
        local clientPlayer = PlayerManager:getClientPlayer()
        if clientPlayer then
            for i = 1, 3 do
                clientPlayer:sendPacket({ pid = "onWatchAdSuccess", type = 1, params = 1 })
                clientPlayer:sendPacket({ pid = "onClickVipRespawn" })
                packetCount = packetCount + 1
            end
            UIHelper.showToast("Pontos Ganhos: " .. packetCount)
        else
            UIHelper.showToast("Nenhum jogador encontrado para enviar os pacotes!")
        end
    end, 10.15, -1)
end


local function stopFastClicker()
    if fastClickerTimer then
        LuaTimer:cancelTimer(fastClickerTimer)
        fastClickerTimer = nil
        isFastClickerActive = false
        UIHelper.showToast("FastClicker desativado!")
    else
        UIHelper.showToast("FastClicker já está desativado!")
    end
end


FastClickerButton:registerEvent(GUIEvent.ButtonClick, function()
    if isFastClickerActive then
        stopFastClicker()
        FastClickerButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
    else
        executeFastClicker()
        FastClickerButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
    end
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(FastClickerButton)


FastClickerButton:SetVisible(false)
FastClickerButton:SetXPosition({ 0, 620 })   
FastClickerButton:SetYPosition({ 0, -260 }) 
local NoFallDamageButton = GUIManager:createGUIWindow(GUIType.Button, "NoFallDamageButton")
NoFallDamageButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
NoFallDamageButton:SetVerticalAlignment(VerticalAlignment.Center)    
NoFallDamageButton:SetHeight({ 0, 50 })    
NoFallDamageButton:SetWidth({ 0, 180 })    
NoFallDamageButton:SetTextColor({ 0, 0, 0 }) 
NoFallDamageButton:SetText("^000000NoFallDamage") 
NoFallDamageButton:SetTouchable(true)


NoFallDamageButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local noFallDamageEnabled = false
local noFallDamageTimer = nil
local previousY = nil


local FALL_TOLERANCE = 1.5  


local function toggleNoFallDamage()
    noFallDamageEnabled = not noFallDamageEnabled

    if noFallDamageEnabled then
        
        NoFallDamageButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        UIHelper.showToast("No Fall Damage: On")

        
        if not noFallDamageTimer then
            noFallDamageTimer = LuaTimer:scheduleTimer(function()
                local clientPlayer = PlayerManager:getClientPlayer().Player
                local currentPos = clientPlayer:getPosition()
                local currentY = currentPos.y

                
                if not previousY then
                    previousY = currentY
                end

                
                if currentY < previousY - FALL_TOLERANCE then
                    clientPlayer.noClip = true
                else
                    
                    clientPlayer.noClip = false
                end

                
                previousY = currentY
            end, 100, -1) 
        end
    else
        
        NoFallDamageButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        UIHelper.showToast("No Fall Damage: Off")

        
        if noFallDamageTimer then
            LuaTimer:cancel(noFallDamageTimer)
            noFallDamageTimer = nil
        end

        
        PlayerManager:getClientPlayer().Player.noClip = false
        previousY = nil
    end
end


NoFallDamageButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleNoFallDamage()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(NoFallDamageButton)


NoFallDamageButton:SetVisible(false)  
NoFallDamageButton:SetXPosition({ 0, 420 }) 
NoFallDamageButton:SetYPosition({ 0, 220 }) 



local UndeadButton = GUIManager:createGUIWindow(GUIType.Button, "UndeadButton")
UndeadButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
UndeadButton:SetVerticalAlignment(VerticalAlignment.Center)    
UndeadButton:SetHeight({ 0, 50 })    
UndeadButton:SetWidth({ 0, 180 })    
UndeadButton:SetTextColor({ 0, 0, 0 }) 
UndeadButton:SetText("^000000Undead") 
UndeadButton:SetTouchable(true)


UndeadButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local togRespawnInSamePlace = false
local respawnCallback = nil


local function toggleUndead()
    togRespawnInSamePlace = not togRespawnInSamePlace

    if not togRespawnInSamePlace and respawnCallback then
        
        CEvents.LuaPlayerDeathEvent:unregisterCallBack(respawnCallback)
        respawnCallback = nil
        UIHelper.showToast("Undead : Off")
        UndeadButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        UndeadButton:SetText("^000000Undead") 
        return
    end

    if togRespawnInSamePlace then
        
        respawnCallback = function(deadPlayer)
            if deadPlayer == CGame.Instance():getPlatformUserId() then
                LuaTimer:scheduleTimer(function()
                    ClientHelper.putBoolPrefs("SyncClientPositionToServer", true)
                end, 1, 1000)

                local playerPosition = PlayerManager:getClientPlayer().Player:getPosition()
                local yaw = PlayerManager:getClientPlayer().Player:getYaw()
                local pitch = PlayerManager:getClientPlayer().Player:getPitch()

                LuaTimer:scheduleTimer(function()
                    PacketSender:getSender():sendRebirth()
                    
                    local player = PlayerManager:getClientPlayer().Player
                    player:setAllowFlying(false)
                    player:setFlying(false)

                    LuaTimer:schedule(function()
                        setPosTest(VectorUtil.newVector3(playerPosition.x, playerPosition.y, playerPosition.z))
                    end, 400)
                end, 1, 300)

                RootGuiLayout.Instance():showMainControl()
            end
        end

        CEvents.LuaPlayerDeathEvent:registerCallBack(respawnCallback)
        UIHelper.showToast("Undead : On")
        UndeadButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        UndeadButton:SetText("^000000Undead") 
    end
end


UndeadButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleUndead()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(UndeadButton)


UndeadButton:SetVisible(false)  
UndeadButton:SetXPosition({0, 420}) 
UndeadButton:SetYPosition({0, 160}) 


local AntiVoidButton = GUIManager:createGUIWindow(GUIType.Button, "AntiVoidButton")
AntiVoidButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
AntiVoidButton:SetVerticalAlignment(VerticalAlignment.Center)    
AntiVoidButton:SetHeight({ 0, 50 })    
AntiVoidButton:SetWidth({ 0, 180 })    
AntiVoidButton:SetTextColor({ 0, 0, 0 }) 
AntiVoidButton:SetText("^000000AntiVoid") 
AntiVoidButton:SetTouchable(true)


AntiVoidButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local antiVoidEnabled = false
local antiVoidTimer = nil
local originalPos = nil
local savePositionTimer = nil


local function toggleAntiVoid()
    antiVoidEnabled = not antiVoidEnabled

    if antiVoidEnabled then
        
        AntiVoidButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        UIHelper.showToast("Anti Void: On")

        
        if not antiVoidTimer then
            antiVoidTimer = LuaTimer:scheduleTimer(function()
                local clientPlayer = PlayerManager:getClientPlayer().Player
                local currentPos = clientPlayer:getPosition()
                local fallDistance = clientPlayer.fallDistance

                
                if fallDistance == 0 then
                    if not originalPos then
                        originalPos = currentPos
                    end
                end

                
                if fallDistance >= 10 and originalPos then
                    clientPlayer:setPosition(originalPos)
                end
            end, 100, -1) 
        end

        
        if not savePositionTimer then
            savePositionTimer = LuaTimer:scheduleTimer(function()
                local clientPlayer = PlayerManager:getClientPlayer().Player
                local fallDistance = clientPlayer.fallDistance
                
                if fallDistance == 0 then
                    originalPos = clientPlayer:getPosition() 
                end
            end, 5000, -1) 
        end
    else
        
        AntiVoidButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        UIHelper.showToast("Anti Void: Off")

        
        if antiVoidTimer then
            LuaTimer:cancel(antiVoidTimer)
            antiVoidTimer = nil
        end

        
        if savePositionTimer then
            LuaTimer:cancel(savePositionTimer)
            savePositionTimer = nil
        end

        originalPos = nil
    end
end


AntiVoidButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleAntiVoid()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(AntiVoidButton)


AntiVoidButton:SetVisible(false)  
AntiVoidButton:SetXPosition({ 0, 420 }) 
AntiVoidButton:SetYPosition({ 0, 100 }) 






local ReachBypassButton = GUIManager:createGUIWindow(GUIType.Button, "ReachBypassButton")
ReachBypassButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
ReachBypassButton:SetVerticalAlignment(VerticalAlignment.Center)    
ReachBypassButton:SetHeight({ 0, 50 })    
ReachBypassButton:SetWidth({ 0, 180 })    
ReachBypassButton:SetTextColor({ 0, 0, 0 }) 
ReachBypassButton:SetText("^000000ReachBypass") 
ReachBypassButton:SetTouchable(true)


ReachBypassButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local reachBypassActive = false
local toggleAttackBypass = true
local savedPosition = nil


local function savePosition()
    local player = PlayerManager:getClientPlayer().Player
    savedPosition = player:getPosition()
end

local function teleportToEntity(entityPosition)
    local player = PlayerManager:getClientPlayer().Player
    player:setPosition(entityPosition)
end

local function teleportBack()
    if savedPosition then
        local player = PlayerManager:getClientPlayer().Player
        player:setPosition(savedPosition)
    end
end


local function registerAttackBypass()
    CEvents.AttackEntityEvent:registerCallBack(function(djjd)
        if not toggleAttackBypass then return end

        local entity = PlayerManager:getPlayerByEntityId(djjd)
        if entity then
            savePosition()
            ClientHelper.putBoolPrefs("SyncClientPositionToServer", true)

            
            local entityPosition = entity:getPosition()
            teleportToEntity(entityPosition)
            entity.height = 3.0
                entity.width = 3.0
                entity.length = 3.0
            
            local initialHP = entity:getHP()
            LuaTimer:scheduleTimer(function()
                if entity:getHP() < initialHP then
                    teleportBack()
                    ClientHelper.putBoolPrefs("SyncClientPositionToServer", false)
                    entity.height = 1.8
                entity.width = 0.6
                entity.length = 0.6
                end
            end, 1, 300) 
        end
    end)
end


local function toggleReachBypass()
    if reachBypassActive then
        
        toggleAttackBypass = false
        ReachBypassButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
	ClientHelper.putFloatPrefs("EntityReachDistance", 5)
        ReachBypassButton:SetText("^000000ReachBypass") 
        UIHelper.showToast("ReachBypass: Off")
    else
        
        toggleAttackBypass = true
        ReachBypassButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        ReachBypassButton:SetText("^000000ReachBypass") 
        UIHelper.showToast("ReachBypass: On")
        ClientHelper.putFloatPrefs("EntityReachDistance", 999)
        registerAttackBypass()
    end
    reachBypassActive = not reachBypassActive
end


ReachBypassButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleReachBypass()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(ReachBypassButton)


ReachBypassButton:SetVisible(false)  
ReachBypassButton:SetXPosition({ 0, 420 }) 
ReachBypassButton:SetYPosition({ 0, 40 }) 




local fpsPingButton = GUIManager:createGUIWindow(GUIType.Button, "FpsPingButton")
fpsPingButton:SetHorizontalAlignment(HorizontalAlignment.Left)
fpsPingButton:SetVerticalAlignment(VerticalAlignment.Center)
fpsPingButton:SetHeight({ 0, 50 })  
fpsPingButton:SetWidth({ 0, 180 })  
fpsPingButton:SetTextColor({ 0, 0, 0 })  
fpsPingButton:SetText("^000000Fps|Ping")  
fpsPingButton:SetTouchable(true)
fpsPingButton:SetBackgroundColor({ 0, 0, 0, 0.7 })  


local showFpsPing = false
local hue = 0
local fpsTextWindow


local function interpolateColor(hue)
    local r, g, b = 0, 0, 0
    if hue < 60 then
        r, g, b = 1, hue / 60, 0
    elseif hue < 120 then
        r, g, b = (120 - hue) / 60, 1, 0
    elseif hue < 180 then
        r, g, b = 0, 1, (hue - 120) / 60
    elseif hue < 240 then
        r, g, b = 0, (240 - hue) / 60, 1
    elseif hue < 300 then
        r, g, b = (hue - 240) / 60, 0, 1
    else
        r, g, b = 1, 0, (360 - hue) / 60
    end
    return r, g, b
end


local function updateFpsPing()
    local fps = Root.Instance():getFPS()
    local ping = ClientNetwork.Instance():getRaknetPing()
    local players = #PlayerManager:getPlayers() 
    
    local displayText = "Fps: " .. fps .. " | Ping: " .. ping .. " | Players: " .. players
    fpsTextWindow:SetText(displayText)

    hue = (hue + 0.5) % 360
    local r, g, b = interpolateColor(hue)
    fpsTextWindow:SetTextColor({ r, g, b, 0.6 })
end


local function toggleFpsPing()
    showFpsPing = not showFpsPing
    if showFpsPing then
        if not fpsTextWindow then
            
            fpsTextWindow = GUIManager:createGUIWindow(GUIType.StaticText, "GUIRoot-FpsPingText")
            fpsTextWindow:SetWidth({ 0, 180 })
            fpsTextWindow:SetHeight({ 0, 50 })
            fpsTextWindow:SetXPosition({ 0, 15 })
            fpsTextWindow:SetYPosition({ 0, 680 })
            fpsTextWindow:SetBordered(true)
            fpsTextWindow:SetTouchable(false)
            fpsTextWindow:SetVisible(true)
            GUISystem.Instance():GetRootWindow():AddChildWindow(fpsTextWindow)
        end
        
        fpsTextWindow:SetVisible(true)
        LuaTimer:scheduleTimer(updateFpsPing, 100, -1)
        UIHelper.showToast("FPS|Ping|Players Display Enabled")
        fpsPingButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70) 
    else
        if fpsTextWindow then
            fpsTextWindow:SetVisible(false)
        end
        UIHelper.showToast("FPS|Ping|Players Display Disabled")
        fpsPingButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        SoundUtil.playSound(70) 
    end
end


fpsPingButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleFpsPing()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(fpsPingButton)
fpsPingButton:SetVisible(false)
fpsPingButton:SetXPosition({0, 420})  
fpsPingButton:SetYPosition({0, -20})  




local webPortedButton = GUIManager:createGUIWindow(GUIType.Button, "WebPortedButton")
webPortedButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
webPortedButton:SetVerticalAlignment(VerticalAlignment.Center)    
webPortedButton:SetHeight({ 0, 50 }) 
webPortedButton:SetWidth({ 0, 180 }) 
webPortedButton:SetTextColor({ 0, 0, 0 }) 
webPortedButton:SetText("^000000WebPorted") 
webPortedButton:SetTouchable(true)
webPortedButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local webPortedActive = false
local autoClickActive = false
local timerAutoClick = nil
local timerDetection = nil 
local checkInterval = 50 
local proximityInterval = 70 
local detectionRadius = 8 
local closePlayersDetected = false






local function detectClosePlayers()
    local players = PlayerManager:getPlayers()
    local clientPlayer = PlayerManager:getClientPlayer()
    local clientTeamId = clientPlayer:getTeamId()
    local nearestPlayer = nil
    local nearestDistance = detectionRadius^2

    if GameType == "g1401" then
        local validTargetTeams = {}
        if clientTeamId == 1 then
            validTargetTeams = { 2 }
        elseif clientTeamId == 2 then
            validTargetTeams = { 1 }
        elseif clientTeamId == 3 then
            validTargetTeams = { 1 }
        end

        for _, player in pairs(players) do
            if player ~= clientPlayer then
                local playerTeamId = player:getTeamId()
                if playerTeamId ~= clientTeamId and table.contains(validTargetTeams, playerTeamId) then
                    local distance = MathUtil:distanceSquare3d(player:getPosition(), clientPlayer:getPosition())
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    else
        for _, player in pairs(players) do
            if player ~= clientPlayer then
                local playerTeamId = player:getTeamId()
                if playerTeamId ~= clientTeamId then
                    local distance = MathUtil:distanceSquare3d(player:getPosition(), clientPlayer:getPosition())
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    end

    closePlayersDetected = nearestPlayer ~= nil
end


local function adjustAutoClickerInterval()
    if closePlayersDetected then
        LuaTimer:cancel(timerAutoClick)
        timerAutoClick = LuaTimer:scheduleTimer(function()
            CGame.Instance():handleTouchClick(x, y)
            GUIManager:getWindowByName("Main-Gun-CrossHairs"):SetVisible(true) 
        end, proximityInterval, -1)
    else
        LuaTimer:cancel(timerAutoClick)
        timerAutoClick = LuaTimer:scheduleTimer(function()
            CGame.Instance():handleTouchClick(x, y)
            GUIManager:getWindowByName("Main-Gun-CrossHairs"):SetVisible(true) 
        end, checkInterval, -1)
    end
end


local function startAutoClicker()
    if not timerAutoClick then
        timerAutoClick = LuaTimer:scheduleTimer(function()
            CGame.Instance():handleTouchClick(x, y)
            GUIManager:getWindowByName("Main-Gun-CrossHairs"):SetVisible(true) 
        end, checkInterval, -1)
    end
    
    if not timerDetection then
        timerDetection = LuaTimer:scheduleTimer(function()
            detectClosePlayers()
            adjustAutoClickerInterval()
        end, 1000, -1) 
    end
end


local function stopAutoClicker()
    if timerAutoClick then
        LuaTimer:cancel(timerAutoClick)
        timerAutoClick = nil
    end
    if timerDetection then
        LuaTimer:cancel(timerDetection)
        timerDetection = nil
    end
    if timerColorChange then
        LuaTimer:cancel(timerColorChange)
        timerColorChange = nil
    end
    UIHelper.showToast("^FF0000AutoClick OFF")
end





local function toggleWebPortedFunctionality()
    webPortedActive = not webPortedActive
    autoClickActive = not autoClickActive

    
    if webPortedActive then
        Blockman.Instance().m_gameSettings:setCollimatorMode(true)
        GUIManager:getWindowByName("Main-Gun-CrossHairs"):SetVisible(true)
        GUIManager:getWindowByName("Main-throwpot-Controls"):SetVisible(true)
        UIHelper.showToast("^00FF00WebPorted ON")
        startAutoClicker()
        
        webPortedButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        SoundUtil.playSound(70)
        webPortedButton:SetText("^000000WebPorted")
    else
        Blockman.Instance().m_gameSettings:setCollimatorMode(false)
        GUIManager:getWindowByName("Main-Gun-CrossHairs"):SetVisible(false)
        GUIManager:getWindowByName("Main-throwpot-Controls"):SetVisible(false)
        SoundUtil.playSound(70)
        UIHelper.showToast("^FF0000WebPorted OFF")
        stopAutoClicker()
        
        if timerColorChange then
            LuaTimer:cancel(timerColorChange)
        end
        webPortedButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        webPortedButton:SetText("^000000WebPorted")
    end
end


webPortedButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleWebPortedFunctionality()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(webPortedButton)
webPortedButton:SetVisible(false)
webPortedButton:SetXPosition({0, 420})
webPortedButton:SetYPosition({0, -80})












local skateButton = GUIManager:createGUIWindow(GUIType.Button, "SkateButton")
skateButton:SetHorizontalAlignment(HorizontalAlignment.Left)
skateButton:SetVerticalAlignment(VerticalAlignment.Center)
skateButton:SetHeight({ 0, 50 })
skateButton:SetWidth({ 0, 180 })
skateButton:SetTextColor({ 0, 0, 0 })
skateButton:SetText("^000000Skate")
skateButton:SetTouchable(true)
skateButton:SetBackgroundColor({ 0, 0, 0, 0.7 })


local skateActive = false






local function toggleSkate()
    skateActive = not skateActive
    if skateActive then
        
        skateButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        UIHelper.showToast("Skate Enabled")
        SoundUtil.playSound(70)
        PlayerManager:getClientPlayer().Player:setBoolProperty("DisableUpdateAnimState", true)
    else
        
        if skateTimer then
            LuaTimer:cancel(skateTimer)
        end
        skateButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        UIHelper.showToast("Skate Disabled")
        SoundUtil.playSound(70)
        PlayerManager:getClientPlayer().Player:setBoolProperty("DisableUpdateAnimState", false)
    end
end


skateButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleSkate()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(skateButton)
skateButton:SetVisible(false)
skateButton:SetXPosition({ 0, 220 })
skateButton:SetYPosition({ 0, 220 })


local showHPButton = GUIManager:createGUIWindow(GUIType.Button, "ShowHPButton")
showHPButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
showHPButton:SetVerticalAlignment(VerticalAlignment.Center)    
showHPButton:SetHeight({ 0, 50 }) 
showHPButton:SetWidth({ 0, 180 }) 
showHPButton:SetTextColor({ 0, 0, 0 }) 
showHPButton:SetText("^000000Show HP") 
showHPButton:SetTouchable(true)
showHPButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 

local showHPTimer = nil
local showHPActive = false
local originalNames = {} 




local function startShowHPTimer()
    if not showHPTimer then
        showHPTimer = LuaTimer:scheduleTimer(function()
            local players = PlayerManager:getPlayers() or {}
            for _, playerData in ipairs(players) do
                local player = playerData.Player
                if player then
                    local showName = player:getShowName() or ""
                    local curHp = math.floor(player:getHealth() + 0.5) or 0

                    if not originalNames[playerData] then
                        originalNames[playerData] = showName 
                    end

                    if playerData.lastShowHP ~= curHp or playerData.lastShowName ~= showName then
                        playerData.lastShowHP = curHp
                        local nameList = StringUtil.split(showName, "\n") or {}
                        if string.find(showName, "♥") then
                            table.remove(nameList)
                        end

                        local hpText = "▢FFFFFFFF" .. tostring(curHp) .. "▢FFFF1F1F  ♥"
                        table.insert(nameList, hpText)
                        playerData.lastShowName = table.concat(nameList, "\n")
                        player:setShowName(playerData.lastShowName)
                    end
                end
            end
        end, 50, 99999) 
        UIHelper.showToast("Show HP ativado")
    end
end


local function stopShowHPTimer()
    if showHPTimer then
        LuaTimer:cancel(showHPTimer)
        showHPTimer = nil

        
        local players = PlayerManager:getPlayers() or {}
        for _, playerData in ipairs(players) do
            local player = playerData.Player
            if player and originalNames[playerData] then
                player:setShowName(originalNames[playerData])
                originalNames[playerData] = nil 
            end
        end

        UIHelper.showToast("Show HP desativado")
    end
end


local function toggleShowHP()
    if showHPActive then
        stopShowHPTimer()
        showHPActive = false
        if timerColorChange then
            LuaTimer:cancel(timerColorChange)
        end
        showHPButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        showHPButton:SetText("^000000Show HP") 
        SoundUtil.playSound(70)
    else
        startShowHPTimer()
        showHPActive = true
        showHPButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
 
        SoundUtil.playSound(70)
        showHPButton:SetText("^000000Show HP") 
    end
end


showHPButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleShowHP()
end)

GUISystem.Instance():GetRootWindow():AddChildWindow(showHPButton)

showHPButton:SetVisible(false)
showHPButton:SetXPosition({0, 420})  
showHPButton:SetYPosition({0, -140}) 









local setAimBotButton = GUIManager:createGUIWindow(GUIType.Button, "SetAimBotButton")
setAimBotButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
setAimBotButton:SetVerticalAlignment(VerticalAlignment.Center)    
setAimBotButton:SetHeight({ 0, 50 }) 
setAimBotButton:SetWidth({ 0, 180 }) 
setAimBotButton:SetTextColor({ 0, 0, 0 }) 
setAimBotButton:SetText("^000000Set AimBot") 
setAimBotButton:SetTouchable(true)
setAimBotButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local aimBotActive = false
local aimBotTimer
local detectionTimer = nil
local detectionRadius = 8 





local function detectAndPointToNearestPlayer()
    local players = PlayerManager:getPlayers()
    local clientPlayer = PlayerManager:getClientPlayer()
    local clientTeamId = clientPlayer:getTeamId()
    local nearestPlayer = nil
    local nearestDistance = detectionRadius^2 

    if GameType == "g1401" then
        local validTargetTeams = {}
        if clientTeamId == 1 then
            validTargetTeams = { 2 }
        elseif clientTeamId == 2 then
            validTargetTeams = { 1 }
        elseif clientTeamId == 3 then
            validTargetTeams = { 1 }
        end

        for _, player in pairs(players) do
            if player ~= clientPlayer then
                local playerTeamId = player:getTeamId()
                if playerTeamId ~= clientTeamId and table.contains(validTargetTeams, playerTeamId) then
                    local distance = MathUtil:distanceSquare3d(player:getPosition(), clientPlayer:getPosition())
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    else
        for _, player in pairs(players) do
            if player ~= clientPlayer then
                local playerTeamId = player:getTeamId()
                if playerTeamId ~= clientTeamId then
                    local distance = MathUtil:distanceSquare3d(player:getPosition(), clientPlayer:getPosition())
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    end

    if nearestPlayer then
        local playerPos = clientPlayer:getPosition()
        local nearestPos = nearestPlayer:getPosition()
        local dx = nearestPos.x - playerPos.x
        local dy = nearestPos.y - playerPos.y
        local dz = nearestPos.z - playerPos.z
        local distanceHorizontal = math.sqrt(dx * dx + dz * dz)

        local angleYaw = math.atan2(dz, dx) * 180 / math.pi - 90
        local anglePitch = -math.atan2(dy, distanceHorizontal) * 180 / math.pi

        anglePitch = anglePitch - 10

        clientPlayer.Player.rotationYaw = angleYaw
        clientPlayer.Player.rotationPitch = anglePitch
    end
end


local function startDetectionTimer()
    if not detectionTimer then
        detectionTimer = LuaTimer:scheduleTimer(function()
            detectAndPointToNearestPlayer()
        end, 10, -1) 
        UIHelper.showToast("Timer de detecção iniciado")
    end
end


local function stopDetectionTimer()
    if detectionTimer then
        LuaTimer:cancel(detectionTimer)
        detectionTimer = nil
        UIHelper.showToast("Timer de detecção parado")
    end
end


local function toggleAimBot()
    if aimBotActive then
        stopDetectionTimer()
        aimBotActive = false
        if aimBotTimer then
            LuaTimer:cancel(aimBotTimer)
        end
        setAimBotButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        setAimBotButton:SetText("^000000Set AimBot") 
        SoundUtil.playSound(70)
        UIHelper.showToast("AimBot Disabled")
    else
        GMHelper:openInput({""}, function(input)
            local inputDistance = tonumber(input)
            if inputDistance then
                detectionRadius = inputDistance
                startDetectionTimer()
                aimBotActive = true
                setAimBotButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
                 
                setAimBotButton:SetText("^000000Set AimBot") 
                UIHelper.showToast("AimBot Enabled")
                SoundUtil.playSound(70)
            else
                UIHelper.showToast("Entrada inválida. Por favor, insira um número.")
            end
        end)
    end
end


setAimBotButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleAimBot()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(setAimBotButton)
setAimBotButton:SetVisible(false)
setAimBotButton:SetXPosition({0, 420})
setAimBotButton:SetYPosition({0, -200})







local autoRespawnButton = GUIManager:createGUIWindow(GUIType.Button, "AutoRespawnButton")
autoRespawnButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
autoRespawnButton:SetVerticalAlignment(VerticalAlignment.Center)    
autoRespawnButton:SetHeight({ 0, 50 })
autoRespawnButton:SetWidth({ 0, 180 })
autoRespawnButton:SetTextColor({ 255, 255, 255 }) 
autoRespawnButton:SetText("^000000AutoRespawn") 
autoRespawnButton:SetTouchable(true)


autoRespawnButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
SoundUtil.playSound(70) 


local autoRespawnActive = false




local function respawnFunction(event)
    if autoRespawnActive then
        local clientPlayer = PlayerManager:getClientPlayer()
        if clientPlayer then
            PacketSender:getSender():sendRebirth()
        end
    end
end


local function toggleAutoRespawn()
    autoRespawnActive = not autoRespawnActive

    if autoRespawnActive then
         
        autoRespawnButton:SetText("^000000AutoRespawn") 
                autoRespawnButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        PacketSender:getSender():sendRebirth()
        UIHelper.showToast("^00FF00Auto Respawn ON")
        
        _G["Listener"].registerCallBack(_G["CEvents"].LuaPlayerDeathEvent, respawnFunction)
    else
        if timerColorChange then
            LuaTimer:cancel(timerColorChange)
        end
        autoRespawnButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        autoRespawnButton:SetText("^000000AutoRespawn") 
        UIHelper.showToast("^FF0000Auto Respawn OFF")
        
        _G["Listener"].unregisterCallBack(_G["CEvents"].LuaPlayerDeathEvent, respawnFunction)
    end
end


autoRespawnButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleAutoRespawn()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(autoRespawnButton)


autoRespawnButton:SetVisible(false)
autoRespawnButton:SetXPosition({0, 20}) 
autoRespawnButton:SetYPosition({0, 220}) 


_G["Listener"].registerCallBack(_G["CEvents"].LuaPlayerDeathEvent, respawnFunction)




local fpsBoosterButton = GUIManager:createGUIWindow(GUIType.Button, "FPSBoosterButton")
fpsBoosterButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
fpsBoosterButton:SetVerticalAlignment(VerticalAlignment.Center)    
fpsBoosterButton:SetHeight({ 0, 50 })
fpsBoosterButton:SetWidth({ 0, 180 })
fpsBoosterButton:SetTextColor({ 255, 255, 255 }) 
fpsBoosterButton:SetText("^000000FPSBooster") 
fpsBoosterButton:SetTouchable(true)


fpsBoosterButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local fpsBoosterActive = false





local function toggleFPSBooster()
    if fpsBoosterActive then
        
        CGame.Instance():SetMaxFps(60)
        ClientHelper.putIntPrefs("SimpleEffectRenderDistance", 250)
        UIHelper.showToast("^00FF00FPS Booster OFF")
        if timerColorChange then
            LuaTimer:cancel(timerColorChange)
        end
        fpsBoosterButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        fpsBoosterButton:SetText("^000000FPSBooster") 
    else
        
        CGame.Instance():SetMaxFps(9999)
        ClientHelper.putIntPrefs("SimpleEffectRenderDistance", 0)
        UIHelper.showToast("^00FF00FPS Booster ON")
        fpsBoosterButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        fpsBoosterButton:SetText("^000000FPSBooster") 
        SoundUtil.playSound(70)
    end
    fpsBoosterActive = not fpsBoosterActive
end


fpsBoosterButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleFPSBooster()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(fpsBoosterButton)


fpsBoosterButton:SetVisible(false)
fpsBoosterButton:SetXPosition({0, 220}) 
fpsBoosterButton:SetYPosition({0, 160}) 




local combinedButton = GUIManager:createGUIWindow(GUIType.Button, "CombinedButton")
combinedButton:SetHorizontalAlignment(HorizontalAlignment.Left)
combinedButton:SetVerticalAlignment(VerticalAlignment.Center)
combinedButton:SetHeight({ 0, 50 })
combinedButton:SetWidth({ 0, 180 })
combinedButton:SetTextColor({ 255, 255, 255 }) 
combinedButton:SetText("^000000AutoClicker")
combinedButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local tntControlsActive = false
local autoClickActive = false
local timerAutoClick = nil
local timerDetection = nil 
local checkInterval = 50 
local proximityInterval = 100 
local detectionRadius = 8 
local closePlayersDetected = false





local function detectClosePlayers()
    local players = PlayerManager:getPlayers()
    local clientPlayer = PlayerManager:getClientPlayer()
    local clientTeamId = clientPlayer:getTeamId()
    local nearestPlayer = nil
    local nearestDistance = detectionRadius^2

    if GameType == "g1401" then
        local validTargetTeams = {}
        if clientTeamId == 1 then
            validTargetTeams = { 2 }
        elseif clientTeamId == 2 then
            validTargetTeams = { 1 }
        elseif clientTeamId == 3 then
            validTargetTeams = { 1 }
        end

        for _, player in pairs(players) do
            if player ~= clientPlayer then
                local playerTeamId = player:getTeamId()
                if playerTeamId ~= clientTeamId and table.contains(validTargetTeams, playerTeamId) then
                    local distance = MathUtil:distanceSquare3d(player:getPosition(), clientPlayer:getPosition())
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    else
        for _, player in pairs(players) do
            if player ~= clientPlayer then
                local playerTeamId = player:getTeamId()
                if playerTeamId ~= clientTeamId then
                    local distance = MathUtil:distanceSquare3d(player:getPosition(), clientPlayer:getPosition())
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    end

    closePlayersDetected = nearestPlayer ~= nil
end


local function adjustAutoClickerInterval()
    if closePlayersDetected then
        LuaTimer:cancel(timerAutoClick)
        timerAutoClick = LuaTimer:scheduleTimer(function()
            CGame.Instance():handleTouchClick(x, y)
        end, proximityInterval, -1)
    else
        LuaTimer:cancel(timerAutoClick)
        timerAutoClick = LuaTimer:scheduleTimer(function()
            CGame.Instance():handleTouchClick(x, y)
        end, checkInterval, -1)
    end
end


local function startAutoClicker()
    if not timerAutoClick then
        timerAutoClick = LuaTimer:scheduleTimer(function()
            CGame.Instance():handleTouchClick(x, y)
        end, checkInterval, -1)
    end
    
    if not timerDetection then
        timerDetection = LuaTimer:scheduleTimer(function()
            detectClosePlayers()
            adjustAutoClickerInterval()
        end, 1000, -1) 
    end
end


local function stopAutoClicker()
    if timerAutoClick then
        LuaTimer:cancel(timerAutoClick)
        timerAutoClick = nil
    end
    if timerDetection then
        LuaTimer:cancel(timerDetection)
        timerDetection = nil
    end
    UIHelper.showToast("^FF0000AutoClick OFF")
end





local function toggleCombinedFunctionality()
    tntControlsActive = not tntControlsActive
    autoClickActive = not autoClickActive

    
    if tntControlsActive then
        GUIManager:getWindowByName("Main-throwpot-Controls"):SetVisible(true)
        SoundUtil.playSound(70)
        UIHelper.showToast("^00FF00TNTControls ON")
    else
        GUIManager:getWindowByName("Main-throwpot-Controls"):SetVisible(false)
        SoundUtil.playSound(70)
        UIHelper.showToast("^FF0000TNTControls OFF")
    end

    
    if autoClickActive then
        UIHelper.showToast("^00FF00AutoClick ON")
        startAutoClicker()
       
       combinedButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
    else
        stopAutoClicker()
        if timerColorChangeCombined then
            LuaTimer:cancel(timerColorChangeCombined)
            timerColorChangeCombined = nil
        end
        combinedButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
    end

    
    if tntControlsActive and autoClickActive then
        combinedButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        combinedButton:SetText("^000000AutoClicker")
    else
        combinedButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        combinedButton:SetText("^000000AutoClicker")
    end
end


combinedButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleCombinedFunctionality()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(combinedButton)


combinedButton:SetVisible(false)
combinedButton:SetXPosition({0, 420})
combinedButton:SetYPosition({0, -260})




local fastBreakButton = GUIManager:createGUIWindow(GUIType.Button, "FastBreakButton")
fastBreakButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
fastBreakButton:SetVerticalAlignment(VerticalAlignment.Center)    
fastBreakButton:SetHeight({ 0, 50 })
fastBreakButton:SetWidth({ 0, 180 })
fastBreakButton:SetTextColor({ 255, 255, 255 }) 
fastBreakButton:SetText("^000000FastBreak") 
fastBreakButton:SetTouchable(true)


fastBreakButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local fastBreakActive = false
local originalHardness = {} 


local function toggleFastBreak()
    if fastBreakActive then
        
        for blockId, hardness in pairs(originalHardness) do
            local block = BlockManager.getBlockById(blockId)
            if block then
                block:setHardness(hardness)
            end
        end
        UIHelper.showToast("^00FF00Turned OFF")
        fastBreakButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        fastBreakButton:SetText("^000000FastBreak") 
    else
        
        for blockId = 1, 40000 do
            local block = BlockManager.getBlockById(blockId)
            if block then
                originalHardness[blockId] = block:getHardness() 
                block:setHardness(0)
            end
        end
        UIHelper.showToast("^00FF00Turned ON")
        fastBreakButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70)
        fastBreakButton:SetText("^000000FastBreak") 
    end
    fastBreakActive = not fastBreakActive
end


fastBreakButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleFastBreak()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(fastBreakButton)


fastBreakButton:SetVisible(false)
fastBreakButton:SetXPosition({0, 220}) 
fastBreakButton:SetYPosition({0, 100}) 


local actionButton = GUIManager:createGUIWindow(GUIType.Button, "ActionButton")
actionButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
actionButton:SetVerticalAlignment(VerticalAlignment.Center)    
actionButton:SetHeight({ 0, 50 }) 
actionButton:SetWidth({ 0, 180 }) 
actionButton:SetTextColor({ 0, 0, 0 }) 
actionButton:SetText("^000000AimBot") 
actionButton:SetTouchable(true)
actionButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 

local detectionTimer = nil
local detectionActive = false
local checkInterval = 1 
local detectionRadius = 8 




local function detectAndPointToNearestPlayer()
    local players = PlayerManager:getPlayers()
    local clientPlayer = PlayerManager:getClientPlayer()
    local clientTeamId = clientPlayer:getTeamId()
    local nearestPlayer = nil
    local nearestDistance = detectionRadius^2 

    
    if GameType == "g1401" then
        
        local validTargetTeams = {}
        if clientTeamId == 1 then 
            validTargetTeams = { 2 } 
        elseif clientTeamId == 2 then 
            validTargetTeams = { 1 } 
        elseif clientTeamId == 3 then 
            validTargetTeams = { 1 } 
        end

        for _, player in pairs(players) do
            if player ~= clientPlayer then
                local playerTeamId = player:getTeamId()
                if playerTeamId ~= clientTeamId and table.contains(validTargetTeams, playerTeamId) then
                    local distance = MathUtil:distanceSquare3d(player:getPosition(), clientPlayer:getPosition())
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    else
        
        for _, player in pairs(players) do
            if player ~= clientPlayer then
                local playerTeamId = player:getTeamId()
                if playerTeamId ~= clientTeamId then 
                    local distance = MathUtil:distanceSquare3d(player:getPosition(), clientPlayer:getPosition())
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    end

    if nearestPlayer then
        local playerPos = clientPlayer:getPosition()
        local nearestPos = nearestPlayer:getPosition()
        local dx = nearestPos.x - playerPos.x
        local dy = nearestPos.y - playerPos.y
        local dz = nearestPos.z - playerPos.z
        local distanceHorizontal = math.sqrt(dx * dx + dz * dz)

        local angleYaw = math.atan2(dz, dx) * 180 / math.pi - 90  
        local anglePitch = -math.atan2(dy, distanceHorizontal) * 180 / math.pi  

        anglePitch = anglePitch - 19  

        clientPlayer.Player.rotationYaw = angleYaw
        clientPlayer.Player.rotationPitch = anglePitch
    end
end

local function startDetectionTimer()
    if not detectionTimer then
        detectionTimer = LuaTimer:scheduleTimer(function()
            detectAndPointToNearestPlayer()
        end, checkInterval, -1) 
        UIHelper.showToast("Timer de detecção iniciado")
    end
end

local function stopDetectionTimer()
    if detectionTimer then
        LuaTimer:cancel(detectionTimer)
        detectionTimer = nil
        UIHelper.showToast("Timer de detecção parado")
    end
end

local function toggleDetection()
    if detectionActive then
        stopDetectionTimer()
        detectionActive = false
        actionButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        actionButton:SetText("^000000AimBot") 
        if timerColorChangeAction then
            LuaTimer:cancel(timerColorChangeAction)
        end
    else
        startDetectionTimer()
        detectionActive = true
        actionButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        SoundUtil.playSound(70)
        actionButton:SetText("^000000AimBot") 
    end
end

actionButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleDetection()
end)

GUISystem.Instance():GetRootWindow():AddChildWindow(actionButton)

actionButton:SetVisible(false)
actionButton:SetXPosition({0, 220}) 
actionButton:SetYPosition({0, -20}) 



local ignoreWaterPushButton = GUIManager:createGUIWindow(GUIType.Button, "ignoreWaterPushButton")
ignoreWaterPushButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
ignoreWaterPushButton:SetVerticalAlignment(VerticalAlignment.Center)    
ignoreWaterPushButton:SetHeight({ 0, 50 })    
ignoreWaterPushButton:SetWidth({ 0, 180 })    
ignoreWaterPushButton:SetTextColor({ 0, 0, 0 }) 
ignoreWaterPushButton:SetText("^000000IgnoreWaterPush") 


ignoreWaterPushButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local waterPushIgnored = false


local function toggleIgnoreWaterPush()
    local entity = PlayerManager:getClientPlayer().Player
    if waterPushIgnored then
        
        entity:setBoolProperty("ignoreWaterPush", false)
        UIHelper.showToast("^00FF00IgnoreWaterPush OFF")
        ignoreWaterPushButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        SoundUtil.playSound(70)
        ignoreWaterPushButton:SetText("^000000IgnoreWaterPush") 
    else
        
        entity:setBoolProperty("ignoreWaterPush", true)
        UIHelper.showToast("^00FF00IgnoreWaterPush ON")
        ignoreWaterPushButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70)
        ignoreWaterPushButton:SetText("^000000IgnoreWaterPush") 
    end
    waterPushIgnored = not waterPushIgnored
end


ignoreWaterPushButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleIgnoreWaterPush()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(ignoreWaterPushButton)


ignoreWaterPushButton:SetVisible(false)
ignoreWaterPushButton:SetXPosition({0, 220}) 
ignoreWaterPushButton:SetYPosition({0, 40}) 


local flyV2Button = GUIManager:createGUIWindow(GUIType.Button, "flyV2Button")
flyV2Button:SetHorizontalAlignment(HorizontalAlignment.Left)  
flyV2Button:SetVerticalAlignment(VerticalAlignment.Center)    
flyV2Button:SetHeight({ 0, 50 })    
flyV2Button:SetWidth({ 0, 180 })    
flyV2Button:SetTextColor({ 0, 0, 0 }) 
flyV2Button:SetText("^000000FlyV2") 


flyV2Button:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local flyV2Active = false


local function toggleFlyV2()
    local player = PlayerManager:getClientPlayer().Player
    if flyV2Active then
        
        ClientHelper.putBoolPrefs("EnableDoubleJumps", false)
        player.m_keepJumping = true
        UIHelper.showToast("^00FF00FlyV2 OFF")
        flyV2Button:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        flyV2Button:SetText("^000000FlyV2") 
    else
        
        ClientHelper.putBoolPrefs("EnableDoubleJumps", true)
        player.m_keepJumping = false
        UIHelper.showToast("^00FF00FlyV2 ON")
        flyV2Button:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70)
        flyV2Button:SetText("^000000FlyV2") 
    end
    flyV2Active = not flyV2Active
end


flyV2Button:registerEvent(GUIEvent.ButtonClick, function()
    toggleFlyV2()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(flyV2Button)


flyV2Button:SetVisible(false)
flyV2Button:SetXPosition({0, 20}) 
flyV2Button:SetYPosition({0, 160}) 


local sharpFlyButton = GUIManager:createGUIWindow(GUIType.Button, "sharpFlyButton")
sharpFlyButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
sharpFlyButton:SetVerticalAlignment(VerticalAlignment.Center)    
sharpFlyButton:SetHeight({ 0, 50 })    
sharpFlyButton:SetWidth({ 0, 180 })    
sharpFlyButton:SetTextColor({ 0, 0, 0 }) 
sharpFlyButton:SetText("^000000SharpFly") 


sharpFlyButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local flyActive = false


local function toggleSharpFly()
    if flyActive then
        
        ClientHelper.putBoolPrefs("DisableInertialFly", false)
        UIHelper.showToast("^00FF00SharpFly OFF")
        sharpFlyButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        sharpFlyButton:SetText("^000000SharpFly") 
    else
        
        ClientHelper.putBoolPrefs("DisableInertialFly", true)
        UIHelper.showToast("^00FF00SharpFly ON")
        sharpFlyButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70)
        sharpFlyButton:SetText("^000000SharpFly") 
    end
    flyActive = not flyActive
end


sharpFlyButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleSharpFly()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(sharpFlyButton)


sharpFlyButton:SetVisible(false)
sharpFlyButton:SetXPosition({0, 20}) 
sharpFlyButton:SetYPosition({0, 100}) 


local reachButton = GUIManager:createGUIWindow(GUIType.Button, "reachButton")
reachButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
reachButton:SetVerticalAlignment(VerticalAlignment.Center)    
reachButton:SetHeight({ 0, 50 })    
reachButton:SetWidth({ 0, 180 })    
reachButton:SetTextColor({ 0, 0, 0 }) 
reachButton:SetText("^000000Reach") 


reachButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local reachActive = false


local function toggleReach()
    if reachActive then
        
        ClientHelper.putFloatPrefs("BlockReachDistance", 6.5)
        ClientHelper.putFloatPrefs("EntityReachDistance", 5)
        UIHelper.showToast("^00FF00Reach OFF")
        reachButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        reachButton:SetText("^000000Reach") 
    else
        
        ClientHelper.putFloatPrefs("BlockReachDistance", 9999)
        ClientHelper.putFloatPrefs("EntityReachDistance", 6.5)
        UIHelper.showToast("^00FF00Reach ON")
        reachButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        SoundUtil.playSound(70) 
        reachButton:SetText("^000000Reach") 
    end
    reachActive = not reachActive
end


reachButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleReach()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(reachButton)


reachButton:SetVisible(false)
reachButton:SetXPosition({0, 220}) 
reachButton:SetYPosition({0, -260}) 

local teleportButton = GUIManager:createGUIWindow(GUIType.Button, "teleportButton")
teleportButton:SetHorizontalAlignment(HorizontalAlignment.Left)
teleportButton:SetVerticalAlignment(VerticalAlignment.Center)
teleportButton:SetHeight({ 0, 50 })
teleportButton:SetWidth({ 0, 180 })
teleportButton:SetTextColor({ 255, 255, 255 })
teleportButton:SetText("^000000TeleportClick")
teleportButton:SetTouchable(true)

teleportButton:SetBackgroundColor({ 0, 0, 0, 0.7 })

local tpClickActive = false


local function teleportFunction(event)
    if tpClickActive then
        local pos = event
        PlayerManager:getClientPlayer().Player:setPosition(VectorUtil.newVector3(pos.x + 0.7, pos.y + 3, pos.z + 0.7))
    end
end

local function toggleTeleport()
    tpClickActive = not tpClickActive

    if tpClickActive then
        teleportButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        SoundUtil.playSound(70)
        teleportButton:SetText("^000000TeleportClick")

        
        ClientHelper.putFloatPrefs("BlockReachDistance", 9999)
       

        
        if reachButton then
            reachButton:SetText("^000000Reach")
            reachButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        end
    else
        teleportButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70)
        

        
        ClientHelper.putFloatPrefs("BlockReachDistance", 6.5)
        

        
        if reachButton then
            
            reachButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        end
    end
end

teleportButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleTeleport()
end)


Listener.registerCallBack(CEvents.ClickToBlockEvent, teleportFunction)

GUISystem.Instance():GetRootWindow():AddChildWindow(teleportButton)

teleportButton:SetVisible(false)
teleportButton:SetXPosition({0, 220}) 
teleportButton:SetYPosition({0, -200}) 

local fovButton = GUIManager:createGUIWindow(GUIType.Button, "fovButton")
fovButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
fovButton:SetVerticalAlignment(VerticalAlignment.Center)    
fovButton:SetHeight({ 0, 50 })    
fovButton:SetWidth({ 0, 180 })    
fovButton:SetTextColor({ 0, 0, 0 }) 
fovButton:SetText("^000000Fov") 


fovButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local fovActive = false


local function toggleFov()
    if fovActive then
        
        Blockman.Instance().m_gameSettings:setFovSetting(1)
        UIHelper.showToast("^FF0000Fov OFF")
        fovButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        SoundUtil.playSound(70)
        fovButton:SetText("^000000Fov") 
    else
        
        Blockman.Instance().m_gameSettings:setFovSetting(1.60)
        UIHelper.showToast("^00FF00Fov ON")
        fovButton:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70)
        fovButton:SetText("^000000Fov") 
    end
    fovActive = not fovActive
end


fovButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleFov()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(fovButton)


fovButton:SetVisible(false)
fovButton:SetXPosition({0, 220}) 
fovButton:SetYPosition({0, -140}) 

local NoHurtCamSwitchButton = GUIManager:createGUIWindow(GUIType.Button, "NoHurtCamSwitchButton")
NoHurtCamSwitchButton:SetHorizontalAlignment(HorizontalAlignment.Left)
NoHurtCamSwitchButton:SetVerticalAlignment(VerticalAlignment.Center)
NoHurtCamSwitchButton:SetHeight({ 0, 50 })    
NoHurtCamSwitchButton:SetWidth({ 0, 180 })     
NoHurtCamSwitchButton:SetTextColor({ 255, 255, 255 }) 
NoHurtCamSwitchButton:SetText("^000000NoHurtCam") 
NoHurtCamSwitchButton:SetTouchable(true)
NoHurtCamSwitchButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local isActive = false


local function defaultHurtCameraEffect()
    
    return true
end


local function disableHurtCameraEffect()
    
    return false
end


local function toggleHurtCameraEffect()
    isActive = not isActive
    
    if isActive then
        NoHurtCamSwitchButton:SetBackgroundColor({ 0, 1, 0, 0.7 })  
        SoundUtil.playSound(70)
        
        
        
        CEvents.HurtCameraEffectEvent:unregisterCallBack(defaultHurtCameraEffect)
        CEvents.HurtCameraEffectEvent:registerCallBack(disableHurtCameraEffect)
    else
        NoHurtCamSwitchButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70)  
        
        
        
        CEvents.HurtCameraEffectEvent:unregisterCallBack(disableHurtCameraEffect)
        CEvents.HurtCameraEffectEvent:registerCallBack(defaultHurtCameraEffect)
    end
end


NoHurtCamSwitchButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleHurtCameraEffect()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(NoHurtCamSwitchButton)


NoHurtCamSwitchButton:SetVisible(false)  
NoHurtCamSwitchButton:SetXPosition({ 0, 220 })  
NoHurtCamSwitchButton:SetYPosition({ 0, -80 })  


local HitBox5xButton = GUIManager:createGUIWindow(GUIType.Button, "HitBox5xButton")
HitBox5xButton:SetHorizontalAlignment(HorizontalAlignment.Left)
HitBox5xButton:SetVerticalAlignment(VerticalAlignment.Center)
HitBox5xButton:SetHeight({ 0, 50 })    
HitBox5xButton:SetWidth({ 0, 180 })    
HitBox5xButton:SetTextColor({ 0, 0, 0 }) 
HitBox5xButton:SetText("^000000HitBox5x")
HitBox5xButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 

local HitBox5xActive = false

local function toggleHitBox5x()
    if not HitBox5xActive then
        HitBox5xActive = true
        for _, player in pairs(PlayerManager:getPlayers()) do
            if player ~= PlayerManager:getClientPlayer() then
                local entity = player.Player
                entity.height = 3.0
                entity.width = 3.0
                entity.length = 3.0
            end
        end
        HitBox5xButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        SoundUtil.playSound(70) 
        HitBox5xButton:SetText("^000000HitBox5x")
        UIHelper.showToast("HitBox5x ativado")
    else
        HitBox5xActive = false
        for _, player in pairs(PlayerManager:getPlayers()) do
            if player ~= PlayerManager:getClientPlayer() then
                local entity = player.Player
                entity.height = 1.8
                entity.width = 0.6
                entity.length = 0.6
            end
        end
        HitBox5xButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        HitBox5xButton:SetText("^000000HitBox5x")
        UIHelper.showToast("HitBox5x desativado")
    end
end

HitBox5xButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleHitBox5x()
end)

GUISystem.Instance():GetRootWindow():AddChildWindow(HitBox5xButton)
HitBox5xButton:SetVisible(false)
HitBox5xButton:SetXPosition({0, 20})   
HitBox5xButton:SetYPosition({0, -260}) 






local HitBox2xButton = GUIManager:createGUIWindow(GUIType.Button, "HitBox2xButton")
HitBox2xButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
HitBox2xButton:SetVerticalAlignment(VerticalAlignment.Center)    
HitBox2xButton:SetHeight({ 0, 50 })    
HitBox2xButton:SetWidth({ 0, 180 })    
HitBox2xButton:SetTextColor({ 0, 0, 0 }) 
HitBox2xButton:SetText("^000000HitBox2x") 
HitBox2xButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local HitBox2xTimer = nil
local HitBox2xActive = false


local function startHitBox2x()
    if not HitBox2xActive then
        HitBox2xActive = true
        HitBox2xTimer = LuaTimer:scheduleTimer(function()
            for _, player in pairs(PlayerManager:getPlayers()) do
                if player ~= PlayerManager:getClientPlayer() then
                    local entity = player.Player
                    entity.height = 1.8
                    entity.width = 1.2
                    entity.length = 1.2
                end
            end
        end, 100, -1) 
        
        HitBox2xButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        SoundUtil.playSound(70) 
        HitBox2xButton:SetText("^000000HitBox2x") 
        UIHelper.showToast("HitBox2x ativado")
    end
end


local function stopHitBox2x()
    if HitBox2xActive then
        HitBox2xActive = false
        if HitBox2xTimer then
            LuaTimer:cancel(HitBox2xTimer)
            HitBox2xTimer = nil
        end
        
        for _, player in pairs(PlayerManager:getPlayers()) do
            if player ~= PlayerManager:getClientPlayer() then
                local entity = player.Player
                entity.height = 1.8
                entity.width = 0.6
                entity.length = 0.6
            end
        end
        
        HitBox2xButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        SoundUtil.playSound(70)
        HitBox2xButton:SetText("^000000HitBox2x") 
        UIHelper.showToast("HitBox2x desativado")
    end
end


local function toggleHitBox2x()
    if HitBox2xActive then
        stopHitBox2x()
    else
        startHitBox2x()
    end
end


HitBox2xButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleHitBox2x()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(HitBox2xButton)


HitBox2xButton:SetVisible(false)  
HitBox2xButton:SetXPosition({0, 20}) 
HitBox2xButton:SetYPosition({0, -200}) 

local blink1Button = GUIManager:createGUIWindow(GUIType.Button, "blink1Button")
blink1Button:SetHorizontalAlignment(HorizontalAlignment.Left)  
blink1Button:SetVerticalAlignment(VerticalAlignment.Center)    
blink1Button:SetHeight({ 0, 50 })    
blink1Button:SetWidth({ 0, 180 })    
blink1Button:SetTextColor({ 0, 0, 0 }) 
blink1Button:SetText("^000000Blink") 


blink1Button:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local blinkActive = false


local function toggleBlink()
    if blinkActive then
        
        ClientHelper.putBoolPrefs("SyncClientPositionToServer", true)
        UIHelper.showToast("^FF0000Blink OFF")
        blink1Button:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        blink1Button:SetText("^000000Blink") 
    else
        
        ClientHelper.putBoolPrefs("SyncClientPositionToServer", false)
        UIHelper.showToast("^00FF00Blink ON")
        blink1Button:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70)
        blink1Button:SetText("^000000Blink") 
    end
    blinkActive = not blinkActive
end


blink1Button:registerEvent(GUIEvent.ButtonClick, function()
    toggleBlink()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(blink1Button)


blink1Button:SetVisible(false)
blink1Button:SetXPosition({0, 20}) 
blink1Button:SetYPosition({0, -140}) 


local nofall87Button = GUIManager:createGUIWindow(GUIType.Button, "nofall87Button")
nofall87Button:SetHorizontalAlignment(HorizontalAlignment.Left)  
nofall87Button:SetVerticalAlignment(VerticalAlignment.Center)    
nofall87Button:SetHeight({ 0, 50 })    
nofall87Button:SetWidth({ 0, 180 })    
nofall87Button:SetTextColor({ 0, 0, 0 }) 
nofall87Button:SetText("^000000Nofall") 
nofall87Button:SetTouchable(true)


nofall87Button:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local nofallActive = false


local function toggleNofall()
    if nofallActive then
        
        ClientHelper.putIntPrefs("SprintLimitCheck", 0)
        UIHelper.showToast("^FF0000Nofall OFF")
        nofall87Button:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        nofall87Button:SetText("^000000Nofall") 
    else
        
        ClientHelper.putIntPrefs("SprintLimitCheck", 7)
        UIHelper.showToast("^00FF00Nofall ON")
        nofall87Button:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70)
        nofall87Button:SetText("^000000Nofall") 
    end
    nofallActive = not nofallActive
end


nofall87Button:registerEvent(GUIEvent.ButtonClick, function()
    toggleNofall()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(nofall87Button)


nofall87Button:SetVisible(false)
nofall87Button:SetXPosition({0, 20}) 
nofall87Button:SetYPosition({0, 40}) 


local speedUp38Button = GUIManager:createGUIWindow(GUIType.Button, "speedUp38Button")
speedUp38Button:SetHorizontalAlignment(HorizontalAlignment.Left)  
speedUp38Button:SetVerticalAlignment(VerticalAlignment.Center)    
speedUp38Button:SetHeight({ 0, 50 })    
speedUp38Button:SetWidth({ 0, 180 })    
speedUp38Button:SetTextColor({ 0, 0, 0 }) 
speedUp38Button:SetText("^000000Speed") 


speedUp38Button:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local speedUpActive = false


local function toggleSpeedUp()
    if speedUpActive then
        
        	PlayerManager:getClientPlayer().Player:setSpeedAdditionLevel(100)
        UIHelper.showToast("^FF0000Speed  OFF")
        speedUp38Button:SetBackgroundColor({ 0, 0, 0, 0.7 }) 
        SoundUtil.playSound(70)
        speedUp38Button:SetText("^000000Speed") 
    else
        
        	PlayerManager:getClientPlayer().Player:setSpeedAdditionLevel(1500)
        UIHelper.showToast("^00FF00Speed ON")
        speedUp38Button:SetBackgroundColor({ 0, 1, 0, 0.7 }) 
        SoundUtil.playSound(70)
        speedUp38Button:SetText("^000000Speed") 
    end
    speedUpActive = not speedUpActive
end


speedUp38Button:registerEvent(GUIEvent.ButtonClick, function()
    toggleSpeedUp()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(speedUp38Button)


speedUp38Button:SetVisible(false)
speedUp38Button:SetXPosition({0, 20}) 
speedUp38Button:SetYPosition({0, -20}) 



local NoDelayButton = GUIManager:createGUIWindow(GUIType.Button, "NoDelayButton")
NoDelayButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
NoDelayButton:SetVerticalAlignment(VerticalAlignment.Center)    
NoDelayButton:SetHeight({ 0, 50 })    
NoDelayButton:SetWidth({ 0, 180 })    
NoDelayButton:SetTextColor({ 0, 0, 0 }) 
NoDelayButton:SetText("^000000NoDelay") 
NoDelayButton:SetTouchable(true)


NoDelayButton:SetBackgroundColor({ 0, 0, 0, 0.7 }) 


local noDelayActive = false


local function toggleNoDelay()
    if noDelayActive then
        
        ClientHelper.putBoolPrefs("banClickCD", false)
        PlayerManager:getClientPlayer().Player:setIntProperty("bedWarAttackCD", 5)
        ClientHelper.putIntPrefs("ClickSceneCD", 5)
        SoundUtil.playSound(70)
        NoDelayButton:SetBackgroundColor({ 0, 0, 0, 0.7 })
        SoundUtil.playSound(70) 
        NoDelayButton:SetText("^000000NoDelay") 
    else
        
        ClientHelper.putBoolPrefs("banClickCD", true)
        PlayerManager:getClientPlayer().Player:setIntProperty("bedWarAttackCD", 0)
        ClientHelper.putIntPrefs("ClickSceneCD", 0)
        SoundUtil.playSound(70)
        NoDelayButton:SetBackgroundColor({ 0, 1, 0, 0.7 })
        SoundUtil.playSound(70) 
        NoDelayButton:SetText("^000000NoDelay") 
    end
    noDelayActive = not noDelayActive
end


NoDelayButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleNoDelay()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(NoDelayButton)


NoDelayButton:SetVisible(false)  
NoDelayButton:SetXPosition({0, 20}) 
NoDelayButton:SetYPosition({0, -80}) 









local toggleEllllButton = GUIManager:createGUIWindow(GUIType.Button, "ToggleEllllButton")
toggleEllllButton:SetHorizontalAlignment(HorizontalAlignment.Left)  
toggleEllllButton:SetVerticalAlignment(VerticalAlignment.Center)    
toggleEllllButton:SetHeight({ 0, 100 })
toggleEllllButton:SetWidth({ 0, 100 })  



toggleEllllButton:SetNormalImage("set:gui_yetanother_icon.json image:icon_up")
toggleEllllButton:SetPushedImage("set:gui_yetanother_icon.json image:icon_up_pressed")


local buttons = {
  HitBox2xButton,
  blink1Button,
  nofall87Button,
  webPortedButton,
  UndeadButton,
  HitBox5xButton,
  ReachBypassButton,
  sharpFlyButton,
  actionButton,
  reachButton,
  AntiVoidButton,
  showHPButton,
  setAimBotButton,
  fpsPingButton,
  FastClickerButton,
  skateButton,
  fastBreakButton,
  flyV2Button,
  DpadJumpButton,
  ignoreWaterPushButton,
  NoFallDamageButton,
  combinedButton,
  raketButton,
  fpsBoosterButton,
  AutoBridgeButton,
  teleportButton,
  fovButton,
  NoHurtCamSwitchButton,
  autoRespawnButton,
  speedUp38Button,
  NoDelayButton
}


local function toggleAll()
    
    local allVisible = true
    for _, button in ipairs(buttons) do
        if button:IsVisible() then
            allVisible = false
            break
        end
    end

    for _, button in ipairs(buttons) do
        button:SetVisible(allVisible)
    end
end


toggleEllllButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleAll()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(toggleEllllButton)


toggleEllllButton:SetVisible(true)
toggleEllllButton:SetXPosition({0, 1260}) 
toggleEllllButton:SetYPosition({0, -305}) 







local changeImageButton = GUIManager:createGUIWindow(GUIType.Button, "ChangeImageButton")
changeImageButton:SetHorizontalAlignment(HorizontalAlignment.Left)
changeImageButton:SetVerticalAlignment(VerticalAlignment.Center)
changeImageButton:SetHeight({0, 50})
changeImageButton:SetWidth({0, 180})
changeImageButton:SetTextColor({255, 255, 255}) 
changeImageButton:SetText("^000000HideIcon") 
changeImageButton:SetTouchable(true)


changeImageButton:SetBackgroundColor({0, 0, 0, 0.7}) 

toggleEllllButton:SetPushedImage("set:gui_inventory_icon.json image:icon_bookrack")
toggleEllllButton:SetNormalImage("set:gui_inventory_icon.json image:icon_bookrack")

local imageActive = false


local function toggleImage()
    if imageActive then
        
        toggleEllllButton:SetNormalImage("set:gui_inventory_icon.json image:icon_bookrack")
        toggleEllllButton:SetPushedImage("set:gui_inventory_icon.json image:icon_bookrack")
        
        changeImageButton:SetBackgroundColor({0, 0, 0, 0.7}) 
        changeImageButton:SetText("^000000HideIcon") 
    else
        
        toggleEllllButton:SetNormalImage("set:bedwarsmall.json image:btn_0_fort")
        toggleEllllButton:SetPushedImage("set:bedwarsmall.json image:btn_0_fort")
        toggleEllllButton:SetText("") 
        changeImageButton:SetBackgroundColor({0, 0, 0, 0.0}) 
        changeImageButton:SetText("") 
    end
    imageActive = not imageActive
end


changeImageButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleImage()
end)


GUISystem.Instance():GetRootWindow():AddChildWindow(changeImageButton)


changeImageButton:SetVisible(true)
changeImageButton:SetXPosition({0, 1420}) 
changeImageButton:SetYPosition({0, -200}) 





    local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end


function Credits()
    local GUI = GUIManager:createGUIWindow(GUIType.StaticText, "GUIRoot-Ping")
    GUI:SetVisible(true)

    local appVersion = ""
    local hue = 0  -- Inicializa a variável hue

    local function Update()
        local YE = "Zpanel panel 1.1.6 Credits: Znyxus & WxJpxW (" .. appVersion .. ")"
        GUI:SetText(YE)
    end

    local function Updatec1()
    hue = (hue + 0.5) % 360
    local r, g, b, a = interpolateColor(hue)
    
    -- Define a cor do texto usando os valores r, g, b e a
    GUI:SetTextColor({r, g, b, a})
end

    GUI:SetWidth({ 0, 200 })
    GUI:SetHeight({ 0, 40 })
    GUI:SetXPosition({ 0, 535 })
    GUI:SetBordered(true)
    GUI:SetYPosition({ 0, 105 })
    GUISystem.Instance():GetRootWindow():AddChildWindow(GUI)

    LuaTimer:scheduleTimer(Update, 100, -1)
    LuaTimer:scheduleTimer(Updatec1, 50, -1)  -- Adiciona a chamada da função Updatec1

    local function readFile(filePath)
        local file = io.open(filePath, "r")
        if not file then
            return nil  -- Remove o toast de erro
        end
        local content = file:read("*a")
        file:close()
        return content
    end

    local function extractAppVersion(content)
        local versionPattern = '"app_version":"(%d+%.%d+%.%d+)"'
        local appVersion = content:match(versionPattern)
        return appVersion
    end

    local filePath = "/storage/emulated/0/Android/data/com.sandboxol.blockymods/files/Download/SandboxOL/BlockMan/config/client.log"

    local content = readFile(filePath)
    if content then
        appVersion = extractAppVersion(content) or "Version not found"
        if appVersion == "Version not found" then
            -- Remove o toast de versão não encontrada
        else
            MsgSender.sendMsg("appVersion: " .. appVersion)
        end
    else
        -- Remove o toast de arquivo não encontrado
    end
end

Credits()





function Dates()
    local DAT = GUIManager:createGUIWindow(GUIType.StaticText, "GUIRoot-Date")
    DAT:SetVisible(true)

    local hue = 0 -- Inicialize hue para mudança de cor

    local function Updater()
        local me = PlayerManager:getClientPlayer()
        if me then
            local myPos = me.Player:getPosition()
            -- Formatar as coordenadas com '/' como separador
            local locationString = string.format("XYZ = %.0f / %.0f / %.0f", myPos.x, myPos.y, myPos.z)
            DAT:SetText(locationString)

            hue = (hue + 0.5) % 360
            local r, g, b, a = interpolateColor(hue)
            DAT:SetTextColor({r, g, b, 0.6})
        end
    end

    DAT:SetWidth({ 0, 200 }) -- Ajuste a largura para caber as coordenadas
    DAT:SetHeight({ 0, 20 })
    DAT:SetXPosition({ 0, 15 })
    DAT:SetBordered(true)
    DAT:SetYPosition({ 0, 670 }) -- Posição inicial das coordenadas (20 pixels mais para baixo)
    GUISystem.Instance():GetRootWindow():AddChildWindow(DAT)

    LuaTimer:scheduleTimer(Updater, 500, -1) -- Atualiza a cada 500ms
end

Dates()

function Tps()
    local DATO = GUIManager:createGUIWindow(GUIType.StaticText, "GUIRoot-Group")
    DATO:SetVisible(true)

    local hue = 0
    local timeFormat = "%I:%M %p %m/%d/%Y"

    local function Updatec()
        local currentTime = os.date(timeFormat)
        DATO:SetText("Date & Time: " .. currentTime)
        
        hue = (hue + 0.5) % 360
        local r, g, b, a = interpolateColor(hue)
        DATO:SetTextColor({r, g, b, 0.6})
    end

    DATO:SetWidth({ 0, 200 })
    DATO:SetHeight({ 0, 20 })
    DATO:SetXPosition({ 0, 15 })
    DATO:SetBordered(true)
    DATO:SetYPosition({ 0, 695 })
    GUISystem.Instance():GetRootWindow():AddChildWindow(DATO)

    LuaTimer:scheduleTimer(Updatec, 100, -1)
end

function readFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

function extractLanguage(content)
    local languagePattern = '"language":"(%a+)"'
    return content:match(languagePattern)
end

function adjustTimeFormatByLanguage(language)
    if language == "pt" then
        return "%H:%M %d/%m/%Y"
    elseif language == "en" then
        return "%I:%M %p %m/%d/%Y"
    else
        return "%I:%M %p %m/%d/%Y"
    end
end

local filePath = "/storage/emulated/0/Android/data/com.sandboxol.blockymods/files/Download/SandboxOL/BlockMan/config/client.log"

local content = readFile(filePath)
if content then
    local language = extractLanguage(content)
    
    if language then
        timeFormat = adjustTimeFormatByLanguage(language)
    end
end

Tps()

function FpsPing()
    local fpsPingButton = GUIManager:createGUIWindow(GUIType.StaticText, "GUIRoot-FpsPing")
    fpsPingButton:SetVisible(true)

    local hue = 0

    local function UpdateFpsPing()
        local fps = Root.Instance():getFPS()
        local ping = ClientNetwork.Instance():getRaknetPing()
        local players = #PlayerManager:getPlayers()

        fpsPingButton:SetText("FPS: " .. fps .. " | Ping: " .. ping .. " | Players: " .. players)

        hue = (hue + 0.5) % 360
        local r, g, b, a = interpolateColor(hue)
        fpsPingButton:SetTextColor({r, g, b, 0.6})
    end

    fpsPingButton:SetWidth({ 0, 200 })
    fpsPingButton:SetHeight({ 0, 20 })
    fpsPingButton:SetXPosition({ 0, 15 })
    fpsPingButton:SetBordered(true)
    fpsPingButton:SetYPosition({ 0, 645 })
    GUISystem.Instance():GetRootWindow():AddChildWindow(fpsPingButton)

    LuaTimer:scheduleTimer(UpdateFpsPing, 1000, -1)
end

FpsPing()

    self.CGame = CGame.Instance()
    self.GameType = self.CGame:getGameType()
    self.EnableIndie = self.CGame:isEnableIndie(true)
    self.Blockman = Blockman.Instance()
    self.World = self.Blockman:getWorld()
    self.LowerDevice = self.CGame:isLowerDevice()
    EngineWorld:setWorld(self.World)

local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end



local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end



local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end




local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end



local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end



local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end



local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end


          
local UIGMTab = require "engine_client.ui.window.GUIGMTab"

local hue = 0

local function interpolateColor(hue)
    local r, g, b, a = 0, 0, 0, 0
    if hue < 60 then
        r, g, b, a = 1, hue / 60, 0, 1 - (hue / 60)
    elseif hue < 120 then
        r, g, b, a = (120 - hue) / 60, 1, 0, (hue - 60) / 60
    elseif hue < 180 then
        r, g, b, a = 0, 1, (hue - 120) / 60, 1 - ((hue - 120) / 60)
    elseif hue < 240 then
        r, g, b, a = 0, (240 - hue) / 60, 1, (hue - 180) / 60
    elseif hue < 300 then
        r, g, b, a = (hue - 240) / 60, 0, 1, 1 - ((hue - 240) / 60)
    else
        r, g, b, a = 1, 0, (360 - hue) / 60, (hue - 300) / 60
    end
    return r, g, b, a
end



function UIGMTab:onLoad()
    local hue = 0
    self.tvTab = self:getChildWindowByName("GMButton", GUIType.StaticText)
    self.tvTab:registerEvent(GUIEvent.Click, function()
        GUIGMControlPanel:selectTab(self.name)
    end)
    self.tvTab:SetBordered(true)

    local function rgbUpdatev1()
        hue = (hue + 0.5) % 360
        local r, g, b, a = interpolateColor(hue)
        self.tvTab:SetTextColor({ r, g, b, 0.6 })
    end

    LuaTimer:scheduleTimer(rgbUpdatev1, 100, -1)
end




end

function Game:isOpenGM()
    return isClient
end

local Settings = {}
GMHelper = {}
GMSetting = {}

local function isGMOpen(userId)
    if isServer then
        return true
    end
    return TableUtil.include(AdminIds, tostring(userId))
end

function GMSetting:addTab(tab_name, index)
    for _, setting in pairs(Settings) do
        if setting.name == tab_name then
            setting.items = {}
            return
        end
    end
    index = index or #Settings + 1
    table.insert(Settings, index, { name = tab_name, items = {} })
end

function GMSetting:addItem(tab_name, item_name, func_name, ...)
    local settings
    for _, group in pairs(Settings) do
        if group.name == tab_name then
            settings = group
        end
    end
    if not settings then
        GMSetting:addTab(tab_name)
        GMSetting:addItem(tab_name, item_name, func_name, ...)
        return
    end
    table.insert(settings.items, { name = item_name, func = func_name, params = { ... } })
end

function GMSetting:getSettings()
    return Settings
end

GMSetting:addTab("main")

local allItems = {
    {"Unlimited Jumps", "AirJump"},
    {"Speed", "Speed"},
    {"AutoClick", "AutoClick"},
    {"Blink", "Blink"},
    {"Tracer", "Tracer"},
    {"TracerForEnemies", "TracerForEnemies"},
    {"tpKill", "ardenkill"},
    {"ClickTP", "Clecktp"},
    {"Teleport to Other Players", "showPlayerTeleportMenu"},
    {"AimBot", "aimbot7"},
    {"DevFly", "FlySpeed"},
    {"LongJump", "LongJump"},
    {"FastBreak", "FastBreak"},
    {"NoClip", "toggleNoClip"},
    {"Jetpack", "Button2"},
    {"Reach", "toggleBlockReach"},
    {"Hitbox", "setHitboxSize"},
    {"CrossHair", "toggleCrossHairsVisibility"},
    {"FlyParachute", "FlyParachute"},
    {"Scaffold", "Scaffold"},
    {"TargetClicker", "TargetClicker"},
    {"Respawn", "Respawn"},
    {"fly2", "toggleJetPackv4"},
    {"DDOSV4", "LagServer4"},
    {"TransBackground", "setP"},
    {"ddos2", "ddos2"},
    {"addItem", "addItem"},
    {"vip 10 name", "UpdatePlayerNickname"}
}

for _, item in ipairs(allItems) do
    GMSetting:addItem("main", "^00FFFF" .. item[1], item[2])
end

local playerButtons = {}  -- Tabela para armazenar os botões dos jogadores
local menuWindow  -- Variável para armazenar a referência do menu

function GMHelper:showPlayerTeleportMenu()
    -- Verifica se o menu já existe
    if not menuWindow then
        -- Cria o menu se ele não existir
        menuWindow = GUIManager:createGUIWindow(GUIType.Window, "PlayerTeleportMenu")
        menuWindow:SetWidth({0, 909})  -- Largura do menu
        menuWindow:SetHeight({0, 400})  -- Altura do menu
        menuWindow:SetXPosition({0, 500})  -- Posição X do menu
        menuWindow:SetYPosition({0, 100})   -- Posição Y do menu
        menuWindow:SetBackgroundColor({0.5, 0.5, 0.5, 0.6})  -- Cor de fundo
        menuWindow:SetVisible(true)  -- Torna o menu visível

        -- Cria o botão de fechar
        local closeButton = GUIManager:createGUIWindow(GUIType.Button, "button-Close")
        closeButton:SetWidth({0, 60})  -- Largura do botão de fechar
        closeButton:SetHeight({0, 60})  -- Altura do botão de fechar
        closeButton:SetNormalImage("set:tip_dialog.json image:btn_close")  -- Imagem normal do botão
        closeButton:SetPushedImage("set:tip_dialog.json image:btn_close")  -- Imagem quando pressionado
        closeButton:SetBackgroundColor({0, 0, 0, 0.5})  -- Cor de fundo do botão
        closeButton:SetVisible(true)  -- Torna o botão de fechar visível

        -- Evento de clique para fechar o menu
        closeButton:registerEvent(GUIEvent.ButtonClick, function()
            GMHelper:togglePlayerTeleportMenu()  -- Alterna a visibilidade do menu
        end)

        menuWindow:AddChildWindow(closeButton)  -- Adiciona o botão de fechar ao menu
        GUISystem.Instance():GetRootWindow():AddChildWindow(menuWindow)  -- Adiciona o menu à janela raiz
    else
        -- Se o menu já existe, apenas torna-o visível novamente
        menuWindow:SetVisible(true)
    end

    -- Atualiza a lista de jogadores quando o menu é exibido
    updatePlayerButtons()
end

function GMHelper:createPlayerButton(player)
    local playerName = player:getName()

    -- Se o botão já existir, não o cria novamente
    if playerButtons[playerName] then
        playerButtons[playerName]:SetVisible(true)
        return
    end

    local playerButton = GUIManager:createGUIWindow(GUIType.Button, "TeleportButton" .. playerName)
    playerButton:SetText(playerName)  -- Nome do jogador no botão
    playerButton:SetWidth({0, 220})  -- Largura do botão
    playerButton:SetHeight({0, 40})  -- Altura do botão

    -- Define a posição X e Y do botão
    local posX = 10 + (#playerButtons % 4) * (220 + 10)  -- 4 botões por linha
    local posY = 70 + math.floor(#playerButtons / 4) * (40 + 10)  -- Posição Y do botão
    playerButton:SetXPosition({0, posX})  -- Posição X do botão
    playerButton:SetYPosition({0, posY})  -- Posição Y do botão

    -- Define a cor de fundo do botão
    playerButton:SetBackgroundColor({0, 0, 0, 0.5})  -- Preto com 50% de opacidade

    -- Evento de clique para teleportar
    playerButton:registerEvent(GUIEvent.ButtonClick, function()
        local me = PlayerManager:getClientPlayer()
        local targetPos = player:getPosition()
        targetPos.y = targetPos.y + 2.0  -- Ajusta a altura em relação ao jogador

        -- Teleporta o jogador
        if me then
            me.Player:setPosition(targetPos)  -- Teleporta para a posição do jogador
            UIHelper.showToast("Teleported to " .. playerName)  -- Mensagem de feedback
        end
    end)

    menuWindow:AddChildWindow(playerButton)  -- Adiciona o botão ao menu
    playerButtons[playerName] = playerButton  -- Adiciona o botão à tabela
end

-- Função para atualizar a lista de jogadores
function updatePlayerButtons()
    local players = PlayerManager:getPlayers()
    local currentPlayerNames = {}

    -- Adiciona botões para jogadores que ainda estão no jogo
    for _, player in ipairs(players) do
        if player ~= PlayerManager:getClientPlayer() then
            currentPlayerNames[player:getName()] = true
            GMHelper:createPlayerButton(player)  -- Cria ou atualiza o botão do jogador
        end
    end

    -- Remove botões de jogadores que não estão mais presentes
    for playerName, playerButton in pairs(playerButtons) do
        if not currentPlayerNames[playerName] then
            playerButton:SetVisible(false)  -- Torna o botão invisível
        end
    end
end

-- Função para alternar a visibilidade do menu e dos botões
function GMHelper:togglePlayerTeleportMenu()
    if menuWindow then
        local isVisible = menuWindow:IsVisible()
        menuWindow:SetVisible(not isVisible)  -- Alterna a visibilidade do menu

        -- Alterna a visibilidade de todos os botões
        for _, playerButton in pairs(playerButtons) do
            playerButton:SetVisible(not isVisible)
        end
    end
end


-- Verifica o tipo de jogo
if CGame.Instance():getGameType() == "g1026" then
    -- Adiciona a aba "Tnt tag"
    GMSetting:addTab("Tnt tag")

    -- Adiciona os itens na aba "Tnt tag" com a cor apropriada
    GMSetting:addItem("Tnt tag", "^00FFFF" .. "tnt_tag_respawn_game_1_", "tnt_tag_respawn_game_1_")
end

local function detectUserLanguage()
    local filePath = "/storage/emulated/0/Android/data/com.sandboxol.blockymods/files/Download/SandboxOL/BlockMan/config/client.log"
    local file, err = io.open(filePath, "r")
    if not file then
        return "en"
    end
    for line in file:lines() do
        if line:find('"language":"pt"') then
            file:close()
            return "pt"
        elseif line:find('"language":"en"') then
            file:close()
            return "en"
        elseif line:find('"language":"es"') then
            file:close()
            return "es"
        elseif line:find('"language":"ru"') then
            file:close()
            return "ru"
        elseif line:find('"language":"it"') then
            file:close()
            return "it"
        elseif line:find('"language":"ar"') then
            file:close()
            return "ar"
        elseif line:find('"language":"de"') then
            file:close()
            return "de"
        end
    end
    file:close()
    return "en"
end

local userLanguage = detectUserLanguage()

local translations = {
    ["Add Teleport Tab"] = {pt = "Adicionar Aba de Teletransporte", en = "Add Teleport Tab", es = "Agregar Pestaña de Teletransporte", ru = "Добавить вкладку телепорта", it = "Aggiungi scheda di teletrasporto", ar = "إضافة علامة تبويب النقل", de = "Teleport-Tab hinzufügen"},
    ["AntiLag"] = {pt = "Anti-Lag", en = "AntiLag", es = "Anti-Lag", ru = "Антилаг", it = "AntiLag", ar = "مضاد التأخير", de = "Anti-Lag"},
    ["Change Actor For Me"] = {pt = "Mudar Ator Para Mim", en = "Change Actor For Me", es = "Cambiar Actor Para Mí", ru = "Изменить актера для меня", it = "Cambia Attore Per Me", ar = "تغيير الممثل لي", de = "Schauspieler für mich ändern"},
    ["CustomDialog"] = {pt = "Diálogo Personalizado", en = "CustomDialog", es = "Diálogo Personalizado", ru = "Пользовательский диалог", it = "Dialogo Personalizzato", ar = "حوار مخصص", de = "Benutzerdefinierter Dialog"},
    ["Emote Freezer"] = {pt = "Congelador de Emojis", en = "Emote Freezer", es = "Congelador de Emojis", ru = "Замораживание эмоций", it = "Freezer di Emozioni", ar = "مجمد الرموز التعبيرية", de = "Emote-Freeze"},
    ["EHurt Camera"] = {pt = "Câmera de Dano", en = "EHurt Camera", es = "Cámara de Daño", ru = "Камера Урона", it = "Telecamera di Danno", ar = "كاميرا ضرر", de = "Schadenkamera"},
    ["EWings"] = {pt = "Asas", en = "EWings", es = "Alas", ru = "Крылья", it = "Ali", ar = "أجنحة", de = "Flügel"},
    ["ESky"] = {pt = "Céu", en = "ESky", es = "Cielo", ru = "Небо", it = "Cielo", ar = "سماء", de = "Himmel"},
    ["Max FPS"] = {pt = "FPS Máximo", en = "Max FPS", es = "FPS Máximo", ru = "Макс FPS", it = "FPS Massimo", ar = "حد أقصى للصور في الثانية", de = "Max FPS"},
    ["Runcode"] = {pt = "Executar Código", en = "RunCode", es = "Ejecutar Código", ru = "Запустить код", it = "Esegui Codice", ar = "تشغيل الرمز", de = "Code ausführen"},
    ["Set Max FPS"] = {pt = "Definir FPS Máximo", en = "Set Max FPS", es = "Establecer FPS Máximo", ru = "Установить максимальный FPS", it = "Imposta FPS Massimo", ar = "تعيين الحد الأقصى للصور في الثانية", de = "Max FPS einstellen"},
    ["Spam Chat2"] = {pt = "Spamar Chat2", en = "Spam Chat2", es = "Spam Chat2", ru = "Спам Чат2", it = "Spam Chat2", ar = "سبام الدردشة 2", de = "Spam-Chat2"},
    ["Super AntiLag"] = {pt = "Super Anti-Lag", en = "Super AntiLag", es = "Super Anti-Lag", ru = "Супер Антилаг", it = "Super AntiLag", ar = "مضاد التأخير الفائق", de = "Super Anti-Lag"},
    ["WWE_Camera"] = {pt = "Câmera WWE", en = "WWE_Camera", es = "Cámara WWE", ru = "Камера WWE", it = "Telecamera WWE", ar = "كاميرا WWE", de = "WWE-Kamera"}
}

local function translate(item)
    local translation = translations[item]
    if translation then
        return translation[userLanguage] or item
    else
        return item
    end
end

-- Itens da aba principal
local mainItems = {
    {"Add Teleport Tab", "addabadeteleport"},
    {"AntiLag", "AntiLag"},
    {"Change Actor For Me", "ChangeActorForMe"},
    {"CustomDialog", "createCustomDialogFromInput"},
    {"Emote Freezer", "EmoteFreezer"},
    {"EHurt Camera", "toggleHurtCamera"},
    {"EWings", "Wings"},
    {"ESky", "Skys"},
    {"Max FPS", "MaxFPS"},
    {"Set Max FPS", "SetMaxFPS"},
    {"Spam Chat2", "SpamChat2"},
    {"Super AntiLag", "SuperAntiLag"},
    {"WWE_Camera", "WWE_Camera"}
}

-- Adiciona os itens na aba principal com a cor apropriada
for _, item in ipairs(mainItems) do
    GMSetting:addItem("main", "^00FFFF" .. translate(item[1]), item[2])  -- Cor azul ciano
end

local function detectUserLanguage()
    local filePath = "/storage/emulated/0/Android/data/com.sandboxol.blockymods/files/Download/SandboxOL/BlockMan/config/client.log"
    local file = io.open(filePath, "r")
    if not file then
        return "en"
    end

    for line in file:lines() do
        if line:find('"language":"pt"') then
            file:close()
            return "pt"
        elseif line:find('"language":"en"') then
            file:close()
            return "en"
        elseif line:find('"language":"es"') then
            file:close()
            return "es"
        elseif line:find('"language":"ru"') then
            file:close()
            return "ru"
        elseif line:find('"language":"it"') then
            file:close()
            return "it"
        elseif line:find('"language":"ar"') then
            file:close()
            return "ar"
        elseif line:find('"language":"de"') then
            file:close()
            return "de"
        end
    end

    file:close()
    return "en"
end

local userLanguage = detectUserLanguage()

local translations = {
    ["Day"] = { pt = "Dia", en = "Day", es = "Día", ru = "День", it = "Giorno", ar = "يوم", de = "Tag" },
    ["Evening"] = { pt = "Noite", en = "Evening", es = "Noche", ru = "Вечер", it = "Sera", ar = "مساء", de = "Abend" },
    ["Snow"] = { pt = "Neve", en = "Snow", es = "Nieve", ru = "Снег", it = "Neve", ar = "ثلج", de = "Schnee" },
    ["Change Weather"] = { pt = "Mudar o Tempo", en = "Change Weather", es = "Cambiar el Clima", ru = "Изменить погоду", it = "Cambia il Tempo", ar = "تغيير الطقس", de = "Wetter ändern" },
    ["Toggle Sky"] = { pt = "Alternar Céu", en = "Toggle Sky", es = "Alternar Cielo", ru = "Переключить Небо", it = "Alterna Cielo", ar = "تبديل السماء", de = "Himmel umschalten" },
    ["Custom Sky"] = { pt = "Céu Personalizado", en = "Custom Sky", es = "Cielo Personalizado", ru = "Пользовательское небо", it = "Cielo Personalizzato", ar = "سماء مخصصة", de = "Benutzerdefinierter Himmel" }
}

local function translate(item)
    local translation = translations[item]
    if translation then
        return translation[userLanguage] or item
    else
        return item
    end
end

-- Traduz o nome da aba "Custom Sky"
GMSetting:addTab(translate("Custom Sky"))

local customSkyItems = {
    {"Day", "Day"},
    {"Night", "Night"},
    {"Snow", "Snow"},
    {"Change Weather", "ChangeWeather"},
    {"Toggle Sky", "toggleSky"}
}

for _, item in ipairs(customSkyItems) do
    GMSetting:addItem(translate("Custom Sky"), translate(item[1]), item[2])
end

GMSetting:addTab("music")
GMSetting:addItem("music", "^00FFFFtheme_sea", "theme_sea")
GMSetting:addItem("music", "^00FFFFtheme_home", "play_theme_home")
GMSetting:addItem("music", "^00FFFFtheme_dead", "play_theme_dead")
GMSetting:addItem("music", "^00FFFFgame_complete", "play_game_complete")
GMSetting:addItem("music", "^00FFFFplane_sound", "play_plane_sound")
GMSetting:addItem("music", "^00FFFFloading_music", "play_loading_music")

GMSetting:addTab("Credits")
GMSetting:addItem("Credits", "^7803FFinfo", "1")
GMSetting:addItem("Credits", "^7803FFyoutube", "1")
GMSetting:addItem("Credits", "^7803FFdiscord", "1")
GMSetting:addItem("Credits", "", "1")
GMSetting:addItem("Credits", "", "1")
GMSetting:addItem("Credits", "^7803FFZpanel by Znyxus", "1")
GMSetting:addItem("Credits", "@VortexHacker1", "1")
GMSetting:addItem("Credits", "@VortexHacker1", "1")
GMSetting:addItem("Credits", "", "1")
GMSetting:addItem("Credits", "", "1")
GMSetting:addItem("Credits", "^7803FFSec Dev VortexHacker", "1")
GMSetting:addItem("Credits", "@ZynxusBG", "1")
GMSetting:addItem("Credits", "@zynxus_", "1")
GMSetting:addItem("Credits", "", "1")
GMSetting:addItem("Credits", "", "1")
GMSetting:addItem("Credits", "More credits", "info")

local function detectUserLanguage()
    local filePath = "/storage/emulated/0/Android/data/com.sandboxol.blockymods/files/Download/SandboxOL/BlockMan/config/client.log"
    local file = io.open(filePath, "r")
    if not file then
        return "en"
    end

    for line in file:lines() do
        if line:find('"language":"pt"') then
            file:close()
            return "pt"
        elseif line:find('"language":"en"') then
            file:close()
            return "en"
        elseif line:find('"language":"es"') then
            file:close()
            return "es"
        elseif line:find('"language":"ru"') then
            file:close()
            return "ru"
        elseif line:find('"language":"it"') then
            file:close()
            return "it"
        elseif line:find('"language":"ar"') then
            file:close()
            return "ar"
        elseif line:find('"language":"de"') then
            file:close()
            return "de"
        end
    end

    file:close()
    return "en"
end

local userLanguage = detectUserLanguage()

local translations = {
    ["BlueWings"] = { pt = "Asas Azuis", en = "BlueWings", es = "Alas Azules", ru = "Синие Крылья", it = "Ali Blu", ar = "أجنحة زرقاء", de = "Blaue Flügel" },
    ["FireWings"] = { pt = "Asas de Fogo", en = "FireWings", es = "Alas de Fuego", ru = "Огненные Крылья", it = "Ali di Fuoco", ar = "أجنحة نارية", de = "Feuerflügel" },
    ["GoldWings"] = { pt = "Asas Douradas", en = "GoldWings", es = "Alas Doradas", ru = "Золотые Крылья", it = "Ali Dorate", ar = "أجنحة ذهبية", de = "Goldene Flügel" },
    ["IceWings"] = { pt = "Asas de Gelo", en = "IceWings", es = "Alas de Hielo", ru = "Ледяные Крылья", it = "Ali di Ghiaccio", ar = "أجنحة جليدية", de = "Eisflügel" },
    ["PinkWings"] = { pt = "Asas Rosas", en = "PinkWings", es = "Alas Rosadas", ru = "Розовые Крылья", it = "Ali Rosa", ar = "أجنحة وردية", de = "Rosa Flügel" },
    ["RainbowWings"] = { pt = "Asas do Arco-íris", en = "RainbowWings", es = "Alas Arcoíris", ru = "Радужные Крылья", it = "Ali Arcobaleno", ar = "أجنحة قوس قزح", de = "Regenbogenflügel" },
    ["YellowWings"] = { pt = "Asas Amarelas", en = "YellowWings", es = "Alas Amarillas", ru = "Желтые Крылья", it = "Ali Gialle", ar = "أجنحة صفرas", de = "Gelbe Flügel" },
    ["View"] = { pt = "Visão", en = "View", es = "Vista", ru = "Вид", it = "Vista", ar = "عرض", de = "Ansicht" }
}

local function translate(item)
    local translation = translations[item]
    if translation then
        return translation[userLanguage] or item
    else
        return item
    end
end

-- Traduz o nome da aba "View"
GMSetting:addTab(translate("View"))

local viewItems = {
    {"BlueWings", "ShareWings"},
    {"FireWings", "XLFireWings"},
    {"GoldWings", "XLGoldWings"},
    {"IceWings", "XLIceWings"},
    {"PinkWings", "PinkWings"},
    {"RainbowWings", "XLRainbow"},
    {"YellowWings", "YellowWings"}
}

for _, item in ipairs(viewItems) do
    GMSetting:addItem(translate("View"), "^00FFFF" .. translate(item[1]), item[2])  -- Cor diretamente definida aqui
end

local function detectUserLanguage()
    local filePath = "/storage/emulated/0/Android/data/com.sandboxol.blockymods/files/Download/SandboxOL/BlockMan/config/client.log"
    local file = io.open(filePath, "r")
    if not file then return "en" end
    for line in file:lines() do
        if line:find('"language":"pt"') then
            file:close()
            return "pt"
        elseif line:find('"language":"en"') then
            file:close()
            return "en"
        elseif line:find('"language":"es"') then
            file:close()
            return "es"
        elseif line:find('"language":"ru"') then
            file:close()
            return "ru"
        elseif line:find('"language":"it"') then
            file:close()
            return "it"
        elseif line:find('"language":"ar"') then
            file:close()
            return "ar"
        end
    end
    file:close()
    return "en"
end

local userLanguage = detectUserLanguage()

local translations = {
    ["ArmSpeed"] = { pt = "Velocidade do Braço", en = "ArmSpeed", es = "Velocidad de Brazo", ru = "Скорость Руки", it = "Velocità del Braccio", ar = "سرعة الذراع" },
    ["ChangeActorForMe"] = { pt = "Mudar Ator Para Mim", en = "ChangeActorForMe", es = "Cambiar Actor Para Mí", ru = "Сменить Актера Для Меня", it = "Cambia Attore Per Me", ar = "تغيير الممثل من أجلي" },
    ["ChangeNick"] = { pt = "Mudar Nick", en = "ChangeNick", es = "Cambiar Nick", ru = "Сменить Ник", it = "Cambia Nick", ar = "تغيير اللقب" },
    ["changeScale"] = { pt = "Alterar Escala", en = "changeScale", es = "Cambiar Escala", ru = "Изменить Масштаб", it = "Cambia Scala", ar = "تغيير الحجم" },
    ["CloseGame"] = { pt = "Fechar Jogo", en = "CloseGame", es = "Cerrar Juego", ru = "Закрыть Игра", it = "Chiudi Gioco", ar = "إغلاق اللعبة" },
    ["CopyPlayersInfo"] = { pt = "Copiar Informações dos Jogadores", en = "CopyPlayersInfo", es = "Copiar Información de Jugadores", ru = "Скопировать Информацию Игроков", it = "Copia Informazioni Giocatori", ar = "نسخ معلومات اللاعبين" },
    ["JumpHeight"] = { pt = "Altura do Salto", en = "JumpHeight", es = "Altura de Salto", ru = "Высота Прыжка", it = "Altezza Salto", ar = "ارتفاع القفز" },
    ["NoFall"] = { pt = "Sem Queda", en = "NoFall", es = "Sin Caída", ru = "Без Падения", it = "Nessuna Caduta", ar = "بدون سقوط" },
    ["RenderWorld"] = { pt = "Renderizar Mundo", en = "RenderWorld", es = "Renderizar Mundo", ru = "Рендеринг Мира", it = "Renderizza Mondo", ar = "تقديم العالم" },
    ["SetMaxFPS"] = { pt = "Definir FPS Máximo", en = "SetMaxFPS", es = "Establecer FPS Máximo", ru = "Установить Максимальный FPS", it = "Imposta FPS Massimo", ar = "تعيين FPS أقصى" },
    ["TeleportByUID"] = { pt = "Teletransportar Por UID", en = "TeleportByUID", es = "Teletransportar Por UID", ru = "Телепорт По UID", it = "Teletrasporta Per UID", ar = "الانتقال بواسطة UID" },
    ["ViewFreecam"] = { pt = "Ativar Freecam", en = "activate Freecam", es = "activar Freecam", ru = "активировать Freecam", it = "attivare Freecam", ar = "تفعيل Freecam" },
    ["ViewFreecamX"] = { pt = "Desativar Freecam", en = "Disable Freecam", es = "Desactivar Freecam", ru = "Отключить Freecam", it = "Disattiva Freecam", ar = "تعطيل Freecam" },
    ["WaterPush"] = { pt = "Empurrar Água", en = "WaterPush", es = "Empujar Agua", ru = "Толкать Воду", it = "Spingere Acqua", ar = "دفع الماء" },
    ["WarnTP"] = { pt = "Avisar TP", en = "WarnTP", es = "Advertir TP", ru = "Предупредить TP", it = "Avvisa TP", ar = "تحذير TP" },
    ["WatchMode"] = { pt = "Modo de Observação", en = "WatchMode", es = "Modo de Observación", ru = "Режим Наблюдения", it = "Modalità Osservazione", ar = "وضع المشاهدة" },
    ["GameID"] = { pt = "ID do Jogo", en = "GameID", es = "ID del Juego", ru = "ID Игры", it = "ID del Gioco", ar = "معرف اللعبة" }
}

local function translate(item)
    local translation = translations[item]
    if translation then
        return translation[userLanguage] or item
    else
        return item
    end
end

GMSetting:addTab("special")

local specialItems = {
    {"ArmSpeed", "ArmSpeed"},
    {"ChangeActorForMe", "ChangeActorForMe"},
    {"ChangeNick", "ChangeNick"},
    {"changeScale", "changeScale"},
    {"CloseGame", "CloseGame"},
    {"CopyPlayersInfo", "CopyPlayersInfo"},
    {"JumpHeight", "JumpHeight"},
    {"NoFall", "NoFall"},
    {"RenderWorld", "RenderWorld"},
    {"SetMaxFPS", "SetMaxFPS"},
    {"TeleportByUID", "TeleportByUID"},
    {"ViewFreecam", "activate Freecam"},
    {"ViewFreecamX", "Disable Freecam"},
    {"WaterPush", "WaterPush"},
    {"WarnTP", "WarnTP"},
    {"WatchMode", "WatchMode"},
    {"GameID", "GameID"}
}



for _, item in ipairs(specialItems) do
    GMSetting:addItem("special", "^00FFFF" .. translate(item[1]), item[2])
end

GMSetting:addItem("custom hacks", "^00FFFFimmortal v2 (with bugs)", "toggleHealthCheck")
GMSetting:addTab("CustomGUI")
GMSetting:addItem("CustomGUI", "^00FFFFAimBotButton", "ezabcdefghijklmnop")
GMSetting:addItem("CustomGUI", "^00FFFFautoclick", "autoclickV3")
GMSetting:addItem("CustomGUI", "^00FFFFFastButtons", "FastButtons")
GMSetting:addItem("CustomGUI", "^00FFFFFlyBtn", "FlyBtn1")
GMSetting:addItem("CustomGUI", "^00FFFFFreecam", "Freecam")
GMSetting:addItem("CustomGUI", "^00FFFFHideBtn", "HideBtn")
GMSetting:addItem("CustomGUI", "^00FFFFParachuteButton", "ParachuteButton")
GMSetting:addItem("CustomGUI", "^00FFFFCannon", "buttoncannonabc2")
GMSetting:addItem("CustomGUI", "^00FFFFCannonWithParachute", "buttonMain175")
GMSetting:addItem("CustomGUI", "^00FFFFspeed", "speedbyttonez")
GMSetting:addTab("SkinChanger")
GMSetting:addItem("SkinChanger", "^00FFFFwing >", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFid", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFchoose", "ChangeWing")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "^00FFFFChangeFace >", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFid", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFchoose", "ChangeFace")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "^00FFFFChangeScarf >", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFid", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFchoose", "ChangeScarf")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "^00FFFFChangeTops >", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFid", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFchoose", "ChangeTops")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "^00FFFFChangeScarf >", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFid", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFchoose", "ChangeScarf")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "^00FFFFChangeGlasses >", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFid", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFchoose", "ChangeGlasses")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "^00FFFFChangeHair >", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFid", "botão1")
GMSetting:addItem("SkinChanger", "^00FFFFchoose", "ChangeHair")
GMSetting:addItem("SkinChanger", "", "1")
GMSetting:addItem("SkinChanger", "", "1")

GMSetting:addTab("Game & panel")
GMSetting:addItem("Game & panel", "^00FFFFRemove Panel", "removePanel")
GMSetting:addItem("Game & panel", "^00FFFFmakeGmButtonTran", "makeGmButtonTran")
GMSetting:addItem("Game & panel", "^00FFFFtoggleOpenAnimation", "toggleAnimation")
GMSetting:addItem("Game & panel", "^00FFFFtoggleCloseAnimation", "toggleCloseAnimation")

function GMHelper:setP(isOpen)
    SpamR = not SpamR
    GUIGMControlPanel:setBackgroundColor(Color.TRANS)
    if SpamR then
    GUIGMControlPanel:setBackgroundColor({ 0, 0, 0, 0.784314 })
    end
end

local off = 'off'
local on = 'on'
state2 = off
state1 = off
state3 = off
state4 = off
state5 = off
state6 = off
state7 = off
state8 = off
state9 = off
state10 = off
state11 = off
state12 = off
state13 = off
state14 = off
state15 = off
state16 = off
state17 = off
state18 = off
state19 = off
state20 = off
state21 = off
state100 = off
state23 = off

function GMHelper:enableGM()
    if GUIGMControlPanel then
        return
    end
    GUIGMControlPanel = UIHelper.newEngineGUILayout("GUIGMControlPanel", "GMControlPanel.json")
    GUIGMControlPanel:hide()
    GUIGMMain = UIHelper.newEngineGUILayout("GUIGMMain", "GMMain.json")
    GUIGMMain:show()
    local isOpenEventDialog = ClientHelper.getBoolForKey("g1008_isOpenEventDialog", false)
    GUIGMMain:changeOpenEventDialog(isOpenEventDialog)
    if GMSetting.addItemGMItems then
        GMSetting:addItemGMItems()
        GMSetting.addItemGMItems = 12
    end
end

function GMHelper:openInput(paramTexts, callBack)
    if type(paramTexts) ~= "table" then
        return
    end
    for _, paramText in pairs(paramTexts) do
        if type(paramText) ~= "string" then
            if isClient then
                assert(true, "param need string type")
            end
            return
        end
    end
    GUIGMControlPanel:openInput(paramTexts, callBack)
end

function GMHelper:callCommand(name,...)
    local func = self[name]
    if type(func) == "function" then
        func(self,...)
    end
    local data = { name = name, params = {... } }
end



function GMHelper:enableGM()
    if GUIGMControlPanel then
        return
    end
    GUIGMControlPanel = UIHelper.newEngineGUILayout("GUIGMControlPanel", "GMControlPanel.json")
    GUIGMControlPanel:hide()
    GUIGMMain = UIHelper.newEngineGUILayout("GUIGMMain", "GMMain.json")
    GUIGMMain:show()
    local isOpenEventDialog = ClientHelper.getBoolForKey("g1008_isOpenEventDialog", false)
    GUIGMMain:changeOpenEventDialog(isOpenEventDialog)
    if GMSetting.addItemGMItems then
        GMSetting:addItemGMItems()
        GMSetting.addItemGMItems = nil
    end
end

function GMHelper:openInput(paramTexts, callBack)
    if type(paramTexts) ~= "table" then
        return
    end
    for _, paramText in pairs(paramTexts) do
        if type(paramText) ~= "string" then
            if isClient then
                assert(true, "param need string type")
            end
            return
        end
    end
    GUIGMControlPanel:openInput(paramTexts, callBack)
end

function GMHelper:callCommand(name,...)
    local func = self[name]
    if type(func) == "function" then
        func(self,...)
    end
    local data = { name = name, params = {... } }
end

function GMHelper:Fly(text)
if state1 == off then
state1 = on
text:SetBackgroundColor(Color.RED)
UIHelper.showToast("^FF00EEFly Enabled")
local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
  PlayerManager:getClientPlayer().Player:setAllowFlying(true)
  PlayerManager:getClientPlayer().Player:setFlying(true)
  PlayerManager:getClientPlayer().Player:moveEntity(moveDir)
else
state1 = off
text:SetBackgroundColor(Color.BLACK)
UIHelper.showToast("^FF0000Fly Disabled")
local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
  PlayerManager:getClientPlayer().Player:setAllowFlying(false)
  PlayerManager:getClientPlayer().Player:setFlying(false)
end
end

state18 = state18 or "off"

function GMHelper:TracerForEnemies(text)
    if state18 == "off" then
        -- Ativar Tracer para equipes inimigas
        state18 = "on"
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00EEEnemy Tracer Enabled")

        -- Timer para atualizar as setas a cada 100 ms
        self.timer5 = LuaTimer:scheduleTimer(function()
            local me = PlayerManager:getClientPlayer()
            local myTeamId = me:getTeamId()
            
            -- Remove setas existentes
            me.Player:deleteAllGuideArrow()
            
            -- Adiciona setas apenas para jogadores inimigos
            local others = PlayerManager:getPlayers()
            for _, c_player in pairs(others) do
                if c_player ~= me and c_player:getTeamId() ~= myTeamId then
                    me.Player:addGuideArrow(c_player:getPosition())
                end
            end
        end, 100, -1)
    else
        -- Desativar Tracer
        PlayerManager:getClientPlayer().Player:deleteAllGuideArrow()
        UIHelper.showToast("^FF0000Enemy Tracer Disabled")
        text:SetBackgroundColor(Color.BLACK)

        -- Cancelar o timer se estiver ativo
        if self.timer5 then
            LuaTimer:cancel(self.timer5)
            self.timer5 = nil -- Limpa o timer após cancelamento
        end

        state18 = "off"
    end
end

function GMHelper:TargetClicker(text)
if state2 == on then
state2 = off
text:SetBackgroundColor(Color.BLACK)
    LuaTimer:cancel(self.timer)
    UIHelper.showToast("^FF0000TargetClicker Disabled")
    else
    state2 = on
    text:SetBackgroundColor(Color.RED)
    UIHelper.showToast("^FF00EETargetClicker Enabled")
        self.timer = LuaTimer:scheduleTimer(function()
            local me = PlayerManager:getClientPlayer()
            
            if me then
                local myPos = me.Player:getPosition()
                local players = PlayerManager:getPlayers()
                
                local myTeamId = me:getTeamId()
                local closestDistance = math.huge
                local closestPlayer = nil

                for _, player in pairs(players) do
                    if player ~= me and player:getTeamId() ~= myTeamId then
                        local playerPos = player:getPosition()
                        local distance = MathUtil:distanceSquare2d(playerPos, myPos)
                        
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end

                if closestPlayer ~= nil and closestDistance < 20 then
                    -- Get the health of the closest player, capped at 50.0
                    local health = math.min(closestPlayer:getHealth(), 50.0)
                    -- Add color formatting to the locationString
                    local locationString = string.format("%s ¦   %.1f^FF0000♥️", closestPlayer.name, health)

                    -- Show the colorized text
                    UIHelper.showToast(locationString)

                    local camera = SceneManager.Instance():getMainCamera()
                    local pos = camera:getPosition()
                    local dir = VectorUtil.sub3(closestPlayer:getPosition(), pos)

                    local yaw = math.atan2(dir.x, dir.z) / math.pi * -180
                    local calculate = math.sqrt(dir.x * dir.x + dir.z * dir.z)
                    local pitch = -math.atan2(dir.y, calculate) / math.pi * 180

                    me.Player.rotationYaw = yaw or 0
                    me.Player.rotationPitch = pitch or 0
                    CGame.Instance():handleTouchClick(800, 360)
                end
            end
        end, 1, -1)
    end
end




function GMHelper:Respawn(text)
    local player = PlayerManager:getClientPlayer().Player
    local timer3 = nil  -- Definindo dentro da função

    -- Revive o jogador
    PacketSender:getSender():sendRebirth()

    -- Atualiza a cor de fundo do texto para azul
    text:SetBackgroundColor(Color.RED)
end


function GMHelper:tnt_tag_respawn_game_1_(text)
    local player = PlayerManager:getClientPlayer().Player

    -- Ativa o modo assistir
    player:setAllowFlying(true)
    player:setFlying(true)
    player:setWatchMode(true)

    -- Teletransporta para a posição especificada
    player:setPosition(VectorUtil.newVector3(2295, 9, 65))

    -- Aguarda 1 segundo para dar tempo ao teletransporte
    LuaTimer:scheduleTimer(function()
        -- Revive o jogador
        PacketSender:getSender():sendRebirth()
        
        -- Sai do modo assistir após 2 segundos
        LuaTimer:scheduleTimer(function()
            player:setAllowFlying(false)
            player:setFlying(false)
            player:setWatchMode(false)
            text:SetBackgroundColor(Color.BLACK)
        end, 2000) -- 2000 milissegundos = 2 segundos

    end, 1000) -- 1000 milissegundos = 1 segundo
end



PacketHandlers = require("engine_client.packet.PidPacketHandler")
function PacketHandlers:AddEventToDialog(packet)
    if GUIGMMain then
        GUIGMMain:addEventToDialog(packet.event_map)
    else
        LuaTimer:schedule(function()
            PacketHandlers.AddEventToDialog(self, packet)
        end, 1000)
    end
end

function UIGMControlPanel:onLoad()
    self.root:SetLevel(1)
    self:getChildWindow("GMControlPanel-Close-Text"):SetText("×")
    local llTabs = self:getChildWindow("GMControlPanel-Tabs")
    self.llInput = self:getChildWindow("GMControlPanel-Input-Layout", GUIType.Layout)
    self.llInput:SetVisible(false)
    self.edInput = self:getChildWindow("GMControlPanel-Input-Edit", GUIType.Edit)
    self.lvTabs = IGUIListView.new("GMControlPanel-Tabs-List", llTabs)
    self.lvTabs:setItemSpace(5)

    local llContent = self:getChildWindow("GMControlPanel-Content")
    self.gvItems = IGUIGridView.new("GMControlPanel-Items-List", llContent)
    self.gvItems:setConfig(10, 10, 5)
    local itemW = (self.gvItems:getWidth() - 60) / 5
    ---@type GMItemAdapter
    self.adapter = UIHelper.newEngineAdapter("GMItemAdapter")
    self.adapter:setItemSize(itemW, 40)
    self.gvItems:setAdapter(self.adapter)

    local btnClose = self:getChildWindow("GMControlPanel-Close", GUIType.Button)
    btnClose:registerEvent(GUIEvent.ButtonClick, function()
        self:hide()
    end)

    local stFilterText = self:getChildWindow("GMControlPanel-FilterText", GUIType.StaticText)
    stFilterText:SetText("^FF0000By: Max/Zynxus & WxJpxW")
stFilterText:SetBordered(true)
    self.etFilterValue = self:getChildWindow("GMControlPanel-FilterValue", GUIType.Edit)
    self.etFilterValue:SetMaxLength(100)
    self.etFilterValue:SetBackgroundColor({ 0, 0, 0, 0 })
    self.etFilterValue:registerEvent(GUIEvent.EditTextInput, function(args)
        if args.trigger == 0 then
            self:selectTab(self.tab)
        end
    end)

    self.edInput:SetMaxLength(100)
    self.edInput:SetVisible(false)
    self.edInput:registerEvent(GUIEvent.EditTextInput, function(args)
        if args.trigger == 0 then
            self:inputText()
        end
    end)

    self.llInput:registerEvent(GUIEvent.Click, function()
        self:closeInput()
    end)

    self.gvItems.root:registerEvent(GUIEvent.ScrollMoveChange, function(args)
        if self.settings then
            self.settings.offset = args.offset
        end
    end)
end

function GMHelper:Speed(text)
    if self.state3 == nil or self.state3 == "off" then
        self.state3 = "on"
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00EESpeed Enabled")
        PlayerManager:getClientPlayer().Player:setSpeedAdditionLevel(15000) -- Velocidade desejada
    else
        self.state3 = "off"
        text:SetBackgroundColor(Color.BLACK)
        UIHelper.showToast("^FF0000Speed Disabled")
        PlayerManager:getClientPlayer().Player:setSpeedAdditionLevel(1) -- Velocidade normal
    end
end

function GMHelper:Parachute()
local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
PlayerManager:getClientPlayer().Player:moveEntity(moveDir)
PlayerManager:getClientPlayer().Player:startParachute()
end

function GMHelper:FlyParachute(text)
if state4 == off then
state4 = on
text:SetBackgroundColor(Color.RED)
local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
UIHelper.showToast("^FF00EEFlyParachute Enabled")
local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
  PlayerManager:getClientPlayer().Player:setAllowFlying(true)
  PlayerManager:getClientPlayer().Player:setFlying(true)
  PlayerManager:getClientPlayer().Player:moveEntity(moveDir)
  PlayerManager:getClientPlayer().Player:startParachute()
  else
  local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
  UIHelper.showToast("^FF0000FlyParachute Disabled")
  text:SetBackgroundColor(Color.BLACK)
  state4 = off
  PlayerManager:getClientPlayer().Player:setAllowFlying(false)
  PlayerManager:getClientPlayer().Player:setFlying(false)
  end
  end
  
  -- Inicialize o estado se ainda não estiver definido
function GMHelper:FlySpeed(text)
    -- Inicialize o estado se ainda não estiver definido
    self.state5 = self.state5 or "off"

    if self.state5 == "off" then
        -- Ativar FlySpeed
        self.state5 = "on"
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00EEFlySpeed Enabled")

        -- Ativar o voo, definir a velocidade aumentada e aplicar moveDir
        local player = PlayerManager:getClientPlayer()
        if player and player.Player then
            local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0) -- Define a direção de movimento
            player.Player:setAllowFlying(true)
            player.Player:setFlying(true)
            player.Player:setSpeedAdditionLevel(15000) -- Aumentar a velocidade
            player.Player:moveEntity(moveDir) -- Aplica o moveDir para efeito de elevação
        end
    else
        -- Desativar FlySpeed
        self.state5 = "off"
        text:SetBackgroundColor(Color.BLACK)
        UIHelper.showToast("^FF0000FlySpeed Disabled")

        -- Desativar o voo e resetar a velocidade
        local player = PlayerManager:getClientPlayer()
        if player and player.Player then
            player.Player:setAllowFlying(false)
            player.Player:setFlying(false)
            player.Player:setSpeedAdditionLevel(1) -- Voltar à velocidade normal
        end
    end
end
  
function GMHelper:FastButtons(text)
if state10 == off then
state10 = on
text:SetBackgroundColor(Color.RED)
UIHelper.showToast("^FF00EEFast Buttons Enabled")
GUIManager:getWindowByName("Main-Parachute"):SetVisible(true)
    GUIManager:getWindowByName("Main-Parachute"):SetXPosition({0, 1350})
    GUIManager:getWindowByName("Main-Parachute"):SetYPosition({0, 228})
    GUIManager:getWindowByName("Main-Parachute"):SetHeight({0, 60})
    GUIManager:getWindowByName("Main-Parachute"):SetWidth({0, 60})
    GUIManager:getWindowByName("Main-Parachute", GUIType.Button):registerEvent(GUIEvent.ButtonClick, function()
  if state6 == off then
  state6 = on
  local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
  PlayerManager:getClientPlayer().Player:setAllowFlying(true)
  PlayerManager:getClientPlayer().Player:setFlying(true)
  PlayerManager:getClientPlayer().Player:moveEntity(moveDir)
  PlayerManager:getClientPlayer().Player:setSpeedAdditionLevel(6000)
  UIHelper.showToast("^FF00EECheat Enabled")
  GUIManager:getWindowByName("PlayerInfo-Health"):SetVisible(true)
    PlayerManager:getClientPlayer().Player:startParachute()
  player.m_canBuildBlockQuickly = true
  player.m_quicklyBuildBlock = true
  else
  state6 = off
  local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
  PlayerManager:getClientPlayer().Player:setAllowFlying(false)
  PlayerManager:getClientPlayer().Player:setFlying(false)
  PlayerManager:getClientPlayer().Player:moveEntity(moveDir)
  PlayerManager:getClientPlayer().Player:setSpeedAdditionLevel(1)
  GUIManager:getWindowByName("PlayerInfo-Health"):SetVisible(false)
  player.m_canBuildBlockQuickly = false
  player.m_quicklyBuildBlock = false
  UIHelper.showToast("^FF0000Cheat Disabled")
end
end)
GUIManager:getWindowByName("Main-BuildWar-Block"):SetVisible(true)
    GUIManager:getWindowByName("Main-BuildWar-Block", GUIType.Button):registerEvent(GUIEvent.ButtonClick, function()
if state7 == on then
state7 = off
    LuaTimer:cancel(self.timer)
    UIHelper.showToast("^FF0000TargetClicker Disabled")
    else
    state7 = on
    UIHelper.showToast("^FF00EETargetClicker Enabled")
        self.timer = LuaTimer:scheduleTimer(function()
        PlayerManager:getClientPlayer().Player:setGlide(true)
            local me = PlayerManager:getClientPlayer()
            
            if me then
                local myPos = me.Player:getPosition()
                local players = PlayerManager:getPlayers()
                
                local myTeamId = me:getTeamId()
                local closestDistance = math.huge
                local closestPlayer = nil

                for _, player in pairs(players) do
                    if player ~= me and player:getTeamId() ~= myTeamId then
                        local playerPos = player:getPosition()
                        local distance = MathUtil:distanceSquare2d(playerPos, myPos)
                        
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end

                if closestPlayer ~= nil and closestDistance < 20 then
                    -- Get the health of the closest player, capped at 50.0
                    local health = math.min(closestPlayer:getHealth(), 50.0)
                    -- Add color formatting to the locationString
                    local locationString = string.format("%s ¦   %.1f^FF0000♥️", closestPlayer.name, health)

                    -- Show the colorized text
                    UIHelper.showToast(locationString)

                    local camera = SceneManager.Instance():getMainCamera()
                    local pos = camera:getPosition()
                    local dir = VectorUtil.sub3(closestPlayer:getPosition(), pos)

                    local yaw = math.atan2(dir.x, dir.z) / math.pi * -180
                    local calculate = math.sqrt(dir.x * dir.x + dir.z * dir.z)
                    local pitch = -math.atan2(dir.y, calculate) / math.pi * 180

                    me.Player.rotationYaw = yaw or 0
                    me.Player.rotationPitch = pitch or 0
                    CGame.Instance():handleTouchClick(800, 360)
                end
            end
        end, 1, -1)
    end
end)
GUIManager:getWindowByName("Main-Cannon"):SetVisible(true)
    GUIManager:getWindowByName("Main-Cannon"):SetYPosition({0, -315})
    GUIManager:getWindowByName("Main-Cannon"):SetXPosition({0, -25})
    GUIManager:getWindowByName("Main-Cannon"):SetHeight({0, 50})
    GUIManager:getWindowByName("Main-Cannon"):SetWidth({0, 50})
    GUIManager:getWindowByName("Main-Cannon", GUIType.Button):registerEvent(GUIEvent.ButtonClick, function()
    if state8 == off then
    state8 = on
    ClientHelper.putBoolPrefs("SyncClientPositionToServer", false)
	UIHelper.showToast("^00FF00Blink Enabled")
    else
    state8 = off
    ClientHelper.putBoolPrefs("SyncClientPositionToServer", true)
	UIHelper.showToast("^FF0000Blink Disabled")
end
end)
else
state10 = off
text:SetBackgroundColor(Color.BLACK)
UIHelper.showToast("^FF0000Fast Buttons Disabled")
GUIManager:getWindowByName("Main-Parachute"):SetVisible(false)
GUIManager:getWindowByName("Main-BuildWar-Block"):SetVisible(false)
GUIManager:getWindowByName("Main-Cannon"):SetVisible(false)
end
end

function GMHelper:GameID()
    UIHelper.showToast("GameID=" .. CGame.Instance():getGameType())
end

function GMHelper:AirJump(text)
    -- Inicialize o estado se ainda não estiver definido
    self.state9 = self.state9 or "off"

    if self.state9 == "off" then
        self.state9 = "on"
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00FFAirJump Enabled")
        ClientHelper.putBoolPrefs("EnableDoubleJumps", true)
        self.doubleJumpCount = 100000
    else
        self.state9 = "off"
        text:SetBackgroundColor(Color.BLACK)
        UIHelper.showToast("^FF0000AirJump Disabled")
        ClientHelper.putBoolPrefs("EnableDoubleJumps", false)
        self.doubleJumpCount = 1
    end
end
 
function GMHelper:Wing1()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 27
        end
        
function GMHelper:Wing2()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 159
        end
        
function GMHelper:WWE_Camera(text)
    if state11 == "off" then
        state11 = "on"
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00EEWWE_Camera Enabled")
        ClientHelper.putBoolPrefs("IsSeparateCamera", true)
    else
        state11 = "off"
        text:SetBackgroundColor(Color.BLACK)
        UIHelper.showToast("^FF0000WWE_Camera Disabled")
        ClientHelper.putBoolPrefs("IsSeparateCamera", false)
    end
end

-- Inicialize o estado se ainda não estiver definido

function GMHelper:LongJump(text)
    -- Inicialize o estado se ainda não estiver definido
    self.state12 = self.state12 or "off"

    if self.state12 == "off" then
        -- Ativar LongJump
        self.state12 = "on"
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00EELongJump Enabled")

        -- Iniciar o timer que aplica o efeito de "glide" no jogador
        self.timer2 = LuaTimer:scheduleTimer(function()
            local player = PlayerManager:getClientPlayer()
            if player and player.Player then
                player.Player:setGlide(true)
            end
        end, 1, -1)

    else
        -- Desativar LongJump
        self.state12 = "off"
        text:SetBackgroundColor(Color.BLACK)
        if self.timer2 then
            LuaTimer:cancel(self.timer2)  -- Cancelar o timer
            self.timer2 = nil
        end
        UIHelper.showToast("^FF0000LongJump Disabled")
    end
end

function GMHelper:Respawn(text)
    -- Revive o jogador
    PacketSender:getSender():sendRebirth()
    text:SetBackgroundColor(Color.RED)
    
    -- Cancela o timer existente se ele estiver ativo
    if self.timer3 then
        LuaTimer:cancel(self.timer3)
        self.timer3 = nil
    end
    
    -- Define um novo timer para resetar a cor do texto após 7 segundos
    self.timer3 = LuaTimer:scheduleTimer(function()
        text:SetBackgroundColor(Color.BLACK)
        self.timer3 = nil  -- Redefine o timer para nil após a execução
    end, 7000)
end

function GMHelper:reviveAll(text)
    text:SetBackgroundColor(Color.RED)
    UIHelper.showToast("^FF00EEAutomaticRebirth Enabled")
    
    local players = PlayerManager:getAllPlayers()  -- Ajuste o método conforme necessário
    for _, player in ipairs(players) do
        PacketSender:getSender():sendRebirth(player)
    end
end



local jajaHitboxVal
function GMHelper:Hitbox(text)
if state14 == off then
state14 = on
text:SetBackgroundColor(Color.RED)
    UIHelper.showToast("^FF00EEHitbox Enabled")
         self.timer4 = LuaTimer:scheduleTimer(function()
         local me = PlayerManager:getPlayers()
         me.Player.width = 10
        me.Player.length = 10
        end, 1, -1)
else
state14 = off
text:SetBackgroundColor(Color.BLACK)
UIHelper.showToast("^FF0000Hitbox Disabled")
LuaTimer:cancel(self.timer4)
        me.Player.width = 0.1
        me.Player.length = 0.1
end
end

function GMHelper:Blink(text)
    self.state15 = self.state15 or "off"

    if self.state15 == "off" then
        self.state15 = "on"
        text:SetBackgroundColor(Color.RED)
        ClientHelper.putBoolPrefs("SyncClientPositionToServer", false)
        UIHelper.showToast("^00FF00Blink Enabled")
    else
        self.state15 = "off"
        text:SetBackgroundColor(Color.BLACK)
        ClientHelper.putBoolPrefs("SyncClientPositionToServer", true)
        UIHelper.showToast("^FF0000Blink Disabled")
    end
end

function GMHelper:NoFall(text)
    self.state16 = self.state16 or "off"

    if self.state16 == "off" then
        self.state16 = "on"
        text:SetBackgroundColor(Color.RED)
        ClientHelper.putIntPrefs("SprintLimitCheck", 7)
        UIHelper.showToast("^FF00EENoFall Enabled")
    else
        self.state16 = "off"
        text:SetBackgroundColor(Color.BLACK)
        ClientHelper.putIntPrefs("SprintLimitCheck", 0)
        UIHelper.showToast("^FF0000NoFall Disabled")
    end
end

function GMHelper:ParachuteButton(text)
if state17 == on then
state17 = off
text:SetBackgroundColor(Color.BLACK)
UIHelper.showToast("^FF0000ParachuteButton Disabled")
GUIManager:getWindowByName("Main-Parachute"):SetVisible(false)
else
state17 = on
UIHelper.showToast("^FF00EEParachuteButton Enabled")
text:SetBackgroundColor(Color.BLACK)
GUIManager:getWindowByName("Main-Parachute"):SetVisible(true)
GUIManager:getWindowByName("Main-Parachute", GUIType.Button):registerEvent(GUIEvent.ButtonClick, function()
PlayerManager:getClientPlayer().Player:startParachute()
end)
end
end

function GMHelper:Wing3()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 160
        end
        
function GMHelper:Wing4()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 24
        end
        
function GMHelper:Wing5()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 22
        end
        
function GMHelper:Wing6()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 42
        end
        
-- Inicialize o estado se ainda não estiver definido
state18 = state18 or "off"

function GMHelper:Tracer(text)
    if state18 == "off" then
        -- Ativar Tracer
        state18 = "on"
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00EETracer Enabled")

        -- Timer para atualizar as setas a cada 100 ms
        self.timer5 = LuaTimer:scheduleTimer(function()
            local me = PlayerManager:getClientPlayer()
            local myTeamId = me:getTeamId()
            
            -- Remove setas existentes
            PlayerManager:getClientPlayer().Player:deleteAllGuideArrow()
            
            local others = PlayerManager:getPlayers()
            for _, c_player in pairs(others) do
                if c_player ~= me and c_player:getTeamId() ~= myTeamId then
                    -- Adiciona seta para jogadores inimigos
                    PlayerManager:getClientPlayer().Player:addGuideArrow(c_player:getPosition())
                end
            end
        end, 100, -1)
    else
        -- Desativar Tracer
        PlayerManager:getClientPlayer().Player:deleteAllGuideArrow()
        UIHelper.showToast("^FF0000Tracer Disabled")
        text:SetBackgroundColor(Color.BLACK)

        -- Cancelar o timer se estiver ativo
        if self.timer5 then
            LuaTimer:cancel(self.timer5)
            self.timer5 = nil -- Limpa o timer após cancelamento
        end

        state18 = "off"
    end
end

function GMHelper:addItem()
GMHelper:openInput({ "itemId" }, function(data)
    local item = Item.getItemById(data)
    if not item then
        return
    end
    PlayerManager:getClientPlayer():addItem(data, item:getItemStackLimit(), 1)
end)
end

function GMHelper:SpawnItem()
       GMHelper:openInput({ "ID", "Count" }, function(data2, data3)
  local position = PlayerManager:getClientPlayer():getPosition() 
  EngineWorld:addEntityItem(data2, data3, 0, 600, position, VectorUtil.ZERO)
end)
end

function GMHelper:Wing7()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 25
        end
        
function GMHelper:Wing8()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 26
        end
        
function GMHelper:Wing9()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 122
        end
        
function GMHelper:Wing10()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 105
        end

function GMHelper:Wing11()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 157
        end
        
function GMHelper:Wing12()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 158
        end
        
function GMHelper:Wing13()
        PlayerManager:getClientPlayer().Player.m_outLooksChanged = true
        PlayerManager:getClientPlayer().Player.m_wingId = 84
        end
        
function GMHelper:TpAuto(text)
if state19 == on then
text:SetBackgroundColor(Color.BLACK)
UIHelper.showToast("^FF0000AutoTp Disabled")
LuaTimer:cancel(self.timer6)
ClientHelper.putBoolPrefs("SyncClientPositionToServer", true)
state15 = off
state19 = off
else
state19 = on
state15 = on
text:SetBackgroundColor(Color.RED)
ClientHelper.putBoolPrefs("SyncClientPositionToServer", false)
UIHelper.showToast("^FF00EEAutoTp Enabled")
self.timer6 = LuaTimer:scheduleTimer(function()
    local me = PlayerManager:getClientPlayer()
    local player = PlayerManager:getClientPlayer().Player
    local players = PlayerManager:getPlayers()
    local myTeamId = me:getTeamId()
    if #players > 1 then
        local randomIndex = math.random(1, #players) -- Генерируем случайный индекс для выбора случайного игрока
        local randomPlayer = players[randomIndex] -- Получаем случайного игрока по индексу
        if randomPlayer:getTeamId() ~= myTeamId then
        player:setPosition(randomPlayer:getPosition())
end
end
end, 50, -1)
end
end

function GMHelper:TeleportAura(text)
if state20 == on then
state20 = off
text:SetBackgroundColor(Color.BLACK)
LuaTimer:cancel(self.timer8)
ClientHelper.putBoolPrefs("SyncClientPositionToServer", true)
UIHelper.showToast("^FF0000TeleportAura Disabled")
else
state20 = on
text:SetBackgroundColor(Color.RED)
UIHelper.showToast("^FF00EETeleportAura Enabled")
self.timer8 = LuaTimer:scheduleTimer(function()
local me = PlayerManager:getClientPlayer()
                local myPos = me.Player:getPosition()
                local players = PlayerManager:getPlayers()
                
                local myTeamId = me:getTeamId()
                local closestDistance = math.huge
                local closestPlayer = nil

                for _, player in pairs(players) do
                    if player ~= me and player:getTeamId() ~= myTeamId then
                        local playerPos = player:getPosition()
                        local distance = MathUtil:distanceSquare2d(playerPos, myPos)
                        
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
if closestDistance <= 70 then
state15 = on
local play = PlayerManager:getClientPlayer().Player
ClientHelper.putBoolPrefs("SyncClientPositionToServer", false)
play:setPosition(closestPlayer:getPosition())
CGame.Instance():handleTouchClick(800, 360)
else
state15 = off
ClientHelper.putBoolPrefs("SyncClientPositionToServer", true)
end
end
end, 50, -1)
end
end

GMHelper.FastKill=function(v139)if (state29==v0) then local v226=0;while true do if (v226==(0 -0)) then state29=v1;UIHelper.showToast("^FF00EEKillAura Enabled");v226=1 + 0 ;end if (v226==(690 -(586 + 103))) then v139.kill=LuaTimer:scheduleTimer(function()local v343=PlayerManager:getClientPlayer();local v344=v343.Player:getPosition();local v345=PlayerManager:getPlayers();local v346=v343:getTeamId();local v347=math.huge;local v348=nil;for v394,v395 in pairs(v345) do if ((v395~=v343) and (v395:getTeamId()~=v346)) then local v461=v395:getPosition();local v462=MathUtil:distanceSquare2d(v461,v344);if (v462<=(7 + 68)) then local v495=0 -0 ;while true do if (v495==0) then v395.Player.width=1493 -(1309 + 179) ;v395.Player.length=9 -4 ;v495=1 + 0 ;end if (v495==(2 -1)) then v395.Player.height=5;CGame.Instance():handleTouchClick(605 + 195 ,360);break;end end end end end end,1, -(1 -0));break;end end else local v227=0 -0 ;while true do if (v227==(609 -(295 + 314))) then state29=v0;UIHelper.showToast("^FF0000KillAura Disabled");v227=1;end if (v227==(2 -1)) then LuaTimer:cancel(v139.kill);player.Player.width=1962.1 -(1300 + 662) ;v227=6 -4 ;end if (v227==(1757 -(1178 + 577))) then player.Player.length=0.1;player.Player.height=0.1 + 0 ;break;end end end end;




GMHelper.RainbowWings=function(self)PlayerManager:getClientPlayer().Player.m_outLooksChanged=true;PlayerManager:getClientPlayer().Player.m_wingId=27;UIHelper.showToast("Sucess");end;GMHelper.XLGoldWings=function(self)PlayerManager:getClientPlayer().Player.m_outLooksChanged=true;PlayerManager:getClientPlayer().Player.m_wingId=26;UIHelper.showToast("Sucess");end;GMHelper.IceWings=function(self)PlayerManager:getClientPlayer().Player.m_outLooksChanged=true;PlayerManager:getClientPlayer().Player.m_wingId=24;UIHelper.showToast("Sucess");end;GMHelper.FireWings=function(self)PlayerManager:getClientPlayer().Player.m_outLooksChanged=true;PlayerManager:getClientPlayer().Player.m_wingId=20;UIHelper.showToast("Sucess");end;GMHelper.YellowWings=function(self)PlayerManager:getClientPlayer().Player.m_outLooksChanged=true;PlayerManager:getClientPlayer().Player.m_wingId=19;UIHelper.showToast("Sucess");end;GMHelper.PinkWings=function(self)PlayerManager:getClientPlayer().Player.m_outLooksChanged=true;PlayerManager:getClientPlayer().Player.m_wingId=18;UIHelper.showToast("Sucess");end;GMHelper.ShareWings=function(self)PlayerManager:getClientPlayer().Player.m_outLooksChanged=true;PlayerManager:getClientPlayer().Player.m_wingId=17;UIHelper.showToast("Sucess");end;

function GMHelper:HitBox1(text)
    -- Open input dialog to get height, width, and length from the user
    text:SetBackgroundColor(Color.RED)
    GMHelper:openInput({ "height", "width", "length" }, function(Num1, Num2, Num3)
        -- Get all players in the game
        local players = PlayerManager:getPlayers()
        -- Iterate through the list of players
        for _, player in ipairs(players) do
            local entity = player.Player

            -- Check if the player is not the client player
            if player ~= PlayerManager:getClientPlayer() then
                -- Set the player's entity dimensions to the provided values
                entity.height = Num1
                entity.width = Num2
                entity.length = Num3
            end
        end
    end)
end

function GMHelper:removePanel()
        CustomDialog.builder()
        CustomDialog.setTitleText("info")
        CustomDialog.setContentText(
            "-->you are about to remove the panel, are you sure u want to remove the panel, you must join sky pixel to reload again"
        )
        CustomDialog.setRightText("^FF0000remove")
        CustomDialog.setLeftText("^006633close")
        CustomDialog.setRightClickListener(
            function()
                print("Night:Starting Removal")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/criex.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1001/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1002/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1003/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1004/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1005/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1006/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1007/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1008/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1009/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1010/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1011/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1012/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1013/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1014/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1015/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1016/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1017/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1018/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1019/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1020/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1021/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1022/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1023/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1024/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1025/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1026/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1027/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1028/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1029/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1030/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1031/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1032/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1033/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1034/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1035/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1036/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1037/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1038/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1039/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1040/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1041/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1042/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1043/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1044/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1045/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1046/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1047/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1048/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1049/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1050/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1051/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1052/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1053/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1054/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1055/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1056/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1057/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1058/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1059/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1060/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1061/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1062/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1063/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1064/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1065/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1066/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1067/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1068/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1069/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1070/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1071/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1072/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1073/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1074/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1075/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1076/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1077/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1078/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1079/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1080/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1081/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1082/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1083/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1084/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1085/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1086/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1087/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1088/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1089/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1090/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1091/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1092/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1093/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1094/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1095/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1096/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1097/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1098/Loader.lua")
                os.remove("/data/user/0/com.sandboxol.blockymods/app_resources/Media/Scripts/Game/g1099/Loader.lua")
                UIHelper.showToast("Removed success")
            end
        )
        CustomDialog.setLeftClickListener(
            function()
                UIHelper.showToast("Closed")
            end
        )
        CustomDialog.show()
    end
    
    function GMHelper:SpamChat(text)
    text:SetBackgroundColor(Color.RED)
  GMHelper:openInput({ "" }, function(wiadomosc)
  LuaTimer:scheduleTimer(function()
  GUIManager:getWindowByName("Chat-Input-Box"):SetProperty("Text", wiadomosc)
  end, 5, 1000000)
  end) 
end

function GMHelper:info()
        CustomDialog.builder()
        CustomDialog.setTitleText("info")
        CustomDialog.setContentText(
            "-->this is panel made by Znyxus, VortexHacker  Crusty Team\n thanks for using our admin panel Client"
        )
        CustomDialog.setRightText("^FF0000Done")
        CustomDialog.setLeftText("^006633close")
        CustomDialog.setRightClickListener(
            function()
                UIHelper.showToast("done")
            end
        )
        CustomDialog.setLeftClickListener(
            function()
                UIHelper.showToast("Closed")
            end
        )
        CustomDialog.show()
    end
    
    local tpClickActive = false
local teleportCallbackRegistered = false


function GMHelper:Clecktp(text)
    tpClickActive = not tpClickActive  

    if tpClickActive then

        ClientHelper.putFloatPrefs("BlockReachDistance", 9999)
        ClientHelper.putFloatPrefs("EntityReachDistance", 6.5)

       
        text:SetBackgroundColor(Color.RED)

        
        if not teleportCallbackRegistered then
            Listener.registerCallBack(CEvents.ClickToBlockEvent, function(event)
                if tpClickActive then  
                    local pos = event
                    PlayerManager:getClientPlayer().Player:setPosition(VectorUtil.newVector3(pos.x + 0.4, pos.y + 3, pos.z + 0.4))
                end
            end)
            teleportCallbackRegistered = true
        end
    else

        ClientHelper.putFloatPrefs("BlockReachDistance", 6.5)
        ClientHelper.putFloatPrefs("EntityReachDistance", 5)


        text:SetBackgroundColor(Color.BLACK)


        if teleportCallbackRegistered then
            Listener.unregisterCallBack(CEvents.ClickToBlockEvent)
            teleportCallbackRegistered = false
        end
    end
end

function GMHelper:ddos2()
    local players = PlayerManager:getPlayers()
    LuaTimer:scheduleTimer(function()
        for _, player in pairs(players) do
            for i = 1, 20 do
                player:sendPacket({pid="pid"})
            end
        end
    end, 0.1, 11111)
end

function GMHelper:toggleCD(enable)
    if enable then
        ClientHelper.putBoolPrefs("banClickCD", true)
        ClientHelper.putIntPrefs("HurtProtectTime", 0)
        ClientHelper.putIntPrefs("ClickSceneCD", 0)
        UIHelper.showToast("^FF0000Attack time off")
    else
        ClientHelper.putBoolPrefs("banClickCD", false)
        ClientHelper.putIntPrefs("HurtProtectTime", 5) -- Default value or whatever you prefer
        ClientHelper.putIntPrefs("ClickSceneCD", 2) -- Default value or whatever you prefer
        UIHelper.showToast("^FF0000Attack time on")
    end
end

function GMHelper:addItem()
GMHelper:openInput({ "itemId" }, function(data)
    local item = Item.getItemById(data)
    if not item then
        return
    end
    PlayerManager:getClientPlayer():addItem(data, item:getItemStackLimit(), 1)
end)
end


-- Function to execute code from a file
function GMHelper:runCodeByFile()
    local filePath = "/storage/emulated/0/Android/data/com.sandboxol.blockymods/files/Download/SandboxOL/BlockManv2/map_temp/g20151633/runCode.lua"

    -- Try to open the file
    local file, err = io.open(filePath, "r")
    if not file then
        UIHelper.showToast("Error opening file: " .. (err or "Unknown"))
        return
    end

    -- Read the content of the file
    local code = file:read("*all")
    file:close()

    -- Try to load the code
    local func, execErr = load(code)
    if not func then
        UIHelper.showToast("Error loading code: " .. (execErr or "Unknown"))
        return
    end

    -- Execute the code
    local status, runtimeErr = pcall(func)
    if not status then
        UIHelper.showToast("Error during code execution: " .. (runtimeErr or "Unknown"))
    else
        UIHelper.showToast("Code executed successfully from file")
    end
end

GMSetting:addItem("main", "^00FFFFrunCodeByFile", "runCodeByFile")


function Cannon1()
    local mainCannonButton = GUIManager:getWindowByName("Main-Cannon")
    
    -- Exibe o botão "Main-Cannon"
    mainCannonButton:SetYPosition({0, -315})
    mainCannonButton:SetXPosition({0, -25})
    mainCannonButton:SetHeight({0, 60})
    mainCannonButton:SetWidth({0, 60})
    mainCannonButton:SetVisible(true)
    
    -- Associe a função ao evento de clique do botão "Main-Cannon"
    mainCannonButton:registerEvent(GUIEvent.ButtonClick, function()
        local clientPlayer = PlayerManager:getClientPlayer()
        if clientPlayer then
            -- Calculate the launch direction based on pitch and yaw
            local pitch = clientPlayer.Player:getPitch()
            local yaw = clientPlayer.Player:getYaw()

            local pitchRad = pitch * math.pi / 180
            local yawRad = yaw * -math.pi / 180
            local x = math.cos(pitchRad) * math.sin(yawRad) * 3 -- Increase cannon speed
            local y = -math.sin(pitchRad) * 20 -- Increase cannon speed
            local z = math.cos(pitchRad) * math.cos(yawRad) * 3 -- Increase cannon speed

            local newPos = VectorUtil.newVector3(x, y, z)
            clientPlayer.Player:setVelocity(newPos)
            clientPlayer.Player:startParachute() -- Start the parachute
            SoundUtil.playSound(313)
        end
    end)
end

function GMHelper:ChangeWingById()
    GMHelper:openInput({ "number" }, function(Kelg)
        local player = PlayerManager:getClientPlayer().Player
        player.m_outLooksChanged = true
        player.m_wingId = Kelg
        UIHelper.showToast("^FF00EESuccess")
    end)
end

-- Function to toggle NoClip
function GMHelper:toggleNoClip(text)
    local clientPlayer = PlayerManager:getClientPlayer()
    if clientPlayer then
        local player = clientPlayer.Player
        player.noClip = not player.noClip

        if player.noClip then
            UIHelper.showToast("NoClip enabled")
            text:SetBackgroundColor(Color.RED)
        else
            UIHelper.showToast("NoClip disabled")
            text:SetBackgroundColor(Color.BLACK)
        end
    end
end



function GMHelper:SetFOV()
   GMHelper:openInput({ "" }, function(data)
    Blockman.Instance().m_gameSettings:setFovSetting(data)
    UIHelper.showToast("^FF55FFFOV ON")
    end)
 end
 
 function GMHelper:SpawnBlock()
       GMHelper:openInput({ "" }, function(martin)
    local blockPos = PlayerManager:getClientPlayer():getPosition() 
    EngineWorld:setBlock(blockPos, martin)
end)
end

-- Day function
function GMHelper:Day(text)
    UIHelper.showToast("^00FF00Sky ON")
    text:SetBackgroundColor(Color.RED)
    HostApi.setSky("Qing")
end

function GMHelper:theme_sea(text)
text:SetBackgroundColor(Color.RED)
SoundUtil.playSound(10000)
end

function GMHelper:play_theme_home(text)
    SoundUtil.playSound(10001)
    text:SetBackgroundColor(Color.RED)
end

function GMHelper:play_theme_dead(text)
    SoundUtil.playSound(10002)
    text:SetBackgroundColor(Color.RED)
end



function GMHelper:play_game_complete(text)
    SoundUtil.playSound(10003)
    text:SetBackgroundColor(Color.RED)
end

function GMHelper:play_plane_sound(text)
    SoundUtil.playSound(10004)
    text:SetBackgroundColor(Color.RED)
end

function GMHelper:play_loading_music(text)
    SoundUtil.playSound(10005)
    text:SetBackgroundColor(Color.RED)
end


-- Night function
function GMHelper:Night(text)
    UIHelper.showToast("^00FF00Sky ON")
    text:SetBackgroundColor(Color.RED)
    HostApi.setSky("fanxing")
    text:SetBackgroundColor(Color.RED)
end

-- Evening function
function GMHelper:Evening(text)
    UIHelper.showToast("^00FF00Sky ON")
    text:SetBackgroundColor(Color.RED)
    HostApi.setSky("Wanxia")
end

-- Snow function
function GMHelper:Snow(text)
    UIHelper.showToast("^00FF00Sky ON")
    HostApi.setSky("xue")
    text:SetBackgroundColor(Color.RED)
end

-- Function to quickly set the block number for building
function GMHelper:test()
    GMHelper:openInput({ "" }, function(Number)
        ClientHelper.putIntPrefs("QuicklyBuildBlockNum", Number)
        UIHelper.showToast("^FF55FFBuild Inf ON")
    end)
end

function GMHelper:toggleAttackReach(text)
    isAttackReachActive = not isAttackReachActive
    print("isAttackReachActive:", isAttackReachActive)  -- Verifique o estado
    
    if isAttackReachActive then
        -- Ativa a distância de ataque aumentada
        print("Aumentando distância de ataque.")
        ClientHelper.putFloatPrefs("EntityReachDistance", 999)
        text:SetBackgroundColor(Color.RED)
    else
        -- Desativa a distância de ataque, retorna ao padrão
        print("Restaurando distância de ataque padrão.")
        ClientHelper.putFloatPrefs("EntityReachDistance", 5)
        text:SetBackgroundColor(Color.BLACK)
    end
end

function GMHelper:toggleBlockReach(text)
    isBlockReachActive = not isBlockReachActive
    
    if isBlockReachActive then
        -- Ativa a distância de bloco aumentada
        ClientHelper.putFloatPrefs("BlockReachDistance", 999999)
        UIHelper.showToast("^00FF00Increased Block Distance ON")
        text:SetBackgroundColor(Color.RED)
    else
        -- Desativa a distância de bloco, retorna ao padrão
        ClientHelper.putFloatPrefs("BlockReachDistance", 7)
        UIHelper.showToast("^FF0000Increased Block Distance OFF")
        text:SetBackgroundColor(Color.BLACK)
    end
end


GMHelper.state23 = "off"
GMHelper.originalHardness = {}

function GMHelper:FastBreak(text)
    if self.state23 == "on" then
        for blockId, hardness in pairs(self.originalHardness) do
            local block = BlockManager.getBlockById(blockId)
            if block then
                block:setHardness(hardness)
            end
        end
        UIHelper.showToast("^FF0000FastBreak Disabled")
        text:SetBackgroundColor(Color.BLACK) 
        self.state23 = "off"
    else
        for blockId = 1, 40000 do
            local block = BlockManager.getBlockById(blockId)
            if block then
                self.originalHardness[blockId] = block:getHardness()
                block:setHardness(0)
            end
        end
        UIHelper.showToast("^00FF00FastBreak Enabled")
        text:SetBackgroundColor(Color.RED) 
        self.state23 = "on"
    end
end

function GMHelper:AutomaticBridge(text)
    A = not A
    LuaTimer:cancel(self.timer)
    
    if A then
        -- Texto ativado
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^00FF00Auto Bridge Cps Increase ON")
        
        self.timer = LuaTimer:scheduleTimer(function()
            local Hold = PlayerManager:getClientPlayer().Player:getHeldItemId()
            if Hold >= 2441 and Hold <= 10000 then
                CGame.Instance():handleTouchClick(1300, 450)
            end
        end, 10, 900000000000000000000000)
        
        GUIGMControlPanel:hide()
    else
        -- Texto desativado
        text:SetBackgroundColor(Color.BLACK)
        UIHelper.showToast("^FF0000Auto Bridge Cps Increase OFF")
    end
end

-- Bed Wars Respawn function
function GMHelper:bedWarsRespawn()
    PacketSender:getSender():sendRebirth()
    UIHelper.showToast("^00FF00Respawn")
end



function GMHelper:openScreenRecord()
    local names = { "Main-PoleControl-Move", "Main-PoleControl", "Main-FlyingControls", "Main-Fly" }
    local window = GUISystem.Instance():GetRootWindow()
    window:SetXPosition({ 0, 10000 })
    local Main = GUIManager:getWindowByName("Main")
    local count = Main:GetChildCount()
    for i = 1, count do
        local child = Main:GetChildByIndex(i - 1)
        local name = child:GetName()
        if not TableUtil.tableContain(names, name) then
            child:SetXPosition({ 0, 10000 })
            child:SetYPosition({ 0, 10000 })
        end
    end
    ClientHelper.putFloatPrefs("MainControlKeyAlphaNormal", 0)
    ClientHelper.putFloatPrefs("MainControlKeyAlphaPress", 0)
    GUIManager:getWindowByName("Main-Fly"):SetProperty("NormalImage", "")
    GUIManager:getWindowByName("Main-Fly"):SetProperty("PushedImage", "")
    GUIManager:getWindowByName("Main-PoleControl-BG"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-PoleControl-Center"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Up"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Drop"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Down"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Break-Block-Progress-Nor"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Break-Block-Progress-Pre"):SetProperty("ImageName", "")
    Main:SetXPosition({ 0, -10000 })
    ClientHelper.putBoolPrefs("RenderHeadText", false)
    PlayerManager:getClientPlayer().Player:setActorInvisible(true)
end

function GMHelper:SetMaxFPS()
    -- Opens input dialog to set the maximum FPS
    GMHelper:openInput({""}, function(FPS)
        CGame.Instance():SetMaxFps(FPS)
    end)
end

function GMHelper:WarnTP(text)    
    -- Toggles the warning teleportation feature
    A = not A
    LuaTimer:cancel(self.timer)
    UIHelper.showToast("^00FF00OFF")
    text:SetBackgroundColor(Color.BLACK)
    if A then
        GMHelper:openInput({ "" }, function(WarnHP)
            WarnHP = tonumber(WarnHP)
            self.timer = LuaTimer:scheduleTimer(function()
                local player = PlayerManager:getClientPlayer()
                local HP = player.Player:getHealth()
                if HP <= WarnHP then
                    local playerPos = PlayerManager:getClientPlayer():getPosition()
                    local playerPosN = VectorUtil.newVector3(playerPos.x,0,playerPos.z)
                    player.Player:setPosition(playerPosN)
                    PacketSender:getSender():sendRebirth()
                end
            end, 0.2, 900000000000000000000000)
            UIHelper.showToast("^00FF00ON")
            text:SetBackgroundColor(Color.RED)
            GUIGMControlPanel:hide()
        end)
    end
end

function GMHelper:NoFall(text) -- NoFall
    -- Toggles the NoFall feature
    A = not A
    ClientHelper.putIntPrefs("SprintLimitCheck", 7)
    if A then
    text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("Enabled")
        return
    end
    ClientHelper.putIntPrefs("SprintLimitCheck", 0)
    UIHelper.showToast("Disabled")
    text:SetBackgroundColor(Color.BLACK)
end

function GMHelper:Freecam(text)
    local freecamState = {}
    local window = GUIManager:getWindowByName("Main-HideAndSeek-Operate")

    if freecamState.isVisible == nil then
        freecamState.isVisible = false
    end

    if freecamState.isVisible then
        window:SetVisible(false)
        freecamState.isVisible = false
        text:SetBackgroundColor(Color.BLACK)
        UIHelper.showToast("^FF0000OFF")
    else
        window:SetVisible(true)
        freecamState.isVisible = true
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^00FF00ON")
    end

    GUIGMControlPanel:hide()
end

function GMHelper:CopyPlayersInfo()
    -- Copies information about all players to clipboard
    local content = ""
    local players = PlayerManager:getPlayers()
    
    if not players then
        print("Error: Could not retrieve players.")
        return
    end

    for _, player in pairs(players) do
        local name = player:getName() or "Unknown"
        local userId = player.userId or "Unknown"
        local gender = player.Player and player.Player:getSex() or "Unknown"

        content = content .. "\n[Player Info] " .. string.format("Username: %s | User ID: %s | Gender: %s", name, userId, gender)
    end

    if content == "" then
        print("Warning: No player information available.")
    else
        ClientHelper.onSetClipboard(content)
        print("Player information copied to clipboard.")
    end
end

function GMHelper:CloseGame(params) 
    -- Exits the game
    Game:exitGame(params)
end

function GMHelper:ChangeActorForMe()
    -- Changes the actor for the current player
    local entity = PlayerManager:getClientPlayer().Player
    GMHelper:openInput({ ".actor" }, function(actor)
        Blockman.Instance():getWorld():changePlayerActor(entity, actor)
        Blockman.Instance():getWorld():changePlayerActor(entity, actor)
        entity.m_isPeopleActor = false
        EngineWorld:restorePlayerActor(entity)
        UIHelper.showToast("^00FF00Success")
    end)
end

function GMHelper:TeleportByUID()
    -- Teleports the player to another player by user ID and enters the same game
    GMHelper:openInput({ "id player" }, function(ID)
        local clientPlayer = PlayerManager:getClientPlayer().Player
        local targetPlayer = PlayerManager:getPlayerByUserId(ID)

        if targetPlayer then
            -- Teleport to the player
            clientPlayer:setPosition(targetPlayer:getPosition())

            -- Get the game ID and map ID of the target player
            local targetGameId = targetPlayer:getCurrentGameId()
            local targetMapId = targetPlayer:getCurrentMapId()

            if targetGameId and targetMapId then
                -- Enter the same game as the target player
                GMHelper:EnterGame(targetMapId, targetGameId)
            else
                print("Error: Could not retrieve game or map ID for player with ID " .. ID)
            end
        else
            print("Error: Player with ID " .. ID .. " not found.")
        end
    end)
end

function GMHelper:RenderWorld()
   GMHelper:openInput({ "" }, function(Number)
        ClientHelper.putIntPrefs("BlockRenderDistance", Number)
        UIHelper.showToast("^00FF00Changed")
   end)
end

function GMHelper:ArmSpeed()
   GMHelper:openInput({ "" }, function(Number)
        ClientHelper.putIntPrefs("ArmSwingAnimationEnd", Number)
        UIHelper.showToast("^00FF00Changed")
   end)
end

function GMHelper:ChangeNick()
   GMHelper:openInput({ "" }, function(Nick)
    PlayerManager:getClientPlayer().Player:setShowName(Nick)
    UIHelper.showToast("^FF00EENickNameChanged")
   end)
end



function GMHelper:WatchMode(text)
    A = not A
    local moveDir = VectorUtil.newVector3(0.0, 1.35, 0.0)
    local player = PlayerManager:getClientPlayer().Player
    player:setAllowFlying(true)
    player:setFlying(true)
    player:setWatchMode(true)
    player:moveEntity(moveDir)
    
    if A then
        -- Ativado
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00EE开")
    else
        -- Desativado
        text:SetBackgroundColor(Color.BLACK)
        player:setAllowFlying(false)
        player:setFlying(false)
        player:setWatchMode(false)
        UIHelper.showToast("^FF00EE关")
    end
end

function GMHelper:WaterPush(text)
    A = not A
    local entity = PlayerManager:getClientPlayer().Player
    
    if A then
        -- Ativado
        entity:setBoolProperty("ignoreWaterPush", true)
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^FF00EEON")
    else
        -- Desativado
        entity:setBoolProperty("ignoreWaterPush", false)
        text:SetBackgroundColor(Color.BLACK)
        UIHelper.showToast("^FF00EEOFF")
    end
end

function GMHelper:changeScale()
    GMHelper:openInput({ "" }, function(Scale)
        local entity = PlayerManager:getClientPlayer().Player
        entity:setScale(Scale)
        UIHelper.showToast("^FF00EESuccess")
    end)
end

function GMHelper:ChatSend()
    GMHelper:openInput({""}, function(msg)
    HostApi.sendMsg(0, 0, msg)
end)
end

function showOez(layout, callback)
    local root = layout.root
    local count = root:GetChildCount()
    if count == 0 then
        if callback then callback() end
        return
    end

    local animationsRemaining = count

    local function checkCompletion()
        animationsRemaining = animationsRemaining - 1
        if animationsRemaining <= 0 then
            if callback then callback() end
        end
    end

    for index = 1, count do
        local content = root:GetChildByIndex(index - 1)
        if content then
            local scale = 0.5
            content:SetScale(VectorUtil.newVector3(scale, scale, scale))
            
            layout:addTimer(LuaTimer:scheduleTicker(function()
                if scale < 1 then
                    scale = scale + 0.1  -- Aumentar mais rápido
                    if scale > 1 then
                        scale = 1
                    end
                    content:SetScale(VectorUtil.newVector3(scale, scale, scale))
                end

                if scale >= 1 then  -- Use >= para garantir a chamada da função de conclusão
                    checkCompletion()
                end
            end, 0.1, 10))  -- Intervalo do timer ajustado para 0.1 segundos (ou seja, 10 vezes por segundo)
        end
    end
end

local Arden = UIHelper function GMHelper:ardenkill(text) allActive = not allActive LuaTimer:cancel(self.timer) LuaTimer:cancel(self.aimTimer) LuaTimer:cancel(autoClickerTimer) if allActive then local me = PlayerManager:getClientPlayer() self.timer = LuaTimer:scheduleTimer(function() local others = PlayerManager:getPlayers() for _, c_player in pairs(others) do if c_player ~= me then local targetPos = c_player:getPosition() targetPos.y = targetPos.y + 2.0 me.Player:setPosition(targetPos) break end end end, 0.5, -1) GUIGMControlPanel:hide() Arden.showToast("Arden Kill ON!") self.aimTimer = LuaTimer:scheduleTimer(function() local players = PlayerManager:getPlayers() local closestPlayer, closestDistance = nil, 500 * 500 for _, player in pairs(players) do if player ~= me then local playerPos = player:getPosition() local distance = MathUtil:distanceSquare2d(playerPos, me.Player:getPosition()) if distance < closestDistance then closestDistance = distance closestPlayer = player if closestDistance < 200 * 200 then break end end end end if closestPlayer then local camera = SceneManager.Instance():getMainCamera() local dir = VectorUtil.sub3(closestPlayer:getPosition(), camera:getPosition()) me.Player.rotationYaw = math.atan2(dir.x, dir.z) * (180 / math.pi) * -1 me.Player.rotationPitch = -math.atan2(dir.y, math.sqrt(dir.x * dir.x + dir.z * dir.z)) * (180 / math.pi) end end, 0.5, -1) UIHelper.showToast("AimBot ON!") state15 = "on" ClientHelper.putBoolPrefs("SyncClientPositionToServer", false) UIHelper.showToast("^00FF00Blink Enabled") autoClickerTimer = LuaTimer:scheduleTimer(function() CGame.Instance():handleTouchClick(800, 360) end, 100.15, -1) UIHelper.showToast("AutoClicker ON!") hitboxSize = 5 self.hitboxActive = true for _, player in pairs(PlayerManager:getPlayers()) do player.Player.width = hitboxSize player.Player.length = hitboxSize end local clientPlayer = PlayerManager:getClientPlayer() if clientPlayer then clientPlayer.Player.width = hitboxSize clientPlayer.Player.length = hitboxSize end UIHelper.showToast("^00FF00Hitbox Activated: " .. hitboxSize) text:SetBackgroundColor(Color.RED) else Arden.showToast("Arden Kill OFF!") UIHelper.showToast("AimBot OFF!") state15 = "off" ClientHelper.putBoolPrefs("SyncClientPositionToServer", true) UIHelper.showToast("^FF0000Blink Disabled") if autoClickerTimer then LuaTimer:cancel(autoClickerTimer) autoClickerTimer = nil end UIHelper.showToast("AutoClicker OFF!") hitboxSize = 1 self.hitboxActive = false for _, player in pairs(PlayerManager:getPlayers()) do player.Player.width = hitboxSize player.Player.length = hitboxSize end local clientPlayer = PlayerManager:getClientPlayer() if clientPlayer then clientPlayer.Player.width = hitboxSize clientPlayer.Player.length = hitboxSize end UIHelper.showToast("^FF0000Hitbox Deactivated: " .. hitboxSize) text:SetBackgroundColor(Color.BLACK) end end



function GMHelper:aimbot7(text)
    local aimbotDistance = 20  -- Distância fixa definida para o Aimbot
    
    -- Inverte o estado do AIM
    AIM = not AIM

    if AIM then
        -- Ativação do Aimbot
        UIHelper.showToast("AimBot Enabled")
        text:SetBackgroundColor(Color.RED)

        -- Cancela qualquer timer existente
        if self.timer then
            LuaTimer:cancel(self.timer)
        end

        -- Cria um novo timer para o Aimbot
        self.timer = LuaTimer:scheduleTimer(function()
            local me = PlayerManager:getClientPlayer()

            if me then
                local myPos = me.Player:getPosition()
                local players = PlayerManager:getPlayers()

                local closestDistance = math.huge
                local closestPlayer = nil

                -- Encontra o jogador mais próximo
                for _, player in pairs(players) do
                    if player ~= me then
                        local playerPos = player:getPosition()
                        local distance = MathUtil:distanceSquare2d(playerPos, myPos)

                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end

                -- Se um jogador próximo foi encontrado, ajusta a mira
                if closestPlayer ~= nil and closestDistance < aimbotDistance then
                    local health = math.min(closestPlayer:getHealth(), 50.0)

                    local camera = SceneManager.Instance():getMainCamera()
                    local pos = camera:getPosition()
                    local dir = VectorUtil.sub3(closestPlayer:getPosition(), pos)

                    local yaw = math.atan2(dir.x, dir.z) / math.pi * -180
                    local calculate = math.sqrt(dir.x * dir.x + dir.z * dir.z)
                    local pitch = -math.atan2(dir.y, calculate) / math.pi * 180

                    me.Player.rotationYaw = yaw or 0
                    me.Player.rotationPitch = pitch or 0
                end
            end
        end, 1, -1)  -- O timer se repete a cada 1 ms
    else
        -- Desativação do Aimbot
        UIHelper.showToast("AimBot Disabled")
        text:SetBackgroundColor(Color.BLACK)

        -- Cancela o timer se estiver ativo
        if self.timer then
            LuaTimer:cancel(self.timer)
            self.timer = nil  -- Limpa o timer após cancelamento
        end
    end
end


function GMHelper:jetPackv2(text)
    JetPack = not JetPack

    if JetPack then
        GMHelper:openInput({"Speed"}, function(YesJetPackSpeed)
            JetPackSpeed = tonumber(YesJetPackSpeed)
            PlayerManager:getClientPlayer().Player:moveEntity(VectorUtil.newVector3(0.0, 1.0, 0.0))
            UIHelper.showToast("JetPack = true")
            text:SetBackgroundColor(Color.RED)
        end)
    else
        JetPackSpeed = nil  -- Set to nil when disabling
        JetPack = nil
        UIHelper.showToast("JetPack = false")
        text:SetBackgroundColor(Color.BLACK)
    end
end

function GMHelper:Scaffold(text)
    -- Toggle state
    A = not A
    
    -- Cancel the existing timer if it exists
    if self.timer then
        LuaTimer:cancel(self.timer)
        self.timer = nil -- Reset timer variable to avoid dangling references
        UIHelper.showToast("^00FF00Scaffold OFF")
        text:SetBackgroundColor(Color.BLACK)
        return -- Exit if toggled off
    end
    
    -- Request BlockID input
    GMHelper:openInput({"BlockID"}, function(block)
        -- Start the timer to place blocks
        self.timer = LuaTimer:scheduleTimer(function()
            local pos = PlayerManager:getClientPlayer():getPosition()
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x, pos.y - 2, pos.z), block)
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x - 1, pos.y - 2, pos.z - 1), block)
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x + 1, pos.y - 2, pos.z + 1), block)
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x, pos.y - 2, pos.z + 1), block)
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x, pos.y - 2, pos.z - 1), block)
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x + 1, pos.y - 2, pos.z), block)
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x - 1, pos.y - 2, pos.z), block)
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x - 1, pos.y - 2, pos.z + 1), block)
            EngineWorld:setBlock(VectorUtil.newVector3(pos.x + 1, pos.y - 2, pos.z - 1), block)
        end, 0.15, -1)
        
        -- Notify user and change background color
        UIHelper.showToast("^00FF00Scaffold ON")
        text:SetBackgroundColor(Color.RED)
    end)
end


function GMHelper:cannonTimerFunction()
    local speedFactor = 4
    local clientPlayer = PlayerManager:getClientPlayer()
    
    if clientPlayer then
        local pitch = clientPlayer.Player:getPitch()
        local yaw = clientPlayer.Player:getYaw()

        local pitchRad = pitch * math.pi / 180
        local yawRad = yaw * -math.pi / 180
        
        local pitchDamping = 0.5
        local verticalBoost = 0.0
        
        local x = math.cos(pitchRad) * math.sin(yawRad) * speedFactor
        local y = (-math.sin(pitchRad) * pitchDamping + verticalBoost) * speedFactor
        local z = math.cos(pitchRad) * math.cos(yawRad) * speedFactor

        local newPos = VectorUtil.newVector3(x, y, z)
        clientPlayer.Player:setVelocity(newPos)
        
        UIHelper.showToast(".")
    else
        UIHelper.showToast(".")
    end
end

function GMHelper:startCannonTimer()
    if not timerCannon then
        UIHelper.showToast("jetpack activated")
        timerCannon = LuaTimer:scheduleTimer(function() GMHelper:cannonTimerFunction() end, 100, -1)
    end
end

function GMHelper:stopCannonTimer()
    if timerCannon then
        UIHelper.showToast("jetpack disabled")
        LuaTimer:cancel(timerCannon)
        timerCannon = nil
    end
end

function GMHelper:SpamRespawn()
GMHelper:openInput({ "" }, function(Number)

for i = 1,Number do
PacketSender:getSender():sendRebirth()
end
end)
end


function GMHelper:SpamChat2(text)
    A = not A

    if self.timer then
        LuaTimer:cancel(self.timer)
    end

    local ez = GUIManager:getWindowByName("Chat-BtnSend")
    if ez then
        text:SetBackgroundColor(Color.BLACK)
        ez:SetVisible(false)
    end
    UIHelper.showToast("Disabled")

    local colors = {
        0xFF0000,
        0xFFA500,
        0xFFFF00,
        0x008000,
        0x0000FF,
        0x800080  
    }

    if A then
        GMHelper:openInput({ "" }, function(wiadomosc)
            local colorIndex = 1
            self.timer = LuaTimer:scheduleTimer(function()
                local chatInputBox = GUIManager:getWindowByName("Chat-Input-Box")
                if chatInputBox then
                    local color = colors[colorIndex]
                    chatInputBox:SetProperty("Text", string.format("^%06X%s", color, wiadomosc))
                    
                    colorIndex = (colorIndex % #colors) + 1
                end
            end, 5, 1000000)
            
            if ez then
                local mainLayout = GUIManager:getWindowByName("Main")
                if mainLayout then
                    mainLayout:AddChildWindow(ez)
                end
                
                ez:SetYPosition({-0.1, 0})
                ez:SetXPosition({-0.5, 0})
                ez:SetVisible(true)
                ez:SetHeight({0, 60})
                ez:SetWidth({0, 60})
                text:SetBackgroundColor(Color.BLACK)
                UIHelper.showToast("Enabled")
            end
        end)
    end
end


function GMHelper:EmoteFreezer(text)
 emote = not emote
     UIHelper.showToast("Disabled")
     text:SetBackgroundColor(Color.BLACK)
     PlayerManager:getClientPlayer().Player:setBoolProperty("DisableUpdateAnimState", false)
 if emote then
     PlayerManager:getClientPlayer().Player:setBoolProperty("DisableUpdateAnimState", true)
     text:SetBackgroundColor(Color.RED)
     UIHelper.showToast("Enabled")
 end
end

function GMHelper:toggleHp()
    local hpVisible = false  -- Inicialize a variável dentro da função
    hpVisible = not hpVisible
    local state = hpVisible and true or false
    GUIManager:getWindowByName("PlayerInfo-Health"):SetVisible(state)
end

function GMHelper:buttonMain175(text)
    local mainCannonButton = GUIManager:getWindowByName("Main-Cannon")
    
    -- Exibe o botão "Main-Cannon"
    mainCannonButton:SetYPosition({0, -315})
    mainCannonButton:SetXPosition({0, -25})
    mainCannonButton:SetHeight({0, 60})
    mainCannonButton:SetWidth({0, 60})
    mainCannonButton:SetVisible(true)
    text:SetBackgroundColor(Color.RED)
    
    -- Associe a função ao evento de clique do botão "Main-Cannon"
    mainCannonButton:registerEvent(GUIEvent.ButtonClick, function()
        local clientPlayer = PlayerManager:getClientPlayer()
        if clientPlayer then
            -- Calculate the launch direction based on pitch and yaw
            local pitch = clientPlayer.Player:getPitch()
            local yaw = clientPlayer.Player:getYaw()

            local pitchRad = pitch * math.pi / 180
            local yawRad = yaw * -math.pi / 180
            local x = math.cos(pitchRad) * math.sin(yawRad) * 3 -- Increase cannon speed
            local y = -math.sin(pitchRad) * 20 -- Increase cannon speed
            local z = math.cos(pitchRad) * math.cos(yawRad) * 3 -- Increase cannon speed

            local newPos = VectorUtil.newVector3(x, y, z)
            clientPlayer.Player:setVelocity(newPos)
            clientPlayer.Player:startParachute() -- Start the parachute
            SoundUtil.playSound(313)
        end
    end)
end

function GMHelper:buttoncannonabc2()
    local mainCannonButton = GUIManager:getWindowByName("Main-Cannon")
    
    -- Exibe o botão "Main-Cannon"
    mainCannonButton:SetVisible(true)
    
    -- Associe a função ao evento de clique do botão "Main-Cannon"
    mainCannonButton:registerEvent(GUIEvent.ButtonClick, function()
        local clientPlayer = PlayerManager:getClientPlayer()
        if clientPlayer then
            -- Calculate the launch direction based on pitch and yaw
            local pitch = clientPlayer.Player:getPitch()
            local yaw = clientPlayer.Player:getYaw()

            local pitchRad = pitch * math.pi / 180
            local yawRad = yaw * -math.pi / 180
            local x = math.cos(pitchRad) * math.sin(yawRad) * 3 -- Increase cannon speed
            local y = -math.sin(pitchRad) * 8 -- Decrease cannon speed
            local z = math.cos(pitchRad) * math.cos(yawRad) * 3 -- Increase cannon speed

            local newPos = VectorUtil.newVector3(x, y, z)
            clientPlayer.Player:setVelocity(newPos)
            SoundUtil.playSound(313)
        end
    end)
end


function GMHelper:setHitboxSize(text)
    local hitboxSize
    if self.hitboxActive then
        hitboxSize = 1
        self.hitboxActive = false
        text:SetBackgroundColor(Color.BLACK)
    else
        hitboxSize = 5
        self.hitboxActive = true
        text:SetBackgroundColor(Color.RED)
    end

    for _, player in pairs(PlayerManager:getPlayers()) do
        player.Player.width = hitboxSize
        player.Player.length = hitboxSize
    end

    local clientPlayer = PlayerManager:getClientPlayer()
    if clientPlayer then
        clientPlayer.Player.width = hitboxSize
        clientPlayer.Player.length = hitboxSize
    end

    local status = self.hitboxActive and "Activated" or "Deactivated"
    UIHelper.showToast("^00FF00Hitbox " .. status .. ": " .. hitboxSize)
end

function GMHelper:ezabcdefghijklmnop()
    -- Create the AimBot button
local aimBotButton = GUIManager:createGUIWindow(GUIType.Button, "AimBotButtonWindow")
aimBotButton:SetHorizontalAlignment(HorizontalAlignment.Left)
aimBotButton:SetVerticalAlignment(VerticalAlignment.Top)
local buttonSize = 100  -- Adjusted size to 100x100 pixels
aimBotButton:SetHeight({0, 60})
aimBotButton:SetWidth({0, buttonSize})

-- Apply position, level, and text color
aimBotButton:SetYPosition({0, 80})  -- Positioned at the top
aimBotButton:SetXPosition({0, 15})   -- Positioned in the center horizontally
aimBotButton:SetLevel(7)
aimBotButton:SetTextColor({255, 0, 0}) -- Red text color

-- Set background color
local backgroundColor = {0, 0, 0, 0.4} -- Black with 40% transparency
aimBotButton:SetBackgroundColor(backgroundColor)

-- Define the AIM variable and toggle function
local AIM = false
local self = {}

function toggleAimBot()
    AIM = not AIM
    LuaTimer:cancel(self.timer)
    
    if AIM then
        UIHelper.showToast("AimBot Enabled")
        -- Removed color change for text
        aimBotButton:SetTextColor({138, 43, 226})
        self.timer = LuaTimer:scheduleTimer(function()
            local me = PlayerManager:getClientPlayer()
            
            if me then
                local myPos = me.Player:getPosition()
                local players = PlayerManager:getPlayers()

                local closestDistance = math.huge
                local closestPlayer = nil

                for _, player in pairs(players) do
                    if player ~= me then
                        local playerPos = player:getPosition()
                        local distance = MathUtil:distanceSquare2d(playerPos, myPos)
                        
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end

                if closestPlayer ~= nil and closestDistance < 500 then
                    local health = math.min(closestPlayer:getHealth(), 50.0)
                    local locationString = string.format("Closest player's health: %.1f", health)
                    UIHelper.showToast(locationString)

                    local camera = SceneManager.Instance():getMainCamera()
                    local pos = camera:getPosition()
                    local dir = VectorUtil.sub3(closestPlayer:getPosition(), pos)

                    local yaw = math.atan2(dir.x, dir.z) / math.pi * -180
                    local calculate = math.sqrt(dir.x * dir.x + dir.z * dir.z)
                    local pitch = -math.atan2(dir.y, calculate) / math.pi * 180

                    me.Player.rotationYaw = yaw or 0
                    me.Player.rotationPitch = pitch or 0
                end
            end
        end, 1, 99999)
    else
        aimBotButton:SetTextColor({255, 0, 0})
        UIHelper.showToast("AimBot Disabled")
        -- Removed color change for text
    end
end

-- Register event for button click to toggle the AimBot
aimBotButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleAimBot()  -- Call the toggleAimBot function
end)

-- Add the button to the root window
GUISystem.Instance():GetRootWindow():AddChildWindow(aimBotButton)

-- Set additional properties
aimBotButton:SetNormalImage("set:gui_yetanother_icon.json image:icon_up")
aimBotButton:SetPushedImage("set:gui_yetanother_icon.json image:icon_up_pressed")
aimBotButton:SetTouchable(true)
aimBotButton:SetVisible(true)
aimBotButton:SetText("AimBot")  -- Changed text to "AimBot"
end

function GMHelper:AutoClick()
    if not autoClickerActive then
        -- Activate AutoClicker
        autoClickerActive = true
        autoClickerTimer = LuaTimer:scheduleTimer(function()
            CGame.Instance():handleTouchClick(800, 360)
        end, 100.15, -1)
        UIHelper.showToast("AutoClicker activated")
    else
        -- Deactivate AutoClicker
        autoClickerActive = false
        if autoClickerTimer then
            LuaTimer:cancel(autoClickerTimer)
            autoClickerTimer = nil
        end
        UIHelper.showToast("AutoClicker deactivated")
    end
end

function GMHelper:autoclickV3()
    -- Define the toggleAutoClicker function
    local function toggleAutoClicker()
        if not autoClickerActive then
            -- Activate AutoClicker
            autoClickerActive = true
            autoClickerTimer = LuaTimer:scheduleTimer(function()
                CGame.Instance():handleTouchClick(800, 360)
            end, 100.15, -1)
            UIHelper.showToast("AutoClicker activated")
        else
            -- Deactivate AutoClicker
            autoClickerActive = false
            if autoClickerTimer then
                LuaTimer:cancel(autoClickerTimer)
                autoClickerTimer = nil
            end
            UIHelper.showToast("AutoClicker deactivated")
        end
    end

    -- Create the button 
    local upButton = GUIManager:createGUIWindow(GUIType.Button, "UpButtonWindow")
    upButton:SetHorizontalAlignment(HorizontalAlignment.Left)
    upButton:SetVerticalAlignment(VerticalAlignment.Top)
    local buttonSize = 100  -- Adjusted size to 100x100 pixels
    upButton:SetHeight({0, 60})
    upButton:SetWidth({0, buttonSize})
    upButton:SetYPosition({0, 160})  -- Positioned at the top
    upButton:SetXPosition({0, 15})   -- Positioned in the center horizontally
    upButton:SetLevel(7)
    upButton:SetTextColor({255, 0, 0}) -- Red text color

    -- Set background color
    local backgroundColor = {0, 0, 0, 0.4} -- Black with 40% transparency
    upButton:SetBackgroundColor(backgroundColor)

    -- Register event for button click to toggle the AutoClicker
    upButton:registerEvent(GUIEvent.ButtonClick, function()
        toggleAutoClicker()  -- Call the toggleAutoClicker function
    end)

    -- Add the button to the root window
    GUISystem.Instance():GetRootWindow():AddChildWindow(upButton)

    -- Set additional properties
    upButton:SetNormalImage("set:gui_yetanother_icon.json image:icon_up")
    upButton:SetPushedImage("set:gui_yetanother_icon.json image:icon_up_pressed")
    upButton:SetTouchable(true)
    upButton:SetVisible(true)
    upButton:SetText("AutoClick")
end

function GMHelper:speedbyttonez()
-- Create the Speed button
local speedButton = GUIManager:createGUIWindow(GUIType.Button, "SpeedButtonWindow")
speedButton:SetHorizontalAlignment(HorizontalAlignment.Left)
speedButton:SetVerticalAlignment(VerticalAlignment.Top)
local buttonSize = 100  -- Adjusted size to 100x100 pixels
speedButton:SetHeight({0, 60})
speedButton:SetWidth({0, buttonSize})

-- Apply position, level, and text color
speedButton:SetYPosition({0, 240})  -- Positioned in the middle vertically
speedButton:SetXPosition({0, 15})   -- Positioned to the left
speedButton:SetLevel(7)
speedButton:SetTextColor({255, 0, 0}) -- Red text color

-- Set background color
local backgroundColor = {0, 0, 0, 0.4} -- Black with 40% transparency
speedButton:SetBackgroundColor(backgroundColor)

-- Define the Speed variable and toggle function
local state3 = "off"  -- Initial state

function toggleSpeed()
    if state3 == "off" then
        state3 = "on"
        UIHelper.showToast("^FF00EESpeed Enabled")
        speedButton:SetTextColor({138, 43, 226})
        PlayerManager:getClientPlayer().Player:setSpeedAdditionLevel(15000)
    else
        state3 = "off"
        speedButton:SetTextColor({255, 0, 0})
        UIHelper.showToast("^FF0000Speed Disabled")
        PlayerManager:getClientPlayer().Player:setSpeedAdditionLevel(1)
    end
end

-- Register event for button click to toggle the Speed
speedButton:registerEvent(GUIEvent.ButtonClick, function()
    toggleSpeed()  -- Call the toggleSpeed function
end)

-- Add the button to the root window
GUISystem.Instance():GetRootWindow():AddChildWindow(speedButton)

-- Set additional properties
speedButton:SetNormalImage("set:gui_yetanother_icon.json image:icon_up")
speedButton:SetPushedImage("set:gui_yetanother_icon.json image:icon_up_pressed")
speedButton:SetTouchable(true)
speedButton:SetVisible(true)
speedButton:SetText("Speed")  -- Changed text to "Speed"
end

function GMHelper:ChangeWing()
  GMHelper:openInput({ "number" }, function(Kelg)
    local player = PlayerManager:getClientPlayer().Player
    player.m_outLooksChanged = true
    player.m_wingId = Kelg
    UIHelper.showToast("^FF00EESuccess")
  end)
end

function GMHelper:ChangeHair()
  GMHelper:openInput({ "number" }, function(Kelg)
    local player = PlayerManager:getClientPlayer().Player
    player.m_outLooksChanged = true
    player.m_hairID = Kelg
    UIHelper.showToast("^FF00EESuccess")
  end)
end

function GMHelper:ChangeFace()
  GMHelper:openInput({ "number" }, function(Kelg)
    local player = PlayerManager:getClientPlayer().Player
    player.m_outLooksChanged = true
    player.m_faceID = Kelg
    UIHelper.showToast("^FF00EESuccess")
  end)
end

function GMHelper:ChangeTops()
  GMHelper:openInput({ "number" }, function(Kelg)
    local player = PlayerManager:getClientPlayer().Player
    player.m_outLooksChanged = true
    player.m_topsID = Kelg
    UIHelper.showToast("^FF00EESuccess")
  end)
end

function GMHelper:ChangePants()
  GMHelper:openInput({ "number" }, function(Kelg)
    local player = PlayerManager:getClientPlayer().Player
    player.m_outLooksChanged = true
    player.m_pantsID = Kelg
    UIHelper.showToast("^FF00EESuccess")
  end)
end

function GMHelper:ChangeShoes()
  GMHelper:openInput({ "number" }, function(Kelg)
    local player = PlayerManager:getClientPlayer().Player
    player.m_outLooksChanged = true
    player.m_shoesID = Kelg
    UIHelper.showToast("^FF00EESuccess")
  end)
end

function GMHelper:ChangeGlasses()
  GMHelper:openInput({ "number" }, function(Kelg)
    local player = PlayerManager:getClientPlayer().Player
    player.m_outLooksChanged = true
    player.m_glassesId = Kelg
    UIHelper.showToast("^FF00EESuccess")
  end)
end

function GMHelper:ChangeScarf()
  GMHelper:openInput({ "number" }, function(Kelg)
    local player = PlayerManager:getClientPlayer().Player
    player.m_outLooksChanged = true
    player.m_scarfId = Kelg
    UIHelper.showToast("^FF00EESuccess")
  end)
end

function GMHelper:attackbnt88738373838()
    local correctPassword = "ZenithHackerBGatkbnt"

    GMHelper:openInput({ "password" }, function(inputPassword)
        if inputPassword == correctPassword then
            open_lay = GUIManager:createGUIWindow(GUIType.Button, "GUIRoot-xuy2")
            open_lay:SetHorizontalAlignment(HorizontalAlignment.Center)
            open_lay:SetVerticalAlignment(VerticalAlignment.Center)
            open_lay:SetHeight({ 0, 60 })
            open_lay:SetWidth({ 0, 60 })
            open_lay:SetTouchable(true)

            local autoClickerActive = false
            local autoClickerTimer

            local function toggleAutoClicker()
                if not autoClickerActive then
                    autoClickerActive = true
                    autoClickerTimer = LuaTimer:scheduleTimer(function()
                        CGame.Instance():handleTouchClick(800, 360)
                    end, 0.15, -1)
                    UIHelper.showToast("AutoClicker activated")
                else
                    autoClickerActive = false
                    if autoClickerTimer then
                        LuaTimer:cancel(autoClickerTimer)
                        autoClickerTimer = nil
                    end
                    UIHelper.showToast("AutoClicker deactivated")
                end
            end

            open_lay:registerEvent(GUIEvent.TouchMove, function()
                if not Blockman.Instance().m_gameSettings:isMouseMoving() then
                    local mousePos = Blockman.Instance().m_gameSettings:getMousePos()
                    open_lay:SetXPosition({ 0, mousePos.x / 1.0 - 740 })
                    open_lay:SetYPosition({ 0, mousePos.y / 1.0 - 305 })
                    toggleAutoClicker()
                end
            end)

            GUISystem.Instance():GetRootWindow():AddChildWindow(open_lay)
            open_lay:SetYPosition({ 0, -100 })
            open_lay:SetXPosition({ 0, 0 })
            open_lay:SetNormalImage("set:main_btn.json image:skill_btn")
            open_lay:SetPushedImage("set:main_btn.json image:skill_btn")
        else
            UIHelper.showToast("Incorrect password")
        end
    end)
end

function GMHelper:attackbnt88738373838()
    local correctPassword = "pass1"

    GMHelper:openInput({ "password" }, function(inputPassword)
        if inputPassword == correctPassword then
            aim_button = GUIManager:createGUIWindow(GUIType.Button, "GUIRoot-AimButton")
aim_button:SetHorizontalAlignment(HorizontalAlignment.Center)
aim_button:SetVerticalAlignment(VerticalAlignment.Center)
aim_button:SetHeight({ 0, 50 })
aim_button:SetWidth({ 0, 50 })
aim_button:SetTouchable(true)

-- Define a imagem do botão de mira
aim_button:SetNormalImage("set:shooting_feedback.json image:feedback_body")
aim_button:SetPushedImage("set:shooting_feedback.json image:feedback_body")

-- Adiciona o botão à janela raiz
GUISystem.Instance():GetRootWindow():AddChildWindow(aim_button)
aim_button:SetVisible(true)

-- Centraliza o botão na tela
aim_button:SetYPosition({ 0, 0 })
aim_button:SetXPosition({ 0, 0 })
        else
            UIHelper.showToast("Incorrect password")
        end
    end)
end

function GMHelper:aimbuttonez()
    local correctPassword = "pass1"

    GMHelper:openInput({ "password" }, function(inputPassword)
        if inputPassword == correctPassword then
            local aim_button = GUIManager:createGUIWindow(GUIType.Button, "GUIRoot-AimButton")
            aim_button:SetHorizontalAlignment(HorizontalAlignment.Center)
            aim_button:SetVerticalAlignment(VerticalAlignment.Center)
            aim_button:SetHeight({ 0, 50 })
            aim_button:SetWidth({ 0, 50 })
            aim_button:SetTouchable(true)

            aim_button:SetNormalImage("set:shooting_feedback.json image:feedback_body")
            aim_button:SetPushedImage("set:shooting_feedback.json image:feedback_body")

            GUISystem.Instance():GetRootWindow():AddChildWindow(aim_button)
            aim_button:SetVisible(true)

            aim_button:SetYPosition({ 0, 0 })
            aim_button:SetXPosition({ 0, 0 })

            UIHelper.showToast("Aim button created successfully!")
        else
            UIHelper.showToast("Incorrect password")
        end
    end)
end




function GMHelper:HideBtn(text)
    text:SetBackgroundColor(Color.RED)
    ClientHelper.putFloatPrefs("MainControlKeyAlphaNormal", 0)
    ClientHelper.putFloatPrefs("MainControlKeyAlphaPress", 0)
    GUIManager:getWindowByName("Main-Fly"):SetProperty("NormalImage", "")
    GUIManager:getWindowByName("Main-Fly"):SetProperty("PushedImage", "")
    GUIManager:getWindowByName("Main-PoleControl-BG"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-PoleControl-Center"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Up"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Drop"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Down"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Break-Block-Progress-Nor"):SetProperty("ImageName", "")
    GUIManager:getWindowByName("Main-Break-Block-Progress-Pre"):SetProperty("ImageName", "")
end

function GMHelper:ChangePositionofCannonButton()
    GMHelper:openInput({"Enter new X position:", "Enter new Y position:"}, function(xInput, yInput)
        local x = tonumber(xInput)
        local y = tonumber(yInput)
        
        if x and y then
            local button = GUIManager:getWindowByName("Main-Cannon")
            button:SetXPosition({0, x})
            button:SetYPosition({0, y})
            
            print("Button position updated to X: " .. x .. ", Y: " .. y)
        else
            print("Invalid input. Please enter valid numbers for X and Y.")
        end
    end)
end

function GMHelper:ChangePositionofParachuteButton()
    GMHelper:openInput({"Enter new X position:", "Enter new Y position:"}, function(xInput, yInput)
        local x = tonumber(xInput)
        local y = tonumber(yInput)
        
        if x and y then
            local button = GUIManager:getWindowByName("Main-Parachute")
            button:SetXPosition({0, x})
            button:SetYPosition({0, y})
            
            print("Button position updated to X: " .. x .. ", Y: " .. y)
        else
            print("Invalid input. Please enter valid numbers for X and Y.")
        end
    end)
end

local originalRenderDistance = 1000
local antiLagRenderDistance = 100
local isAntiLagEnabled = false
local A = false

function GMHelper:SuperAntiLag(text)
    print("ToggleSuperAntiLagAndViewBobbing function called")

    CustomDialog.builder()
    CustomDialog.setTitleText("Toggle Super Anti Lag and View Bobbing?")
    CustomDialog.setContentText("Do you want to toggle Super Anti Lag and View Bobbing? This may improve performance on slower devices. The changes will take effect immediately.")
    CustomDialog.setRightText(isAntiLagEnabled and "^00FF00Disable" or "^FF0000Activate")
    CustomDialog.setLeftText("^006633Cancel")

    CustomDialog.setRightClickListener(
        function()
            if isAntiLagEnabled then
                print("Disabling SuperAntiLag")
                ClientHelper.putIntPrefs("BlockRenderDistance", originalRenderDistance)
                ClientHelper.putIntPrefs("BlockDestroyEffectSize", 1)
                ClientHelper.putIntPrefs("BlockRenderDistance", 300)
                ClientHelper.putFloatPrefs("PlayerBobbingScale", 1)
                ClientHelper.putBoolPrefs("DisableRenderClouds", false)
                cBlockManager.cGetBlockById(66):setNeedRender(true)
                cBlockManager.cGetBlockById(253):setNeedRender(true)
                for blockId = 1, 40000 do
                    local block = BlockManager.getBlockById(blockId)
                    if block then
                        block:setLightValue(250, 250, 250)
                    end
                end
                isAntiLagEnabled = false
            else
                print("Activating SuperAntiLag")
                originalRenderDistance = ClientHelper.getIntPrefs("BlockRenderDistance")
                ClientHelper.putIntPrefs("SimpleEffectRenderDistance", 0)
                ClientHelper.putIntPrefs("BlockRenderDistance", antiLagRenderDistance)
                ClientHelper.putIntPrefs("BlockDestroyEffectSize", nil)
                ClientHelper.putFloatPrefs("PlayerBobbingScale", nil)
                ClientHelper.putBoolPrefs("DisableRenderClouds", true)
                CGame.Instance():SetMaxFps(1000000000000)
                cBlockManager.cGetBlockById(66):setNeedRender(false)
                cBlockManager.cGetBlockById(253):setNeedRender(false)
                for blockId = 1, 40000 do
                    local block = BlockManager.getBlockById(blockId)
                    if block then
                        block:setLightValue(150, 150, 150)
                    end
                end
                isAntiLagEnabled = true
            end

            A = not A
            ClientHelper.putBoolPrefs("IsViewBobbing", not A)

            if A then
                UIHelper.showToast("^FF0000ViewBobbing: OFF")
            else
                UIHelper.showToast("^00FF00ViewBobbing: ON")
            end

            if text then
                text:SetBackgroundColor(Color.RED)
            else
                print("Error: text object is not defined")
            end
        end
    )

    CustomDialog.setLeftClickListener(
        function()
            print("Operation canceled")
        end
    )

    CustomDialog.show()
end

function GMHelper:updateButtonSize()
    GMHelper:openInput({"Enter new width:", "Enter new height:"}, function(widthInput, heightInput)
        local width = tonumber(widthInput)
        local height = tonumber(heightInput)
        
        if width and height then
            local button = GUIManager:getWindowByName("Main-Parachute")
            button:SetWidth({0, width})
            button:SetHeight({0, height})
            
            print("Button size updated to width: " .. width .. ", height: " .. height)
        else
            print("Invalid input. Please enter valid numbers for width and height.")
        end
    end)
end

function GMHelper:updateButtonSihjdjdjdjdze()
    GMHelper:openInput({"Enter new width:", "Enter new height:"}, function(widthInput, heightInput)
        local width = tonumber(widthInput)
        local height = tonumber(heightInput)
        
        if width and height then
            local button = GUIManager:getWindowByName("Main-Cannon")
            button:SetWidth({0, width})
            button:SetHeight({0, height})
            
            print("Button size updated to width: " .. width .. ", height: " .. height)
        else
            print("Invalid input. Please enter valid numbers for width and height.")
        end
    end)
end

function GMHelper:makeGmButtonTran()
    GUIGMMain:setTransparent()
end

function GMHelper:Crash()
    UIHelper.showToast("all players crashed")
    local clientPlayer = PlayerManager:getClientPlayer()
    for _, player in ipairs(players) do
        if player ~= clientPlayer then
            removePlayer(player)
        end
    end
end




function GMHelper:toggleJetPackv4(text)
    local isEnabled = ClientHelper.getBoolPrefs("EnableDoubleJumps")
    
    if isEnabled then
        -- Desativar
        ClientHelper.putBoolPrefs("EnableDoubleJumps", false)
        PlayerManager:getClientPlayer().Player.m_keepJumping = true
        text:SetBackgroundColor(Color.BLACK)
    else
        -- Ativar
        ClientHelper.putBoolPrefs("EnableDoubleJumps", true)
        PlayerManager:getClientPlayer().Player.m_keepJumping = false
        text:SetBackgroundColor(Color.RED)
    end
end

function GMHelper:toggleSky(text)
    local isActive = true

    isActive = not isActive 
    local status = isActive and "activated" or "deactivated"
    
    if isActive then
        text:SetBackgroundColor(Color.RED)
    else
        text:SetBackgroundColor(Color.BLACK)
    end
    
    UIHelper.showToast("^00FF00Sky control " .. status)

    if isActive then
        local currentHour = os.date("%H")
        local currentTime = os.date("%H:%M")

        if tonumber(currentHour) >= 6 and tonumber(currentHour) < 12 then
            UIHelper.showToast("^00FF00Sky ON - Day | Time: " .. currentTime)
            HostApi.setSky("Qing")
        elseif tonumber(currentHour) >= 12 and tonumber(currentHour) < 18 then
            UIHelper.showToast("^00FF00Sky ON - Evening | Time: " .. currentTime)
            HostApi.setSky("Wanxia")
        else
            UIHelper.showToast("^00FF00Sky ON - Night | Time: " .. currentTime)
            HostApi.setSky("fanxing")
        end
    end
end


function GMHelper:RenderWorld(text)
   GMHelper:openInput({ "" }, function(Number)
        ClientHelper.putIntPrefs("BlockRenderDistance", Number)
        UIHelper.showToast("^00FF00Changed")
   end)
end

local originalRenderDistance = 1000
local antiLagRenderDistance = 100
local isAntiLagEnabled = false

function GMHelper:AntiLag(text)
    print("AntiLag function called")
    if isAntiLagEnabled then
        print("Disabling AntiLag")
        ClientHelper.putIntPrefs("BlockRenderDistance", originalRenderDistance)
        if text then
            text:SetBackgroundColor(Color.BLACK)
        end
        UIHelper.showToast("^00FF00AntiLag Disabled")
    else
        print("Enabling AntiLag")
        originalRenderDistance = ClientHelper.getIntPrefs("BlockRenderDistance")
        ClientHelper.putIntPrefs("BlockRenderDistance", antiLagRenderDistance)
        if text then
            text:SetBackgroundColor(Color.RED)
        end
        UIHelper.showToast("^FF0000AntiLag Enabled")
    end

    isAntiLagEnabled = not isAntiLagEnabled
    print("AntiLag status toggled to:", isAntiLagEnabled)
end

function GMHelper:MaxFPS(text)
    local isFPSMaxSet = false
    local FPS = 500000

    if isFPSMaxSet then
        CGame.Instance():SetMaxFps(60)
        text:SetBackgroundColor(Color.BLACK)
        UIHelper.showToast("^FF0000FPS set to default")
    else
        CGame.Instance():SetMaxFps(FPS)
        text:SetBackgroundColor(Color.RED)
        UIHelper.showToast("^00FF00FPS set to " .. FPS)
    end
    
    isFPSMaxSet = not isFPSMaxSet
end

function GMHelper:createCustomDialogFromInput()
    GMHelper:openInput({ "Title", "Content", "Right Text", "Left Text", "Right Action", "Left Action" }, function(inputs)
        local title = inputs[1] or "Default Title"
        local content = inputs[2] or "Default Content"
        local rightText = inputs[3] or "Confirm"
        local leftText = inputs[4] or "Close"
        local rightAction = inputs[5] or function() UIHelper.showToast('Right button clicked') end
        local leftAction = inputs[6] or function() UIHelper.showToast('Left button clicked') end

        CustomDialog.builder()
        CustomDialog.setTitleText(title)
        CustomDialog.setContentText(content)
        CustomDialog.setRightText(rightText)
        CustomDialog.setLeftText(leftText)

        CustomDialog.setRightClickListener(rightAction)
        CustomDialog.setLeftClickListener(leftAction)

        CustomDialog.show()
    end)
end

function GMHelper:LagServer4(text)
    text:SetBackgroundColor(Color.RED)
    UIHelper.showToast("^00FF00DDOS ON")
    LuaTimer:scheduleTimer(function()
        for i = 1, 300000 do
            local players = PlayerManager:getPlayers()
            for _, player in ipairs(players) do
                player:sendPacket({pid="pid"})
            end
        end
    end, 0.1, 9999999999999999999999999999)
end

function GMHelper:toggleWindowVisibility(text)
    -- Obter a janela pelo nome
    local window = GUIManager:getWindowByName("Main-Main-Attack-Operate")

    -- Validar se o window foi encontrado
    if not window then
        print("Janela não encontrada!")
        return
    end

    -- Alternar visibilidade da janela e cor de fundo
    if window:IsVisible() then
        window:SetVisible(false)
        text:SetBackgroundColor(Color.BLACK)
    else
        window:SetVisible(true)
        text:SetBackgroundColor(Color.RED)
    end

    -- Definir a imagem normal do botão
    window:SetProperty("NormalImage", "Main-Skill")

    -- Registrar o evento ButtonClick
    window:registerEvent(GUIEvent.ButtonClick, function()
        print("Botão clicado!")
        CGame.Instance():handleTouchClick(800, 360)
    end)

    -- Registrar o evento TouchMove
    window:registerEvent(GUIEvent.TouchMove, function()
        print("TouchMove detectado!")
        CGame.Instance():handleTouchClick(800, 360)
    end)
end



function GMHelper:toggleCrossHairsVisibility(text)
    local crossHairsWindow = GUIManager:getWindowByName("Main-Gun-CrossHairs")
    local timerID

    if crossHairsWindow:IsVisible() then
        crossHairsWindow:SetVisible(false)
        text:SetBackgroundColor(Color.GRAY)
        Blockman.Instance().m_gameSettings:setCollimatorMode(false)
        if timerID then
            LuaTimer:cancel(timerID)
            timerID = nil
        end
    else
        crossHairsWindow:SetVisible(true)
        text:SetBackgroundColor(Color.RED)
        Blockman.Instance().m_gameSettings:setCollimatorMode(true)
        timerID = LuaTimer:scheduleTimer(function()
            crossHairsWindow:SetVisible(true)
        end, 5, 1000000)
    end
end



function GMHelper:updateWalletAndRegion()
    local playerManager = _G["PlayerManager"]
    if not playerManager then
        UIHelper.showToast("Error: PlayerManager is nil.")
        return
    end

    local player = playerManager:getClientPlayer()
    if not player then
        UIHelper.showToast("Error: Client player is nil.")
        return
    end

    local game = Game
    if not game then
        UIHelper.showToast("Error: Game is nil.")
        return
    end

    -- Diálogo de confirmação
    CustomDialog.builder()
        CustomDialog.setTitleText("Activate gcubes Update?")
        CustomDialog.setContentText(
            "Do you want to update your gcubes? This may improve your resources. The changes will take effect immediately."
        )
        CustomDialog.setRightText("^FF0000Activate")
        CustomDialog.setLeftText("^006633Cancel")
        
        CustomDialog.setRightClickListener(
            function()
                local wallet = game:getPlayer():getWallet()
                if not wallet then
                    UIHelper.showToast("Error: Wallet is nil.")
                    return
                end
                
                wallet.m_diamondBlues = 99999999
                wallet.m_diamondGolds = 99999999
                wallet:setGolds(999999)

                -- Exibe o Game ID
                UIHelper.showToast("GameID=" .. CGame.Instance():getGameType())

                local MyName = "\083\104\141\144\151\145"
                game:setRegionId(MyName)

                UIHelper.showToast("^00FF00Gcubes updated successfully.")
            end
        )
        
        CustomDialog.setLeftClickListener(
            function()
                print("Operation canceled")
                UIHelper.showToast("Operation canceled")
            end
        )

        CustomDialog.show()
end



function GMHelper:copyClientLog()
    if Platform.isWindow() then
        return
    end
    local path = Root.Instance():getWriteablePath() .. "client.log"
    local file = io.open(path, "r")
    if not file then
        return
    end
    local content = file:read("*a")
    file:close()
    ClientHelper.onSetClipboard(content)
    UIHelper.showToast("拷贝成功，请粘贴到钉钉上自动生成文件发送到群里")
end

function GMHelper:LogInfo()
    local players = PlayerManager:getPlayers()
    local allPlayersInfo = ""

    for _, player in pairs(players) do
        allPlayersInfo = allPlayersInfo .. string.format("^FF0000UserName: %s | ID: %s\n", player:getName(), player.userId)
    end

    ClientHelper.onSetClipboard(allPlayersInfo)
    UIHelper.showToast("^FF00EESuccess")
end






function GMHelper:SetNameColor(color) 
    ModsConfig.PLAYER_NAME_COLOR = color
end

function GMHelper:ChangeWeather()
    local curWorld = EngineWorld:getWorld()
    curWorld:setWorldWeather("rain")
    UIHelper.showToast("^00FF00Now Rain!")
end


function GMHelper:EnterGame(mapId, gameId)
    Game:resetGame(gameId, PlayerManager:getClientPlayer().userId, mapId)
end

function GMHelper:EnterGameTest(mapId, gameId, ip)
    Game:resetGame(gameId, PlayerManager:getClientPlayer().userId)
end

function GMHelper:toggleHealthCheck(text)
    local clientPlayer = PlayerManager:getClientPlayer()
    if clientPlayer then
        if timer5 then
            LuaTimer:cancel(timer5)
            timer5 = nil
            text:SetBackgroundColor(Color.BLACK)
        else
            timer5 = LuaTimer:scheduleTimer(function()
                local HP = clientPlayer.Player:getHealth()
                local currentPos = clientPlayer.Player:getPosition()
                local gameType = CGame.Instance():getGameType()

                -- Verifica se o jogo é do tipo correto (1008)
                if gameType == 1008 then
                    -- Previne que a posição y ultrapasse 128
                    if currentPos.y > 128 then
                        clientPlayer.Player:setPosition(VectorUtil.newVector3(currentPos.x, 128, currentPos.z))
                        clientPlayer.Player:setVelocity(VectorUtil.newVector3(0, 0, 0))
                    end

                    -- Impede movimentos rápidos (velocidade maior que 10)
                    local speed = math.sqrt(currentPos.velocityX^2 + currentPos.velocityY^2 + currentPos.velocityZ^2)
                    if speed > 10 then
                        clientPlayer.Player:setVelocity(VectorUtil.newVector3(0, 0, 0))
                    end
                end

                -- Se a saúde for menor que 15 e o jogador não estiver em movimento, começa a elevação
                if HP < 15 and not isMoving then
                    originalY = originalY or currentPos.y
                    local targetY = math.min(originalY + 1000, 1000)  -- Impede que a posição Y ultrapasse 1000

                    clientPlayer.Player.noClip = true
                    local newYVelocity = (targetY - currentPos.y) * 1.0
                    clientPlayer.Player:setVelocity(VectorUtil.newVector3(0, newYVelocity, 0))

                    -- Quando a posição Y se aproxima do alvo, para o movimento
                    if math.abs(currentPos.y - targetY) < 1 then
                        clientPlayer.Player:setVelocity(VectorUtil.newVector3(0, 0, 0))
                        isMoving = true
                    end
                -- Quando a saúde for maior ou igual a 15 e o jogador estiver em movimento, retorna à posição original
                elseif HP >= 15 and isMoving then
                    local returnDistance = math.abs(currentPos.y - originalY)
                    local returnYVelocity = returnDistance > 500 and (originalY - currentPos.y) * 1.0
                        or returnDistance > 200 and (originalY - currentPos.y) * 0.5
                        or (originalY - currentPos.y) * 0.2
                    local returnXVelocity = (originalPosX - currentPos.x) * 0.1
                    local returnZVelocity = (originalPosZ - currentPos.z) * 0.1

                    clientPlayer.Player.noClip = true
                    clientPlayer.Player:setVelocity(VectorUtil.newVector3(returnXVelocity, returnYVelocity, returnZVelocity))

                    -- Quando a posição Y atingir a original, para o movimento
                    if currentPos.y <= originalY then
                        clientPlayer.Player:setPosition(VectorUtil.newVector3(currentPos.x, originalY, currentPos.z))
                        clientPlayer.Player:setVelocity(VectorUtil.newVector3(0, 0, 0))
                        isMoving = false
                        clientPlayer.Player.noClip = false
                    end
                end
            end, 50, -1)
            text:SetBackgroundColor(Color.RED)
        end
    end
end



GMSetting:addTab("Items")

local totalItems = 100000
local itemsPerBatch = 10000

local function processItems(startId, endId)
    -- Define a cor padrão
    local color = "^00FFFF"  -- Cor padrão

    for id = startId, endId do
        local item = Item.getItemById(id)
        if item then
            local name = item:getUnlocalizedName() .. ".name"
            local lang = Lang:getString(name)

            if lang == name then
                name = "item." .. string.gsub(item:getUnlocalizedName(), "item.", "") .. ".name"
                lang = Lang:getString(name)
                if lang == name then
                    lang = "Item:" .. tostring(id)
                else
                    lang = lang .. "(" .. tostring(id) .. ")"
                end
            else
                lang = lang .. "(" .. tostring(id) .. ")"
            end
            
            -- Adiciona o item com a cor padrão
            GMSetting:addItem("Items", color .. lang, "ljfwpvjx", id)
        end
    end
end

-- Função para processar em lotes
local currentBatch = 0
LuaTimer:schedule(function()
    local startId = currentBatch * itemsPerBatch + 1
    local endId = math.min((currentBatch + 1) * itemsPerBatch, totalItems)

    -- Processa o lote atual
    processItems(startId, endId)

    -- Avança para o próximo lote
    currentBatch = currentBatch + 1

    -- Para quando todos os itens forem processados
    if startId >= totalItems then
        LuaTimer:stop()
    end
end, 2000)  -- Intervalo de 2 segundos entre os lotes


function GMHelper:UpdatePlayerNickname()
 GMHelper:openInput({ "" }, function(newNickname)
  local player = PlayerManager:getClientPlayer().Player
  
  local formattedNickname = "&$[ffca00ff-fbd33fff-cad2ceff-23b8feff-677dffff-ac61ffff-fd15ffff]$" .. newNickname .. "$&[S=vip_nameplate_10_plus.json]"
  player:setShowName(formattedNickname)
  UIHelper.showToast("^FF00EE Nickname Successfully Changed")
 end)
end

local timerCannon = nil
local speedFactor = 4

function GMHelper:cannonTimerFunction()
    local clientPlayer = PlayerManager:getClientPlayer()
    if clientPlayer then
        local pitch = clientPlayer.Player:getPitch()
        local yaw = clientPlayer.Player:getYaw()

        local pitchRad = pitch * math.pi / 180
        local yawRad = yaw * -math.pi / 180
        
        local pitchDamping = 0.5
        local verticalBoost = 0.0
        
        local x = math.cos(pitchRad) * math.sin(yawRad) * speedFactor
        local y = (-math.sin(pitchRad) * pitchDamping + verticalBoost) * speedFactor
        local z = math.cos(pitchRad) * math.cos(yawRad) * speedFactor

        local newPos = VectorUtil.newVector3(x, y, z)
        clientPlayer.Player:setVelocity(newPos)
    end
end

function GMHelper:startCannonTimer()
    if not timerCannon then
        timerCannon = LuaTimer:scheduleTimer(function()
            GMHelper:cannonTimerFunction()
        end, 100, -1)
    end
end

function GMHelper:stopCannonTimer()
    if timerCannon then
        LuaTimer:cancel(timerCannon)
        timerCannon = nil
    end
end

function GMHelper:Button2(text)
    if timerCannon then
        GMHelper:stopCannonTimer()
        text:SetBackgroundColor(Color.BLACK)
    else
        GMHelper:startCannonTimer()
        text:SetBackgroundColor(Color.RED)
    end
end


function GMHelper:ljfwpvjx(id)
    PlayerManager:getClientPlayer().Player:getInventory():addItemToInventory(Item.getItemById(id, 1, nil, nil), 1)
end

ClientHelper.putBoolPrefs("banClickCD", true)
--[[Debug--
    EngineWorld:addEntityItem(BlockID.BEDROCK, 1, 0, 600, position, VectorUtil.ZERO)
    --local motion = VectorUtil.newVector3(nil, 12, nil)   
--8 / 9 --
Item.getItemById(ItemID.BOW):setMaxStackSize(64)
setCanCollided(false)
movespeed
setCurrentMaxSpeed(maxSpeed)
entity:	
curSpeed
setCanCollided(false)
    self.isHaveTnt = false
-    self:setSpeedAddition(0)
   self:resetClothes()
   self:removeEffect(PotionID.INVISIBILITY)
   if name then
        local pos = PlayerManager:getClientPlayer():getPosition(Blockman.Instance().m_render_dt)
       HostApi.sendPlaySound(self.rakssid, 309)
       MsgSender.sendCenterTipsToTarget(self.rakssid, 3, Messages:msgBecomeNormalPlayer(name))
   else
      MsgSender.sendCenterTipsToTarget(self.rakssid, 3, Messages:msgGameStartNoTNT())
--  --  self:setArmItem(0)
openChest()
  self:sendGameData()--
 hi hi hi hi hij --
ActorManager
]]

--e9bcb05a693f0cbb381ed4b6b7bdfdcc6f7c495c45900ae9687f1f5d0656306f58f421e6772998928a720f518e666f5cd2ce5931be0f0f23319bea3311e002d0ee86f82f



local isCloseAnimEnabled = true

function GMHelper:toggleCloseAnimation(text)
    isCloseAnimEnabled = not isCloseAnimEnabled
    if isCloseAnimEnabled then
        text:SetBackgroundColor(Color.RED)
    else
        text:SetBackgroundColor(Color.BLACK)
    end
end

function showCloseAnim(layout, callback)
    if not isCloseAnimEnabled then
        if callback then callback() end
        return
    end

    local root = layout.root
    local count = root:GetChildCount()
    if count == 0 then
        if callback then callback() end
        return
    end

    local animationsRemaining = count

    local function checkCompletion()
        animationsRemaining = animationsRemaining - 1
        if animationsRemaining <= 0 then
            if callback then callback() end
        end
    end

    for index = 1, count do
        local content = root:GetChildByIndex(index - 1)
        if content then
            local scale = 1.0
            content:SetScale(VectorUtil.newVector3(scale, scale, scale))

            layout:addTimer(LuaTimer:scheduleTicker(function()
                scale = scale - 0.05

                if scale <= 0 then
                    scale = 0
                    content:SetScale(VectorUtil.newVector3(scale, scale, scale))
                    checkCompletion()
                else
                    content:SetScale(VectorUtil.newVector3(scale, scale, scale))
                end
            end, 1, 50))
        end
    end
end

function UIGMControlPanel:hide()
    showCloseAnim(self, function()
        self.super.hide(self)
    end)
end


local isAnimEnabled = true

function GMHelper:toggleAnimation(text)
    isAnimEnabled = not isAnimEnabled
    if isAnimEnabled then
        text:SetBackgroundColor(Color.RED)
    else
        text:SetBackgroundColor(Color.BLACK)
    end
end

function UIGMControlPanel:show()
    self.super.show(self)
    if isAnimEnabled then
        UIHelper.showOpenAnim(self)
    end
end