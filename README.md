# Raid Loot Counter (WoW 3.3.5a)

A simple, robust addon for tracking loot distribution in raids. Designed for Warmane (WotLK 3.3.5a).

## Features

- **Raid Member Sync**: Automatically populates the list from the current raid roster, grouped by class.
- **Loot Tracking**: +/- buttons to track items received per player.
- **Auto Announce**: (Optional) Automatically sends a Raid Warning whenever a player receives an item.
    - Format: `{Name} - 新增 1 - 总数: {Total}`
- **Roll Capture**: Captures `/roll` results from chat, sorts them by value, and identifies the winner. Supports both English and Chinese clients.
- **Double Column UI**: Efficient use of screen space for 25-man raids.
- **Persistence**: Data is saved between sessions.
- **Localization**: Supports enUS, zhCN (Simplified Chinese), and zhTW (Traditional Chinese).

## Usage

1. **Open Window**: Type `/rlc` or `/raidlootcounter`.
2. **Sync**: Click "Sync Raid" to load current raid members.
3. **Track**: Click `+` when a player wins an item.
    - If "Auto Announce" is checked, a raid warning is sent instantly.
4. **Rolls**: 
    - Click "Start Roll Capture" before asking for rolls.
    - Click "Stop Roll Capture" after rolls are done. The winner and all rolls will be printed to your chat window.
5. **Report**: Click "Send Stats" to broadcast the full loot table to Raid Warning channel at the end of the raid.

## Installation

1. Download and extract to `Interface/AddOns/RaidLootCounter`.
2. Ensure the folder structure is correct (`Interface/AddOns/RaidLootCounter/RaidLootCounter.toc` exists).
3. Enable in character selection screen.

## Localization Note

This addon is optimized for players using Chinese clients (zhCN) on English servers (like Warmane).
- **UI**: Localized to your client language.
- **Chat Capture**: Supports both "Name rolls..." (English) and "Name掷出..." (Chinese) formats.
- **Broadcasts**: Uses bilingual or clear formats suitable for international groups.

## Troubleshooting

- **Regex Issues**: If roll capture fails, ensure you are using the latest version with updated regex patterns for Chinese clients.
- **Checkbox Reset**: The "Auto Announce" setting is preserved across sessions and is NOT cleared when clicking "Clear Data".
