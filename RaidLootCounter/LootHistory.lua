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
        RaidLootCounterLootHistoryFrame:ClearAllPoints()
        RaidLootCounterLootHistoryFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
            local bossName = data.name or ns.CONSTANTS.DEFAULTS.UNKNOWN_BOSS
            local instanceName = data.instance or ns.CONSTANTS.DEFAULTS.UNKNOWN_INSTANCE
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
                                lineText = lineText .. ns.CONSTANTS.COLORS.BOSS .. "[" .. tier .. "]|r "
                            end
                            
                            local isBOE = itemData.isBOE
                            if isBOE == nil then
                                isBOE = ns.IsItemBOE(itemData.link)
                            end

                            if isBOE then
                                lineText = lineText .. ns.CONSTANTS.COLORS.BOE .. "[BOE]|r "
                            end

                            lineText = lineText .. itemData.link

                            if itemData.holder then
                                local typeStr = (itemData.type == ns.CONSTANTS.LOOT_TYPE.OS) and " -OS" or " -MS"
                                
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
    FauxScrollFrame_Update(scrollFrame, numRows, ns.CONSTANTS.UI.HISTORY_MAX_ROWS, ns.CONSTANTS.UI.HISTORY_ROW_HEIGHT)
    
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    RLC:HideAllHistoryRows()
    
    local parent = RaidLootCounterLootHistoryFrame
    local yPos = -50
    
    for i = 1, ns.CONSTANTS.UI.HISTORY_MAX_ROWS do
        local dataIndex = offset + i
        if dataIndex > numRows then break end
        
        local rowData = RLC.lootHistoryData[dataIndex]
        local row = GetHistoryRow(parent, i)
        row:SetPoint("TOPLEFT", 25, yPos)
        row.text:SetText(rowData.text)
        row.data = rowData
        
        yPos = yPos - ns.CONSTANTS.UI.HISTORY_ROW_HEIGHT
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
                { link = "|cffa335ee|Hitem:50415:0:0:0:0:0:0:0:80|h[Bryntroll, the Bone Arbiter]|h|r", holder = nil, type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN },
                { link = "|cffa335ee|Hitem:50412:0:0:0:0:0:0:0:80|h[Loop of the Endless Labyrinth]|h|r", holder = nil, type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN }
            }
        },
        -- ICC 25H: Lady Deathwhisper
        {
            guid = "Mock_ICC_25H_Lady",
            name = "Lady Deathwhisper (25H)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 3000,
            loot = {
                { link = "|cffa335ee|Hitem:50363:0:0:0:0:0:0:0:80|h[Deathwhisper Raiment]|h|r", holder = nil, type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN }
            }
        },
        -- ICC 25H: Gunship Chest (Test Chest logic)
        {
            guid = "Chest_Gunship_25H", 
            name = (L["CHEST_OR_UNKNOWN"] or "Chest") .. " - Gunship Battle (25H)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 2400,
            loot = {
                 { link = "|cffa335ee|Hitem:50343:0:0:0:0:0:0:0:80|h[Muradin's Spyglass]|h|r", holder = nil, type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN }
            }
        },
        -- ICC 10N: Marrowgar (Different difficulty)
        {
            guid = "Mock_ICC_10N_Marrowgar",
            name = "Lord Marrowgar (10N)",
            instance = "Icecrown Citadel",
            timestamp = currentTime - 7200,
            loot = {
                { link = "|cffa335ee|Hitem:50787:0:0:0:0:0:0:0:80|h[Citadel Enforcer's Claymore]|h|r", holder = "PlayerB", type = ns.CONSTANTS.LOOT_TYPE.OS, isBOE = true }
            }
        },
        -- RS 25H: Halion
        {
            guid = "Mock_RS_25H_Halion",
            name = "Halion (25H)",
            instance = "The Ruby Sanctum",
            timestamp = currentTime - 1800,
            loot = {
                { link = "|cffa335ee|Hitem:54590:0:0:0:0:0:0:0:80|h[Sharpened Twilight Scale]|h|r", holder = nil, type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN },
                { link = "|cffa335ee|Hitem:54569:0:0:0:0:0:0:0:80|h[Halion, Staff of Forgotten Love]|h|r", holder = nil, type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN }
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

-- ============================================================================
-- 手动添加掉落功能 (Manual Add Loot)
-- ============================================================================

local manualAddRows = {}
local manualAddData = {}
local selectedManualItem = nil

local function GetManualAddRow(parent, index)
    if not manualAddRows[index] then
        local rowName = "RLC_ManualAddRow_" .. index
        -- Reuse the loot selection row template as it fits well (Item Name + Details)
        local row = CreateFrame("Button", rowName, parent, "RLC_LootSelectionRowTemplate")
        -- Adjust font strings if needed, but defaults should be okay
        row.itemText = _G[rowName.."Item"]
        row.detailsText = _G[rowName.."Boss"] -- We can use this for ilvl or type
        
        -- Override OnClick to point to our handler
        row:SetScript("OnClick", function(self)
             RLC:OnManualAddRowClick(self)
        end)

        -- Init highlight
        row.highlight = _G[rowName.."Highlight"]
        
        manualAddRows[index] = row
    end
    local row = manualAddRows[index]
    row:SetParent(parent)
    row:ClearAllPoints()
    row:Show()
    return row
end

function RLC:OnManualAddClick()
    -- Init localized text
    if _G["RLCManualAddFrameTitle"] then
        _G["RLCManualAddFrameTitle"]:SetText(L["TITLE_MANUAL_ADD"] or "Manual Add Equipment")
    end
    if _G["RLCManualAddFrameSaveButton"] then
        _G["RLCManualAddFrameSaveButton"]:SetText(L["BUTTON_SAVE"] or "Save")
    end

    if RLCManualAddFrame:IsShown() then
        RLCManualAddFrame:Hide()
    else
        RLCManualAddFrame:ClearAllPoints()
        RLCManualAddFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        RLCManualAddFrame:Show()
        RLC:RefreshManualAddList()
    end
end

function RLC:RefreshManualAddList()
    manualAddData = {}
    selectedManualItem = nil
    
    -- Scan bags for Epic (4) or Legendary (5) items
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, quality, iLevel = GetItemInfo(link)
                
                -- Fallback if GetItemInfo is not ready (returns nil)
                if not quality then
                    -- Parse color from link |cffRRGGBB
                    if link:find("|cffa335ee") then -- Epic (Purple)
                        quality = 4
                    elseif link:find("|cffff8000") then -- Legendary (Orange)
                        quality = 5
                    elseif link:find("|cffe6cc80") then -- Heirloom (Gold)
                        quality = 7
                    end
                end

                if quality and quality >= 4 then
                    -- Check for BOE
                    local isBOE = ns.IsItemBOE(link)
                    
                    table.insert(manualAddData, {
                        link = link,
                        bag = bag,
                        slot = slot,
                        quality = quality,
                        iLevel = iLevel or 0,
                        isBOE = isBOE
                    })
                end
            end
        end
    end
    
    -- Sort by quality desc, then name
    table.sort(manualAddData, function(a, b)
        if a.quality == b.quality then
             return (a.link or "") < (b.link or "")
        end
        return a.quality > b.quality
    end)
    
    RLC:UpdateManualAddScroll()
end

function RLC:UpdateManualAddScroll()
    if not RLCManualAddFrame:IsShown() then return end
    
    local scrollFrame = RLCManualAddScrollFrame
    local numItems = #manualAddData
    
    FauxScrollFrame_Update(scrollFrame, numItems, ns.CONSTANTS.UI.MANUAL_ADD_MAX_ROWS, ns.CONSTANTS.UI.MANUAL_ADD_ROW_HEIGHT)
    
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    
    for i = 1, ns.CONSTANTS.UI.MANUAL_ADD_MAX_ROWS do
        local index = offset + i
        -- Fix: Parent to the main frame (RLCManualAddFrame), not the scroll frame
        local row = GetManualAddRow(scrollFrame:GetParent(), i)
        
        if index <= numItems then
            local data = manualAddData[index]
            row.data = data
            
            local displayText = ""
            
            -- Tier info
            local tier = ns.GetItemTier(data.link)
            if tier then
                displayText = displayText .. ns.CONSTANTS.COLORS.BOSS .. "[" .. tier .. "]|r "
            end
            
            -- BOE info
            if data.isBOE then
                displayText = displayText .. ns.CONSTANTS.COLORS.BOE .. "[BOE]|r "
            end
            
            displayText = displayText .. data.link
            
            row.itemText:SetText(displayText)
            row.detailsText:SetText("iLvl: " .. (data.iLevel or "?"))
            
            -- Fix: Correctly position rows relative to the frame content area
            -- The scroll frame is anchored at TOPLEFT x=20, y=-50
            -- We should position rows relative to the scroll frame's content or similar anchor
            -- Since we are attaching to Parent (Main Frame), we need to offset manually to match the scroll area
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i-1)*ns.CONSTANTS.UI.MANUAL_ADD_ROW_HEIGHT))
            row:SetWidth(760) 
            
            -- Update Highlight
            if selectedManualItem and selectedManualItem == data then
                if row.highlight then row.highlight:Show() end
            else
                if row.highlight then row.highlight:Hide() end
            end
            
            row:Show()
        else
            row:Hide()
        end
    end
end

function RLC:OnManualAddRowClick(row)
    if not row or not row.data then return end
    
    for _, r in pairs(manualAddRows) do
        if r.highlight then r.highlight:Hide() end
    end
    
    if row.highlight then row.highlight:Show() end
    selectedManualItem = row.data
end

function RLC:OnManualAddSaveClick()
    if not selectedManualItem then
        print(ns.CONSTANTS.CHAT_PREFIX .. (L["MSG_NO_ITEM_SELECTED"] or "Please select an item first."))
        return
    end
    
    -- Gather environment info
    local instanceName = GetInstanceInfo() or ns.CONSTANTS.DEFAULTS.UNKNOWN_INSTANCE
    local difficulty = GetInstanceDifficulty()
    local difficultyName = ""
    local SUFFIX = ns.CONSTANTS.DIFFICULTY_SUFFIX
    local _, instanceType = IsInInstance()
    
    if instanceType == "party" then
        if difficulty == 1 then difficultyName = SUFFIX["5N"]
        elseif difficulty == 2 then difficultyName = SUFFIX["5H"] end
    elseif instanceType == "raid" then
        if difficulty == 1 then difficultyName = SUFFIX["10N"]
        elseif difficulty == 2 then difficultyName = SUFFIX["25N"]
        elseif difficulty == 3 then difficultyName = SUFFIX["10H"]
        elseif difficulty == 4 then difficultyName = SUFFIX["25H"] end
    end
    
    local bossName = (L["BOSS_MANUAL_ADD"] or "Manual Add")
    
    -- Construct Loot Data
    local guid = "Manual_" .. time() .. "_" .. math.random(1000)
    
    local lootData = {
        name = bossName,
        instance = instanceName .. difficultyName,
        loot = {
            {
                link = selectedManualItem.link,
                holder = nil,
                type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN,
                isBOE = ns.IsItemBOE(selectedManualItem.link)
            }
        },
        timestamp = time()
    }
    
    if not RaidLootCounterDB.lootedBosses then
        RaidLootCounterDB.lootedBosses = {}
    end
    
    RaidLootCounterDB.lootedBosses[guid] = lootData
    
    print(ns.CONSTANTS.CHAT_PREFIX .. string.format(L["MSG_MANUAL_ADD_SUCCESS"] or "Added %s to history.", selectedManualItem.link))
    
    -- Refresh History
    if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
        RLC:RefreshLootHistory()
    end
    
    RLCManualAddFrame:Hide()
end
