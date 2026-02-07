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

    -- Instance Abbreviations
    ["INSTANCE_ABBREVIATIONS"] = {
        ["冰冠堡垒"] = "ICC",
        ["十字军的试炼"] = "ToC",
        ["红玉圣殿"] = "RS",
        ["奥妮克希亚的巢穴"] = "Ony",
        ["阿尔卡冯的宝库"] = "VoA",
        ["纳克萨玛斯"] = "Naxx",
        ["奥杜尔"] = "Uld",
        ["永恒之眼"] = "EoE",
        ["黑曜石圣殿"] = "OS"
    },

    -- Tier Patterns
    ["TIER_PATTERNS"] = {
        ["T7"] = {
            "失落征服者的", "失落保卫者的", "失落胜利者的"
        },
        ["T8"] = {
            "遗忘征服者的", "遗忘保卫者的", "遗忘胜利者的"
        },
        ["T9"] = {
            "北伐奖章",
            "大十字军的"
        },
        ["T10"] = {
            "圣洁徽记"
        }
    },

    -- Tier Sets (Prefixes)
    ["TIER_SETS"] = {
        -- T7
        ["天灾苦痛"] = "T7", ["梦游者"] = "T7", ["地穴追猎者"] = "T7", ["霜火"] = "T7",
        ["救赎"] = "T7", ["信仰"] = "T7", ["骨镰"] = "T7", ["地碎"] = "T7",
        ["瘟疫之心"] = "T7", ["无畏"] = "T7",
        
        -- T8
        ["黑暗符文"] = "T8", ["夜歌"] = "T8", ["天灾追猎者"] = "T8", ["肯瑞托"] = "T8",
        ["庇护"] = "T8", ["圣灵"] = "T8", ["恐怖利刃"] = "T8", ["碎地者"] = "T8",
        ["死亡使者"] = "T8", ["破城者"] = "T8",

        -- T9
        ["萨萨里安"] = "T9", ["库尔迪拉"] = "T9",
        ["玛法里奥"] = "T9", ["符文图腾"] = "T9",
        ["风行者"] = "T9", ["龙追猎者"] = "T9",
        ["卡德加"] = "T9", ["逐日者"] = "T9",
        ["图拉扬"] = "T9", ["莉亚德琳"] = "T9",
        ["维伦"] = "T9", ["扎布拉"] = "T9",
        ["范克里夫"] = "T9", ["加罗娜"] = "T9",
        ["努波顿"] = "T9", ["萨尔"] = "T9",
        ["克尔苏加德"] = "T9", ["古尔丹"] = "T9",
        ["乌瑞恩"] = "T9", ["地狱咆哮"] = "T9",
        ["得胜"] = "T9", ["征服者的"] = "T9",

        -- T10
        ["天灾领主"] = "T10", ["树纹"] = "T10", ["安卡哈"] = "T10", ["鲜血法师"] = "T10",
        ["光誓"] = "T10", ["血色侍祭"] = "T10", ["影刃"] = "T10", ["霜巫"] = "T10",
        ["黑金"] = "T10", ["伊米亚"] = "T10", ["神圣"] = "T10"
    }
}

for k, v in pairs(zhCN) do
    L[k] = v
end
