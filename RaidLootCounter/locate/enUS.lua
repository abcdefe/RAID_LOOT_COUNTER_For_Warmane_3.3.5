local addonName, RLC = ...
local L = RLC.L

local enUS = {
    ["WINDOW_TITLE"] = "Raid Loot Counter",
    ["SYNC_RAID"] = "Sync Raid",
    ["CLEAR_DATA"] = "Clear Data",
    ["SEND_STATS"] = "Send Stats",
    ["VIEW_LOOT"] = "View Loot",
    ["DISTRO_MODE"] = "Distro Mode",
    ["DISTRO_MODE_TITLE"] = "Distribution Mode",
    ["DISTRO_MODE_LABEL"] = "Please select a distribution mode:",
    ["MS_PLUS_1"] = "MS+1",
    ["MS_GT_OS"] = "MS>OS",
    ["LOOT_HISTORY_TITLE"] = "Loot History",
    ["NO_LOOT"] = "No loot",
    ["UNKNOWN_BOSS"] = "Unknown Boss",
    ["UNKNOWN_INSTANCE"] = "Unknown Instance",
    ["LOOTED_PREFIX"] = "Looted: ",
    
    ["MSG_NOT_IN_RAID"] = "You are not in a raid group.",
    ["MSG_SYNC_COMPLETE"] = "Sync complete",
    ["MSG_ADDED"] = "added %d members",
    ["MSG_REMOVED"] = "removed %d members",
    ["MSG_DATA_CLEARED"] = "Data cleared.",
    ["MSG_NO_DATA"] = "No data to send.",
    ["MSG_STATS_SENT"] = "Stats sent to raid chat.",
    ["MSG_NEW_BOSS_LOOT"] = "Found new boss loot (%d items):",
    ["MSG_LOADED"] = "loaded. Use |cffff00ff/rlc|r to open.",
    
    -- Output strings (Must be English for international servers)
    ["OUTPUT_HEADER"] = "==== Raid Loot Counter ====",
    ["OUTPUT_ITEMS"] = "items",
    ["OUTPUT_ADD"] = "Add",
    ["OUTPUT_REMOVE"] = "Remove",
    ["OUTPUT_TOTAL"] = "Total:",
    
    ["CHECKBOX_AUTO_ANNOUNCE"] = "Update immediately notify raid",

    ["START_ROLL_CAPTURE"] = "Start Roll Capture",
    ["STOP_ROLL_CAPTURE"] = "Stop Roll Capture",

    ["ROLL_CAPTURE_STARTED"] = "Roll capture started. Listening for raid rolls...",
    ["ROLL_CAPTURE_STOPPED"] = "Roll capture stopped.",
    ["ROLL_CAPTURE_ALREADY_ACTIVE"] = "Roll capture is already active.",
    ["ROLL_CAPTURE_NOT_ACTIVE"] = "Roll capture is not active.",
    ["MSG_STOP_ROLL_COUNTDOWN"] = "Stopping roll in 3 seconds...",
    ["ROLL_NO_RESULTS"] = "No roll results captured.",
    ["ROLL_RESULTS_HEADER"] = "=== Roll Results ===",
    ["ROLL_RESULTS_COUNT"] = "rolls",
    ["ROLL_WINNER"] = "Winner",
    ["ROLL_PATTERN"] = "(.+)%s+rolls%s+(%d+)[^%d]+(%d+)[^%d]+(%d+)",
    ["ROLL_CAPTURE_SINGLE"] = "%s rolls %s (%s-%s)",

    ["CONFIRM_CLEAR_TEXT"] = "Are you sure you want to clear all data?\n\nThis will delete all members and their loot records!",
    ["CONFIRM"] = "Confirm",
    ["CANCEL"] = "Cancel",

    ["TITLE_ASSIGN_MS"] = "Assign MS: ",
    ["TITLE_ASSIGN_OS"] = "Assign OS: ",
    ["TITLE_ASSIGN_LOOT"] = "Assign Loot: ",
    ["TITLE_REMOVE_LOOT"] = "Remove Loot: ",
    ["TITLE_ROLL_LOOT"] = "Roll Loot",
    ["MSG_SELECT_ITEM"] = "Please select an item.",
    ["MSG_LOOT_REMOVED"] = "Removed ",
    ["MSG_LOOT_ASSIGNED"] = "Assigned ",
    ["MSG_FROM"] = " from ",
    ["MSG_TO"] = " to ",
    ["ROLL_ANNOUNCE"] = "Roll ",

    -- Buttons
    ["BUTTON_MS_ROLL"] = "MS Roll",
    ["BUTTON_OS_ROLL"] = "OS Roll",
    ["BUTTON_MS_SAVE"] = "MS Save",
    ["BUTTON_OS_SAVE"] = "OS Save",
    ["BUTTON_REMOVE"] = "Remove",
    ["BUTTON_MANUAL_ADD"] = "Manual Add",
    ["BUTTON_SAVE"] = "Save",
    ["TITLE_MANUAL_ADD"] = "Manual Add Loot",
    ["BOSS_MANUAL_ADD"] = "Manual Add",
    ["MSG_MANUAL_ADD_SUCCESS"] = "Added %s to history.",
    ["MSG_NO_ITEM_SELECTED"] = "Please select an item first.",

    -- Errors / Info
    ["ERR_NO_LOOT_SELECTION_FRAME"] = "Error: RLCLootSelectionFrame not found",
    ["ERR_PARENT_FRAME_NIL"] = "Error: Parent frame is nil",
    ["ERR_PLAYERNAME_NIL"] = "Error: PlayerName is nil on frame %s",

    -- Auto announce toggle
    ["AUTO_ANNOUNCE_ON"] = "Auto announce: |cff00ff00Enabled|r",
    ["AUTO_ANNOUNCE_OFF"] = "Auto announce: |cffff0000Disabled|r",

    -- Instance Abbreviations
    ["INSTANCE_ABBREVIATIONS"] = {
        ["Icecrown Citadel"] = "ICC",
        ["Trial of the Crusader"] = "ToC",
        ["Ruby Sanctum"] = "RS",
        ["The Ruby Sanctum"] = "RS",
        ["Onyxia's Lair"] = "Ony",
        ["Vault of Archavon"] = "VoA",
        ["Naxxramas"] = "Naxx",
        ["Ulduar"] = "Uld",
        ["The Eye of Eternity"] = "EoE",
        ["The Obsidian Sanctum"] = "OS"
    },

    -- Tier Patterns
    ["TIER_PATTERNS"] = {
        ["T7"] = {
            "of the Lost Conqueror", "of the Lost Protector", "of the Lost Vanquisher"
        },
        ["T8"] = {
            "of the Wayward Conqueror", "of the Wayward Protector", "of the Wayward Vanquisher"
        },
        ["T9"] = {
            "Trophy of the Crusade", 
            "Regalia of the Grand Conqueror", "Regalia of the Grand Protector", "Regalia of the Grand Vanquisher"
        },
        ["T10"] = {
            "Mark of Sanctification"
        }
    },

    -- Tier Sets (Prefixes)
    ["TIER_SETS"] = {
        -- T7
        ["Scourgeborne"] = "T7", ["Dreamwalker"] = "T7", ["Cryptstalker"] = "T7", ["Frostfire"] = "T7",
        ["Redemption"] = "T7", ["Faith"] = "T7", ["Bonescythe"] = "T7", ["Earthshatter"] = "T7",
        ["Plagueheart"] = "T7", ["Dreadnaught"] = "T7",
        
        -- T8
        ["Darkruned"] = "T8", ["Nightsong"] = "T8", ["Scourgestalker"] = "T8", ["Kirin Tor"] = "T8",
        ["Aegis"] = "T8", ["Sanctification"] = "T8", ["Terrorblade"] = "T8", ["Worldbreaker"] = "T8",
        ["Deathbringer"] = "T8", ["Siegebreaker"] = "T8",

        -- T9
        ["Thassarian"] = "T9", ["Koltira"] = "T9",
        ["Malfurion"] = "T9", ["Runetotem"] = "T9",
        ["Windrunner"] = "T9", ["Wyrmstalker"] = "T9",
        ["Khadgar"] = "T9", ["Sunstrider"] = "T9",
        ["Turalyon"] = "T9", ["Liadrin"] = "T9",
        ["Velen"] = "T9", ["Zabra"] = "T9",
        ["VanCleef"] = "T9", ["Garona"] = "T9",
        ["Nobundo"] = "T9", ["Thrall"] = "T9",
        ["Kel'Thuzad"] = "T9", ["Gul'dan"] = "T9",
        ["Wrynn"] = "T9", ["Hellscream"] = "T9",
        ["Triumphant"] = "T9", ["Conqueror's"] = "T9",

        -- T10
        ["Scourgelord"] = "T10", ["Lasherweave"] = "T10", ["Ahn'Kahar"] = "T10", ["Bloodmage"] = "T10",
        ["Lightsworn"] = "T10", ["Crimson Acolyte"] = "T10", ["Shadowblade"] = "T10", ["Frost Witch"] = "T10",
        ["Dark Coven"] = "T10", ["Ymirjar"] = "T10", ["Sanctified"] = "T10"
    }
}

-- Initialize L with English defaults (ensures all keys exist)
for k, v in pairs(enUS) do
    L[k] = v
end
