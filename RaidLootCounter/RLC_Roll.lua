local addonName, ns = ...
local L = ns.L

local Chat = ns.Chat

-- ============================================================================
-- Roll 点逻辑模块 (Roll Module)
-- ============================================================================

local Roll = {}
ns.Roll = Roll

local isRollCapturing = false
local rollResults = {}
local rollCaptureFrame = nil

-- 对外状态查询
function Roll.IsActive()
    return isRollCapturing
end

-- 内部：判断是否是当前队伍/团队成员
local function IsGroupMember(playerName)
    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers and numRaidMembers > 0 then
        for i = 1, numRaidMembers do
            local raidName = GetRaidRosterInfo(i)
            if raidName then
                local cleanRaidName = string.match(raidName, "^([^-]+)")
                if cleanRaidName == playerName or raidName == playerName then
                    return true
                end
            end
        end
        return false
    end

    local numPartyMembers = GetNumPartyMembers()
    if numPartyMembers and numPartyMembers > 0 then
        local myName = UnitName("player")
        if myName == playerName then return true end
        for i = 1, numPartyMembers do
            if UnitName("party"..i) == playerName then
                return true
            end
        end
        return false
    end

    return UnitName("player") == playerName
end

-- 内部：处理系统 roll 消息
local function ProcessRollMessage(message)
    local pattern = L["ROLL_PATTERN"] or "(.+) rolls (%d+) %((%d+)-(%d+)%)"
    local playerName, rollValue, minValue, maxValue = string.match(message, pattern)

    if not (playerName and rollValue and minValue and maxValue) then
        return
    end

    playerName = string.match(playerName, "^%s*(.-)%s*$")
    if not IsGroupMember(playerName) then
        return
    end

    for _, result in ipairs(rollResults) do
        if result.player == playerName then
            return
        end
    end

    table.insert(rollResults, {
        player = playerName,
        roll = tonumber(rollValue),
        min = tonumber(minValue),
        max = tonumber(maxValue),
        timestamp = time(),
    })

    print(string.format(ns.CONSTANTS.CHAT_PREFIX .. L["ROLL_CAPTURE_SINGLE"] or "%s rolls %s (%s-%s)",
        playerName, rollValue, minValue, maxValue))
end

-- 内部：为结果补充职业与 MS/OS 计数
local function EnrichResults()
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
end

-- 内部：排序 roll 结果
local function SortResults(isOSRoll)
    table.sort(rollResults, function(a, b)
        if isOSRoll then
            return a.roll > b.roll
        else
            if a.msCount ~= b.msCount then
                return a.msCount < b.msCount
            end
            return a.roll > b.roll
        end
    end)
end

-- 内部：构造胜者字符串
local function BuildWinners(isOSRoll)
    if #rollResults == 0 then
        return nil
    end

    local winners = {}
    local first = rollResults[1]

    local function GetWinnerString(res)
        local className = res.class or "Unknown"
        local displayClass = ns.CONSTANTS.ENGLISH_CLASS_NAMES[className] or className
        return string.format("%s {%s} (%d (%d-%d)  MS: %d)",
            res.player, displayClass, res.roll, res.min, res.max, res.msCount)
    end

    table.insert(winners, GetWinnerString(first))

    for i = 2, #rollResults do
        local current = rollResults[i]
        local isTie = false
        if isOSRoll then
            isTie = current.roll == first.roll
        else
            isTie = (current.roll == first.roll and current.msCount == first.msCount)
        end

        if isTie then
            table.insert(winners, GetWinnerString(current))
        else
            break
        end
    end

    return winners
end

-- 对外：开始 roll 捕获
function Roll.Start(itemLink, rollType)
    if isRollCapturing then return end

    rollResults = {}
    isRollCapturing = true
    Roll.currentRollType = rollType or "MS"

    if not rollCaptureFrame then
        rollCaptureFrame = CreateFrame("Frame")
    end
    rollCaptureFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    rollCaptureFrame:SetScript("OnEvent", function(self, event, message)
        if event == "CHAT_MSG_SYSTEM" and isRollCapturing then
            ProcessRollMessage(message)
        end
    end)

    print(ns.CONSTANTS.CHAT_PREFIX .. L["ROLL_CAPTURE_STARTED"] .. " (" .. (rollType or "MS") .. ")")

    if itemLink then
        local prefix = (rollType == "OS") and "OS Roll " or "MS Roll "
        Chat.SendRaidOrPrint(prefix .. itemLink, "RAID_WARNING")
    end
end

-- 对外：停止并通告结果
function Roll.StopAndAnnounce()
    if not isRollCapturing then
        print("|cffff0000[RaidLootCounter]|r " .. L["ROLL_CAPTURE_NOT_ACTIVE"])
        return
    end

    isRollCapturing = false
    if rollCaptureFrame then
        rollCaptureFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
    end

    if #rollResults == 0 then
        print(ns.CONSTANTS.CHAT_PREFIX .. L["ROLL_NO_RESULTS"])
        return
    end

    EnrichResults()

    local isOSRoll = (Roll.currentRollType == "OS")
    SortResults(isOSRoll)

    local rollTypeStr = isOSRoll and "OS" or "MS"
    Chat.SendRaidOrPrint("=== Raid Loot Counter " .. rollTypeStr .. " Roll Results === (" .. #rollResults .. " rolls)", "RAID_WARNING")

    for i, result in ipairs(rollResults) do
        local msg = string.format("%d. %s: %d (%d-%d) [MS: %d]",
            i, result.player, result.roll, result.min, result.max, result.msCount)
        Chat.SendRaidOrPrint(msg, "RAID_WARNING")
    end

    local winners = BuildWinners(isOSRoll)
    if winners and #winners > 0 then
        Chat.SendRaidOrPrint("Winner (" .. rollTypeStr .. "): " .. table.concat(winners, ", "), "RAID_WARNING")
    end

    print(ns.CONSTANTS.CHAT_PREFIX .. L["ROLL_CAPTURE_STOPPED"])
end

