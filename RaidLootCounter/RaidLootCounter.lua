-- 魔兽世界 3.3.5a 团队拾取计数器插件
-- RaidLootCounter.lua
-- 整理后的代码结构

local addonName, ns = ...
local L = ns.L

local ADDON_NAME = "RaidLootCounter"
RLC = {} -- 全局对象，供XML调用

local Chat = ns.Chat
-- local LootUtil = ns.LootUtil -- Was nil
local Roll = ns.Roll
local DB = ns.DB

-- ============================================================================
-- 0. 工具模块 (LootUtil) - 定义在此处以确保可用
-- ============================================================================
-- Note: LootUtil is now defined in Constants.lua to avoid duplication
local LootUtil = ns.LootUtil

-- ============================================================================
-- 1. 常量与变量 (Constants & Globals)
-- ============================================================================

local CLASS_COLORS = ns.CONSTANTS.CLASS_COLORS
local ENGLISH_CLASS_NAMES = ns.CONSTANTS.ENGLISH_CLASS_NAMES

-- 工具函数：检查物品是否为装备绑定 (BOE)
local tooltipScanner
function ns.IsItemBOE(itemLink)
    if not itemLink then return false end
    
    -- Check cache first
    if ns.ItemCache[itemLink] and ns.ItemCache[itemLink].isBOE ~= nil then
        return ns.ItemCache[itemLink].isBOE
    end
    
    if not tooltipScanner then
        tooltipScanner = CreateFrame("GameTooltip", "RLCScannerTooltip", nil, "GameTooltipTemplate")
        tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    
    tooltipScanner:ClearLines()
    tooltipScanner:SetHyperlink(itemLink)
    
    for i = 1, tooltipScanner:NumLines() do
        local line = _G["RLCScannerTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text == ITEM_BIND_ON_EQUIP then
                ns.ItemCache[itemLink] = ns.ItemCache[itemLink] or {}
                ns.ItemCache[itemLink].isBOE = true
                return true
            end
        end
    end
    
    ns.ItemCache[itemLink] = ns.ItemCache[itemLink] or {}
    ns.ItemCache[itemLink].isBOE = false
    return false
end

-- 工具函数：获取物品的 Tier 等级 (T7, T8, T9, T10)
function ns.GetItemTier(itemLink)
    if not itemLink then return nil end
    
    -- Check cache first
    if ns.ItemCache[itemLink] and ns.ItemCache[itemLink].tier ~= nil then
        return ns.ItemCache[itemLink].tier
    end

    local itemName = GetItemInfo(itemLink)
    if not itemName then 
        -- Fallback to extracting name from link if not cached
        itemName = string.match(itemLink, "%[([^%]]+)%]")
    end
    
    if not itemName then 
        ns.ItemCache[itemLink] = ns.ItemCache[itemLink] or {}
        ns.ItemCache[itemLink].tier = nil
        return nil 
    end

    -- 1. Check for Token Patterns
    for tier, patterns in pairs(ns.CONSTANTS.TIER_PATTERNS) do
        for _, pattern in ipairs(patterns) do
            if string.find(itemName, pattern) then
                ns.ItemCache[itemLink] = ns.ItemCache[itemLink] or {}
                ns.ItemCache[itemLink].tier = tier
                return tier
            end
        end
    end

    -- 2. Check for Set Names via Tooltip
    if not tooltipScanner then
        tooltipScanner = CreateFrame("GameTooltip", "RLCScannerTooltip", nil, "GameTooltipTemplate")
        tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    
    tooltipScanner:ClearLines()
    tooltipScanner:SetHyperlink(itemLink)
    
    -- Check lines for Set Name
    -- Usually "Set Name (0/5)"
    for i = 1, tooltipScanner:NumLines() do
        local line = _G["RLCScannerTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Relaxed check: Look for set count pattern like "0/5"
                -- Matches "(0/5)", "（0/5）", or any variation
                if string.find(text, "%d+/%d+") then
                    -- Check if line contains any of our known keys
                    for key, tier in pairs(ns.CONSTANTS.TIER_SETS) do
                        if string.find(text, key) then
                            ns.ItemCache[itemLink] = ns.ItemCache[itemLink] or {}
                            ns.ItemCache[itemLink].tier = tier
                            return tier
                        end
                    end
                end
            end
        end
    end

    ns.ItemCache[itemLink] = ns.ItemCache[itemLink] or {}
    ns.ItemCache[itemLink].tier = nil
    return nil
end
-- Roll点捕获变量
local isRollCapturing = false
local rollResults = {}
local rollCaptureFrame = nil

-- UI对象池
local playerFramePool = {}
local classHeaderPool = {}
local lootSelectionRows = {}

-- 临时状态
RLC.targetPlayer = nil
RLC.selectedLoot = nil
RLC.selectionMode = ns.CONSTANTS.MODES.ASSIGN -- "ASSIGN", "UNASSIGN", "ROLL"
RLC.distroMode = "MS+1"
RLC.tempDistroMode = "MS+1"

-- ============================================================================
-- 2. 数据管理 (Data Management)
-- ============================================================================

-- 初始化数据库
local function InitDB()
    DB.Init()
    RLC.distroMode = DB.GetDistroMode()
end

-- 清空所有数据
local function ClearAllData()
    DB.ClearAllData()

    -- 重置Mock数据状态（Mock 本身由 LootHistory 管理）
    if RLC.ResetMockData then
        RLC:ResetMockData()
    end
end



function RLC:UpdateDistroModeUI()
    if RLC.distroMode == "MS+1" then
        RLC_DistroModeFrameMSPlus1Radio:SetChecked(true)
        RLC_DistroModeFrameMSGTOSRadio:SetChecked(false)
    else
        RLC_DistroModeFrameMSPlus1Radio:SetChecked(false)
        RLC_DistroModeFrameMSGTOSRadio:SetChecked(true)
    end
end


-- ============================================================================
-- 5. 分配模式 (Distro Mode)
-- ============================================================================

function RLC:ToggleDistroMode()
    local frame = RLC_DistroModeFrame
    if frame:IsShown() then
        frame:Hide()
    else
        RLC.tempDistroMode = RLC.distroMode -- Initialize with current saved mode
        frame:Show()
        RLC:UpdateDistroModeUI() -- Set radio buttons to current saved mode
    end
end

function RLC:OnSaveDistroModeClick()
    RLC:SetDistroMode(RLC.tempDistroMode)
    RLC_DistroModeFrame:Hide()
end

function RLC:SetDistroMode(mode)
    RLC.distroMode = mode
    DB.SetDistroMode(mode)
    -- This function call implies RLC:UpdateUIText() should exist. It updates the button in the main frame.
    -- Since it's not defined elsewhere, we assume it's part of another change or should be added.
    -- For now, we are adding the functions from the request. The text update logic is in InitUI.
    if RaidLootCounterFrameDistroModeButton then 
        RaidLootCounterFrameDistroModeButton:SetText(L["DISTRO_MODE"] .. ": " .. RLC.distroMode) 
    end
end

-- 检查数据库是否为空
local function IsDBEmpty()
    return DB.IsEmpty()
end

-- 获取团队成员信息 (按职业分组)
local function GetRaidMembers()
    -- 向后兼容：保留函数名，但直接读取 DB.SyncRaidMembers 使用的逻辑
    -- 这里仅作为内部工具，不再对外使用
    return nil
end

-- 获取玩家持有的装备列表
local function GetPlayerItems(playerName)
    return DB.GetPlayerItems(playerName)
end

-- 同步团队成员
local function SyncRaidMembers()
    return DB.SyncRaidMembers()
end

-- 增加拾取计数
local function AddLoot(playerName, isOS)
    return DB.AddLoot(playerName, isOS)
end

-- 减少拾取计数
local function RemoveLoot(playerName, isOS)
    return DB.RemoveLoot(playerName, isOS)
end

-- ============================================================================
-- 3. 核心逻辑与通报 (Logic & Reporting)
-- ============================================================================

-- 通报消息 (团队/打印)
local function Announce(msg)
    Chat.SendRaidOrPrint(msg, "RAID_WARNING")
end

-- 发送单个玩家的拾取更新
function RLC:SendLootUpdate(playerName, newCount, isAdd, itemLink, isOS)
    if not RaidLootCounterDB.autoAnnounce then return end
    
    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers == 0 then return end
    
    local action = isAdd and "Add" or "Remove"
    local itemPart = itemLink and (" " .. itemLink) or " 1"
    local typeStr = isOS and "(OS)" or "(MS)"
    
    -- 1. 发送本次操作信息
    local msg = playerName .. " - " .. action .. itemPart .. typeStr
    Chat.SendRaidOrPrint(msg, "RAID_WARNING")
    
    -- 获取玩家最新数据
    local playerData = RaidLootCounterDB.players[playerName]
    local msCount = playerData and playerData.msCount or 0
    local osCount = playerData and playerData.osCount or 0
    
    -- 2. 发送 Total 信息
    if RLC.distroMode ~= "MS>OS" then
        local totalMsg = "Total: MS " .. msCount
        SendChatMessage(totalMsg, "RAID_WARNING")
    end
    
    -- 3. 发送 MS 和 OS 装备列表
    local items = GetPlayerItems(playerName)
    local msItems = {}
    local osItems = {}
    
    for _, item in ipairs(items) do
        if item.type == ns.CONSTANTS.LOOT_TYPE.OS then
            table.insert(osItems, item.link)
        else
            table.insert(msItems, item.link)
        end
    end
    
    local function SendList(prefix, list)
        if #list == 0 then return end
        Chat.SendWrapped(prefix, list, "RAID_WARNING", "  ")
    end
    
    SendList("MS:", msItems)
    SendList("OS:", osItems)
end

-- 发送完整统计到团队
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
    
    -- 数据分组
    local dataByClass = {}
    local playersDB = RaidLootCounterDB.players or {}

    for playerName, data in pairs(playersDB) do
        if data and type(data) == "table" then
            local class = data.class or ns.CONSTANTS.DEFAULTS.DEFAULT_CLASS
            if not dataByClass[class] then dataByClass[class] = {} end
            table.insert(dataByClass[class], {
                name = playerName,
                msCount = data.msCount or 0,
                osCount = data.osCount or 0
            })
        end
    end
    
    Chat.SendRaidOrPrint("=== Raid Loot Counter ===", "RAID_WARNING")
    
    local sortedClasses = {}
    for class in pairs(dataByClass) do table.insert(sortedClasses, class) end
    table.sort(sortedClasses)
    
    for _, class in ipairs(sortedClasses) do
        local players = dataByClass[class]
        table.sort(players, function(a, b)
            if a.msCount == b.msCount then 
                 if a.osCount == b.osCount then
                     return a.name < b.name 
                 end
                 return a.osCount > b.osCount
            end
            return a.msCount > b.msCount
        end)
        
        local displayClass = ENGLISH_CLASS_NAMES[class] or class
        Chat.SendRaidOrPrint("[" .. displayClass .. "]", "RAID_WARNING")
        
        for _, player in ipairs(players) do
            local msgParts = {player.name}
            if RLC.distroMode == "MS>OS" then
                -- No count in MS>OS mode
            else
                table.insert(msgParts, ": MS:")
                table.insert(msgParts, tostring(player.msCount))
            end
            local msg = table.concat(msgParts)
            Chat.SendRaidOrPrint(msg, "RAID_WARNING")
            
            local items = GetPlayerItems(player.name)
            if #items > 0 then
                local currentLineParts = {"  "}
                for i, item in ipairs(items) do
                    local itemStr = item.link .. (item.type == ns.CONSTANTS.LOOT_TYPE.OS and "(OS)" or "(MS)")
                    if string.len(table.concat(currentLineParts)) + string.len(itemStr) > 250 then
                        Chat.SendRaidOrPrint(table.concat(currentLineParts), "RAID_WARNING")
                        currentLineParts = {"  ", itemStr}
                    else
                        table.insert(currentLineParts, itemStr)
                        table.insert(currentLineParts, " ")
                    end
                end
                if #currentLineParts > 1 then
                    Chat.SendRaidOrPrint(table.concat(currentLineParts), "RAID_WARNING")
                end
            end
        end
        Chat.SendRaidOrPrint(" ", "RAID_WARNING")
    end
    
    Chat.SendRaidOrPrint("=======================================", "RAID_WARNING")
    print(ns.CONSTANTS.CHAT_PREFIX .. L["MSG_STATS_SENT"])
end

-- Roll 相关逻辑已移动到独立模块 RLC_Roll.lua

-- ============================================================================
-- 4. UI 逻辑 (UI Implementation)
-- ============================================================================

local function HideAllPoolObjects()
    for _, frame in pairs(playerFramePool) do frame:Hide() end
    for _, header in pairs(classHeaderPool) do header:Hide() end
end

local function GetPlayerFrame(parent, index)
    if not playerFramePool[index] then
        local frameName = "RLC_PlayerRow_" .. index
        local frame = CreateFrame("Frame", frameName, parent, "RLC_PlayerRowTemplate")
        frame.nameText = _G[frameName.."Name"]
        frame.msCountText = _G[frameName.."MSCount"]
        frame.osCountText = _G[frameName.."OSCount"]
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

local function GetClassHeader(parent, index)
    if not classHeaderPool[index] then
        local headerName = "RLC_ClassHeader_" .. index
        local header = CreateFrame("Frame", headerName, parent, "RLC_ClassHeaderTemplate")
        header.text = _G[headerName.."Text"]
        classHeaderPool[index] = header
    end
    local header = classHeaderPool[index]
    header:SetParent(parent)
    header:ClearAllPoints()
    header:Show()
    return header
end

function RLC:RefreshDisplay()
    local mainFrame = RaidLootCounterFrame
    if not mainFrame then return end
    
    local scrollChild = RLCScrollChild
    if not scrollChild then return end
    
    HideAllPoolObjects()
    
    if IsDBEmpty() then
        scrollChild:SetHeight(1)
        return
    end
    
    local membersByClass = {}
    local playersDB = RaidLootCounterDB.players or {}
    
    for playerName, data in pairs(playersDB) do
        if data and type(data) == "table" then
            local class = data.class or ns.CONSTANTS.DEFAULTS.DEFAULT_CLASS
            if not membersByClass[class] then membersByClass[class] = {} end
            table.insert(membersByClass[class], {
                name = playerName,
                msCount = data.msCount or 0,
                osCount = data.osCount or 0,
                class = class
            })
        end
    end
    
    local sortedClasses = {}
    for class in pairs(membersByClass) do table.insert(sortedClasses, class) end
    table.sort(sortedClasses)
    
    local yOffsetLeft = -10
    local yOffsetRight = -10
    local headerIndex = 0
    local frameIndex = 0
    
    for _, className in ipairs(sortedClasses) do
        local players = membersByClass[className]
        local numPlayers = #players
        
        local isLeft = math.abs(yOffsetLeft) <= math.abs(yOffsetRight)
        local xPos = isLeft and 10 or 380
        local yPos = isLeft and yOffsetLeft or yOffsetRight
        
        -- Header
        headerIndex = headerIndex + 1
        local classHeaderFrame = GetClassHeader(scrollChild, headerIndex)
        classHeaderFrame:SetPoint("TOPLEFT", xPos, yPos)
        local color = CLASS_COLORS[className] or {r = 1, g = 1, b = 1}
        classHeaderFrame.text:SetTextColor(color.r, color.g, color.b)
        
        local displayName = LOCALIZED_CLASS_NAMES_MALE[className] or className
        classHeaderFrame.text:SetText(displayName)
        yPos = yPos - 25
        
        -- Players
        table.sort(players, function(a, b) return a.name < b.name end)
        
        for _, player in ipairs(players) do
            local playerName = player.name
            local msCount = player.msCount
            local osCount = player.osCount
            
            frameIndex = frameIndex + 1
            local playerFrame = GetPlayerFrame(scrollChild, frameIndex)
            playerFrame:SetPoint("TOPLEFT", xPos, yPos)
            playerFrame.playerName = playerName
            
            playerFrame.nameText:SetTextColor(color.r, color.g, color.b)
            playerFrame.nameText:SetText(playerName)
            playerFrame.msCountText:SetText("MS: " .. msCount)
            playerFrame.osCountText:SetText("OS: " .. osCount)
            
            yPos = yPos - 35
        end
        
        yPos = yPos - 10
        if isLeft then yOffsetLeft = yPos else yOffsetRight = yPos end
    end
    
    scrollChild:SetHeight(math.max(1, math.max(math.abs(yOffsetLeft), math.abs(yOffsetRight)) + 20))
end

-- 装备选择相关
local function HideAllLootSelectionRows()
    for _, row in pairs(lootSelectionRows) do
        row:Hide()
        if row.highlight then row.highlight:Hide() end
    end
end

local function GetLootSelectionRow(parent, index)
    if not lootSelectionRows[index] then
        local rowName = "RLC_LootSelectionRow_" .. index
        local row = CreateFrame("Button", rowName, parent, "RLC_LootSelectionRowTemplate")
        row.itemText = _G[rowName.."Item"]
        row.bossText = _G[rowName.."Boss"]
        row.itemHitBox = _G[rowName.."ItemHitBox"]
        row.highlight = _G[rowName.."Highlight"]
        lootSelectionRows[index] = row
    end
    local row = lootSelectionRows[index]
    row:SetParent(parent)
    row:ClearAllPoints()
    row:Show()
    return row
end

function RLC:UpdateLootSelectionScroll()
    if not RLC.lootSelectionData then return end
    
    local scrollFrame = RLCLootSelectionScrollFrame
    if not scrollFrame then return end
    
    local numRows = #RLC.lootSelectionData
    -- Visible rows defined in Constants
    FauxScrollFrame_Update(scrollFrame, numRows, ns.CONSTANTS.UI.SELECTION_MAX_ROWS, ns.CONSTANTS.UI.SELECTION_ROW_HEIGHT)
    
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    HideAllLootSelectionRows()
    
    local parent = RLCLootSelectionFrame
    local yPos = -50
    
    for i = 1, ns.CONSTANTS.UI.SELECTION_MAX_ROWS do
        local dataIndex = offset + i
        if dataIndex > numRows then break end
        
        local item = RLC.lootSelectionData[dataIndex]
        local row = GetLootSelectionRow(parent, i)
        row:SetPoint("TOPLEFT", 20, yPos)
        
        local prefix = ""
        local tier = ns.GetItemTier(item.link)
        if tier then
            prefix = ns.CONSTANTS.COLORS.BOSS .. "[" .. tier .. "]|r "
        end
        
        if item.isBOE then
            prefix = prefix .. ns.CONSTANTS.COLORS.BOE .. "[BOE]|r "
        end
        
        local link = item.link
        local suffix = ""
        
        if RLC.selectionMode == ns.CONSTANTS.MODES.UNASSIGN then
             local typeStr = item.type or ns.CONSTANTS.LOOT_TYPE.UNASSIGN
             suffix = "  " .. ns.CONSTANTS.COLORS.GRAY .. "(" .. typeStr .. ")|r"
        end
        
        local displayText = prefix .. link .. suffix
        row.itemText:SetText(displayText)
        
        local locationText = ""
        if item.instanceName and item.instanceName ~= "" then
            locationText = item.instanceName .. " - "
        end
        locationText = locationText .. (item.bossName or "Unknown")
        row.bossText:SetText(locationText)
        
        row.data = item
        
        -- Update Highlight
        if RLC.selectedLoot and RLC.selectedLoot == item then
            if row.highlight then row.highlight:Show() end
        else
            if row.highlight then row.highlight:Hide() end
        end

        -- Update HitBox size
        if row.itemHitBox then
            row.itemText:SetText(prefix)
            local prefixWidth = row.itemText:GetStringWidth()
            
            row.itemText:SetText(link)
            local linkWidth = row.itemText:GetStringWidth()
            
            row.itemText:SetText(displayText)
            
            row.itemHitBox:ClearAllPoints()
            row.itemHitBox:SetPoint("LEFT", row.itemText, "LEFT", prefixWidth, 0)
            row.itemHitBox:SetWidth(linkWidth)
            row.itemHitBox:SetHeight(ns.CONSTANTS.UI.SELECTION_ROW_HEIGHT)
            row.itemHitBox:Show()
        end
        
        yPos = yPos - ns.CONSTANTS.UI.SELECTION_ROW_HEIGHT
    end
end

function RLC:ShowLootSelection(playerName, mode)
    RLC.targetPlayer = playerName
    RLC.selectionMode = mode or ns.CONSTANTS.MODES.ASSIGN
    RLC.selectedLoot = nil
    
    local frame = RLCLootSelectionFrame
    if not frame then 
        print(ns.CONSTANTS.CHAT_PREFIX .. L["ERR_NO_LOOT_SELECTION_FRAME"])
        return 
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    
    local title = _G[frame:GetName().."Title"]
    local saveButton = _G[frame:GetName().."SaveButton"]
    local saveOSButton = _G[frame:GetName().."SaveOSButton"]
    
    if title then 
        if RLC.selectionMode == ns.CONSTANTS.MODES.UNASSIGN then
            title:SetText(L["TITLE_REMOVE_LOOT"] .. (playerName or "?"))
        elseif RLC.selectionMode == ns.CONSTANTS.MODES.ROLL then
            title:SetText(L["TITLE_ROLL_LOOT"])
        else
            title:SetText(L["TITLE_ASSIGN_LOOT"] .. (playerName or "?")) 
        end
    end
    
    -- 按钮状态调整
    if saveButton and saveOSButton then
        if RLC.selectionMode == ns.CONSTANTS.MODES.ROLL then
            saveButton:SetText(L["BUTTON_MS_ROLL"])
            saveButton:ClearAllPoints()
            saveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -10, 20)
            
            saveOSButton:Show()
            saveOSButton:SetText(L["BUTTON_OS_ROLL"])
            saveOSButton:ClearAllPoints()
            saveOSButton:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 10, 20)
        elseif RLC.selectionMode == ns.CONSTANTS.MODES.ASSIGN then
            saveButton:SetText(L["BUTTON_MS_SAVE"])
            saveButton:ClearAllPoints()
            saveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -10, 20)
            
            saveOSButton:Show()
            saveOSButton:SetText(L["BUTTON_OS_SAVE"])
            saveOSButton:ClearAllPoints()
            saveOSButton:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 10, 20)
        else
            saveButton:SetText(L["BUTTON_REMOVE"])
            saveButton:ClearAllPoints()
            saveButton:SetPoint("BOTTOM", 0, 20)
            saveOSButton:Hide()
        end
    end
    
    RLC.lootSelectionData = {}
    if RaidLootCounterDB.lootedBosses then
        for bossGUID, data in pairs(RaidLootCounterDB.lootedBosses) do
            if data.loot then
                for i, itemData in ipairs(data.loot) do
                    local link, holder, itemType, isBOE
                    if type(itemData) == "table" then
                        link = itemData.link
                        holder = itemData.holder
                        itemType = itemData.type
                        isBOE = itemData.isBOE
                        if isBOE == nil and link then
                            isBOE = ns.IsItemBOE(link)
                        end
                    else
                        link = itemData
                        holder = nil
                        itemType = nil
                        isBOE = nil
                        if link then
                            isBOE = ns.IsItemBOE(link)
                        end
                    end
                    
                    local shouldInclude = false
                    if RLC.selectionMode == ns.CONSTANTS.MODES.ASSIGN then
                        if link and not holder then shouldInclude = true end
                    elseif RLC.selectionMode == ns.CONSTANTS.MODES.UNASSIGN then
                        if link and holder == playerName then shouldInclude = true end
                    elseif RLC.selectionMode == ns.CONSTANTS.MODES.ROLL then
                        if link and not holder then shouldInclude = true end
                    end
                    
                    if shouldInclude then
                        table.insert(RLC.lootSelectionData, {
                            bossGUID = bossGUID,
                            bossName = data.name,
                            instanceName = ns.CONSTANTS.INSTANCE_ABBREVIATIONS[data.instance] or data.instance,
                            lootIndex = i,
                            link = link,
                            timestamp = data.timestamp,
                            type = itemType,
                            isBOE = isBOE
                        })
                    end
                end
            end
        end
    end
    
    table.sort(RLC.lootSelectionData, function(a, b)
        return (a.timestamp or 0) < (b.timestamp or 0)
    end)
    
    RLC:UpdateLootSelectionScroll()
    frame:Show()
end

-- ============================================================================
-- 5. 交互事件处理 (Event Handlers)
-- ============================================================================



function RLC:OnSyncClick()
    if GetNumRaidMembers() == 0 then
        print("|cffff0000[RaidLootCounter]|r " .. L["MSG_NOT_IN_RAID"])
        return
    end
    
    local addedCount, removedCount = SyncRaidMembers()
    RLC:RefreshDisplay()
    
    local msg = "|cff00ff00[RaidLootCounter]|r " .. L["MSG_SYNC_COMPLETE"]
    if addedCount > 0 then msg = msg .. ", " .. string.format(L["MSG_ADDED"], addedCount) end
    if removedCount > 0 then msg = msg .. ", " .. string.format(L["MSG_REMOVED"], removedCount) end
    print(msg)
end

function RLC:OnMinusClick(parentFrame)
    if not parentFrame or not parentFrame.playerName then return end
    RLC:ShowLootSelection(parentFrame.playerName, ns.CONSTANTS.MODES.UNASSIGN)
end

function RLC:OnPlusClick(parentFrame)
    if not parentFrame then
        print(ns.CONSTANTS.CHAT_PREFIX .. L["ERR_PARENT_FRAME_NIL"])
        return
    end
    if not parentFrame.playerName then 
        local frameName = parentFrame:GetName() or "Unknown"
        print(ns.CONSTANTS.CHAT_PREFIX .. string.format(L["ERR_PLAYERNAME_NIL"], frameName))
        return 
    end
    RLC:ShowLootSelection(parentFrame.playerName, ns.CONSTANTS.MODES.ASSIGN)
end

function RLC:OnAutoAnnounceClick(checkbox)
    if checkbox:GetChecked() then
        RaidLootCounterDB.autoAnnounce = true
        print(ns.CONSTANTS.CHAT_PREFIX .. L["AUTO_ANNOUNCE_ON"])
    else
        RaidLootCounterDB.autoAnnounce = false
        print(ns.CONSTANTS.CHAT_PREFIX .. L["AUTO_ANNOUNCE_OFF"])
    end
end

function RLC:OnStartRollCaptureClick()
    -- 检查是否已在进行 Roll 捕获
    if Roll.IsActive() then
        print(ns.CONSTANTS.CHAT_PREFIX .. (L["ROLL_CAPTURE_ALREADY_ACTIVE"] or "Roll capture is already active."))
        return
    end
    
    -- 仅负责打开选择窗口，实际 Roll 逻辑在 Roll 模块中处理
    RLC:ShowLootSelection(nil, ns.CONSTANTS.MODES.ROLL)
end

function RLC:OnStopRollCaptureClick()
    if not Roll.IsActive() then
        Roll.StopAndAnnounce()
        return
    end

    if RLC.stopRollFrame then return end

    Chat.SendRaidOrPrint(L["MSG_STOP_ROLL_COUNTDOWN"], "RAID_WARNING")
    
    RLC.stopRollFrame = CreateFrame("Frame")
    RLC.stopRollFrame.timeLeft = 3
    RLC.stopRollFrame.timeSinceLastUpdate = 0
    
    RLC.stopRollFrame:SetScript("OnUpdate", function(self, elapsed)
        if not Roll.IsActive() then
            self:SetScript("OnUpdate", nil)
            RLC.stopRollFrame = nil
            return
        end

        self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
        if self.timeSinceLastUpdate >= 1 then
            self.timeSinceLastUpdate = self.timeSinceLastUpdate - 1
            
            if self.timeLeft > 0 then
                Chat.SendRaidOrPrint(".." .. tostring(self.timeLeft) .. "..", "RAID_WARNING")
                self.timeLeft = self.timeLeft - 1
            else
                Roll.StopAndAnnounce()
                self:SetScript("OnUpdate", nil)
                RLC.stopRollFrame = nil
            end
        end
    end)
end

function RLC:OnLootSelectionRowClick(row)
    if not row or not row.data then return end
    if IsShiftKeyDown() then
        if ChatEdit_InsertLink and row.data and row.data.link then
            local _, itemLink = GetItemInfo(row.data.link)
            if itemLink then
                ChatEdit_InsertLink(itemLink)
            else
                ChatEdit_InsertLink(row.data.link)
            end
        end
        return
    end

    for _, r in pairs(lootSelectionRows) do
        if r and r.highlight then r.highlight:Hide() end
    end
    
    if row.highlight then row.highlight:Show() end
    RLC.selectedLoot = row.data
end

function RLC:OnLootSelectionRowEnter(row, anchor)
    if not row or not row.data or not row.data.link then return end
    GameTooltip:SetOwner(anchor or row, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(row.data.link)
    GameTooltip:Show()
end

function RLC:PerformAssignment(isOS)
    if not RLC.targetPlayer then return end
    
    local data = RLC.selectedLoot
    local bossData = RaidLootCounterDB.lootedBosses[data.bossGUID]
    
    if bossData and bossData.loot and bossData.loot[data.lootIndex] then
        local lootItem = LootUtil.NormalizeLootItem(bossData.loot, data.lootIndex)
        
        local playerData = RaidLootCounterDB.players[RLC.targetPlayer]
        
        lootItem.holder = RLC.targetPlayer
        lootItem.type = isOS and ns.CONSTANTS.LOOT_TYPE.OS or ns.CONSTANTS.LOOT_TYPE.MS
        
        if AddLoot(RLC.targetPlayer, isOS) then
            local newCount = isOS and playerData.osCount or playerData.msCount
            RLC:RefreshDisplay()
            RLC:SendLootUpdate(RLC.targetPlayer, newCount, true, data.link, isOS)
        end
        local suffix = isOS and " (OS)" or " (MS)"
        print(ns.CONSTANTS.CHAT_PREFIX .. L["MSG_LOOT_ASSIGNED"] .. data.link .. L["MSG_TO"] .. RLC.targetPlayer .. suffix)
        
        if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
            RLC:RefreshLootHistory()
        end
        
        RLCLootSelectionFrame:Hide()
    end
end

function RLC:OnLootSelectionSaveOSClick()
    if not RLC.selectedLoot then
        print(ns.CONSTANTS.CHAT_PREFIX .. L["MSG_SELECT_ITEM"])
        return
    end

    if RLC.selectionMode == ns.CONSTANTS.MODES.ROLL then
        local link = RLC.selectedLoot.link
        if link then
            local _, itemLink = GetItemInfo(link)
            itemLink = itemLink or link
            if Roll then
                Roll.Start(itemLink, ns.CONSTANTS.LOOT_TYPE.OS)
            end
        end
        RLCLootSelectionFrame:Hide()
    elseif RLC.selectionMode == ns.CONSTANTS.MODES.ASSIGN then
        RLC:PerformAssignment(true)
    end
end

function RLC:OnLootSelectionSaveClick()
    if not RLC.selectedLoot then
        print(ns.CONSTANTS.CHAT_PREFIX .. L["MSG_SELECT_ITEM"])
        return
    end

    -- 处理 ROLL 模式 (MS Roll)
    if RLC.selectionMode == ns.CONSTANTS.MODES.ROLL then
        local link = RLC.selectedLoot.link
        if link then
             -- 获取实际的物品链接（如果是字符串）
            local _, itemLink = GetItemInfo(link)
            itemLink = itemLink or link
            
            -- 开始监听并发送通告
            if Roll then
                Roll.Start(itemLink, ns.CONSTANTS.LOOT_TYPE.MS)
            end
        end
        RLCLootSelectionFrame:Hide()
        return
    end

    if RLC.selectionMode == ns.CONSTANTS.MODES.ASSIGN then
        RLC:PerformAssignment(false)
        return
    end

    if not RLC.targetPlayer then return end
    
    local data = RLC.selectedLoot
    local bossData = RaidLootCounterDB.lootedBosses[data.bossGUID]
    
    if bossData and bossData.loot and bossData.loot[data.lootIndex] then
        local lootItem = LootUtil.NormalizeLootItem(bossData.loot, data.lootIndex)
        local isUnassign = (RLC.selectionMode == ns.CONSTANTS.MODES.UNASSIGN)
        
        local playerData = RaidLootCounterDB.players[RLC.targetPlayer]

        if isUnassign then
            local isOS = false
            -- 尝试从记录中判断类型
            if lootItem.type == ns.CONSTANTS.LOOT_TYPE.OS then
                isOS = true
            elseif lootItem.type == ns.CONSTANTS.LOOT_TYPE.MS then
                isOS = false
            else
                -- 旧数据或未记录类型，尝试猜测
                if playerData and (playerData.osCount or 0) > 0 and (playerData.msCount or 0) == 0 then
                    isOS = true
                end
            end
            
            lootItem.holder = nil
            lootItem.type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN -- 恢复为 UNASSIGN
            
            if RemoveLoot(RLC.targetPlayer, isOS) then
                local newCount = isOS and playerData.osCount or playerData.msCount
                RLC:RefreshDisplay()
                RLC:SendLootUpdate(RLC.targetPlayer, newCount, false, data.link, isOS)
            end
            print(ns.CONSTANTS.CHAT_PREFIX .. L["MSG_LOOT_REMOVED"] .. data.link .. L["MSG_FROM"] .. RLC.targetPlayer)
        end
        
        if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
            RLC:RefreshLootHistory()
        end
        
        RLCLootSelectionFrame:Hide()
    end
end

-- ============================================================================
-- 6. 初始化 (Initialization)
-- ============================================================================

local function InitUI()
    if RaidLootCounterFrameTitle then RaidLootCounterFrameTitle:SetText(L["WINDOW_TITLE"]) end
    if RaidLootCounterFrameSyncButton then RaidLootCounterFrameSyncButton:SetText(L["SYNC_RAID"]) end
    if RaidLootCounterFrameClearButton then RaidLootCounterFrameClearButton:SetText(L["CLEAR_DATA"]) end
    if RaidLootCounterFrameSendButton then RaidLootCounterFrameSendButton:SetText(L["SEND_STATS"]) end
    if RaidLootCounterFrameViewLootButton then RaidLootCounterFrameViewLootButton:SetText(L["VIEW_LOOT"]) end
    if RaidLootCounterFrameDistroModeButton then RaidLootCounterFrameDistroModeButton:SetText(L["DISTRO_MODE"] .. ": " .. RLC.distroMode) end

    -- Distro Mode Frame
    if RLC_DistroModeFrameTitle then RLC_DistroModeFrameTitle:SetText(L["DISTRO_MODE_TITLE"]) end
    if RLC_DistroModeFrameLabel then RLC_DistroModeFrameLabel:SetText(L["DISTRO_MODE_LABEL"]) end
    if RLC_DistroModeFrameMSPlus1RadioText then RLC_DistroModeFrameMSPlus1RadioText:SetText(L["MS_PLUS_1"]) end
    if RLC_DistroModeFrameMSGTOSRadioText then RLC_DistroModeFrameMSGTOSRadioText:SetText(L["MS_GT_OS"]) end
    if RLC_DistroModeFrameSaveButton then RLC_DistroModeFrameSaveButton:SetText(L["BUTTON_SAVE"]) end
    if RaidLootCounterLootHistoryFrameTitle then RaidLootCounterLootHistoryFrameTitle:SetText(L["LOOT_HISTORY_TITLE"]) end
    if RaidLootCounterFrameAutoAnnounceCheckboxText then RaidLootCounterFrameAutoAnnounceCheckboxText:SetText(L["CHECKBOX_AUTO_ANNOUNCE"]) end
    if RaidLootCounterFrameAutoAnnounceCheckbox then RaidLootCounterFrameAutoAnnounceCheckbox:SetChecked(RaidLootCounterDB.autoAnnounce) end
    if RaidLootCounterFrameStartRollCaptureButton then RaidLootCounterFrameStartRollCaptureButton:SetText(L["START_ROLL_CAPTURE"]) end
    if RaidLootCounterFrameStopRollCaptureButton then RaidLootCounterFrameStopRollCaptureButton:SetText(L["STOP_ROLL_CAPTURE"]) end
    
    -- Manual Add Frame and Buttons
    if RaidLootCounterLootHistoryFrameManualAddButton then RaidLootCounterLootHistoryFrameManualAddButton:SetText(L["BUTTON_MANUAL_ADD"]) end
    if RLCManualAddFrameTitle then RLCManualAddFrameTitle:SetText(L["TITLE_MANUAL_ADD"]) end
    if RLCManualAddFrameSaveButton then RLCManualAddFrameSaveButton:SetText(L["BUTTON_SAVE"]) end
end

local function OnAddonLoaded(self, event, addonName)

    if addonName ~= ADDON_NAME then return end
    
    InitDB()
    InitUI()
    
    -- Add keyboard shortcuts
    RaidLootCounterFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    
    SLASH_RLC1 = "/rlc"
    SlashCmdList["RLC"] = function(msg)
        if msg == "debug" then
            if RLC.InjectMockData then
                RLC:InjectMockData()
            else
                print("|cffff0000[RaidLootCounter]|r InjectMockData not found.")
            end
            return
        elseif msg == "reset" then
            if RaidLootCounterFrame then 
                RaidLootCounterFrame:ClearAllPoints()
                RaidLootCounterFrame:SetPoint("CENTER") 
            end
            if RLCLootSelectionFrame then 
                RLCLootSelectionFrame:ClearAllPoints()
                RLCLootSelectionFrame:SetPoint("CENTER") 
            end
            if RLC_DINFrame then
                RLC_DINFrame:ClearAllPoints()
                RLC_DINFrame:SetPoint("CENTER")
            end
            print(ns.CONSTANTS.CHAT_PREFIX .. "Frames reset to center.")
            return
        end

        if RaidLootCounterFrame:IsShown() then
            RaidLootCounterFrame:Hide()
        else
            RaidLootCounterFrame:Show()
            RLC:RefreshDisplay()
        end
    end
    
    StaticPopupDialogs["RLC_CLEAR_CONFIRM"] = {
        text = L["CONFIRM_CLEAR_TEXT"],
        button1 = L["CONFIRM"],
        button2 = L["CANCEL"],
        OnAccept = function()
            ClearAllData()
            RLC:RefreshDisplay()
            -- Also refresh loot history if it's open
            if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
                RLC:RefreshLootHistory()
            end
            print("|cff00ff00[RaidLootCounter]|r " .. L["MSG_DATA_CLEARED"])
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    print(ns.CONSTANTS.CHAT_PREFIX .. L["MSG_LOADED"])
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then OnAddonLoaded(self, event, ...) end
end)
