local addonName, ns = ...

-- ============================================================================
-- Constants
-- ============================================================================

ns.CONSTANTS = {}

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

-- 掉落记录配置
ns.CONSTANTS.LOOT_CONFIG = {
    MIN_QUALITY = 4, -- Epic
}
