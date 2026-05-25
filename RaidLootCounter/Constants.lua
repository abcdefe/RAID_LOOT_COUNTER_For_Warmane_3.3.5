local addonName, ns = ...

-- ============================================================================
-- Constants
-- ============================================================================

ns.CONSTANTS = {}

-- Cache for item properties to improve performance
ns.ItemCache = {}

-- 职业颜色配置

-- 职业颜色配置
ns.CONSTANTS.CLASS_COLORS = {
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
ns.CONSTANTS.ENGLISH_CLASS_NAMES = {
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

-- 文本颜色
ns.CONSTANTS.COLORS = {
    INSTANCE = "|cff00ffff",
    DIFFICULTY = "|cffffff00",
    BOSS = "|cffffd100",
    TIMESTAMP = "|cffaaaaaa",
    HOLDER = "|cff00ff00",
    BOE = "|cff00ccff",
    
    GREEN = "|cff00ff00",
    RED = "|cffff0000",
    GRAY = "|cffaaaaaa",
    RESET = "|r"
}

-- 聊天信息前缀
ns.CONSTANTS.CHAT_PREFIX = "|cff00ff00[RaidLootCounter]|r "

-- 副本难度后缀
ns.CONSTANTS.DIFFICULTY_SUFFIX = {
    ["5N"] = " (5N)",
    ["5H"] = " (5H)",
    ["10N"] = " (10N)",
    ["25N"] = " (25N)",
    ["10H"] = " (10H)",
    ["25H"] = " (25H)",
}

-- 副本名称缩写映射 (支持多语言)
ns.CONSTANTS.INSTANCE_ABBREVIATIONS = ns.L["INSTANCE_ABBREVIATIONS"] or {}

-- 掉落记录配置
ns.CONSTANTS.LOOT_CONFIG = {
    MIN_QUALITY = 4, -- Epic
    EXCLUDED_ITEM_IDS = {
        [20725] = true, -- Nexus Crystal
        [34057] = true, -- Abyss Crystal  
        [22450] = true, -- Greater Planar Essence
    },
}

-- 掉落类型常量
ns.CONSTANTS.LOOT_TYPE = {
    MS = "MS",
    OS = "OS",
    UNASSIGN = "UNASSIGN",
}

-- UI 模式常量
ns.CONSTANTS.MODES = {
    ASSIGN = "ASSIGN",
    UNASSIGN = "UNASSIGN",
    ROLL = "ROLL",
}

-- UI 常量
ns.CONSTANTS.UI = {
    HISTORY_MAX_ROWS = 35,    -- Loot History 窗口可视行数
    HISTORY_ROW_HEIGHT = 16,  -- Loot History 每一行高度
    SELECTION_MAX_ROWS = 12,  -- Loot Selection 窗口可视行数 (假设为12，需在 XML 或 Lua 中确认)
    SELECTION_ROW_HEIGHT = 25,-- Loot Selection 每一行高度
    MANUAL_ADD_MAX_ROWS = 10,
    MANUAL_ADD_ROW_HEIGHT = 25,
}

-- 默认值常量
ns.CONSTANTS.DEFAULTS = {
    UNKNOWN_INSTANCE = "Unknown Instance",
    UNKNOWN_BOSS = "Unknown Boss",
    UNKNOWN_CLASS = "Unknown",
    DEFAULT_CLASS = "WARRIOR",
}

-- Tier Set Definitions (Loaded from Localization)
ns.CONSTANTS.TIER_PATTERNS = ns.L["TIER_PATTERNS"] or {}
ns.CONSTANTS.TIER_SETS = ns.L["TIER_SETS"] or {}

-- ============================================================================
-- Chat Utilities
-- ============================================================================

ns.Chat = {}

-- 统一的团队/本地输出
function ns.Chat.SendRaidOrPrint(msg, channel)
    if not msg or msg == "" then return end

    local numRaidMembers = GetNumRaidMembers and GetNumRaidMembers() or 0
    if numRaidMembers > 0 and SendChatMessage then
        SendChatMessage(msg, channel or "RAID_WARNING")
    else
        print(msg)
    end
end

-- 带自动折行的列表输出（用于物品列表等，需要考虑 255 长度限制）
function ns.Chat.SendWrapped(prefix, items, channel, indent)
    if not items or #items == 0 then return end

    local line = prefix or ""
    local channelToUse = channel or "RAID_WARNING"
    local indentText = indent or "  "

    for _, part in ipairs(items) do
        local itemStr = " " .. part
        if string.len(line) + string.len(itemStr) > 250 then
            ns.Chat.SendRaidOrPrint(line, channelToUse)
            line = indentText .. part
        else
            line = line .. itemStr
        end
    end

    if line ~= "" then
        ns.Chat.SendRaidOrPrint(line, channelToUse)
    end
end

-- ============================================================================
-- Loot Utilities
-- ============================================================================

ns.LootUtil = {}

-- 从物品链接中提取物品ID
function ns.LootUtil.GetItemID(itemLink)
    if not itemLink then return nil end
    local itemID = string.match(itemLink, "item:(%d+):")
    return itemID and tonumber(itemID) or nil
end

-- 检查物品是否应该被排除
function ns.LootUtil.IsItemExcluded(itemLink)
    local itemID = ns.LootUtil.GetItemID(itemLink)
    return itemID and ns.CONSTANTS.LOOT_CONFIG.EXCLUDED_ITEM_IDS[itemID] or false
end

-- 统一规范化掉落条目结构，兼容旧的字符串格式
function ns.LootUtil.NormalizeLootItem(lootTable, index)
    if not lootTable or not index then return nil end

    local item = lootTable[index]
    if type(item) ~= "table" then
        lootTable[index] = {
            link = item,
            holder = nil,
            type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN,
        }
        item = lootTable[index]
    else
        if item.type == nil then
            item.type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN
        end
    end

    return item
end
