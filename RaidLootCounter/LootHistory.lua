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
        row.hitBox = _G[rowName.."HitBox"]
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
    
    RLC:BuildHistoryData()
    RLC:UpdateLootHistoryScroll()
end

-- Helper function to build history data
function RLC:BuildHistoryData()
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
        return
    end
    
    RLC:FlattenHistoryData(instances)
end

-- Helper function to flatten history data
function RLC:FlattenHistoryData(instances)
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
                            local prefix = "      "
                            local tier = ns.GetItemTier(itemData.link)
                            if tier then
                                prefix = prefix .. ns.CONSTANTS.COLORS.BOSS .. "[" .. tier .. "]|r "
                            end
                            
                            local isBOE = itemData.isBOE
                            if isBOE == nil then
                                isBOE = ns.IsItemBOE(itemData.link)
                            end

                            if isBOE then
                                prefix = prefix .. ns.CONSTANTS.COLORS.BOE .. "[BOE]|r "
                            end

                            local link = itemData.link
                            local suffix = ""

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
                                
                                suffix = " " .. ns.CONSTANTS.COLORS.HOLDER .. "(" .. classColor .. holderName .. ns.CONSTANTS.COLORS.HOLDER .. typeStr .. ")|r"
                            end
                            
                            local fullText = prefix .. link .. suffix
                            table.insert(RLC.lootHistoryData, { text = fullText, link = link, data = itemData, prefix = prefix })
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
        
        if row.hitBox then
            if rowData.link and rowData.prefix then
                row.text:SetText(rowData.prefix)
                local prefixWidth = row.text:GetStringWidth()
                
                row.text:SetText(rowData.link)
                local linkWidth = row.text:GetStringWidth()
                
                row.text:SetText(rowData.text)
                
                row.hitBox:ClearAllPoints()
                row.hitBox:SetPoint("LEFT", row.text, "LEFT", prefixWidth, 0)
                row.hitBox:SetWidth(linkWidth)
                row.hitBox:SetHeight(ns.CONSTANTS.UI.HISTORY_ROW_HEIGHT)
                row.hitBox:Show()
            else
                row.hitBox:Hide()
            end
        end
        
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

function RLC:OnHistoryRowEnter(row, anchor)
    if row.data and row.data.link then
        -- pcall 保护：RatingBuster/StatLogic 等 tooltip 钩子在此客户端可能报错
        -- （其内部 StatLogicTooltip 有行未设字体），不影响本体 tooltip 显示
        pcall(function()
            GameTooltip:SetOwner(anchor or row, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(row.data.link)
        end)
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
local selectedManualItems = {}   -- 手动添加多选：点击切换选中，保存时批量加入历史
local manualAddMode = "add"   -- "add" or "block"

-- 判断指定数据是否已被选中（用于高亮与切换）
local function IsManualItemSelected(data)
    if not data then return false end
    for _, item in ipairs(selectedManualItems) do
        if item == data then return true end
    end
    return false
end

local function GetManualAddRow(parent, index)
    if not manualAddRows[index] then
        local rowName = "RLC_ManualAddRow_" .. index
        -- Reuse the loot selection row template as it fits well (Item Name + Details)
        local row = CreateFrame("Button", rowName, parent, "RLC_LootSelectionRowTemplate")
        -- Adjust font strings if needed, but defaults should be okay
        row.itemText = _G[rowName.."Item"]
        row.detailsText = _G[rowName.."Boss"] -- We can use this for ilvl or type
        row.itemHitBox = _G[rowName.."ItemHitBox"]
        
        -- Override OnClick to point to our handler
        row:SetScript("OnClick", function(self)
             RLC:OnManualAddRowClick(self)
        end)

        -- 模板里 itemHitBox 的 OnClick 默认指向拾取分配的选择处理（OnLootSelectionRowClick），
        -- 手动添加复用了该模板；itemHitBox 覆盖在物品名区域，若不改指，
        -- 点击物品名会走错处理器 → selectedManualItem 不注册、保存报"请选择一件装备"。
        if row.itemHitBox then
            row.itemHitBox:SetScript("OnClick", function(self)
                RLC:OnManualAddRowClick(self:GetParent())
            end)
        end

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
    manualAddMode = "add"
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

function RLC:OnBlockClick()
    manualAddMode = "block"
    if _G["RLCManualAddFrameTitle"] then
        _G["RLCManualAddFrameTitle"]:SetText(L["TITLE_BLOCK"] or "Block Items")
    end
    if _G["RLCManualAddFrameSaveButton"] then
        _G["RLCManualAddFrameSaveButton"]:SetText(L["BUTTON_BLOCK"] or "Block")
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

function RLC:OnUnblockClick()
    manualAddMode = "unblock"
    if _G["RLCManualAddFrameTitle"] then
        _G["RLCManualAddFrameTitle"]:SetText(L["TITLE_UNBLOCK"] or "Block List")
    end
    if _G["RLCManualAddFrameSaveButton"] then
        _G["RLCManualAddFrameSaveButton"]:SetText(L["BUTTON_UNBLOCK"] or "Unblock")
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
    selectedManualItems = {}
    print("[RLC Debug] RefreshManualAddList started, mode=" .. manualAddMode)

    if manualAddMode == "unblock" then
        -- Show currently blocked items from DB
        if RaidLootCounterDB.blockedItems then
            for itemID, itemLink in pairs(RaidLootCounterDB.blockedItems) do
                if itemLink then
                    local _, _, quality, iLevel = GetItemInfo(itemLink)
                    table.insert(manualAddData, {
                        link = itemLink,
                        quality = quality or 4,
                        iLevel = iLevel or 0,
                        isBOE = ns.IsItemBOE(itemLink)
                    })
                end
            end
        end
    else
        -- Scan bags for Epic (4) or Legendary (5) items
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            print("[RLC Debug] Bag " .. bag .. ": " .. numSlots .. " slots")
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
                        print("[RLC Debug] Found Epic+ item: " .. link)
                        -- Skip blocked items
                        local itemID = ns.LootUtil.GetItemID(link)
                        local isBlocked = itemID and RaidLootCounterDB.blockedItems and RaidLootCounterDB.blockedItems[itemID]
                        if not isBlocked then
                            -- Check for BOE
                            local isBOE = ns.IsItemBOE(link)
                            print("[RLC Debug] Item BOE=" .. tostring(isBOE) .. ", adding to list")
                            
                            table.insert(manualAddData, {
                                link = link,
                                bag = bag,
                                slot = slot,
                                quality = quality,
                                iLevel = iLevel or 0,
                                isBOE = isBOE,
                                uid = (bag and slot and GetItemUID) and GetItemUID(bag, slot) or nil
                            })
                        end
                    end
                end
            end
        end
        print("[RLC Debug] Scan complete, found " .. #manualAddData .. " items")
    
    -- Sort by quality desc, then name
    table.sort(manualAddData, function(a, b)
        if a.quality == b.quality then
             return (a.link or "") < (b.link or "")
        end
        return a.quality > b.quality
    end)
    end
    
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
            
            local prefix = ""
            
            -- Tier info
            local tier = ns.GetItemTier(data.link)
            if tier then
                prefix = prefix .. ns.CONSTANTS.COLORS.BOSS .. "[" .. tier .. "]|r "
            end
            
            -- BOE info
            if data.isBOE then
                prefix = prefix .. ns.CONSTANTS.COLORS.BOE .. "[BOE]|r "
            end
            
            local link = data.link
            local displayText = prefix .. link
            
            row.itemText:SetText(displayText)
            local uid = data.uid or ns.LootUtil.GetItemID(data.link)
            row.detailsText:SetText("iLvl: " .. (data.iLevel or "?") .. " | UID: " .. (uid or "?"))

            if row.itemHitBox then
                 row.itemText:SetText(prefix)
                 local prefixWidth = row.itemText:GetStringWidth()
                 
                 row.itemText:SetText(link)
                 local linkWidth = row.itemText:GetStringWidth()
                 
                 row.itemText:SetText(displayText)
                 
                 row.itemHitBox:ClearAllPoints()
                 row.itemHitBox:SetPoint("LEFT", row.itemText, "LEFT", prefixWidth, 0)
                 row.itemHitBox:SetWidth(linkWidth)
                 row.itemHitBox:SetHeight(ns.CONSTANTS.UI.MANUAL_ADD_ROW_HEIGHT)
                 row.itemHitBox:Show()
            end
            
            -- Fix: Correctly position rows relative to the frame content area
            -- The scroll frame is anchored at TOPLEFT x=20, y=-50
            -- We should position rows relative to the scroll frame's content or similar anchor
            -- Since we are attaching to Parent (Main Frame), we need to offset manually to match the scroll area
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i-1)*ns.CONSTANTS.UI.MANUAL_ADD_ROW_HEIGHT))
            row:SetWidth(760) 
            
            -- Update Highlight
            if IsManualItemSelected(data) then
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
    
    -- 切换选中：已在选中集合则移除（反选），否则加入（支持多选）
    local found = false
    for i, item in ipairs(selectedManualItems) do
        if item == row.data then
            table.remove(selectedManualItems, i)
            found = true
            break
        end
    end
    if not found then
        table.insert(selectedManualItems, row.data)
    end
    
    -- 刷新该行高亮（选中高亮 / 反选取消）
    if row.highlight then
        if IsManualItemSelected(row.data) then
            row.highlight:Show()
        else
            row.highlight:Hide()
        end
    end
end

function RLC:OnManualAddSaveClick()
    print("[RLC Debug] OnManualAddSaveClick called, selected=" .. #selectedManualItems .. ", mode=" .. manualAddMode)
    if #selectedManualItems == 0 then
        print(ns.CONSTANTS.CHAT_PREFIX .. (L["MSG_NO_ITEM_SELECTED"] or "Please select an item first."))
        return
    end

    if manualAddMode == "unblock" then
        -- Unblock mode: remove selected items from blockedItems
        local unblockedCount = 0
        for _, item in ipairs(selectedManualItems) do
            local itemID = ns.LootUtil.GetItemID(item.link)
            if itemID and RaidLootCounterDB.blockedItems and RaidLootCounterDB.blockedItems[itemID] then
                RaidLootCounterDB.blockedItems[itemID] = nil
                unblockedCount = unblockedCount + 1
            end
        end

        print(ns.CONSTANTS.CHAT_PREFIX .. string.format(L["MSG_UNBLOCK_SUCCESS"] or "Unblocked %d items.", unblockedCount))

        -- Refresh History if shown
        if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
            RLC:RefreshLootHistory()
        end

        RLCManualAddFrame:Hide()
        return
    end

    if manualAddMode == "block" then
        -- Block mode: add selected items to blocked list
        if not RaidLootCounterDB.blockedItems then
            RaidLootCounterDB.blockedItems = {}
        end

        local blockedCount = 0
        for _, item in ipairs(selectedManualItems) do
            local itemID = ns.LootUtil.GetItemID(item.link)
            if itemID then
                RaidLootCounterDB.blockedItems[itemID] = item.link
                blockedCount = blockedCount + 1
            end
        end

        print(ns.CONSTANTS.CHAT_PREFIX .. string.format(L["MSG_BLOCK_SUCCESS"] or "Blocked %d items.", blockedCount))
        
        -- Refresh History if shown (blocked items will be filtered)
        if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
            RLC:RefreshLootHistory()
        end
        
        RLCManualAddFrame:Hide()
        return
    end

    -- Add mode: gather environment info
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

    -- Batch: add all selected items to one "Manual Add" boss entry
    local loot = {}
    for _, item in ipairs(selectedManualItems) do
        local uid = nil
        if item.bag and item.slot and GetItemUID then
            uid = GetItemUID(item.bag, item.slot)
        end
        table.insert(loot, {
            link = item.link,
            holder = nil,
            type = ns.CONSTANTS.LOOT_TYPE.UNASSIGN,
            isBOE = ns.IsItemBOE(item.link),
            uid = uid
        })
    end

    local guid = "Manual_" .. time() .. "_" .. math.random(1000)

    local lootData = {
        name = bossName,
        instance = instanceName .. difficultyName,
        loot = loot,
        timestamp = time()
    }

    if not RaidLootCounterDB.lootedBosses then
        RaidLootCounterDB.lootedBosses = {}
    end

    RaidLootCounterDB.lootedBosses[guid] = lootData

    print(ns.CONSTANTS.CHAT_PREFIX .. string.format(L["MSG_MANUAL_ADD_SUCCESS"] or "Added %d items to history.", #loot))

    -- Refresh History
    if RaidLootCounterLootHistoryFrame and RaidLootCounterLootHistoryFrame:IsShown() then
        RLC:RefreshLootHistory()
    end

    RLCManualAddFrame:Hide()
end
