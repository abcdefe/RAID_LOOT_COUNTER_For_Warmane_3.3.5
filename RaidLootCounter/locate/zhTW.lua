if GetLocale() ~= "zhTW" then return end

local addonName, RLC = ...
local L = RLC.L

local zhTW = {
    ["WINDOW_TITLE"] = "團隊拾取計數器",
    ["SYNC_RAID"] = "同步團隊",
    ["CLEAR_DATA"] = "清空數據",
    ["SEND_STATS"] = "發送統計",
    ["LOOTED_PREFIX"] = "已拾取: ",
    
    ["MSG_NOT_IN_RAID"] = "你不在一個團隊中。",
    ["MSG_SYNC_COMPLETE"] = "同步完成",
    ["MSG_ADDED"] = "新增 %d 人",
    ["MSG_REMOVED"] = "移除 %d 人",
    ["MSG_DATA_CLEARED"] = "數據已清空。",
    ["MSG_NO_DATA"] = "沒有數據可發送。",
    ["MSG_STATS_SENT"] = "統計信息已發送到團隊頻道。",
    ["MSG_LOADED"] = "已加載。輸入 |cffff00ff/rlc|r 打開窗口。",
    
    -- Note: OUTPUT_ keys are intentionally OMITTED to fallback to English
    
    ["CHECKBOX_AUTO_ANNOUNCE"] = "更新數量後立刻團隊通知",

    ["CONFIRM_CLEAR_TEXT"] = "確定要清空所有數據嗎？\n\n這將刪除所有成員和他們的拾取記錄！",
    ["CONFIRM"] = "確定",
    ["CANCEL"] = "取消",
}

for k, v in pairs(zhTW) do
    L[k] = v
end
