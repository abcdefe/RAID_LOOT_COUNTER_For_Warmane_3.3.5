# 团队拾取计数器 - 更新日志

## 最新修复 (2026-02-01)

### 🐛 Bug修复

#### 1. 修复点击"+"按钮导致列表消失的问题
**问题原因**：
- 按钮点击事件中使用了闭包变量 `player.name`
- 在 RefreshDisplay 后，闭包变量可能指向已清除的临时对象

**解决方案**：
- 在创建按钮前，将 `player.name` 保存到局部变量 `currentPlayerName`
- 按钮点击事件使用局部变量而非闭包变量
- 增加数据存在性检查 `if RaidLootCounterDB[currentPlayerName]`
- 在调用 RefreshDisplay 前先获取新的计数值

**修复代码**：
```lua
local currentPlayerName = player.name  -- 保存到局部变量

plusBtn:SetScript("OnClick", function()
    if RaidLootCounterDB[currentPlayerName] then  -- 检查数据存在
        AddLoot(currentPlayerName)
        local newCount = RaidLootCounterDB[currentPlayerName].count
        RLC:RefreshDisplay()
        RLC:SendLootUpdate(currentPlayerName, newCount, true)
    end
end)
```

#### 2. 修复清空数据后职业标题残留的问题
**问题原因**：
- 职业标题是 FontString 对象，不是 Frame
- 原清除逻辑只清除了 Frame 子元素，没有清除 FontString

**解决方案**：
- 增加对所有 Region 的遍历
- 专门清除 FontString 类型的对象
- 数据为空时，直接返回不创建任何UI元素

**修复代码**：
```lua
-- 清除所有FontString
local regions = {scrollChild:GetRegions()}
for _, region in ipairs(regions) do
    if region:GetObjectType() == "FontString" then
        region:Hide()
        region:SetText("")
        region:SetParent(nil)
    end
end

-- 数据为空时直接返回
if not hasData then
    scrollChild:SetHeight(1)
    return
end
```

#### 3. 优化同步团队功能
**改进内容**：
- 同步时保留已有成员的拾取记录
- 只有新成员才初始化为 0
- 显示新增成员数量提示
- 增加不在团队时的错误提示

#### 4. 优化发送格式
**更新内容**：
- 单次更新格式：`{人名} - {Add/Remove} {数量} - {更新后总数}`
- 示例：`张三 - Add 1 - 5`

### ✅ 功能验证

所有功能已测试通过：
- ✅ 点击"+"按钮：正常增加，列表正常显示
- ✅ 点击"-"按钮：正常减少，列表正常显示
- ✅ 点击"同步团队"：正确合并数据，显示新增人数
- ✅ 点击"新增成员"：正确添加到列表并显示
- ✅ 点击"清空数据"：完全清空，无残留
- ✅ 点击"发送统计"：正确发送到团队聊天

### 📝 注意事项

1. **闭包变量问题**：在循环中创建回调函数时，务必使用局部变量保存循环变量的值
2. **UI清除**：WoW的UI元素包括Frame和Region两大类，清除时要分别处理
3. **数据检查**：在访问数据库前先检查数据是否存在，避免nil错误

---

## 历史版本

### v1.0 (初始版本)
- 基础团队拾取统计功能
- 职业分组显示
- 数据持久化存储
