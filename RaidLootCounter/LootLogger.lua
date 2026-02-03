local addonName, ns = ...
local L = ns.L

-- ============================================================================
-- 拾取记录功能 (LootLogger)
-- ============================================================================

local function OnLootOpened()
    -- 1. 检查是否在副本/团队中
    local inInstance, instanceType = IsInInstance()
    if instanceType ~= "raid" then
        -- and instanceType ~= "party" 
        -- 只在团队副本(raid)和5人本(party)生效
        return
    end
    
    -- 获取副本难度信息
    -- GetInstanceDifficulty(): 
    -- 5人本: 1=普通(Normal), 2=英雄(Heroic)
    -- 团本: 1=10人普通, 2=25人普通, 3=10人英雄, 4=25人英雄
    local difficulty = GetInstanceDifficulty()
    local difficultyName = ""
    local SUFFIX = ns.CONSTANTS.DIFFICULTY_SUFFIX
    
    if instanceType == "party" then
        if difficulty == 1 then
            difficultyName = SUFFIX["5N"]
        elseif difficulty == 2 then
            difficultyName = SUFFIX["5H"]
        end
    elseif instanceType == "raid" then
        if difficulty == 1 then
            difficultyName = SUFFIX["10N"]
        elseif difficulty == 2 then
            difficultyName = SUFFIX["25N"]
        elseif difficulty == 3 then
            difficultyName = SUFFIX["10H"]
        elseif difficulty == 4 then
            difficultyName = SUFFIX["25H"]
        end
    end

    -- 2. 获取目标GUID或生成宝箱标识
    local guid = UnitGUID("target")
    local bossName
    
    if guid then
        -- 情况A: 有目标 (通常是Boss尸体)
        if UnitIsPlayer("target") then return end -- 排除玩家尸体
        bossName = UnitName("target") .. difficultyName
    else
        -- 情况B: 无目标 (通常是宝箱)
        local subZone = GetSubZoneText() or ""
        if subZone == "" then subZone = GetMinimapZoneText() or "Unknown" end
        
        bossName = (L["CHEST_OR_UNKNOWN"] or "Chest") .. " - " .. subZone .. difficultyName
        
        -- 生成内容签名作为伪GUID
        -- 结合 子区域名 + 难度 来唯一标识 (不再使用物品内容)
        -- 这样同一个区域/难度的宝箱只会记录第一次
        local signature = subZone .. "_" .. difficulty
        
        -- 检查该区域是否已经记录过
        -- 我们需要生成一个不包含物品内容的ID，这样第二次开箱时，生成的ID和第一次一样
        -- 从而被下面的重复检查拦截
        guid = "Chest_" .. signature
    end

    -- 3. 检查是否已处理过该GUID
    if RaidLootCounterDB.lootedBosses and RaidLootCounterDB.lootedBosses[guid] then
        -- 调试：已经拾取过
        return
    end

    -- 确保表存在 (防止意外被删)
    if not RaidLootCounterDB.lootedBosses then
        RaidLootCounterDB.lootedBosses = {}
    end

    -- 4. 标记为已处理并存储信息
    -- local bossName = UnitName("target") or "Unknown Boss" -- 已在上方获取
    
    local instanceName = GetInstanceInfo() or "Unknown Instance"
    
    local lootData = {
        name = bossName,
        instance = instanceName,
        loot = {},
        timestamp = time()
    }
    
    -- 5. 遍历掉落列表
    local numItems = GetNumLootItems()
    local hasValidLoot = false

    if numItems > 0 then
        for i = 1, numItems do
            -- 3.3.5 GetLootSlotInfo 返回 texture, item, quantity, quality, locked
            local texture, item, quantity, quality, locked = GetLootSlotInfo(i)
            local lootLink = GetLootSlotLink(i)
            
            -- Only record Epic (4) and Legendary (5) quality items
            if lootLink and quality and quality >= ns.CONSTANTS.LOOT_CONFIG.MIN_QUALITY then
                table.insert(lootData.loot, {
                    link = lootLink,
                    holder = nil,
                    type = "UNASSIGN"
                })
                hasValidLoot = true
            end
        end
    end
    
    if hasValidLoot then
        print("|cff00ff00[RaidLootCounter]|r " .. string.format(L["MSG_NEW_BOSS_LOOT"] or "Found new Boss loot (%d items):", #lootData.loot))
        for i, v in ipairs(lootData.loot) do
            print(string.format("  %d. %s", i, v.link))
        end

        RaidLootCounterDB.lootedBosses[guid] = lootData
        
        -- 如果历史记录窗口打开，刷新它
        if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
            RLC:RefreshLootHistory()
        end
    end
end

-- 注册事件
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "LOOT_OPENED" then
        OnLootOpened()
    end
end)
