local addonName, ns = ...
local L = ns.L

-- ============================================================================
-- 掉落历史功能 (LootHistory)
-- ============================================================================

function RLC:OnViewLootClick()
    if RaidLootCounterLootHistoryFrame:IsShown() then
        RaidLootCounterLootHistoryFrame:Hide()
    else
        RaidLootCounterLootHistoryFrame:Show()
        RLC:RefreshLootHistory()
    end
end

function RLC:RefreshLootHistory()
    if not RaidLootCounterLootHistoryFrame or not RaidLootCounterLootHistoryFrame:IsShown() then return end
    
    local textWidget = RLCLootHistoryText
    if not textWidget then return end
    
    local scrollChild = RLCLootHistoryScrollChild
    
    if not RaidLootCounterDB.lootedBosses then
        textWidget:SetText(L["MSG_NO_DATA"] or "No data")
        return
    end
    
    -- Convert map to list and group data
    local history = {}
    local instances = {} -- 副本名称 -> { 难度 -> { boss列表 } }

    for guid, data in pairs(RaidLootCounterDB.lootedBosses) do
        if type(data) == "table" then
            table.insert(history, data)
            
            -- 从Boss名称中提取难度信息
            local bossName = data.name or "Unknown Boss"
            local instanceName = data.instance or "Unknown Instance"
            local difficulty = "Unknown Difficulty"
            
            -- 尝试从名字末尾匹配 (10N), (25H) 等
            local diffMatch = string.match(bossName, "%((%d+[NH])%)$")
            if diffMatch then
                difficulty = diffMatch
                bossName = string.gsub(bossName, "%s*%(%d+[NH]%)", "")
            else
                difficulty = "Normal"
            end
            
            if not instances[instanceName] then instances[instanceName] = {} end
            if not instances[instanceName][difficulty] then instances[instanceName][difficulty] = {} end
            
            table.insert(instances[instanceName][difficulty], {
                name = bossName,
                timestamp = data.timestamp,
                loot = data.loot
            })
        end
    end
    
    if #history == 0 then
        textWidget:SetText(L["MSG_NO_DATA"] or "No data")
        return
    end
    
    -- 构建显示内容
    local content = ""
    
    -- 1. 副本排序
    local sortedInstances = {}
    for inst in pairs(instances) do table.insert(sortedInstances, inst) end
    table.sort(sortedInstances)
    
    for _, instName in ipairs(sortedInstances) do
        content = content .. "|cff00ffff[" .. instName .. "]|r\n"
        
        -- 2. 难度排序
        local sortedDiffs = {}
        for diff in pairs(instances[instName]) do table.insert(sortedDiffs, diff) end
        table.sort(sortedDiffs)
        
        for _, diffName in ipairs(sortedDiffs) do
            content = content .. "  |cffffff00" .. diffName .. "|r\n"
            
            -- 3. Boss按时间排序 (倒序，最近的在上面)
            local bosses = instances[instName][diffName]
            table.sort(bosses, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
            
            for _, boss in ipairs(bosses) do
                local dateStr = date("%H:%M:%S", boss.timestamp)
                content = content .. "    |cffffd100" .. boss.name .. "|r  |cffaaaaaa(" .. dateStr .. ")|r\n"
                
                if boss.loot and #boss.loot > 0 then
                    for _, itemData in ipairs(boss.loot) do
                        if type(itemData) == "table" then
                            content = content .. "      " .. itemData.link
                            if itemData.holder then
                                content = content .. " |cff00ff00(" .. itemData.holder .. ")|r"
                            end
                            content = content .. "\n"
                        else
                             -- Legacy support for string format
                            content = content .. "      " .. itemData .. "\n"
                        end
                    end
                else
                    content = content .. "      " .. (L["NO_LOOT"] or "No loot") .. "\n"
                end
                content = content .. "\n"
            end
        end
        content = content .. "\n" -- 副本之间多空一行
    end
    
    textWidget:SetText(content)
    
    -- Adjust scroll child height based on text height
    local height = textWidget:GetContentHeight()
    if height < 10 then height = 10 end
    scrollChild:SetHeight(height + 20)
end

function RLC:OnHistoryHyperlinkClick(self, link, text, button)
    if IsShiftKeyDown() then
        if ChatEdit_InsertLink then
            local _, itemLink = GetItemInfo(link)
            if itemLink then
                ChatEdit_InsertLink(itemLink)
            else
                ChatEdit_InsertLink(text)
            end
        end
    else
        SetItemRef(link, text, button)
    end
end

function RLC:OnHistoryHyperlinkEnter(self, link, text)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

-- ============================================================================
-- 调试功能 (Mock Data)
-- ============================================================================

function RLC:InjectMockData()
    if not RaidLootCounterDB.lootedBosses then
        RaidLootCounterDB.lootedBosses = {}
    end

    local currentTime = time()
    
    -- Mock Data Definition
    local mockData = {
        -- ICC 25H: Marrowgar
        {
            guid = "Mock_ICC_25H_Marrowgar",
            name = "Lord Marrowgar (25H)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 3600,
            loot = {
                { link = "|cffa335ee|Hitem:50415:0:0:0:0:0:0:0:80|h[Bryntroll, the Bone Arbiter]|h|r", holder = "PlayerA" },
                { link = "|cffa335ee|Hitem:50412:0:0:0:0:0:0:0:80|h[Loop of the Endless Labyrinth]|h|r", holder = nil }
            }
        },
        -- ICC 25H: Lady Deathwhisper
        {
            guid = "Mock_ICC_25H_Lady",
            name = "Lady Deathwhisper (25H)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 3000,
            loot = {
                { link = "|cffa335ee|Hitem:50363:0:0:0:0:0:0:0:80|h[Deathwhisper Raiment]|h|r", holder = nil }
            }
        },
        -- ICC 25H: Gunship Chest (Test Chest logic)
        {
            guid = "Chest_Gunship_25H", 
            name = (L["CHEST_OR_UNKNOWN"] or "Chest/Unknown") .. " - Gunship Battle (25H)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 2400,
            loot = {
                 { link = "|cffa335ee|Hitem:50343:0:0:0:0:0:0:0:80|h[Muradin's Spyglass]|h|r", holder = nil }
            }
        },
        -- ICC 10N: Marrowgar (Different difficulty)
        {
            guid = "Mock_ICC_10N_Marrowgar",
            name = "Lord Marrowgar (10N)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 7200,
            loot = {
                { link = "|cffa335ee|Hitem:50787:0:0:0:0:0:0:0:80|h[Citadel Enforcer's Claymore]|h|r", holder = "PlayerB" }
            }
        },
        -- RS 25H: Halion
        {
            guid = "Mock_RS_25H_Halion",
            name = "Halion (25H)",
            instance = "The Ruby Sanctum",
            timestamp = currentTime - 1800,
            loot = {
                { link = "|cffa335ee|Hitem:54590:0:0:0:0:0:0:0:80|h[Sharpened Twilight Scale]|h|r", holder = nil },
                { link = "|cffa335ee|Hitem:54569:0:0:0:0:0:0:0:80|h[Halion, Staff of Forgotten Love]|h|r", holder = nil }
            }
        }
    }

    for _, data in ipairs(mockData) do
        RaidLootCounterDB.lootedBosses[data.guid] = {
            name = data.name,
            instance = data.instance,
            timestamp = data.timestamp,
            loot = data.loot
        }
    end

    print("|cff00ff00[RaidLootCounter]|r Mock data injected.")
    if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
        RLC:RefreshLootHistory()
    end
end

function RLC:ResetMockData()
    -- Placeholder for any specific mock data cleanup if needed
    -- Currently ClearAllData handles the DB cleanup
end
