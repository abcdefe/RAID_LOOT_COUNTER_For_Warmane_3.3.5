if GetLocale() ~= "zhCN" then return end

local addonName, RLC = ...
local L = RLC.L

local zhCN = {
    ["WINDOW_TITLE"] = "团队拾取计数器",
    ["SYNC_RAID"] = "同步团队",
    ["CLEAR_DATA"] = "清空数据",
    ["SEND_STATS"] = "发送统计",
    ["LOOTED_PREFIX"] = "已拾取: ",
    
    ["MSG_NOT_IN_RAID"] = "你不在一个团队中。",
    ["MSG_SYNC_COMPLETE"] = "同步完成",
    ["MSG_ADDED"] = "新增 %d 人",
    ["MSG_REMOVED"] = "移除 %d 人",
    ["MSG_DATA_CLEARED"] = "数据已清空。",
    ["MSG_NO_DATA"] = "没有数据可发送。",
    ["MSG_STATS_SENT"] = "统计信息已发送到团队频道。",
    ["MSG_LOADED"] = "已加载。输入 |cffff00ff/rlc|r 打开窗口。",
    
    -- Note: OUTPUT_ keys are intentionally OMITTED to fallback to English
    
    ["CHECKBOX_AUTO_ANNOUNCE"] = "更新数量后立刻团队通知",

    ["CONFIRM_CLEAR_TEXT"] = "确定要清空所有数据吗？\n\n这将删除所有成员和他们的拾取记录！",
    ["CONFIRM"] = "确定",
    ["CANCEL"] = "取消",
}

for k, v in pairs(zhCN) do
    L[k] = v
end
