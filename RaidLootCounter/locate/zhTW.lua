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

    ["START_ROLL_CAPTURE"] = "開啟roll捕獲",
    ["STOP_ROLL_CAPTURE"] = "停止roll捕獲",

    ["ROLL_CAPTURE_STARTED"] = "已開啟roll捕獲，正在監聽團隊roll點...",
    ["ROLL_CAPTURE_STOPPED"] = "已停止roll捕獲。",
    ["ROLL_CAPTURE_ALREADY_ACTIVE"] = "roll捕獲已在進行中。",
    ["ROLL_CAPTURE_NOT_ACTIVE"] = "roll捕獲未開啟。",
    ["ROLL_NO_RESULTS"] = "沒有捕獲到roll結果。",
    ["ROLL_RESULTS_HEADER"] = "=== Roll點結果 ===",
    ["ROLL_RESULTS_COUNT"] = "個roll點",
    ["ROLL_WINNER"] = "獲勝者",
    ["ROLL_PATTERN"] = "(.+)擲出(%d+)[^%d]+(%d+)[^%d]+(%d+)",

    ["OUTPUT_ADD"] = "新增",
    ["OUTPUT_REMOVE"] = "移除",
    ["OUTPUT_TOTAL"] = "總數:",
    ["OUTPUT_HEADER"] = "團隊拾取統計:",
    ["OUTPUT_ITEMS"] = "件物品",

    ["CONFIRM_CLEAR_TEXT"] = "確定要清空所有數據嗎？\n\n這將刪除所有成員和他們的拾取記錄！",
    ["CONFIRM"] = "確定",
    ["CANCEL"] = "取消",
}

for k, v in pairs(zhTW) do
    L[k] = v
end
