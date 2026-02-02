local addonName, RLC = ...
local L = RLC.L

local enUS = {
    ["WINDOW_TITLE"] = "Raid Loot Counter",
    ["SYNC_RAID"] = "Sync Raid",
    ["CLEAR_DATA"] = "Clear Data",
    ["SEND_STATS"] = "Send Stats",
    ["VIEW_LOOT"] = "View Loot",
    ["LOOT_HISTORY_TITLE"] = "Loot History",
    ["NO_LOOT"] = "No loot",
    ["CHEST_OR_UNKNOWN"] = "Chest/Unknown",
    ["LOOTED_PREFIX"] = "Looted: ",
    
    ["MSG_NOT_IN_RAID"] = "You are not in a raid group.",
    ["MSG_SYNC_COMPLETE"] = "Sync complete",
    ["MSG_ADDED"] = "added %d members",
    ["MSG_REMOVED"] = "removed %d members",
    ["MSG_DATA_CLEARED"] = "Data cleared.",
    ["MSG_NO_DATA"] = "No data to send.",
    ["MSG_STATS_SENT"] = "Stats sent to raid chat.",
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
    ["ROLL_NO_RESULTS"] = "No roll results captured.",
    ["ROLL_RESULTS_HEADER"] = "=== Roll Results ===",
    ["ROLL_RESULTS_COUNT"] = "rolls",
    ["ROLL_WINNER"] = "Winner",
    ["ROLL_PATTERN"] = "(.+)%s+rolls%s+(%d+)[^%d]+(%d+)[^%d]+(%d+)",

    ["CONFIRM_CLEAR_TEXT"] = "Are you sure you want to clear all data?\n\nThis will delete all members and their loot records!",
    ["CONFIRM"] = "Confirm",
    ["CANCEL"] = "Cancel",
}

-- Initialize L with English defaults (ensures all keys exist)
for k, v in pairs(enUS) do
    L[k] = v
end
