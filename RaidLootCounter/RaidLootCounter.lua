-- 魔兽世界 3.3.5a 团队拾取计数器插件
-- RaidLootCounter.lua
-- 整理后的代码结构

local addonName, ns = ...
local L = ns.L

local ADDON_NAME = "RaidLootCounter"
RLC = {} -- 全局对象，供XML调用

-- ============================================================================
-- 1. 常量与变量 (Constants & Globals)
-- ============================================================================

local CLASS_COLORS = ns.CONSTANTS.CLASS_COLORS
local ENGLISH_CLASS_NAMES = ns.CONSTANTS.ENGLISH_CLASS_NAMES

-- 工具函数：检查物品是否为装备绑定 (BOE)
local tooltipScanner
function ns.IsItemBOE(itemLink)
    if not itemLink then return false end
    
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
                return true
            end
        end
    end
    
    return false
end

-- 工具函数：获取物品的 Tier 等级 (T7, T8, T9, T10)
function ns.GetItemTier(itemLink)
    if not itemLink then return nil end
    
    local itemName = GetItemInfo(itemLink)
    if not itemName then 
        -- Fallback to extracting name from link if not cached
        itemName = string.match(itemLink, "%[([^%]]+)%]")
    end
    
    if not itemName then return nil end

    -- 1. Check for Token Patterns
    for tier, patterns in pairs(ns.CONSTANTS.TIER_PATTERNS) do
        for _, pattern in ipairs(patterns) do
            if string.find(itemName, pattern) then
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
                -- Try to extract Set Name
                -- Pattern: "Name (x/y)"
                local setName = string.match(text, "^(.+) %([%d]+/[%d]+%)$")
                if setName then
                    -- Check if Set Name contains any of our known keys
                    for key, tier in pairs(ns.CONSTANTS.TIER_SETS) do
                        if string.find(setName, key) then
                            return tier
                        end
                    end
                end
            end
        end
    end

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
RLC.selectionMode = "ASSIGN" -- "ASSIGN", "UNASSIGN", "ROLL"

-- ============================================================================
-- 2. 数据管理 (Data Management)
-- ============================================================================

-- 初始化数据库
local function InitDB()
    if not RaidLootCounterDB then
        RaidLootCounterDB = {}
    end
    
    if RaidLootCounterDB.autoAnnounce == nil then
        RaidLootCounterDB.autoAnnounce = true
    end
    
    if not RaidLootCounterDB.lootedBosses then
        RaidLootCounterDB.lootedBosses = {}
    end
    
    if not RaidLootCounterDB.players then
        RaidLootCounterDB.players = {}
        
        -- 数据迁移逻辑
        local keysToRemove = {}
        for key, value in pairs(RaidLootCounterDB) do
            if key ~= "autoAnnounce" and key ~= "lootedBosses" and key ~= "players" then
                if type(value) == "table" and (value.class or value.count) then
                    RaidLootCounterDB.players[key] = value
                    table.insert(keysToRemove, key)
                end
            end
        end
        for _, key in ipairs(keysToRemove) do
            RaidLootCounterDB[key] = nil
        end
    end
end

-- 清空所有数据
local function ClearAllData()
    RaidLootCounterDB.players = {}
    RaidLootCounterDB.lootedBosses = {}
    
    -- 重置Mock数据状态
    if RLC.ResetMockData then
        RLC:ResetMockData()
    end
end

-- 检查数据库是否为空
local function IsDBEmpty()
    if not RaidLootCounterDB.players then return true end
    return next(RaidLootCounterDB.players) == nil
end

-- 获取团队成员信息 (按职业分组)
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

-- 获取玩家持有的装备列表
local function GetPlayerItems(playerName)
    local items = {}
    if RaidLootCounterDB.lootedBosses then
        for bossGUID, data in pairs(RaidLootCounterDB.lootedBosses) do
            if data.loot then
                for _, itemData in ipairs(data.loot) do
                    local link, holder, itemType
                    if type(itemData) == "table" then
                        link = itemData.link
                        holder = itemData.holder
                        itemType = itemData.type
                    else
                        -- 兼容旧格式
                        link = itemData
                        holder = nil 
                        itemType = "MS"
                    end
                    
                    if holder == playerName and link then
                        table.insert(items, {link = link, type = itemType or "MS"})
                    end
                end
            end
        end
    end
    
    table.sort(items, function(a, b)
        local isAMS = (a.type == "MS")
        local isBMS = (b.type == "MS")
        if isAMS and not isBMS then return true end
        if not isAMS and isBMS then return false end
        return false 
    end)
    
    return items
end

-- 同步团队成员
local function SyncRaidMembers()
    local raidMembers = GetRaidMembers()
    local currentRaidNames = {}
    local addedCount = 0
    local removedCount = 0
    
    if not RaidLootCounterDB.players then RaidLootCounterDB.players = {} end
    
    -- 添加新成员
    for className, players in pairs(raidMembers) do
        for _, player in ipairs(players) do
            currentRaidNames[player.name] = true
            
            if not RaidLootCounterDB.players[player.name] then
                RaidLootCounterDB.players[player.name] = {
                    msCount = 0,
                    osCount = 0,
                    class = className
                }
                addedCount = addedCount + 1
            else
                RaidLootCounterDB.players[player.name].class = className
                -- Data migration for existing players if needed
                if RaidLootCounterDB.players[player.name].msCount == nil then
                    RaidLootCounterDB.players[player.name].msCount = RaidLootCounterDB.players[player.name].count or 0
                    RaidLootCounterDB.players[player.name].osCount = 0
                    RaidLootCounterDB.players[player.name].count = nil -- Remove old field
                end
            end
        end
    end
    
    -- 移除不在团队的成员
    for name in pairs(RaidLootCounterDB.players) do
        if not currentRaidNames[name] then
            RaidLootCounterDB.players[name] = nil
            removedCount = removedCount + 1
        end
    end
    
    return addedCount, removedCount
end

-- 增加拾取计数
local function AddLoot(playerName, isOS)
    if not playerName or playerName == "" then return false end
    if not RaidLootCounterDB.players then return false end

    if RaidLootCounterDB.players[playerName] then
        if isOS then
            RaidLootCounterDB.players[playerName].osCount = (RaidLootCounterDB.players[playerName].osCount or 0) + 1
        else
            RaidLootCounterDB.players[playerName].msCount = (RaidLootCounterDB.players[playerName].msCount or 0) + 1
        end
        return true
    end
    return false
end

-- 减少拾取计数
local function RemoveLoot(playerName, isOS)
    if not playerName or playerName == "" then return false end
    if not RaidLootCounterDB.players then return false end

    if RaidLootCounterDB.players[playerName] then
        if isOS then
            local currentCount = RaidLootCounterDB.players[playerName].osCount or 0
            RaidLootCounterDB.players[playerName].osCount = math.max(0, currentCount - 1)
        else
            local currentCount = RaidLootCounterDB.players[playerName].msCount or 0
            RaidLootCounterDB.players[playerName].msCount = math.max(0, currentCount - 1)
        end
        return true
    end
    return false
end

-- ============================================================================
-- 3. 核心逻辑与通报 (Logic & Reporting)
-- ============================================================================

-- 通报消息 (团队/打印)
local function Announce(msg)
    if GetNumRaidMembers() > 0 then
        SendChatMessage(msg, "RAID_WARNING")
    else
        print(msg)
    end
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
    SendChatMessage(msg, "RAID_WARNING")
    
    -- 获取玩家最新数据
    local playerData = RaidLootCounterDB.players[playerName]
    local msCount = playerData and playerData.msCount or 0
    local osCount = playerData and playerData.osCount or 0
    
    -- 2. 发送 Total 信息
    local totalMsg = "Total: MS " .. msCount
    SendChatMessage(totalMsg, "RAID_WARNING")
    
    -- 3. 发送 MS 和 OS 装备列表
    local items = GetPlayerItems(playerName)
    local msItems = {}
    local osItems = {}
    
    for _, item in ipairs(items) do
        if item.type == "OS" then
            table.insert(osItems, item.link)
        else
            table.insert(msItems, item.link)
        end
    end
    
    local function SendList(prefix, list)
        if #list == 0 then return end
        local currentMsg = prefix
        for _, link in ipairs(list) do
            local itemStr = " " .. link
            if string.len(currentMsg) + string.len(itemStr) > 250 then
                SendChatMessage(currentMsg, "RAID_WARNING")
                currentMsg = "  " .. link -- 继续下一行，缩进
            else
                currentMsg = currentMsg .. itemStr
            end
        end
        SendChatMessage(currentMsg, "RAID_WARNING")
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
            local class = data.class or "WARRIOR"
            if not dataByClass[class] then dataByClass[class] = {} end
            table.insert(dataByClass[class], {
                name = playerName,
                msCount = data.msCount or 0,
                osCount = data.osCount or 0
            })
        end
    end
    
    SendChatMessage("=== Raid Loot Counter ===", "RAID_WARNING")
    
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
        SendChatMessage("[" .. displayClass .. "]", "RAID_WARNING")
        
        for _, player in ipairs(players) do
            local msg = player.name .. ": MS:" .. player.msCount
            SendChatMessage(msg, "RAID_WARNING")
            
            local items = GetPlayerItems(player.name)
            if #items > 0 then
                local currentLine = "  "
                for i, item in ipairs(items) do
                    local itemStr = item.link .. (item.type == "OS" and "(OS)" or "(MS)")
                    if string.len(currentLine) + string.len(itemStr) > 250 then
                        SendChatMessage(currentLine, "RAID_WARNING")
                        currentLine = "  " .. itemStr
                    else
                        currentLine = currentLine .. itemStr .. " "
                    end
                end
                if currentLine ~= "  " then
                    SendChatMessage(currentLine, "RAID_WARNING")
                end
            end
        end
        SendChatMessage(" ", "RAID_WARNING")
    end
    
    SendChatMessage("=======================================", "RAID_WARNING")
    print(ns.CONSTANTS.CHAT_PREFIX .. L["MSG_STATS_SENT"])
end

-- 处理 Roll 点消息
function RLC:ProcessRollMessage(message)
    local pattern = L["ROLL_PATTERN"] or "(.+) rolls (%d+) %((%d+)-(%d+)%)"
    local playerName, rollValue, minValue, maxValue = string.match(message, pattern)

    if playerName and rollValue and minValue and maxValue then
        playerName = string.match(playerName, "^%s*(.-)%s*$")
        
        local numRaidMembers = GetNumRaidMembers()
        local isRaidMember = false
        
        if numRaidMembers > 0 then
            for i = 1, numRaidMembers do
                local raidName = GetRaidRosterInfo(i)
                if raidName then
                    local cleanRaidName = string.match(raidName, "^([^-]+)")
                    if cleanRaidName == playerName or raidName == playerName then
                        isRaidMember = true
                        break
                    end
                end
            end
        else
            local numPartyMembers = GetNumPartyMembers()
            if numPartyMembers > 0 then
                local myName = UnitName("player")
                if myName == playerName then isRaidMember = true else
                    for i = 1, numPartyMembers do
                        if UnitName("party"..i) == playerName then isRaidMember = true break end
                    end
                end
            else
                if UnitName("player") == playerName then isRaidMember = true end
            end
        end
        
        if isRaidMember then
            local hasRolled = false
            for _, result in ipairs(rollResults) do
                if result.player == playerName then hasRolled = true break end
            end

            if not hasRolled then
                table.insert(rollResults, {
                    player = playerName,
                    roll = tonumber(rollValue),
                    min = tonumber(minValue),
                    max = tonumber(maxValue),
                    timestamp = time()
                })
                print(string.format("|cff00ff00[RaidLootCounter]|r 捕获: %s 掷出 %s (%s-%s)", 
                    playerName, rollValue, minValue, maxValue))
            end
        end
    end
end

-- 开始 Roll 点捕获 (逻辑部分)
function RLC:StartRollCapture(itemLink, rollType)
    if isRollCapturing then return end
    
    rollResults = {}
    isRollCapturing = true
    RLC.currentRollType = rollType or "MS"
    
    if not rollCaptureFrame then rollCaptureFrame = CreateFrame("Frame") end
    rollCaptureFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    rollCaptureFrame:SetScript("OnEvent", function(self, event, message)
        if event == "CHAT_MSG_SYSTEM" and isRollCapturing then
            RLC:ProcessRollMessage(message)
        end
    end)
    
    print(ns.CONSTANTS.CHAT_PREFIX .. L["ROLL_CAPTURE_STARTED"] .. " (" .. (rollType or "MS") .. ")")
    if itemLink then
        local prefix = (rollType == "OS") and "OS Roll " or "MS Roll "
        SendChatMessage(prefix .. itemLink, "RAID_WARNING")
    end
end

-- 显示 Roll 点结果
function RLC:DisplayRollResults()
    if #rollResults == 0 then
        print(ns.CONSTANTS.CHAT_PREFIX .. L["ROLL_NO_RESULTS"])
        return
    end
    
    for _, result in ipairs(rollResults) do
        local dbData = RaidLootCounterDB.players and RaidLootCounterDB.players[result.player]
        result.msCount = (dbData and dbData.msCount) or 0
        result.osCount = (dbData and dbData.osCount) or 0
        result.class = (dbData and dbData.class)
        
        if not result.class and GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do
                local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
                if name == result.player then
                    result.class = fileName
                    break
                end
            end
        end
    end

    local isOSRoll = (RLC.currentRollType == "OS")
    
    table.sort(rollResults, function(a, b)
        if isOSRoll then
            -- OS Roll: Just Roll DESC (Ignore OS Count)
            return a.roll > b.roll
        else
            -- MS Roll: MS Count ASC -> Roll DESC
            if a.msCount ~= b.msCount then
                return a.msCount < b.msCount
            end
            return a.roll > b.roll
        end
    end)
    
    local rollTypeStr = isOSRoll and "OS" or "MS"
    Announce("=== Raid Loot Counter " .. rollTypeStr .. " Roll Results === (" .. #rollResults .. " rolls)")
    
    for i, result in ipairs(rollResults) do
        local msg = string.format("%d. %s: %d (%d-%d) [MS: %d]", 
            i, result.player, result.roll, result.min, result.max, result.msCount)
        Announce(msg)
    end
    
    if #rollResults > 0 then
        local winners = {}
        local first = rollResults[1]
        
        local function GetWinnerString(res)
            local className = res.class or "Unknown"
            local displayClass = ns.CONSTANTS.ENGLISH_CLASS_NAMES[className] or className
            return string.format("%s {%s} (%d (%d-%d)  MS: %d)", res.player, displayClass, res.roll, res.min, res.max, res.msCount)
        end
        
        table.insert(winners, GetWinnerString(first))
        
        for i = 2, #rollResults do
            local current = rollResults[i]
            local isTie = false
            if isOSRoll then
                 if current.roll == first.roll then isTie = true end
            else
                 if current.roll == first.roll and current.msCount == first.msCount then isTie = true end
            end
            
            if isTie then
                table.insert(winners, GetWinnerString(current))
            else
                break
            end
        end
        
        Announce("Winner (" .. rollTypeStr .. "): " .. table.concat(winners, ", "))
    end
end

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
            local class = data.class or "WARRIOR"
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
    -- 12 visible rows (approx 300 height / 25)
    FauxScrollFrame_Update(scrollFrame, numRows, 12, 25)
    
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    HideAllLootSelectionRows()
    
    local parent = RLCLootSelectionFrame
    local yPos = -50
    
    for i = 1, 12 do
        local dataIndex = offset + i
        if dataIndex > numRows then break end
        
        local item = RLC.lootSelectionData[dataIndex]
        local row = GetLootSelectionRow(parent, i)
        row:SetPoint("TOPLEFT", 20, yPos)
        
        local displayText = ""
        local tier = ns.GetItemTier(item.link)
        if tier then
            displayText = "|cffffd100[" .. tier .. "]|r "
        end
        
        if item.isBOE then
            displayText = displayText .. "|cff00ccff[BOE]|r "
        end
        
        displayText = displayText .. item.link
        if RLC.selectionMode == "UNASSIGN" then
             local typeStr = item.type or "UNASSIGN"
             displayText = displayText .. "  " .. ns.CONSTANTS.COLORS.GRAY .. "(" .. typeStr .. ")|r"
        end
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

        yPos = yPos - 25
    end
end

function RLC:ShowLootSelection(playerName, mode)
    RLC.targetPlayer = playerName
    RLC.selectionMode = mode or "ASSIGN"
    RLC.selectedLoot = nil
    
    local frame = RLCLootSelectionFrame
    if not frame then 
        print(ns.CONSTANTS.CHAT_PREFIX .. "Error: RLCLootSelectionFrame not found")
        return 
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    
    local title = _G[frame:GetName().."Title"]
    local saveButton = _G[frame:GetName().."SaveButton"]
    local saveOSButton = _G[frame:GetName().."SaveOSButton"]
    
    if title then 
        if RLC.selectionMode == "UNASSIGN" then
            title:SetText(L["TITLE_REMOVE_LOOT"] .. (playerName or "?"))
        elseif RLC.selectionMode == "ROLL" then
            title:SetText(L["TITLE_ROLL_LOOT"])
        else
            title:SetText(L["TITLE_ASSIGN_LOOT"] .. (playerName or "?")) 
        end
    end
    
    -- 按钮状态调整
    if saveButton and saveOSButton then
        if RLC.selectionMode == "ROLL" then
            saveButton:SetText("MS Roll")
            saveButton:ClearAllPoints()
            saveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -10, 20)
            
            saveOSButton:Show()
            saveOSButton:SetText("OS Roll")
            saveOSButton:ClearAllPoints()
            saveOSButton:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 10, 20)
        elseif RLC.selectionMode == "ASSIGN" then
            saveButton:SetText("MS Save")
            saveButton:ClearAllPoints()
            saveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -10, 20)
            
            saveOSButton:Show()
            saveOSButton:SetText("OS Save")
            saveOSButton:ClearAllPoints()
            saveOSButton:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 10, 20)
        else
            saveButton:SetText("Remove")
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
                    if RLC.selectionMode == "ASSIGN" then
                        if link and not holder then shouldInclude = true end
                    elseif RLC.selectionMode == "UNASSIGN" then
                        if link and holder == playerName then shouldInclude = true end
                    elseif RLC.selectionMode == "ROLL" then
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
    RLC:ShowLootSelection(parentFrame.playerName, "UNASSIGN")
end

function RLC:OnPlusClick(parentFrame)
    if not parentFrame then
        print(ns.CONSTANTS.CHAT_PREFIX .. "Error: Parent frame is nil")
        return
    end
    if not parentFrame.playerName then 
        print(ns.CONSTANTS.CHAT_PREFIX .. "Error: PlayerName is nil on frame " .. (parentFrame:GetName() or "Unknown"))
        return 
    end
    RLC:ShowLootSelection(parentFrame.playerName, "ASSIGN")
end

function RLC:OnAutoAnnounceClick(checkbox)
    if checkbox:GetChecked() then
        RaidLootCounterDB.autoAnnounce = true
        print(ns.CONSTANTS.CHAT_PREFIX .. "自动通报: " .. ns.CONSTANTS.COLORS.GREEN .. "已开启|r")
    else
        RaidLootCounterDB.autoAnnounce = false
        print(ns.CONSTANTS.CHAT_PREFIX .. "自动通报: " .. ns.CONSTANTS.COLORS.RED .. "已关闭|r")
    end
end

function RLC:OnStartRollCaptureClick()
    if isRollCapturing then
        print("|cffff0000[RaidLootCounter]|r " .. L["ROLL_CAPTURE_ALREADY_ACTIVE"])
        return
    end
    
    -- 打开装备选择浮窗，模式为 ROLL
    RLC:ShowLootSelection(nil, "ROLL")
end

function RLC:OnStopRollCaptureClick()
    if not isRollCapturing then
        print("|cffff0000[RaidLootCounter]|r " .. L["ROLL_CAPTURE_NOT_ACTIVE"])
        return
    end
    
    isRollCapturing = false
    if rollCaptureFrame then rollCaptureFrame:UnregisterEvent("CHAT_MSG_SYSTEM") end
    
    RLC:DisplayRollResults()
    print("|cff00ff00[RaidLootCounter]|r " .. L["ROLL_CAPTURE_STOPPED"])
end

function RLC:OnViewLootClick()
    if RaidLootCounterLootHistoryFrame:IsShown() then
        RaidLootCounterLootHistoryFrame:Hide()
    else
        RaidLootCounterLootHistoryFrame:Show()
        RLC:RefreshLootHistory()
    end
end

function RLC:OnLootSelectionRowClick(row)
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
        if r.highlight then r.highlight:Hide() end
    end
    
    if row.highlight then row.highlight:Show() end
    RLC.selectedLoot = row.data
end

function RLC:OnLootSelectionRowEnter(row)
    if not row or not row.data or not row.data.link then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(row.data.link)
    GameTooltip:Show()
end

function RLC:PerformAssignment(isOS)
    if not RLC.targetPlayer then return end
    
    local data = RLC.selectedLoot
    local bossData = RaidLootCounterDB.lootedBosses[data.bossGUID]
    
    if bossData and bossData.loot and bossData.loot[data.lootIndex] then
        local lootItem = bossData.loot[data.lootIndex]
        
        if type(lootItem) ~= "table" then
             bossData.loot[data.lootIndex] = { link = lootItem, holder = nil }
             lootItem = bossData.loot[data.lootIndex]
        end
        
        local playerData = RaidLootCounterDB.players[RLC.targetPlayer]
        
        lootItem.holder = RLC.targetPlayer
        lootItem.type = isOS and "OS" or "MS"
        
        if AddLoot(RLC.targetPlayer, isOS) then
            local newCount = isOS and playerData.osCount or playerData.msCount
            RLC:RefreshDisplay()
            RLC:SendLootUpdate(RLC.targetPlayer, newCount, true, data.link, isOS)
        end
        print(ns.CONSTANTS.CHAT_PREFIX .. "已分配 " .. data.link .. " 给 " .. RLC.targetPlayer .. (isOS and " (OS)" or " (MS)"))
        
        if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
            RLC:RefreshLootHistory()
        end
        
        RLCLootSelectionFrame:Hide()
    end
end

function RLC:OnLootSelectionSaveOSClick()
    if not RLC.selectedLoot then
        print(ns.CONSTANTS.CHAT_PREFIX .. "请选择一件装备。")
        return
    end

    if RLC.selectionMode == "ROLL" then
        local link = RLC.selectedLoot.link
        if link then
            local _, itemLink = GetItemInfo(link)
            itemLink = itemLink or link
            RLC:StartRollCapture(itemLink, "OS")
        end
        RLCLootSelectionFrame:Hide()
    elseif RLC.selectionMode == "ASSIGN" then
        RLC:PerformAssignment(true)
    end
end

function RLC:OnLootSelectionSaveClick()
    if not RLC.selectedLoot then
        print(ns.CONSTANTS.CHAT_PREFIX .. "请选择一件装备。")
        return
    end

    -- 处理 ROLL 模式 (MS Roll)
    if RLC.selectionMode == "ROLL" then
        local link = RLC.selectedLoot.link
        if link then
             -- 获取实际的物品链接（如果是字符串）
            local _, itemLink = GetItemInfo(link)
            itemLink = itemLink or link
            
            -- 开始监听并发送通告
            RLC:StartRollCapture(itemLink, "MS")
        end
        RLCLootSelectionFrame:Hide()
        return
    end

    if RLC.selectionMode == "ASSIGN" then
        RLC:PerformAssignment(false)
        return
    end

    if not RLC.targetPlayer then return end
    
    local data = RLC.selectedLoot
    local bossData = RaidLootCounterDB.lootedBosses[data.bossGUID]
    
    if bossData and bossData.loot and bossData.loot[data.lootIndex] then
        local lootItem = bossData.loot[data.lootIndex]
        local isUnassign = (RLC.selectionMode == "UNASSIGN")
        
        -- 确保数据格式为表
        if type(lootItem) ~= "table" then
             bossData.loot[data.lootIndex] = { link = lootItem, holder = nil }
             lootItem = bossData.loot[data.lootIndex]
        end
        
        local playerData = RaidLootCounterDB.players[RLC.targetPlayer]

        if isUnassign then
            local isOS = false
            -- 尝试从记录中判断类型
            if lootItem.type == "OS" then
                isOS = true
            elseif lootItem.type == "MS" then
                isOS = false
            else
                -- 旧数据或未记录类型，尝试猜测
                if playerData and (playerData.osCount or 0) > 0 and (playerData.msCount or 0) == 0 then
                    isOS = true
                end
            end
            
            lootItem.holder = nil
            lootItem.type = "UNASSIGN" -- 恢复为 UNASSIGN
            
            if RemoveLoot(RLC.targetPlayer, isOS) then
                local newCount = isOS and playerData.osCount or playerData.msCount
                RLC:RefreshDisplay()
                RLC:SendLootUpdate(RLC.targetPlayer, newCount, false, data.link, isOS)
            end
            print(ns.CONSTANTS.CHAT_PREFIX .. "已移除 " .. data.link .. " from " .. RLC.targetPlayer)
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
    if RaidLootCounterLootHistoryFrameTitle then RaidLootCounterLootHistoryFrameTitle:SetText(L["LOOT_HISTORY_TITLE"]) end
    if RaidLootCounterFrameAutoAnnounceCheckboxText then RaidLootCounterFrameAutoAnnounceCheckboxText:SetText(L["CHECKBOX_AUTO_ANNOUNCE"]) end
    if RaidLootCounterFrameAutoAnnounceCheckbox then RaidLootCounterFrameAutoAnnounceCheckbox:SetChecked(RaidLootCounterDB.autoAnnounce) end
    if RaidLootCounterFrameStartRollCaptureButton then RaidLootCounterFrameStartRollCaptureButton:SetText(L["START_ROLL_CAPTURE"]) end
    if RaidLootCounterFrameStopRollCaptureButton then RaidLootCounterFrameStopRollCaptureButton:SetText(L["STOP_ROLL_CAPTURE"]) end
end

local function OnAddonLoaded(self, event, addonName)
    if addonName ~= ADDON_NAME then return end
    
    InitDB()
    InitUI()
    
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
