if GetLocale() ~= "zhCN" then return end

local addonName, RLC = ...
local L = RLC.L

local zhCN = {
    ["WINDOW_TITLE"] = "团队拾取计数器",
    ["SYNC_RAID"] = "同步团队",
    ["CLEAR_DATA"] = "清空数据",
    ["SEND_STATS"] = "发送统计",
    ["VIEW_LOOT"] = "查看掉落",
    ["LOOT_HISTORY_TITLE"] = "历史掉落记录",
    ["NO_LOOT"] = "没有掉落",
    ["CHEST_OR_UNKNOWN"] = "宝箱",
    ["LOOTED_PREFIX"] = "已拾取: ",
    
    ["MSG_NOT_IN_RAID"] = "你不在一个团队中。",
    ["MSG_SYNC_COMPLETE"] = "同步完成",
    ["MSG_ADDED"] = "新增 %d 人",
    ["MSG_REMOVED"] = "移除 %d 人",
    ["MSG_DATA_CLEARED"] = "数据已清空。",
    ["MSG_NO_DATA"] = "没有数据可发送。",
    ["MSG_STATS_SENT"] = "统计信息已发送到团队频道。",
    ["MSG_NEW_BOSS_LOOT"] = "发现新Boss掉落 (%d 件):",
    ["MSG_LOADED"] = "已加载。输入 |cffff00ff/rlc|r 打开窗口。",
    
    -- Note: OUTPUT_ keys are intentionally OMITTED to fallback to English
    
    ["CHECKBOX_AUTO_ANNOUNCE"] = "更新数量后立刻团队通知",

    ["START_ROLL_CAPTURE"] = "开启roll捕获",
    ["STOP_ROLL_CAPTURE"] = "停止roll捕获",

    ["ROLL_CAPTURE_STARTED"] = "已开启roll捕获，正在监听团队roll点...",
    ["ROLL_CAPTURE_STOPPED"] = "已停止roll捕获。",
    ["ROLL_CAPTURE_ALREADY_ACTIVE"] = "roll捕获已在进行中。",
    ["ROLL_CAPTURE_NOT_ACTIVE"] = "roll捕获未开启。",
    ["ROLL_NO_RESULTS"] = "没有捕获到roll结果。",
    ["ROLL_RESULTS_HEADER"] = "=== Roll点结果 ===",
    ["ROLL_RESULTS_COUNT"] = "个roll点",
    ["ROLL_WINNER"] = "获胜者",
    ["ROLL_PATTERN"] = "(.+)掷出(%d+)[^%d]+(%d+)[^%d]+(%d+)",

    ["OUTPUT_ADD"] = "新增",
    ["OUTPUT_REMOVE"] = "移除",
    ["OUTPUT_TOTAL"] = "总数:",
    ["OUTPUT_HEADER"] = "团队拾取统计:",
    ["OUTPUT_ITEMS"] = "件物品",

    ["CONFIRM_CLEAR_TEXT"] = "确定要清空所有数据吗？\n\n这将删除所有成员和他们的拾取记录！",
    ["CONFIRM"] = "确定",
    ["CANCEL"] = "取消",

    ["TITLE_ASSIGN_MS"] = "分配MS: ",
    ["TITLE_ASSIGN_OS"] = "分配OS: ",
    ["TITLE_ASSIGN_LOOT"] = "分配装备: ",
    ["TITLE_REMOVE_LOOT"] = "移除装备: ",
    ["TITLE_ROLL_LOOT"] = "Roll 装备",
    ["MSG_SELECT_ITEM"] = "请选择一件装备。",
    ["MSG_LOOT_REMOVED"] = "已移除 ",
    ["MSG_LOOT_ASSIGNED"] = "已分配 ",
    ["MSG_FROM"] = " 从 ",
    ["MSG_TO"] = " 给 ",
    ["ROLL_ANNOUNCE"] = "Roll ",
}

for k, v in pairs(zhCN) do
    L[k] = v
end
