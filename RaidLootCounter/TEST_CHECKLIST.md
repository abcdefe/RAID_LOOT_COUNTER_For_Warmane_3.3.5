# Raid Loot Counter - Test Checklist

Use this checklist to verify the functionality of the addon.

## 1. Setup & Initialization
- [ ] **Load Addon**: Launch WoW and ensure `RaidLootCounter` is enabled.
- [ ] **Slash Command**: Type `/rlc`.
    - [ ] Verify the window toggles open/closed.
- [ ] **Initial State**:
    - [ ] Window title is localized.
    - [ ] "Update immediately..." checkbox defaults to checked.

## 2. Basic UI Layout
- [ ] **Layout**: Window width ~800px.
- [ ] **Double Column**:
    - [ ] Join a raid. Click `Sync Raid`.
    - [ ] Verify members are split into two columns.
- [ ] **Object Pooling**:
    - [ ] Spam `Sync Raid` multiple times.
    - [ ] Verify no UI flickering or memory spikes.

## 3. Data Management
- [ ] **Sync Raid**:
    - [ ] Add/Kick members from raid. Click `Sync`. Verify list updates correctly.
- [ ] **Loot Tracking**:
    - [ ] Click `+`/`-`. Verify count updates.
- [ ] **Persistence Regression Test**:
    - [ ] Set "Update immediately" checkbox to **OFF**.
    - [ ] Click `Sync Raid`.
    - [ ] Verify checkbox remains **OFF**.
    - [ ] Click `Clear Data` -> `Confirm`.
    - [ ] Verify checkbox remains **OFF**.

## 4. Announcements
- [ ] **Format Verification**:
    - [ ] Enable "Update immediately".
    - [ ] Click `+` on a player.
    - [ ] **CRITICAL**: Verify message format is exactly:
      `{Name} - Add 1 - Total: {N}` (English) or `{Name} - 新增 1 - 总数: {N}` (Chinese).
- [ ] **Send Stats**:
    - [ ] Click `Send Stats`. Verify full raid warning report.

## 5. Roll Capture (New Feature)
- [ ] **Start/Stop**:
    - [ ] Click `Start Roll Capture`. Verify message "Roll capture started".
    - [ ] Click `Stop Roll Capture`. Verify message "Roll capture stopped" and results list.
- [ ] **Solo Testing**:
    - [ ] Not in a party/raid.
    - [ ] Type `/roll`.
    - [ ] Verify console prints: "Captured: {You} rolls {N} (1-100)".
- [ ] **Regex Robustness (Chinese)**:
    - [ ] Verify capture of message: `Xtails掷出78（1-100）`.
    - [ ] Verify capture of message: `Name 掷出 100 (1-100)`.
- [ ] **Regex Robustness (English)**:
    - [ ] Verify capture of message: `Name rolls 50 (1-100)`.

## 6. Localization
- [ ] **zhCN**:
    - [ ] Verify UI is Chinese.
    - [ ] Verify Roll Capture works with Chinese system messages.
    - [ ] Verify Raid Warnings use Chinese prefixes (新增/移除/总数).
- [ ] **enUS**:
    - [ ] Verify UI is English.
    - [ ] Verify Roll Capture works with English system messages.
