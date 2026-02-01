local addonName, RLC = ...
local L = RLC.L

local enUS = {
    ["WINDOW_TITLE"] = "Raid Loot Counter",
    ["SYNC_RAID"] = "Sync Raid",
    ["CLEAR_DATA"] = "Clear Data",
    ["SEND_STATS"] = "Send Stats",
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

    ["CONFIRM_CLEAR_TEXT"] = "Are you sure you want to clear all data?\n\nThis will delete all members and their loot records!",
    ["CONFIRM"] = "Confirm",
    ["CANCEL"] = "Cancel",
}

-- Initialize L with English defaults (ensures all keys exist)
for k, v in pairs(enUS) do
    L[k] = v
end
