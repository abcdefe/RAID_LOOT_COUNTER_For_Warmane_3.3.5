local addonName, ns = ...
local L = ns.L

-- ============================================================================
-- 拾取记录功能 (LootLogger)
-- ============================================================================

local function OnLootOpened()
    -- 1. 检查是否在副本/团队中
    local inInstance, instanceType = IsInInstance()
    if instanceType ~= "raid" then
        -- 如果只想在团本生效，保持此判断
        -- return
    end
    
    -- 获取副本难度信息
    -- GetInstanceDifficulty(): 1=10N, 2=25N, 3=10H, 4=25H (3.3.5a standard for ICC/ToC)
    local difficulty = GetInstanceDifficulty()
    local difficultyName = ""
    
    if difficulty == 1 then
        difficultyName = " (10N)"
    elseif difficulty == 2 then
        difficultyName = " (25N)"
    elseif difficulty == 3 then
        difficultyName = " (10H)"
    elseif difficulty == 4 then
        difficultyName = " (25H)"
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
        
        bossName = (L["CHEST_OR_UNKNOWN"] or "Chest/Unknown") .. " - " .. subZone .. difficultyName
        
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
    if numItems > 0 then
        print("|cff00ff00[RaidLootCounter]|r 发现新Boss掉落 (" .. numItems .. " 件):")
        for i = 1, numItems do
            -- 3.3.5 GetLootSlotInfo 返回 texture, item, quantity, quality, locked
            local texture, item, quantity, quality, locked = GetLootSlotInfo(i)
            local lootLink = GetLootSlotLink(i)
            
            -- 只记录紫色(4)及以上品质
            if lootLink and quality and quality >= 4 then
                table.insert(lootData.loot, {
                    link = lootLink,
                    holder = nil
                })
                print(string.format("  %d. %s", i, lootLink))
            end
        end
    end
    
    RaidLootCounterDB.lootedBosses[guid] = lootData
    
    -- 如果历史记录窗口打开，刷新它
    if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
        RLC:RefreshLootHistory()
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
