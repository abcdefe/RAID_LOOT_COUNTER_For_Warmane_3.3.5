-- 魔兽世界 3.3.5a 团队拾取计数器插件
-- RaidLootCounter.lua
-- 整理后的代码结构

local addonName, ns = ...
local L = ns.L

local ADDON_NAME = "RaidLootCounter"
RLC = {} -- 全局对象，供XML调用

-- ============================================================================
-- 1. 常量与配置
-- ============================================================================

-- 职业颜色配置
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

-- 英文职业名称 (用于团队通报)
local ENGLISH_CLASS_NAMES = {
    ["WARRIOR"] = "Warrior",
    ["PALADIN"] = "Paladin",
    ["HUNTER"] = "Hunter",
    ["ROGUE"] = "Rogue",
    ["PRIEST"] = "Priest",
    ["DEATHKNIGHT"] = "Death Knight",
    ["SHAMAN"] = "Shaman",
    ["MAGE"] = "Mage",
    ["WARLOCK"] = "Warlock",
    ["DRUID"] = "Druid",
}

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
RLC.selectionMode = "ASSIGN" -- "ASSIGN" or "UNASSIGN"

-- ============================================================================
-- 2. 数据库管理
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

-- ============================================================================
-- 3. 基础工具函数
-- ============================================================================

-- 通报消息 (团队/打印)
local function Announce(msg)
    if GetNumRaidMembers() > 0 then
        SendChatMessage(msg, "RAID_WARNING")
    else
        print(msg)
    end
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
                    local link, holder
                    if type(itemData) == "table" then
                        link = itemData.link
                        holder = itemData.holder
                    else
                        -- 兼容旧格式
                        link = itemData
                        holder = nil 
                    end
                    
                    if holder == playerName and link then
                        table.insert(items, link)
                    end
                end
            end
        end
    end
    return items
end

-- ============================================================================
-- 4. 核心逻辑 (数据操作)
-- ============================================================================

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
                    count = 0,
                    class = className
                }
                addedCount = addedCount + 1
            else
                RaidLootCounterDB.players[player.name].class = className
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
local function AddLoot(playerName)
    if not playerName or playerName == "" then return false end
    if not RaidLootCounterDB.players then return false end

    if RaidLootCounterDB.players[playerName] then
        RaidLootCounterDB.players[playerName].count = RaidLootCounterDB.players[playerName].count + 1
        return true
    end
    return false
end

-- 减少拾取计数
local function RemoveLoot(playerName)
    if not playerName or playerName == "" then return false end
    if not RaidLootCounterDB.players then return false end

    if RaidLootCounterDB.players[playerName] then
        local currentCount = RaidLootCounterDB.players[playerName].count
        RaidLootCounterDB.players[playerName].count = math.max(0, currentCount - 1)
        return true
    end
    return false
end

-- ============================================================================
-- 5. 聊天与通报逻辑
-- ============================================================================

-- 发送单个玩家的拾取更新
function RLC:SendLootUpdate(playerName, newCount, isAdd, itemLink)
    if not RaidLootCounterDB.autoAnnounce then return end
    
    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers == 0 then return end
    
    local action = isAdd and "Add" or "Remove"
    local itemPart = itemLink and (" " .. itemLink) or " 1"
    
    local msg = playerName .. " - " .. action .. itemPart .. " - Total: " .. newCount
    
    local items = GetPlayerItems(playerName)
    if #items > 0 then
        msg = msg .. " "
        for _, link in ipairs(items) do
            if string.len(msg) + string.len(link) > 250 then
                SendChatMessage(msg, "RAID_WARNING")
                msg = "  " .. link
            else
                msg = msg .. link .. " "
            end
        end
    end
    
    SendChatMessage(msg, "RAID_WARNING")
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
                count = data.count or 0
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
            if a.count == b.count then return a.name < b.name end
            return a.count > b.count
        end)
        
        local displayClass = ENGLISH_CLASS_NAMES[class] or class
        SendChatMessage("[" .. displayClass .. "]", "RAID_WARNING")
        
        for _, player in ipairs(players) do
            local msg = player.name .. ": " .. player.count .. " Items"
            SendChatMessage(msg, "RAID_WARNING")
            
            local items = GetPlayerItems(player.name)
            if #items > 0 then
                local currentLine = "  "
                for i, link in ipairs(items) do
                    if string.len(currentLine) + string.len(link) > 250 then
                        SendChatMessage(currentLine, "RAID_WARNING")
                        currentLine = "  " .. link
                    else
                        currentLine = currentLine .. link .. " "
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
    print("|cff00ff00[RaidLootCounter]|r " .. L["MSG_STATS_SENT"])
end

-- ============================================================================
-- 6. UI逻辑 - 主窗口
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
                count = data.count or 0,
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
            local playerCount = player.count
            
            frameIndex = frameIndex + 1
            local playerFrame = GetPlayerFrame(scrollChild, frameIndex)
            playerFrame:SetPoint("TOPLEFT", xPos, yPos)
            playerFrame.playerName = playerName
            
            playerFrame.nameText:SetTextColor(color.r, color.g, color.b)
            playerFrame.nameText:SetText(playerName)
            playerFrame.countText:SetText(L["LOOTED_PREFIX"] .. playerCount)
            
            yPos = yPos - 35
        end
        
        yPos = yPos - 10
        if isLeft then yOffsetLeft = yPos else yOffsetRight = yPos end
    end
    
    scrollChild:SetHeight(math.max(1, math.max(math.abs(yOffsetLeft), math.abs(yOffsetRight)) + 20))
end

-- ============================================================================
-- 7. UI逻辑 - 装备分配/移除
-- ============================================================================

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

function RLC:ShowLootSelection(playerName, mode)
    RLC.targetPlayer = playerName
    RLC.selectionMode = mode or "ASSIGN"
    RLC.selectedLoot = nil
    
    local frame = RLCLootSelectionFrame
    if not frame then return end
    
    local scrollChild = RLCLootSelectionScrollChild
    if not scrollChild then return end
    
    local title = _G[frame:GetName().."Title"]
    if title then 
        if RLC.selectionMode == "UNASSIGN" then
            title:SetText("移除装备: " .. playerName)
        else
            title:SetText("分配装备: " .. playerName) 
        end
    end
    
    HideAllLootSelectionRows()
    
    local displayLoot = {}
    if RaidLootCounterDB.lootedBosses then
        for bossGUID, data in pairs(RaidLootCounterDB.lootedBosses) do
            if data.loot then
                for i, itemData in ipairs(data.loot) do
                    local link, holder
                    if type(itemData) == "table" then
                        link = itemData.link
                        holder = itemData.holder
                    else
                        link = itemData
                        holder = nil
                    end
                    
                    local shouldInclude = false
                    if RLC.selectionMode == "ASSIGN" then
                        if link and not holder then shouldInclude = true end
                    elseif RLC.selectionMode == "UNASSIGN" then
                        if link and holder == playerName then shouldInclude = true end
                    end
                    
                    if shouldInclude then
                        table.insert(displayLoot, {
                            bossGUID = bossGUID,
                            bossName = data.name,
                            lootIndex = i,
                            link = link,
                            timestamp = data.timestamp
                        })
                    end
                end
            end
        end
    end
    
    table.sort(displayLoot, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
    
    local yPos = -5
    for i, item in ipairs(displayLoot) do
        local row = GetLootSelectionRow(scrollChild, i)
        row:SetPoint("TOPLEFT", 5, yPos)
        row.itemText:SetText(item.link)
        row.bossText:SetText(item.bossName)
        row.data = item
        yPos = yPos - 25
    end
    
    scrollChild:SetHeight(math.abs(yPos) + 10)
    frame:Show()
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

function RLC:OnLootSelectionSaveClick()
    if not RLC.targetPlayer then return end
    if not RLC.selectedLoot then
        print("|cffff0000[RaidLootCounter]|r 请选择一件装备。")
        return
    end
    
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
        
        if isUnassign then
            lootItem.holder = nil
            if RemoveLoot(RLC.targetPlayer) then
                local newCount = RaidLootCounterDB.players[RLC.targetPlayer].count
                RLC:RefreshDisplay()
                RLC:SendLootUpdate(RLC.targetPlayer, newCount, false, data.link)
            end
            print("|cff00ff00[RaidLootCounter]|r 已移除 " .. data.link .. " from " .. RLC.targetPlayer)
        else
            lootItem.holder = RLC.targetPlayer
            if AddLoot(RLC.targetPlayer) then
                local newCount = RaidLootCounterDB.players[RLC.targetPlayer].count
                RLC:RefreshDisplay()
                RLC:SendLootUpdate(RLC.targetPlayer, newCount, true, data.link)
            end
            print("|cff00ff00[RaidLootCounter]|r 已分配 " .. data.link .. " 给 " .. RLC.targetPlayer)
        end
        
        if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
            RLC:RefreshLootHistory()
        end
        
        RLCLootSelectionFrame:Hide()
    end
end

-- ============================================================================
-- 8. Roll点捕获功能
-- ============================================================================

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

function RLC:DisplayRollResults()
    if #rollResults == 0 then
        print("|cffff0000[RaidLootCounter]|r " .. L["ROLL_NO_RESULTS"])
        return
    end
    
    for _, result in ipairs(rollResults) do
        local dbData = RaidLootCounterDB.players and RaidLootCounterDB.players[result.player]
        result.lootCount = (dbData and dbData.count) or 0
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

    table.sort(rollResults, function(a, b)
        if a.lootCount ~= b.lootCount then
            return a.lootCount < b.lootCount
        end
        return a.roll > b.roll
    end)
    
    Announce("=== Raid Loot Counter Roll Results === (" .. #rollResults .. " rolls)")
    
    for i, result in ipairs(rollResults) do
        local msg = string.format("%d. %s: %d (%d-%d) [Looted: %d]", 
            i, result.player, result.roll, result.min, result.max, result.lootCount)
        Announce(msg)
    end
    
    if #rollResults > 0 then
        local winners = {}
        local first = rollResults[1]
        
        local function GetWinnerString(res)
            local className = res.class or "Unknown"
            local displayClass = ENGLISH_CLASS_NAMES[className] or className
            return string.format("%s {%s} (%d (%d-%d)  Looted: %d)", res.player, displayClass, res.roll, res.min, res.max, res.lootCount)
        end
        
        table.insert(winners, GetWinnerString(first))
        
        for i = 2, #rollResults do
            local current = rollResults[i]
            if current.roll == first.roll and current.lootCount == first.lootCount then
                table.insert(winners, GetWinnerString(current))
            else
                break
            end
        end
        
        Announce("Winner: " .. table.concat(winners, ", "))
    end
end

-- ============================================================================
-- 9. 界面交互回调 (XML Binding)
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
    if not parentFrame or not parentFrame.playerName then return end
    RLC:ShowLootSelection(parentFrame.playerName, "ASSIGN")
end

function RLC:OnAutoAnnounceClick(checkbox)
    if checkbox:GetChecked() then
        RaidLootCounterDB.autoAnnounce = true
        print("|cff00ff00[RaidLootCounter]|r 自动通报: |cff00ff00已开启|r")
    else
        RaidLootCounterDB.autoAnnounce = false
        print("|cff00ff00[RaidLootCounter]|r 自动通报: |cffff0000已关闭|r")
    end
end

function RLC:OnStartRollCaptureClick()
    if isRollCapturing then
        print("|cffff0000[RaidLootCounter]|r " .. L["ROLL_CAPTURE_ALREADY_ACTIVE"])
        return
    end
    
    rollResults = {}
    isRollCapturing = true
    
    if not rollCaptureFrame then rollCaptureFrame = CreateFrame("Frame") end
    rollCaptureFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    rollCaptureFrame:SetScript("OnEvent", function(self, event, message)
        if event == "CHAT_MSG_SYSTEM" and isRollCapturing then
            RLC:ProcessRollMessage(message)
        end
    end)
    
    print("|cff00ff00[RaidLootCounter]|r " .. L["ROLL_CAPTURE_STARTED"])
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

-- ============================================================================
-- 10. 初始化与事件循环
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
        -- if msg == "debug" then
        --     RLC:InjectMockData()
        --     if RaidLootCounterLootHistoryFrame and not RaidLootCounterLootHistoryFrame:IsShown() then
        --         RaidLootCounterLootHistoryFrame:Show()
        --     end
        --     RLC:RefreshLootHistory()
        -- else
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
    
    print("|cff00ff00RaidLootCounter|r " .. L["MSG_LOADED"])
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then OnAddonLoaded(self, event, ...) end
end)
