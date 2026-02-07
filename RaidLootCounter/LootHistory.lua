local addonName, ns = ...
local L = ns.L

-- ============================================================================
-- 掉落历史功能 (LootHistory)
-- ============================================================================

local historyRows = {}
local function GetHistoryRow(parent, index)
    if not historyRows[index] then
        local rowName = "RLC_HistoryRow_" .. index
        local row = CreateFrame("Button", rowName, parent, "RLC_LootHistoryRowTemplate")
        row.text = _G[rowName.."Text"]
        historyRows[index] = row
    end
    local row = historyRows[index]
    row:SetParent(parent)
    row:ClearAllPoints()
    row:Show()
    return row
end

function RLC:HideAllHistoryRows()
    for _, row in pairs(historyRows) do row:Hide() end
end

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
    
    RLC.lootHistoryData = {}
    
    if not RaidLootCounterDB.lootedBosses then
        table.insert(RLC.lootHistoryData, { text = L["MSG_NO_DATA"] or "No data" })
        RLC:UpdateLootHistoryScroll()
        return
    end
    
    -- Convert map to list and group data
    local instances = {} -- 副本名称 -> { 难度 -> { boss列表 } }
    local hasData = false

    for guid, data in pairs(RaidLootCounterDB.lootedBosses) do
        if type(data) == "table" then
            hasData = true
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
    
    if not hasData then
        table.insert(RLC.lootHistoryData, { text = L["MSG_NO_DATA"] or "No data" })
        RLC:UpdateLootHistoryScroll()
        return
    end
    
    -- Flatten Data
    local sortedInstances = {}
    for inst in pairs(instances) do table.insert(sortedInstances, inst) end
    table.sort(sortedInstances)
    
    for _, instName in ipairs(sortedInstances) do
        table.insert(RLC.lootHistoryData, { text = ns.CONSTANTS.COLORS.INSTANCE .. "[" .. instName .. "]|r" })
        
        local sortedDiffs = {}
        for diff in pairs(instances[instName]) do table.insert(sortedDiffs, diff) end
        table.sort(sortedDiffs)
        
        for _, diffName in ipairs(sortedDiffs) do
            table.insert(RLC.lootHistoryData, { text = "  " .. ns.CONSTANTS.COLORS.DIFFICULTY .. diffName .. "|r" })
            
            local bosses = instances[instName][diffName]
            table.sort(bosses, function(a, b) return (a.timestamp or 0) < (b.timestamp or 0) end)
            
            for _, boss in ipairs(bosses) do
                local dateStr = date("%H:%M:%S", boss.timestamp)
                table.insert(RLC.lootHistoryData, { text = "    " .. ns.CONSTANTS.COLORS.BOSS .. boss.name .. "|r  " .. ns.CONSTANTS.COLORS.TIMESTAMP .. "(" .. dateStr .. ")|r" })
                
                if boss.loot and #boss.loot > 0 then
                    for _, itemData in ipairs(boss.loot) do
                        if type(itemData) == "table" then
                            local lineText = "      "
                            local tier = ns.GetItemTier(itemData.link)
                            if tier then
                                lineText = lineText .. "|cffffd100[" .. tier .. "]|r "
                            end
                            
                            local isBOE = itemData.isBOE
                            if isBOE == nil then
                                isBOE = ns.IsItemBOE(itemData.link)
                            end

                            if isBOE then
                                lineText = lineText .. "|cff00ccff[BOE]|r "
                            end

                            lineText = lineText .. itemData.link

                            if itemData.holder then
                                local typeStr = (itemData.type == "OS") and " -OS" or " -MS"
                                
                                local holderName = itemData.holder
                                local classColor = ""
                                if RaidLootCounterDB.players and RaidLootCounterDB.players[holderName] then
                                    local class = RaidLootCounterDB.players[holderName].class
                                    if class and ns.CONSTANTS.CLASS_COLORS[class] then
                                        local c = ns.CONSTANTS.CLASS_COLORS[class]
                                        classColor = string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
                                    end
                                end
                                
                                lineText = lineText .. " " .. ns.CONSTANTS.COLORS.HOLDER .. "(" .. classColor .. holderName .. ns.CONSTANTS.COLORS.HOLDER .. typeStr .. ")|r"
                            end
                            table.insert(RLC.lootHistoryData, { text = lineText, link = itemData.link, data = itemData })
                        else
                             -- Legacy support for string format
                            table.insert(RLC.lootHistoryData, { text = "      " .. itemData })
                        end
                    end
                else
                    table.insert(RLC.lootHistoryData, { text = "      " .. (L["NO_LOOT"] or "No loot") })
                end
                table.insert(RLC.lootHistoryData, { text = "" }) -- Spacer
            end
        end
        table.insert(RLC.lootHistoryData, { text = "" }) -- Instance Spacer
    end
    
    RLC:UpdateLootHistoryScroll()
end

function RLC:UpdateLootHistoryScroll()
    if not RLC.lootHistoryData then return end
    
    local scrollFrame = RLCLootHistoryScrollFrame
    if not scrollFrame then return end
    
    local numRows = #RLC.lootHistoryData
    -- 35 visible rows (approx 600 height / 16)
    FauxScrollFrame_Update(scrollFrame, numRows, 35, 16)
    
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    RLC:HideAllHistoryRows()
    
    local parent = RaidLootCounterLootHistoryFrame
    local yPos = -50
    
    for i = 1, 35 do
        local dataIndex = offset + i
        if dataIndex > numRows then break end
        
        local rowData = RLC.lootHistoryData[dataIndex]
        local row = GetHistoryRow(parent, i)
        row:SetPoint("TOPLEFT", 25, yPos)
        row.text:SetText(rowData.text)
        row.data = rowData
        
        yPos = yPos - 16
    end
end

function RLC:OnHistoryRowClick(row)
    if IsShiftKeyDown() and row.data and row.data.link then
        if ChatEdit_InsertLink then
            local _, itemLink = GetItemInfo(row.data.link)
            if itemLink then
                ChatEdit_InsertLink(itemLink)
            else
                ChatEdit_InsertLink(row.data.link)
            end
        end
    end
end

function RLC:OnHistoryRowEnter(row)
    if row.data and row.data.link then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(row.data.link)
        GameTooltip:Show()
    end
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
                { link = "|cffa335ee|Hitem:50415:0:0:0:0:0:0:0:80|h[Bryntroll, the Bone Arbiter]|h|r", holder = nil, type = "UNASSIGN" },
                { link = "|cffa335ee|Hitem:50412:0:0:0:0:0:0:0:80|h[Loop of the Endless Labyrinth]|h|r", holder = nil, type = "UNASSIGN" }
            }
        },
        -- ICC 25H: Lady Deathwhisper
        {
            guid = "Mock_ICC_25H_Lady",
            name = "Lady Deathwhisper (25H)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 3000,
            loot = {
                { link = "|cffa335ee|Hitem:50363:0:0:0:0:0:0:0:80|h[Deathwhisper Raiment]|h|r", holder = nil, type = "UNASSIGN" }
            }
        },
        -- ICC 25H: Gunship Chest (Test Chest logic)
        {
            guid = "Chest_Gunship_25H", 
            name = (L["CHEST_OR_UNKNOWN"] or "Chest") .. " - Gunship Battle (25H)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 2400,
            loot = {
                 { link = "|cffa335ee|Hitem:50343:0:0:0:0:0:0:0:80|h[Muradin's Spyglass]|h|r", holder = nil, type = "UNASSIGN" }
            }
        },
        -- ICC 10N: Marrowgar (Different difficulty)
        {
            guid = "Mock_ICC_10N_Marrowgar",
            name = "Lord Marrowgar (10N)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 7200,
            loot = {
                { link = "|cffa335ee|Hitem:50787:0:0:0:0:0:0:0:80|h[Citadel Enforcer's Claymore]|h|r", holder = "PlayerB", type = "OS", isBOE = true }
            }
        },
        -- RS 25H: Halion
        {
            guid = "Mock_RS_25H_Halion",
            name = "Halion (25H)",
            instance = "The Ruby Sanctum",
            timestamp = currentTime - 1800,
            loot = {
                { link = "|cffa335ee|Hitem:54590:0:0:0:0:0:0:0:80|h[Sharpened Twilight Scale]|h|r", holder = nil, type = "UNASSIGN" },
                { link = "|cffa335ee|Hitem:54569:0:0:0:0:0:0:0:80|h[Halion, Staff of Forgotten Love]|h|r", holder = nil, type = "UNASSIGN" }
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

    print(ns.CONSTANTS.CHAT_PREFIX .. "Mock data injected.")
    if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
        RLC:RefreshLootHistory()
    end
end

function RLC:ResetMockData()
    -- Placeholder for any specific mock data cleanup if needed
    -- Currently ClearAllData handles the DB cleanup
end
