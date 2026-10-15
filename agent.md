# RaidLootCounter - 项目代理指南

> 供 AI 代理协作用此代码库的综合参考文档。

## 1. 项目概述

**类型：** 魔兽世界 3.3.5a (WotLK) 插件
**版本：** 1.2.9
**目的：** 团队拾取管理插件，追踪 MS/OS（主天赋/副天赋）装备分配、Roll 点捕获，以及全团统计信息。

## 2. 文件结构

```
RaidLootCounter/
├── RaidLootCounter.toc          # 插件清单（Interface: 30300，SavedVariablesPerCharacter）
├── RaidLootCounter.xml          # 所有 XML UI 框架定义
├── Constants.lua                # 共享常量、Chat/LootUtil 工具模块
├── RLC_DB.lua                   # 数据库模块 (DB) - SavedVariables 管理
├── RLC_Roll.lua                 # Roll 点模块 (Roll) - Roll 点捕获与解析
├── RaidLootCounter.lua          # 主入口 - UI 逻辑、事件处理、初始化
├── LootLogger.lua               # LOOT_OPENED 事件处理 - 自动拾取扫描
├── LootHistory.lua              # 掉落历史 UI、Mock 数据、手动添加系统
└── locate/
    ├── Localization.lua         # L 表初始化
    ├── enUS.lua                 # 英文本地化（默认）
    ├── zhCN.lua                 # 简体中文（GetLocale ~= zhCN 守卫）
    └── zhTW.lua                 # 繁体中文（GetLocale ~= zhTW 守卫）
```

## 3. 模块架构与依赖

### 加载顺序（来自 .toc，至关重要）
1. `locate/Localization.lua` — 创建 `ns.L = {}`
2. `locate/enUS.lua` — 用英文默认值填充 `L`
3. `locate/zhCN.lua` / `locate/zhTW.lua` — 本地化守卫式覆盖
4. `Constants.lua` — 定义 `ns.CONSTANTS`、`ns.Chat`、`ns.LootUtil`、`ns.ItemCache`
5. `RLC_DB.lua` — 定义 `ns.DB`（需要 `ns.CONSTANTS.LOOT_TYPE`）
6. `RLC_Roll.lua` — 定义 `ns.Roll`（需要 `ns.Chat`、`ns.CONSTANTS`）
7. `RaidLootCounter.xml` — XML UI 框架
8. `RaidLootCounter.lua` — 主逻辑（需要上述全部）
9. `LootHistory.lua` — 历史 UI + 手动添加（需要 `ns.CONSTANTS`、`ns.GetItemTier`、`ns.IsItemBOE`）
10. `LootLogger.lua` — 拾取扫描（需要 `ns.CONSTANTS`、`ns.LootUtil`、`ns.IsItemBOE`）

### 模块命名空间

| 命名空间 | 定义位置 | 导出内容 |
|-----------|-----------|---------|
| `ns` | 所有文件通过 `local addonName, ns = ...` | 共享插件私有表 |
| `RLC` | `RaidLootCounter.lua`（全局） | UI 界面 API，供 XML 处理程序调用 |
| `ns.L` | `Localization.lua` | 本地化键 |
| `ns.CONSTANTS` | `Constants.lua` | 职业颜色、拾取配置、UI 常量、模式 |
| `ns.Chat` | `Constants.lua` | `SendRaidOrPrint()`、`SendWrapped()` |
| `ns.LootUtil` | `Constants.lua` | `GetItemID()`、`IsItemExcluded()`、`NormalizeLootItem()` |
| `ns.DB` | `RLC_DB.lua` | `Init()`、`ClearAllData()`、`SyncRaidMembers()`、`AddLoot()`、`RemoveLoot()` 等 |
| `ns.Roll` | `RLC_Roll.lua` | `Start()`、`StopAndAnnounce()`、`IsActive()` |
| `ns.ItemCache` | `Constants.lua` | 物品属性缓存（BOE、套装等级） |

## 4. SavedVariables 数据结构

**变量：** `RaidLootCounterDB`（SavedVariablesPerCharacter）

```lua
RaidLootCounterDB = {
    meta = { version = 1 },
    players = {
        ["玩家名"] = {
            msCount = number,    -- 主天赋拾取计数
            osCount = number,    -- 副天赋拾取计数
            class = "WARRIOR",   -- 职业文件名
        },
    },
    lootedBosses = {
        ["GUID"] = {
            name = "Boss 名称 (25H)",
            instance = "Icecrown Citadel",
            timestamp = number,
            loot = {
                {
                    link = "物品链接字符串",
                    holder = "玩家名" or nil,
                    type = "MS" | "OS" | "UNASSIGN",
                    isBOE = boolean,
                },
            },
        },
    },
    distroMode = "MS+1" | "MS>OS",
    autoAnnounce = boolean,
    stopRollCountdown = boolean,
}
```

### 数据迁移路径
- `RLC_DB.lua` 中的 `MigrateToV1()`：将顶级玩家数据移入 `players` 表，将 `count` 字段转换为 `msCount`/`osCount`。
- 当前数据库版本：1（`CURRENT_DB_VERSION`）

## 5. 数据流

### 拾取扫描（LootLogger.lua）
```
LOOT_OPENED 事件
  → 检查 IsInInstance() == "raid"
  → 获取目标 GUID 或生成箱子签名
  → 检查 GUID 是否已记录
  → 扫描 GetLootSlotInfo() 中的史诗(4)+品质物品
  → 过滤被排除的物品（Nexus Crystal、Abyss Crystal、Greater Planar Essence）
  → 通过 ns.IsItemBOE() 标记 BOE 属性
  → 存入 RaidLootCounterDB.lootedBosses[GUID]
  → 刷新掉落历史（如果窗口已打开）
```

### 拾取分配流程
```
玩家点击玩家行的 +/-
  → RLC:ShowLootSelection(playerName, mode)
  → 过滤未分配的拾取物品供显示
  → 玩家选择物品 → 点击保存（MS/OS/移除）
  → RLC:PerformAssignment(isOS)
    → 更新 lootItem.holder 和 lootItem.type
    → DB.AddLoot(playerName, isOS)
    → RLC:RefreshDisplay()
    → RLC:SendLootUpdate()（如果启用自动通报）
    → 刷新掉落历史（如果已打开）
```

### Roll 点捕获流程
```
玩家点击"开启 Roll 捕获"
  → RLC:ShowLootSelection(nil, ROLL 模式)
  → 玩家选择物品 → 点击 MS Roll / OS Roll
  → Roll.Start(itemLink, LOOT_TYPE)
    → 注册 CHAT_MSG_SYSTEM 事件
    → ProcessRollMessage() 解析"玩家 roll X (min-max)"
    → 仅接受团队成员（IsGroupMember 检查）
  → 玩家点击"停止 Roll 捕获"
  → Roll.StopAndAnnounce()
    → 注销事件
    → EnrichResults() 用 msCount/osCount/class 丰富结果
    → SortResults() 根据 distroMode 排序
    → BuildWinners() 检测并列
    → 发送到 RAID_WARNING 频道
```

## 6. 事件系统

| 事件 | 注册位置 | 处理程序 |
|-------|--------------|---------|
| `ADDON_LOADED` | `RaidLootCounter.lua` | `OnAddonLoaded` — 数据库初始化、UI 初始化、小地图图标、斜杠命令 |
| `LOOT_OPENED` | `LootLogger.lua` | `OnLootOpened` — 扫描拾取，记录 Boss/箱子数据 |
| `CHAT_MSG_SYSTEM` | `RLC_Roll.lua`（动态） | Roll 点捕获 — 捕获期间解析 roll 点消息 |

## 7. 斜杠命令

| 命令 | 作用 |
|---------|--------|
| `/rlc` | 切换主窗口 |
| `/rlc reset` | 重置所有窗口位置到屏幕中央 |
| `/rlc debug` | 注入 mock 测试数据 |
| `/rlc clear` | 等同于"清空数据"按钮 |

## 8. UI 框架层级

| 框架 | 用途 | XML 定义 |
|-------|---------|----------------|
| `RaidLootCounterFrame` | 主窗口 — 玩家列表、控件 | `RaidLootCounter.xml` |
| `RLCScrollFrame` | 主窗口内的可滚动玩家列表 | `RaidLootCounter.xml` |
| `RLCLootSelectionFrame` | 分配/移除/Roll 点拾取选择 | `RaidLootCounter.xml` |
| `RaidLootCounterLootHistoryFrame` | 掉落历史显示 | `RaidLootCounter.xml` |
| `RLCManualAddFrame` | 手动添加物品（扫描背包） | `RaidLootCounter.xml`（重复定义！） |
| `RLC_DistroModeFrame` | 分配模式选择 | `RaidLootCounter.xml` |
| `RLC_DINFrame` | 最小化悬浮图标 | `RaidLootCounter.xml` |

### 玩家行模板（`RLC_PlayerRowTemplate`）
- 名称显示（职业颜色）
- MS 计数显示
- OS 计数显示
- 减号按钮（移除拾取）
- 加号按钮（分配拾取）

### 对象池
- `playerFramePool` — 玩家行框架池
- `classHeaderPool` — 职业标题框架池
- `lootSelectionRows` — 拾取选择行池
- `historyRows` — 历史行池
- `manualAddRows` — 手动添加行池

## 9. 分配模式

| 模式 | 逻辑 | 排序顺序 |
|------|-------|-----------|
| `MS+1` | MS 拾取优先分配给 MS 次数较少的玩家；OS 按 roll 点值 | MS：MS 计数少者优先，然后 roll 点高者。OS：roll 点高者。 |
| `MS>OS` | 纯 roll 点值，无 MS/OS 偏向 | roll 点高者胜。 |

## 10. 本地化系统

- `enUS.lua` 无条件加载（提供默认值）
- `zhCN.lua` / `zhTW.lua` 通过 `if GetLocale() ~= "zhCN" then return end` 守卫
- 键使用 `L["KEY"]` 语法贯穿代码
- 复杂数据（INSTANCE_ABBREVIATIONS、TIER_PATTERNS、TIER_SETS）也进行了本地化
- `ns.CONSTANTS.INSTANCE_ABBREVIATIONS` = `ns.L["INSTANCE_ABBREVIATIONS"] or {}`
- `ns.CONSTANTS.TIER_PATTERNS` = `ns.L["TIER_PATTERNS"] or {}`

## 11. 已知问题与技术债务

### 代码问题
1. **重复 XML 定义**：`RLCManualAddFrame` 在 `RaidLootCounter.xml` 中定义了两次（第 551-635 行和第 795-879 行）。第二个定义会覆盖第一个。
2. **死代码**：`RaidLootCounter.lua`（第 219 行）中的 `GetRaidMembers()` 返回 nil — 这是一个存根。实际逻辑在 `RLC_DB.lua` 中。
3. **未使用的变量**：`RaidLootCounter.lua`（第 133-135 行）中声明的 `isRollCapturing`、`rollResults`、`rollCaptureFrame` 未使用 — 实际逻辑在 `RLC_Roll.lua` 中。
4. **重复的 OnKeyDown**：`OnAddonLoaded` 注册了两次相同的 ESCAPE 处理程序（第 1095-1106 行）。
5. **未使用的函数**：`Announce()`（第 250 行）已定义但从未调用。
6. **缺少 `/rlc clear` 实现**：斜杠命令文档提到 `/rlc clear`，但 `SlashCmdList` 中的实现未处理 "clear" 消息字符串。
7. **`local function` 在使用之前定义**：`Announce()` 是 local 的，但在可能调用它的某些函数之后才定义 — Lua 的 local 作用域意味着它不可见。

### 架构隐患
1. **XML/Lua 耦合**：XML OnClick 处理程序调用全局 `RLC:` 方法。耦合较紧，但对 WoW 插件来说很常见。
2. **FauxScrollFrame 性能**：`LootHistory.lua` 每次刷新都重建整个显示列表。当前规模下可接受。
3. **共享的 Tooltip 扫描器**：`IsItemBOE` 和 `GetItemTier` 使用单个 `tooltipScanner` 框架。概念上不是线程安全的，但 WoW 是单线程的。
4. **跨服务器玩家名**：`RLC_Roll.lua` 中的 `IsGroupMember` 处理 `玩家-服务器` 格式，但如果服务器名包含特殊字符可能会失败。

### 数据库隐患
1. **lootedBosses 无大小限制**：可能跨多个副本无限增长。没有清理机制。
2. **无按会话重置**：数据跨副本持久化，除非手动清除。
3. **箱子的字符串 GUID**：`Chest_` 前缀的 GUID 使用区域+难度作为签名 — 相同区域/难度的箱子不会被重新记录。

## 12. 关键 API 函数参考

### ns.DB (RLC_DB.lua)
| 函数 | 描述 |
|----------|-------------|
| `DB.Init()` | 初始化/迁移 SavedVariables |
| `DB.ClearAllData()` | 清除玩家和 lootedBosses |
| `DB.IsEmpty()` | 检查玩家表是否为空 |
| `DB.SyncRaidMembers()` | 同步团队名单，返回（新增，移除）计数 |
| `DB.GetPlayerItems(playerName)` | 获取玩家已分配的物品 |
| `DB.AddLoot(playerName, isOS)` | 递增 MS/OS 计数 |
| `DB.RemoveLoot(playerName, isOS)` | 递减 MS/OS 计数（最小值 0） |
| `DB.SetDistroMode(mode)` | 设置分配模式 |
| `DB.GetDistroMode()` | 获取分配模式 |

### ns.Chat (Constants.lua)
| 函数 | 描述 |
|----------|-------------|
| `Chat.SendRaidOrPrint(msg, channel)` | 发送到团队频道，如果单人则打印 |
| `Chat.SendWrapped(prefix, items, channel, indent)` | 发送多物品列表，250 字符换行 |

### ns.LootUtil (Constants.lua)
| 函数 | 描述 |
|----------|-------------|
| `LootUtil.GetItemID(itemLink)` | 从链接中提取数字物品 ID |
| `LootUtil.IsItemExcluded(itemLink)` | 检查物品是否应被排除 |
| `LootUtil.NormalizeLootItem(lootTable, index)` | 确保拾取物品具有正确的结构 |

### ns.Roll (RLC_Roll.lua)
| 函数 | 描述 |
|----------|-------------|
| `Roll.Start(itemLink, rollType)` | 为 MS/OS 开始 Roll 点捕获 |
| `Roll.StopAndAnnounce()` | 停止捕获，排序结果，通报获胜者 |
| `Roll.IsActive()` | 检查捕获是否活跃 |

### RLC (RaidLootCounter.lua) — 全局
| 函数 | 描述 |
|----------|-------------|
| `RLC:RefreshDisplay()` | 重绘主玩家列表 |
| `RLC:RefreshLootHistory()` | 重绘掉落历史 |
| `RLC:ShowLootSelection(playerName, mode)` | 打开拾取选择窗口 |
| `RLC:UpdateLootSelectionScroll()` | 更新选择滚动框架 |
| `RLC:UpdateManualAddScroll()` | 更新手动添加滚动框架 |
| `RLC:UpdateDistroModeUI()` | 更新分配模式单选按钮 |
| `RLC:OnSyncClick()` | 同步团队成员 |
| `RLC:OnPlusClick(parentFrame)` | 为玩家分配拾取 |
| `RLC:OnMinusClick(parentFrame)` | 移除玩家的拾取 |
| `RLC:SendToRaid()` | 发送完整统计到团队频道 |
| `RLC:SendLootUpdate(...)` | 发送单个玩家更新 |
| `RLC:PerformAssignment(isOS)` | 执行拾取分配 |
| `RLC:ToggleDistroMode()` | 切换分配模式窗口 |
| `RLC:OnStartRollCaptureClick()` | 开始 Roll 点捕获 |
| `RLC:OnStopRollCaptureClick()` | 停止 Roll 点捕获 |
| `RLC:InjectMockData()` | 注入测试数据 |
| `RLC:ResetMockData()` | 清除 Mock 数据（占位符） |

## 13. 常量参考

### 拾取类型（ns.CONSTANTS.LOOT_TYPE）
- `MS` = "MS" — 主天赋
- `OS` = "OS" — 副天赋
- `UNASSIGN` = "UNASSIGN" — 尚未分配

### 模式（ns.CONSTANTS.MODES）
- `ASSIGN` = "ASSIGN" — 分配拾取
- `UNASSIGN` = "UNASSIGN" — 移除拾取
- `ROLL` = "ROLL" — Roll 点捕获

### UI 尺寸（ns.CONSTANTS.UI）
| 常量 | 值 | 描述 |
|----------|-------|-------------|
| HISTORY_MAX_ROWS | 35 | 掉落历史中的可见行数 |
| HISTORY_ROW_HEIGHT | 16 | 掉落历史中的行高 |
| SELECTION_MAX_ROWS | 12 | 拾取选择中的可见行数 |
| SELECTION_ROW_HEIGHT | 25 | 拾取选择中的行高 |
| MANUAL_ADD_MAX_ROWS | 10 | 手动添加中的可见行数 |
| MANUAL_ADD_ROW_HEIGHT | 25 | 手动添加中的行高 |

### 被排除的物品（ns.CONSTANTS.LOOT_CONFIG.EXCLUDED_ITEM_IDS）
- 20725: Nexus Crystal（节点水晶）
- 34057: Abyss Crystal（深渊水晶）
- 22450: Greater Planar Essence（大地底精华）

### 最低品质
- `MIN_QUALITY = 4`（史诗）— 仅记录史诗及以上物品

## 14. 近期重要变更（来自 CHANGELOG）

### v1.2.6（2026-02-12）
- **精确 Tooltip 触发区域**：重构列表渲染逻辑，物品 Tooltip 仅在鼠标精确悬停在物品链接文本上时显示。
- **代码重构**：优化 `LootHistory.lua` 和 `RaidLootCounter.lua` 中的滚动更新逻辑。

### v1.2.6（2026-02-11）
- **手动添加装备系统**：在"掉落历史"窗口右上角新增"手动添加"按钮，自动扫描背包中史诗及以上品质的装备。
- **套装识别**：支持识别 T7/T8/T9/T10 套装部件，并标记 `[T9]` 等前缀。
- **BOE 标记**：自动检测装备绑定属性，标记 `[BOE]`。
- **Roll 点捕获优化**：状态保护，防止多次同时捕获。
- **窗口位置管理**：每次打开窗口自动重置到屏幕中央。
- **多语言支持**：完善繁体中文本地化，优化 T9 套装识别逻辑。

### v1.2.0（2026-02-10）
- **窗口管理系统**：最小化模式（`-` 按钮 + RLC-PIN 悬浮条）、快速恢复、`/rlc reset` 命令。
- **装备分配优化**：MS 装备自动置顶。
- **问题修复**：空指针保护、Mock 数据注入优化、UI 健壮性增强。

### v1.1.0（2026-02-01）
- **Roll 点捕获功能**：新增"开启/停止 roll 捕获"按钮，支持监听团队 roll 点聊天消息。
- **解析与排序**：自动解析 roll 点结果，前三名金银铜颜色标识。
- **跨服务器支持**：修复服务器名处理问题，正确匹配跨服团队成员名称。
- **UI 布局优化**：重新排列按钮顺序，优化视觉层次。

### v1.0.1（2026-02-01）
- **修复点击"+"按钮导致列表消失**：使用局部变量替代闭包变量。
- **修复清空数据后职业标题残留**：遍历所有 Region 清除 FontString。
- **优化同步团队功能**：保留已有成员的拾取记录。
- **优化发送格式**：`{人名} - {Add/Remove} {数量} - {更新后总数}`。

## 15. 开发指南

1. **始终使用 `ns.L["KEY"]`** 处理面向用户的文本 — 绝不硬编码字符串。
2. **使用 `ns.CONSTANTS`** 处理共享值 — 不要在多个文件中重新定义常量。
3. **使用 `ns.Chat.SendRaidOrPrint()`** 发送团队消息 — 绝不调用 `SendChatMessage`。
4. **访问拾取物品时使用 `ns.LootUtil.NormalizeLootItem()`** — 处理旧版字符串格式。
5. **在 `ns.ItemCache` 中缓存物品属性** 以避免重复的 Tooltip 扫描。
6. **用 nil 检查保护 UI 元素访问** — WoW 框架在初始化期间可能尚不存在。
7. **为动态创建的 UI 元素使用对象池**（遵循 `playerFramePool` 模式）。
8. **使用 `CreateFrame` 注册事件** — 每个文件使用专用的事件框架。
9. **遵循加载顺序** — 新文件必须在其依赖之后添加到 `.toc` 中。
10. **在提交拾取/历史系统更改前使用 `/rlc debug` 测试**。
11. **每次刷新列表时注意重绘成本** — `FauxScrollFrame` 会重建整个显示列表。
12. **手动添加系统使用"手动添加"作为 Boss 名称** — 注意历史记录中的归类逻辑。
