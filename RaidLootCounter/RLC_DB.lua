local addonName, ns = ...
local L = ns.L

-- ============================================================================
-- 数据管理模块 (DB Module)
-- 负责 RaidLootCounterDB 的初始化、迁移和查询/更新
-- ============================================================================

local DB = {}
ns.DB = DB

local LOOT_TYPE = ns.CONSTANTS.LOOT_TYPE

local RESERVED_KEYS = {
    autoAnnounce = true,
    lootedBosses = true,
    players = true,
    meta = true,
}

local CURRENT_DB_VERSION = 1

-- 一次性迁移：统一 players 表结构 & 老字段
local function MigrateToV1()
    if not RaidLootCounterDB then return end

    -- 1. 确保 players 表存在
    if not RaidLootCounterDB.players then
        RaidLootCounterDB.players = {}
    end

    -- 2. 旧版本中，玩家数据可能直接挂在顶层，把它们搬到 players
    local keysToRemove = {}
    for key, value in pairs(RaidLootCounterDB) do
        if not RESERVED_KEYS[key] then
            if type(value) == "table" and (value.class or value.count) then
                RaidLootCounterDB.players[key] = value
                table.insert(keysToRemove, key)
            end
        end
    end
    for _, key in ipairs(keysToRemove) do
        RaidLootCounterDB[key] = nil
    end

    -- 3. 统一玩家字段：count -> msCount/osCount
    for _, data in pairs(RaidLootCounterDB.players) do
        if type(data) == "table" then
            if data.msCount == nil then
                data.msCount = data.count or data.msCount or 0
            end
            if data.osCount == nil then
                data.osCount = data.osCount or 0
            end
            data.count = nil
        end
    end
end

-- 对外：初始化数据库（包括迁移）
function DB.Init()
    if not RaidLootCounterDB then
        RaidLootCounterDB = {}
    end

    if not RaidLootCounterDB.meta then
        RaidLootCounterDB.meta = {}
    end

    local version = RaidLootCounterDB.meta.version or 0
    if version < 1 then
        MigrateToV1()
        RaidLootCounterDB.meta.version = CURRENT_DB_VERSION
    end

    -- Data validation
    if RaidLootCounterDB.players then
        for name, data in pairs(RaidLootCounterDB.players) do
            if type(data) ~= "table" then
                RaidLootCounterDB.players[name] = nil
            else
                if data.msCount and type(data.msCount) ~= "number" then data.msCount = 0 end
                if data.osCount and type(data.osCount) ~= "number" then data.osCount = 0 end
            end
        end
    end

    if RaidLootCounterDB.lootedBosses then
        for guid, data in pairs(RaidLootCounterDB.lootedBosses) do
            if type(data) ~= "table" or not data.name then
                RaidLootCounterDB.lootedBosses[guid] = nil
            end
        end
    end

    if RaidLootCounterDB.autoAnnounce == nil then
        RaidLootCounterDB.autoAnnounce = true
    end

    if not RaidLootCounterDB.lootedBosses then
        RaidLootCounterDB.lootedBosses = {}
    end

    if not RaidLootCounterDB.players then
        RaidLootCounterDB.players = {}
    end

    if not RaidLootCounterDB.distroMode then
        RaidLootCounterDB.distroMode = "MS+1"
    end
end

function DB.ClearAllData()
    RaidLootCounterDB.players = {}
    RaidLootCounterDB.lootedBosses = {}
end

function DB.IsEmpty()
    if not RaidLootCounterDB or not RaidLootCounterDB.players then
        return true
    end
    return next(RaidLootCounterDB.players) == nil
end

function DB.SetDistroMode(mode)
    RaidLootCounterDB.distroMode = mode
end

function DB.GetDistroMode()
    return RaidLootCounterDB.distroMode or "MS+1"
end

-- 内部：读取当前团队成员（按职业分组）
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
                    class = fileName,
                })
            end
        end
    end

    return members
end

-- 对外：同步团队成员到 DB.players
function DB.SyncRaidMembers()
    local raidMembers = GetRaidMembers()
    local currentRaidNames = {}
    local addedCount = 0
    local removedCount = 0

    if not RaidLootCounterDB.players then
        RaidLootCounterDB.players = {}
    end

    -- 添加新成员
    for className, players in pairs(raidMembers) do
        for _, player in ipairs(players) do
            currentRaidNames[player.name] = true

            local record = RaidLootCounterDB.players[player.name]
            if not record then
                RaidLootCounterDB.players[player.name] = {
                    msCount = 0,
                    osCount = 0,
                    class = className,
                }
                addedCount = addedCount + 1
            else
                record.class = className
                -- 兼容极旧数据
                if record.msCount == nil then
                    record.msCount = record.count or 0
                    record.osCount = record.osCount or 0
                    record.count = nil
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

-- 对外：获取某个玩家已分配的装备列表
function DB.GetPlayerItems(playerName)
    local items = {}
    if not RaidLootCounterDB or not RaidLootCounterDB.lootedBosses then
        return items
    end

    for _, data in pairs(RaidLootCounterDB.lootedBosses) do
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
                    itemType = LOOT_TYPE.MS
                end

                if holder == playerName and link then
                    table.insert(items, {
                        link = link,
                        type = itemType or LOOT_TYPE.MS,
                    })
                end
            end
        end
    end

    table.sort(items, function(a, b)
        local isAMS = (a.type == LOOT_TYPE.MS)
        local isBMS = (b.type == LOOT_TYPE.MS)
        if isAMS and not isBMS then return true end
        if not isAMS and isBMS then return false end
        return false
    end)

    return items
end

function DB.AddLoot(playerName, isOS)
    if not playerName or playerName == "" then return false end
    if not RaidLootCounterDB or not RaidLootCounterDB.players then return false end

    local record = RaidLootCounterDB.players[playerName]
    if record then
        if isOS then
            record.osCount = (record.osCount or 0) + 1
        else
            record.msCount = (record.msCount or 0) + 1
        end
        return true
    end

    return false
end

function DB.RemoveLoot(playerName, isOS)
    if not playerName or playerName == "" then return false end
    if not RaidLootCounterDB or not RaidLootCounterDB.players then return false end

    local record = RaidLootCounterDB.players[playerName]
    if record then
        if isOS then
            local current = record.osCount or 0
            record.osCount = math.max(0, current - 1)
        else
            local current = record.msCount or 0
            record.msCount = math.max(0, current - 1)
        end
        return true
    end

    return false
end

