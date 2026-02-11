# Raid Loot Counter (RLC)

**Raid Loot Counter** is a World of Warcraft (3.3.5a) addon designed to help raid leaders track loot distribution, manage rolls, and maintain a history of drops. It simplifies the process of ensuring fair loot distribution by tracking how many Main-Spec (MS) and Off-Spec (OS) items each raider has received.

## Features

### 1. Raid Tracking & Sync
- **One-Click Sync**: Quickly sync current raid members to the addon's database.
- **Class Grouping**: Automatically groups players by class for easy overview.
- **Loot Counts**: Displays the number of MS and OS items each player has received.

### 2. Automated Loot Logging
- **Boss & Chest Detection**: Automatically detects when a boss is looted or a chest is opened.
- **Item Filtering**: Records Epic and Legendary items (configurable quality threshold).
- **Difficulty Tracking**: Distinguishes between 10/25 Normal and Heroic modes.
- **Manual Add**: Manually add items from your bags to the loot history if they were missed or traded later.

### 3. Loot Assignment
- **Visual Assignment**: Click the `+` button next to a player's name to assign loot.
- **MS/OS Support**: Assign items as Main Spec (MS) or Off Spec (OS).
- **Smart Sorting**: The loot list prioritizes Main Spec items for easier selection.
- **Modification**: You can remove previously assigned items if a mistake was made.

### 4. Roll Management
- **Roll Capture**: Captures `/roll` results from raid chat.
- **Active Warning**: Prevents opening new roll windows if a capture is already in progress.
- **Smart Sorting**: Sorts rollers based on their loot history (players with fewer items get priority) and then by roll value.
- **Announcement**: Announces the winner and roll results to the raid channel.

### 5. Loot History
- **Detailed Log**: View a history of all drops, organized by instance, difficulty, and boss.
- **Holder Tracking**: Shows who received which item directly in the history view.
- **BOE & Tier Detection**: Highlights Bind-on-Equip items and Tier tokens.
- **Manual Entry**: Supports manually adding items to the history log via the "Manual Add" button.

### 6. Reporting
- **Raid Broadcast**: Broadcast the full loot distribution list to the raid channel with one click.
- **Auto-Announce**: Option to automatically announce loot updates when an item is assigned.

### 7. Window Management
- **Minimize/Pin**: Minimize the main window to a small "PIN" bar to save screen space while keeping it accessible.
- **Position Reset**: Built-in command (`/rlc reset`) to reset window positions if they get lost off-screen.
- **Center on Open**: Windows automatically center themselves when opened to prevent being lost off-screen.

## Installation

1. Download the addon.
2. Extract the `RaidLootCounter` folder to your WoW installation directory:
   `\Interface\AddOns\`
3. Restart the game or reload the UI.

## Usage

### Commands
- `/rlc`: Open the main window.
- `/rlc reset`: **Important**. Resets all window positions to the center of the screen. Use this if a window is missing.
- `/rlc debug`: Injects mock data for testing purposes.

### Basic Workflow
1. **Start Raid**: Click **Sync Raid** to load current members.
2. **Boss Kill**: Loot the boss. RLC will print detected items to the chat.
3. **Distribute**:
   - **Roll**: Click **Start Roll Capture**, ask for rolls, then click **Stop** to see results.
   - **Assign**: Find the winner in the list, click `+`, select the item, and choose **MS Save** or **OS Save**.
   - **Manual Add**: If an item wasn't detected, open Loot History -> Manual Add to insert it from your bag.
4. **End of Raid**: Click **Send Stats** to publish the loot summary.

## Supported Locales
- English (enUS)
- Simplified Chinese (zhCN)
- Traditional Chinese (zhTW)

## Author
Bowen
