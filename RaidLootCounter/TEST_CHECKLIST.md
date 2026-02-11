# RLC Test Checklist

## 1. Installation & Initialization
- [ ] **Load Addon**: Verify addon loads without Lua errors on login.
- [ ] **Command Check**: Type `/rlc` and verify the main window opens centered.
- [ ] **Reset Command**: Drag window to a corner, type `/rlc reset`, verify it returns to center.

## 2. Raid Management
- [ ] **Sync Raid (Empty)**: Click "Sync Raid" when solo. Should show 1 player (yourself).
- [ ] **Sync Raid (Group)**: Join a raid group, click "Sync Raid". Verify all members appear and are grouped by class.
- [ ] **Clear Data**: Click "Clear Data", confirm dialog. Verify list is empty.

## 3. Loot Detection (Mock)
- [ ] **Inject Mock Data**: Type `/rlc debug`. Verify:
  - Chat message "Found new boss loot..." appears.
  - "Loot History" window populates with mock data (ICC/RS bosses).
- [ ] **Real Loot (In-Game)**: Open a boss loot window. Verify chat output lists the items.

## 4. Loot Assignment
- [ ] **Open Assign Window**: Click `+` next to a player name. Verify "Assign Loot: [PlayerName]" window opens.
- [ ] **Window Position**: Verify the assignment window opens in the center (or resets with `/rlc reset`).
- [ ] **Select Item**: Click an item in the list. Verify it highlights.
- [ ] **Assign MS**: Click "MS Save".
  - Verify assignment window closes.
  - Verify player's MS count increments by 1.
  - Verify chat announcement (if enabled).
- [ ] **Assign OS**: Repeat for "OS Save". Verify OS count increments.
- [ ] **Remove Loot**: Click `-` next to player name.
  - Verify "Remove Loot" window opens.
  - Select item and click "Remove".
  - Verify count decrements.

## 5. Roll System
- [ ] **Start Capture**: Click "Start Roll Capture". Verify chat message.
- [ ] **Double Start Check**: Click "Start Roll Capture" again while one is running. Verify warning message appears (no new window).
- [ ] **Perform Rolls**:
  - Type `/roll 100` (yourself).
  - (Optional) Have others roll.
- [ ] **Stop Capture**: Click "Stop Roll Capture".
- [ ] **Verify Results**:
  - Chat should announce winner.
  - Logic check: Ensure players with *lower* MS/OS count win ties or are ranked higher if that logic is active.

## 6. Loot History
- [ ] **View History**: Click "View Loot".
- [ ] **Content Check**:
  - Verify instances and difficulties are grouped.
  - Verify items show "MS" or "OS" tags and the holder's name after assignment.
  - Verify tooltips work when hovering over items.

## 7. Manual Add (New Feature v1.3.0)
- [ ] **Open Window**: In "Loot History", click "Manual Add".
  - Verify "Manual Add" window opens centered.
- [ ] **Bag Scan**:
  - Verify list shows Epic/Legendary/Heirloom items from your bags.
  - Verify **[BOE]** tag appears for unbound items.
  - Verify **[T9]** (or other Tier) tag appears for set tokens.
- [ ] **Save Item**:
  - Select an item.
  - Click "Save".
  - Verify item appears in "Loot History" under Boss: "Manual Add".

## 8. Window Management
- [ ] **Minimize**: Click `-` button on the main window title bar.
  - Verify Main Window hides.
  - Verify "RLC-PIN" floating bar appears.
- [ ] **Drag Pin**: Drag the "RLC-PIN" bar. Verify it moves.
- [ ] **Maximize**: Click `+` on the "RLC-PIN" bar.
  - Verify Pin bar hides.
  - Verify Main Window reappears in the **center**.
- [ ] **Auto-Center**: Open "Loot History" or "Manual Add" windows. Verify they always appear in center of screen.

## 9. Localization
- [ ] **Switch Language**: Change game client language (if possible) or mock `GetLocale`.
- [ ] **Verify Strings**: Check titles and buttons match the active locale (zhCN/zhTW/enUS).
- [ ] **T9 Recognition**: In zhCN, verify "萨尔的征服头饰" is correctly identified as T9.
