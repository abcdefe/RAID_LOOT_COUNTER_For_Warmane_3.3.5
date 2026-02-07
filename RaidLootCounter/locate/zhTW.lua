if GetLocale() ~= "zhTW" then return end

local addonName, RLC = ...
local L = RLC.L

local zhTW = {
    ["WINDOW_TITLE"] = "團隊拾取計數器",
    ["SYNC_RAID"] = "同步團隊",
    ["CLEAR_DATA"] = "清空數據",
    ["SEND_STATS"] = "發送統計",
    ["VIEW_LOOT"] = "查看掉落",
    ["LOOT_HISTORY_TITLE"] = "歷史掉落記錄",
    ["NO_LOOT"] = "沒有掉落",
    ["CHEST_OR_UNKNOWN"] = "寶箱",
    ["LOOTED_PREFIX"] = "已拾取: ",
    
    ["MSG_NOT_IN_RAID"] = "你不在一個團隊中。",
    ["MSG_SYNC_COMPLETE"] = "同步完成",
    ["MSG_ADDED"] = "新增 %d 人",
    ["MSG_REMOVED"] = "移除 %d 人",
    ["MSG_DATA_CLEARED"] = "數據已清空。",
    ["MSG_NO_DATA"] = "沒有數據可發送。",
    ["MSG_STATS_SENT"] = "統計信息已發送到團隊頻道。",
    ["MSG_NEW_BOSS_LOOT"] = "發現新Boss掉落 (%d 件):",
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

    ["TITLE_ASSIGN_MS"] = "分配MS: ",
    ["TITLE_ASSIGN_OS"] = "分配OS: ",
    ["TITLE_ASSIGN_LOOT"] = "分配裝備: ",
    ["TITLE_REMOVE_LOOT"] = "移除裝備: ",
    ["TITLE_ROLL_LOOT"] = "Roll 裝備",
    ["MSG_SELECT_ITEM"] = "請選擇一件裝備。",
    ["MSG_LOOT_REMOVED"] = "已移除 ",
    ["MSG_LOOT_ASSIGNED"] = "已分配 ",
    ["MSG_FROM"] = " 從 ",
    ["MSG_TO"] = " 給 ",
    ["ROLL_ANNOUNCE"] = "Roll ",

    -- Instance Abbreviations
    ["INSTANCE_ABBREVIATIONS"] = {
        ["冰冠城塞"] = "ICC",
        ["十字軍試煉"] = "ToC",
        ["晶紅聖所"] = "RS",
        ["奧妮克希亞的巢穴"] = "Ony",
        ["亞夏梵穹殿"] = "VoA",
        ["納克薩瑪斯"] = "Naxx",
        ["奧杜亞"] = "Uld",
        ["永恆之眼"] = "EoE",
        ["黑曜聖所"] = "OS"
    },

    -- Tier Patterns
    ["TIER_PATTERNS"] = {
        ["T7"] = {
            "失落征服者", "失落保衛者", "失落鎮壓者"
        },
        ["T8"] = {
            "嚮往征服者", "嚮往保衛者", "嚮往鎮壓者"
        },
        ["T9"] = {
            "十字軍戰利品",
            "大十字軍征服者", "大十字軍保衛者", "大十字軍鎮壓者"
        },
        ["T10"] = {
            "聖潔徽記"
        }
    },

    -- Tier Sets (Prefixes)
    ["TIER_SETS"] = {
        -- T7
        ["天譴"] = "T7", ["夢行者"] = "T7", ["地穴行者"] = "T7", ["霜火"] = "T7",
        ["救贖"] = "T7", ["信仰"] = "T7", ["骨鐮"] = "T7", ["碎地"] = "T7",
        ["瘟疫之心"] = "T7", ["無畏"] = "T7",
        
        -- T8
        ["黑暗符文"] = "T8", ["夜歌"] = "T8", ["天譴行者"] = "T8", ["祈倫托"] = "T8",
        ["埃吉斯"] = "T8", ["聖化"] = "T8", ["恐怖利刃"] = "T8", ["碎界者"] = "T8",
        ["死亡使者"] = "T8", ["破城者"] = "T8",

        -- T9
        ["薩薩里安"] = "T9", ["庫爾迪拉"] = "T9",
        ["瑪法里奧"] = "T9", ["符文圖騰"] = "T9",
        ["風行者"] = "T9", ["追龍者"] = "T9", 
        ["卡德加"] = "T9", ["逐日者"] = "T9",
        ["圖拉揚"] = "T9", ["李亞德倫"] = "T9",
        ["費倫"] = "T9", ["薩布拉"] = "T9",
        ["范克里夫"] = "T9", ["迦羅娜"] = "T9",
        ["諾柏頓"] = "T9", ["索爾"] = "T9",
        ["克爾蘇加德"] = "T9", ["古爾丹"] = "T9",
        ["烏瑞恩"] = "T9", ["地獄吼"] = "T9",
        ["凱旋"] = "T9", ["征服者"] = "T9",
        
        -- T10
        ["天譴領主"] = "T10", ["鞭笞之林"] = "T10", ["安卡哈"] = "T10", ["血法師"] = "T10",
        ["赤紅侍僧"] = "T10", ["黑暗集會"] = "T10", ["依米亞"] = "T10", ["聖潔"] = "T10"
    }
}

for k, v in pairs(zhTW) do
    L[k] = v
end
