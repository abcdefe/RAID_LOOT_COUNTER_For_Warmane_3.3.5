# Raid Loot Counter (WoW 3.3.5a)

A robust addon for tracking loot distribution in raids, designed for Warmane (WotLK 3.3.5a).

## Features

- **Raid Member Sync**: Automatically populates the list from the current raid roster, grouped by class.
- **Loot Tracking**: Track Main Spec (MS) and Off Spec (OS) loot counts per player.
- **Loot History**: 
  - Automatically records all boss kills and dropped items.
  - Displays drop times, item links, and assignments.
  - **Smart Detection**: Identifies Tier Tokens (T7-T10) and Bind-on-Equip (BOE) items.
  - **Class Colors**: Player names in history are colored by their class.
- **Loot Assignment System**:
  - Assign specific items to players directly from the drop list.
  - Support for "Roll" management linked to specific items.
- **Auto Announce**: (Optional) Automatically sends a Raid Warning whenever a player receives an item.
- **Roll Capture**: 
  - Captures `/roll` results from chat.
  - Sorts by value and identifies the winner.
  - Supports both English and Chinese clients.
- **Performance**: Uses virtual scrolling (FauxScrollFrame) to handle unlimited history and loot lists without performance impact.
- **Localization**: Fully localized for enUS, zhCN, and zhTW.

## Usage

### Basic Controls
1. **Open Window**: Type `/rlc` or `/raidlootcounter`.
2. **Sync**: Click "Sync Raid" to load current raid members.
3. **Report**: Click "Send Stats" to broadcast the full loot table to Raid Warning channel.

### Assigning Loot
1. Click the `+` button next to a player's name.
2. A window will appear listing recent unassigned loot.
3. Select an item (items are sorted chronologically).
   - **[Tier]** and **[BOE]** tags are displayed for relevant items.
4. Click **MS Save** (Main Spec) or **OS Save** (Off Spec).
5. The item is assigned to the player, and the count is updated.

### Removing Loot
1. Click the `-` button next to a player's name.
2. Select the item you want to remove from their history.
3. Click **Remove**.

### Rolling for Loot
1. Click **Start Roll Capture**.
2. Optionally, select an item from the list to associate the roll with it.
3. Ask raid members to roll.
4. Click **Stop Roll Capture** to announce the winner and results.

### Loot History
- Click **View Loot** to open the history window.
- View all drops organized by Instance and Boss.
- **Shift+Click** an item to link it in chat.
- Hover to see item details.

## Installation

1. Download and extract to `Interface/AddOns/RaidLootCounter`.
2. Ensure the folder structure is correct (`Interface/AddOns/RaidLootCounter/RaidLootCounter.toc` exists).
3. Enable in character selection screen.

## Localization Note

This addon is optimized for players using Chinese clients (zhCN) on English servers (like Warmane).
- **UI**: Localized to your client language.
- **Chat Capture**: Supports both "Name rolls..." (English) and "Name掷出..." (Chinese) formats.
