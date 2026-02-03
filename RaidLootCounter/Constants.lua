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

-- 副本名称缩写映射 (支持多语言)
ns.CONSTANTS.INSTANCE_ABBREVIATIONS = {
    -- English
    ["Icecrown Citadel"] = "ICC",
    ["Trial of the Crusader"] = "ToC",
    ["Ruby Sanctum"] = "RS",
    ["The Ruby Sanctum"] = "RS",
    ["Onyxia's Lair"] = "Ony",
    ["Vault of Archavon"] = "VoA",
    ["Naxxramas"] = "Naxx",
    ["Ulduar"] = "Uld",
    ["The Eye of Eternity"] = "EoE",
    ["The Obsidian Sanctum"] = "OS",
    
    -- zhCN
    ["冰冠堡垒"] = "ICC",
    ["十字军的试炼"] = "ToC",
    ["红玉圣殿"] = "RS",
    ["奥妮克希亚的巢穴"] = "Ony",
    ["阿尔卡冯的宝库"] = "VoA",
    ["纳克萨玛斯"] = "Naxx",
    ["奥杜尔"] = "Uld",
    ["永恒之眼"] = "EoE",
    ["黑曜石圣殿"] = "OS",
    
    -- zhTW
    ["冰冠城塞"] = "ICC",
    ["十字軍試煉"] = "ToC",
    ["晶紅聖所"] = "RS",
    ["奧妮克希亞的巢穴"] = "Ony",
    ["亞夏梵穹殿"] = "VoA",
    ["納克薩瑪斯"] = "Naxx",
    ["奧杜亞"] = "Uld",
    ["永恆之眼"] = "EoE",
    ["黑曜聖所"] = "OS",
}

-- 掉落记录配置
ns.CONSTANTS.LOOT_CONFIG = {
    MIN_QUALITY = 4, -- Epic
}
