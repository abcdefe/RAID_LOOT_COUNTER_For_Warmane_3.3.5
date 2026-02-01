-- 魔兽世界 3.3.5a 团队拾取计数器插件
-- 完全Debug版本

local addonName, ns = ...
local L = ns.L

local ADDON_NAME = "RaidLootCounter"
RLC = {} -- Make RLC global so XML can access it

-- ============================================================================
-- 常量定义
-- ============================================================================

-- 职业颜色配置（魔兽世界官方配色）
local CLASS_COLORS = {
    ["WARRIOR"] = {r = 0.78, g = 0.61, b = 0.43},
    ["PALADIN"] = {r = 0.96, g = 0.55, b = 0.73},
    ["HUNTER"] = {r = 0.67, g = 0.83, b = 0.45},
    ["ROGUE"] = {r = 1.00, g = 0.96, b = 0.41},
    ["PRIEST"] = {r = 1.00, g = 1.00, b = 1.00},
    ["DEATHKNIGHT"] = {r = 0.77, g = 0.12, b = 0.23},
    ["SHAMAN"] = {r = 0.00, g = 0.44, b = 0.87},
    ["MAGE"] = {r = 0.41, g = 0.80, b = 0.94},
    ["WARLOCK"] = {r = 0.58, g = 0.51, b = 0.79},
    ["DRUID"] = {r = 1.00, g = 0.49, b = 0.04},
}

-- ============================================================================
-- 数据库函数
-- ============================================================================

-- 初始化数据库
local function InitDB()
    if not RaidLootCounterDB then
        RaidLootCounterDB = {}
    end
    -- 默认开启自动通报
    if RaidLootCounterDB.autoAnnounce == nil then
        RaidLootCounterDB.autoAnnounce = true
    end
end

-- 清空所有数据
local function ClearAllData()
    -- 遍历删除所有键，但保留配置项
    for key in pairs(RaidLootCounterDB) do
        if key ~= "autoAnnounce" then
            RaidLootCounterDB[key] = nil
        end
    end
end

-- 检查数据库是否为空
local function IsDBEmpty()
    for _ in pairs(RaidLootCounterDB) do
        return false
    end
    return true
end

-- ============================================================================
-- 团队相关函数
-- ============================================================================

-- 获取团队成员信息（返回按职业分组的表）
local function GetRaidMembers()
    local members = {}
    local numRaidMembers = GetNumRaidMembers()
    
    if numRaidMembers > 0 then
        for i = 1, numRaidMembers do
            local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
            if name and fileName then
                if not members[fileName] then
                    members[fileName] = {}
                end
                table.insert(members[fileName], {
                    name = name,
                    class = fileName
                })
            end
        end
    end
    
    return members
end

-- 同步团队成员到数据库（移除不在团队中的成员）
local function SyncRaidMembers()
    local raidMembers = GetRaidMembers()
    local currentRaidNames = {}
    local addedCount = 0
    local removedCount = 0
    
    -- 1. 标记在团成员并添加新成员
    for className, players in pairs(raidMembers) do
        for _, player in ipairs(players) do
            currentRaidNames[player.name] = true
            
            if not RaidLootCounterDB[player.name] then
                -- 新成员，初始化数据
                RaidLootCounterDB[player.name] = {
                    count = 0,
                    class = className
                }
                addedCount = addedCount + 1
            else
                -- 已存在的成员，只更新职业（防止职业变更）
                RaidLootCounterDB[player.name].class = className
            end
        end
    end
    
    -- 2. 移除不在团队中的成员
    for name in pairs(RaidLootCounterDB) do
        -- 忽略配置项
        if name ~= "autoAnnounce" then
            if not currentRaidNames[name] then
                RaidLootCounterDB[name] = nil
                removedCount = removedCount + 1
            end
        end
    end
    
    return addedCount, removedCount
end

-- ============================================================================
-- 拾取数量操作函数
-- ============================================================================

-- 增加拾取数量
local function AddLoot(playerName)
    if not playerName or playerName == "" then
        return false
    end
    
    if RaidLootCounterDB[playerName] then
        RaidLootCounterDB[playerName].count = RaidLootCounterDB[playerName].count + 1
        return true
    end
    
    return false
end

-- 减少拾取数量
local function RemoveLoot(playerName)
    if not playerName or playerName == "" then
        return false
    end
    
    if RaidLootCounterDB[playerName] then
        local currentCount = RaidLootCounterDB[playerName].count
        RaidLootCounterDB[playerName].count = math.max(0, currentCount - 1)
        return true
    end
    
    return false
end

-- ============================================================================
-- 交互回调 (供XML调用)
-- ============================================================================

function RLC:OnSyncClick()
    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers == 0 then
        print("|cffff0000[RaidLootCounter]|r " .. L["MSG_NOT_IN_RAID"])
        return
    end
    
    local addedCount, removedCount = SyncRaidMembers()
    
    RLC:RefreshDisplay()
    
    local msg = "|cff00ff00[RaidLootCounter]|r " .. L["MSG_SYNC_COMPLETE"]
    if addedCount > 0 then
        msg = msg .. ", " .. string.format(L["MSG_ADDED"], addedCount)
    end
    if removedCount > 0 then
        msg = msg .. ", " .. string.format(L["MSG_REMOVED"], removedCount)
    end
    print(msg)
end

function RLC:OnMinusClick(parentFrame)
    if not parentFrame or not parentFrame.playerName then return end
    
    local playerName = parentFrame.playerName
    if RemoveLoot(playerName) then
        local newCount = RaidLootCounterDB[playerName].count
        RLC:RefreshDisplay()
        RLC:SendLootUpdate(playerName, newCount, false)
    end
end

function RLC:OnPlusClick(parentFrame)
    if not parentFrame or not parentFrame.playerName then return end
    
    local playerName = parentFrame.playerName
    if AddLoot(playerName) then
        local newCount = RaidLootCounterDB[playerName].count
        RLC:RefreshDisplay()
        RLC:SendLootUpdate(playerName, newCount, true)
    end
end

function RLC:OnAutoAnnounceClick(checkbox)
    if checkbox:GetChecked() then
        RaidLootCounterDB.autoAnnounce = true
    else
        RaidLootCounterDB.autoAnnounce = false
    end
end

-- ============================================================================
-- UI对象池管理
-- ============================================================================

local playerFramePool = {}
local classHeaderPool = {}

-- 隐藏所有池对象
local function HideAllPoolObjects()
    for _, frame in pairs(playerFramePool) do
        frame:Hide()
    end
    for _, header in pairs(classHeaderPool) do
        header:Hide()
    end
end

-- 获取或创建玩家行
local function GetPlayerFrame(parent, index)
    if not playerFramePool[index] then
        -- 使用 XML 模板创建
        local frameName = "RLC_PlayerRow_" .. index
        local frame = CreateFrame("Frame", frameName, parent, "RLC_PlayerRowTemplate")
        
        -- 获取子控件引用以便后续快速访问
        frame.nameText = _G[frameName.."Name"]
        frame.countText = _G[frameName.."Count"]
        frame.minusBtn = _G[frameName.."MinusBtn"]
        frame.plusBtn = _G[frameName.."PlusBtn"]
        
        playerFramePool[index] = frame
    end
    
    local frame = playerFramePool[index]
    frame:SetParent(parent)
    frame:ClearAllPoints()
    frame:Show()
    return frame
end

-- 获取或创建职业标题
local function GetClassHeader(parent, index)
    if not classHeaderPool[index] then
        -- 使用 XML 模板创建
        local headerName = "RLC_ClassHeader_" .. index
        local header = CreateFrame("Frame", headerName, parent, "RLC_ClassHeaderTemplate")
        
        -- 获取子控件引用
        header.text = _G[headerName.."Text"]
        
        classHeaderPool[index] = header
    end
    
    local header = classHeaderPool[index]
    header:SetParent(parent)
    header:ClearAllPoints()
    header:Show()
    return header
end

-- 刷新显示列表
function RLC:RefreshDisplay()
    -- mainFrame 现在由 XML 定义，名字是 RaidLootCounterFrame
    local mainFrame = RaidLootCounterFrame
    if not mainFrame then return end
    
    -- ScrollChild 名字在 XML 中定义为 RLCScrollChild
    local scrollChild = RLCScrollChild
    if not scrollChild then return end
    
    -- 隐藏所有旧内容（使用对象池复用）
    HideAllPoolObjects()
    
    -- 如果数据库为空，直接返回
    if IsDBEmpty() then
        scrollChild:SetHeight(1)
        return
    end
    
    -- 从数据库整理数据，按职业分组
    local membersByClass = {}
    for playerName, data in pairs(RaidLootCounterDB) do
        if data and type(data) == "table" then
            local class = data.class or "WARRIOR"
            if not membersByClass[class] then
                membersByClass[class] = {}
            end
            table.insert(membersByClass[class], {
                name = playerName,
                count = data.count or 0,
                class = class
            })
        end
    end
    
    -- 职业排序
    local sortedClasses = {}
    for class in pairs(membersByClass) do
        table.insert(sortedClasses, class)
    end
    table.sort(sortedClasses)
    
    local yOffsetLeft = -10
    local yOffsetRight = -10
    local headerIndex = 0
    local frameIndex = 0
    
    -- 显示每个职业的成员
    for _, className in ipairs(sortedClasses) do
        local players = membersByClass[className]
        local numPlayers = #players
        local blockHeight = 25 + (numPlayers * 35) + 10 -- Header + Players + Padding
        
        -- 决定放在哪一列（高度较小优先）
        local isLeft = math.abs(yOffsetLeft) <= math.abs(yOffsetRight)
        local xPos = isLeft and 10 or 380 -- 左列X=10, 右列X=380
        local yPos = isLeft and yOffsetLeft or yOffsetRight
        
        -- 职业标题
        headerIndex = headerIndex + 1
        local classHeaderFrame = GetClassHeader(scrollChild, headerIndex)
        classHeaderFrame:SetPoint("TOPLEFT", xPos, yPos)
        local color = CLASS_COLORS[className] or {r = 1, g = 1, b = 1}
        classHeaderFrame.text:SetTextColor(color.r, color.g, color.b)
        
        -- Use global localized class names
        local displayName = LOCALIZED_CLASS_NAMES_MALE[className] or className
        classHeaderFrame.text:SetText(displayName)
        yPos = yPos - 25
        
        -- 成员列表（按名字排序）
        table.sort(players, function(a, b) return a.name < b.name end)
        
        for _, player in ipairs(players) do
            local playerName = player.name
            local playerCount = player.count
            
            frameIndex = frameIndex + 1
            local playerFrame = GetPlayerFrame(scrollChild, frameIndex)
            playerFrame:SetPoint("TOPLEFT", xPos, yPos)
            
            -- 保存玩家名到 frame 上，供 XML 点击事件使用
            playerFrame.playerName = playerName
            
            -- 玩家名字
            playerFrame.nameText:SetTextColor(color.r, color.g, color.b)
            playerFrame.nameText:SetText(playerName)
            
            -- 拾取数量
            playerFrame.countText:SetText(L["LOOTED_PREFIX"] .. playerCount)
            
            -- 按钮事件已在 XML 中绑定到 RLC:OnMinusClick/OnPlusClick
            -- 无需在此处 SetScript
            
            yPos = yPos - 35
        end
        
        yPos = yPos - 10
        
        -- 更新对应列的高度
        if isLeft then
            yOffsetLeft = yPos
        else
            yOffsetRight = yPos
        end
    end
    
    -- 设置滚动区域高度
    scrollChild:SetHeight(math.max(1, math.max(math.abs(yOffsetLeft), math.abs(yOffsetRight)) + 20))
end

-- ============================================================================
-- 聊天发送函数
-- ============================================================================

-- 发送完整统计到团队聊天
function RLC:SendToRaid()
    local numRaidMembers = GetNumRaidMembers()
    
    if numRaidMembers == 0 then
        print("|cffff0000[RaidLootCounter]|r " .. L["MSG_NOT_IN_RAID"])
        return
    end
    
    if IsDBEmpty() then
        print("|cffff0000[RaidLootCounter]|r " .. L["MSG_NO_DATA"])
        return
    end
    
    -- 整理数据按职业分组
    local dataByClass = {}
    for playerName, data in pairs(RaidLootCounterDB) do
        if data and type(data) == "table" then
            local class = data.class or "WARRIOR"
            if not dataByClass[class] then
                dataByClass[class] = {}
            end
            table.insert(dataByClass[class], {
                name = playerName,
                count = data.count or 0
            })
        end
    end
    
    -- 发送标题
    SendChatMessage(L["OUTPUT_HEADER"], "RAID_WARNING")
    
    -- 职业排序
    local sortedClasses = {}
    for class in pairs(dataByClass) do
        table.insert(sortedClasses, class)
    end
    table.sort(sortedClasses)
    
    -- 按职业发送数据
    for _, class in ipairs(sortedClasses) do
        local players = dataByClass[class]
        
        -- 对玩家按拾取数量排序（降序）
        table.sort(players, function(a, b)
            if a.count == b.count then
                return a.name < b.name
            end
            return a.count > b.count
        end)
        
        -- 发送职业标题（使用英文职业名/文件名，保持一致性）
        SendChatMessage("[" .. class .. "]", "RAID_WARNING")
        
        -- 发送每个玩家的数据
        for _, player in ipairs(players) do
            local msg = player.name .. ": " .. player.count .. " " .. L["OUTPUT_ITEMS"]
            SendChatMessage(msg, "RAID_WARNING")
        end
        
        -- 发送空行分隔
        SendChatMessage(" ", "RAID_WARNING")
    end
    
    SendChatMessage("=======================================", "RAID_WARNING")
    
    print("|cff00ff00[RaidLootCounter]|r " .. L["MSG_STATS_SENT"])
end

-- 发送单个玩家的拾取更新
function RLC:SendLootUpdate(playerName, newCount, isAdd)
    -- 如果未开启自动通报，直接返回
    if not RaidLootCounterDB.autoAnnounce then
        return
    end

    local numRaidMembers = GetNumRaidMembers()
    
    if numRaidMembers == 0 then
        return  -- 不在团队中，静默不发送
    end
    
    -- 格式：{人名} - {Add/Remove} {更新的数量} - {更新后数量}
    local action = isAdd and L["OUTPUT_ADD"] or L["OUTPUT_REMOVE"]
    local changeAmount = 1
    local msg = playerName .. " - " .. action .. " " .. changeAmount .. " - " .. L["OUTPUT_TOTAL"] .. " " .. newCount
    SendChatMessage(msg, "RAID_WARNING")
end

-- ============================================================================
-- 插件初始化
-- ============================================================================

local function InitUI()
    if RaidLootCounterFrameTitle then
        RaidLootCounterFrameTitle:SetText(L["WINDOW_TITLE"])
    end
    if RaidLootCounterFrameSyncButton then
        RaidLootCounterFrameSyncButton:SetText(L["SYNC_RAID"])
    end
    if RaidLootCounterFrameClearButton then
        RaidLootCounterFrameClearButton:SetText(L["CLEAR_DATA"])
    end
    if RaidLootCounterFrameSendButton then
        RaidLootCounterFrameSendButton:SetText(L["SEND_STATS"])
    end
    if RaidLootCounterFrameAutoAnnounceCheckboxText then
        RaidLootCounterFrameAutoAnnounceCheckboxText:SetText(L["CHECKBOX_AUTO_ANNOUNCE"])
    end
    if RaidLootCounterFrameAutoAnnounceCheckbox then
        RaidLootCounterFrameAutoAnnounceCheckbox:SetChecked(RaidLootCounterDB.autoAnnounce)
    end
end

local function OnAddonLoaded(self, event, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    
    -- 初始化数据库
    InitDB()
    
    -- 初始化UI文本
    InitUI()
    
    -- 注册斜杠命令
    SLASH_RLC1 = "/rlc"
    SlashCmdList["RLC"] = function(msg)
        if RaidLootCounterFrame:IsShown() then
            RaidLootCounterFrame:Hide()
        else
            RaidLootCounterFrame:Show()
            RLC:RefreshDisplay()
        end
    end
    
    -- 创建清空确认对话框
    StaticPopupDialogs["RLC_CLEAR_CONFIRM"] = {
        text = L["CONFIRM_CLEAR_TEXT"],
        button1 = L["CONFIRM"],
        button2 = L["CANCEL"],
        OnAccept = function()
            ClearAllData()
            RLC:RefreshDisplay()
            print("|cff00ff00[RaidLootCounter]|r " .. L["MSG_DATA_CLEARED"])
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    print("|cff00ff00RaidLootCounter|r " .. L["MSG_LOADED"])
end

-- 注册事件
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnAddonLoaded)
