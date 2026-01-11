# Day of Defeat: Source - Chat to Discord

A SourceMod plugin that sends in-game chat logs to Discord via webhook when the game ends.

![Day of Defeat: Source](https://cdn2.steamgriddb.com/icon/2555b8e9861b4b0e141181b725fb1b3b/32/256x256.png)

## Features

- 📝 Captures all chat messages during gameplay (team chat and all chat)
- 🎮 Differentiates between teams (Allies/Axis) and spectators
- 💀 Shows if players were alive or dead when messaging
- 👥 Lists all players by team from 1 minute before game end
- 🔒 Includes Steam IDs for player identification
- 🎨 Beautiful Discord embed with custom images
- ⏰ Timestamps in European format (DD-MM-YYYY)
- 🧪 Test command to verify webhook connectivity

## Requirements

- SourceMod 1.10 or higher
- [RipExt Extension](https://github.com/ErikMinekus/sm-ripext) v1.3.2 or higher

## Installation

### 1. Install RipExt Extension

Download the latest version of RipExt from [GitHub Releases](https://github.com/ErikMinekus/sm-ripext/releases)

**For Windows:**
1. Extract `ripext.ext.dll` to `addons/sourcemod/extensions/`
2. Extract `ripext.ext.dll` (x64) to `addons/sourcemod/extensions/x64/`
3. Install the certificate from `addons/sourcemod/configs/ripext/` (double-click the `.crt` file)

**For Linux:**
1. Extract `ripext.ext.so` to `addons/sourcemod/extensions/`
2. Install CA certificates:
   ```bash
   # Debian/Ubuntu
   sudo apt-get install ca-certificates
   sudo update-ca-certificates
   
   # CentOS/RHEL
   sudo yum install ca-certificates
   sudo update-ca-trust
   ```

### 2. Install the Plugin

1. Download `sm_dods_chat2discord.sp` from this repository
2. Place it in `addons/sourcemod/scripting/`
3. Compile the plugin:
   ```bash
   cd addons/sourcemod/scripting
   ./spcomp sm_dods_chat2discord.sp
   ```
4. Move the compiled `sm_dods_chat2discord.smx` to `addons/sourcemod/plugins/`
5. **Edit the plugin** and replace the webhook URL with your own Discord webhook
6. Restart your server or load the plugin:
   ```
   sm plugins load sm_dods_chat2discord
   ```

## Configuration

### Discord Webhook Setup

1. Go to your Discord server settings
2. Navigate to **Integrations** → **Webhooks**
3. Click **New Webhook**
4. Choose the channel where you want to receive chat logs
5. Copy the webhook URL
6. Open `sm_dods_chat2discord.sp` and replace the `WEBHOOK_URL` with your own:
   ```cpp
   #define WEBHOOK_URL "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL_HERE"
   ```
7. Recompile the plugin

## Usage

The plugin works automatically:

- **Game Start**: Begins capturing chat messages
- **1 Minute Before End**: Takes a snapshot of all players and their teams
- **Game Over**: Sends all captured chat logs to Discord with player lists

### Admin Commands

- `sm_testwebhook` - Send a test message to Discord to verify the webhook is working
  - Requires: `ADMFLAG_ROOT` (root admin access)

## Chat Format

Messages are formatted to show maximum information:

```
[ALLIED TEAM] STEAM_0:1:12345 | pratinha: rush B
[AXIS ALL] STEAM_0:0:67890 | player2: gg wp
[ALLIED ALL DEAD] STEAM_0:1:11111 | observer: nice game
[SPECTATE] STEAM_0:1:22222 | spectator: watching
```

### Chat Types

- `[ALLIED TEAM]` - Team chat from Allies (alive)
- `[ALLIED DEAD]` - Team chat from Allies (dead)
- `[ALLIED ALL]` - All chat from Allies (alive)
- `[ALLIED ALL DEAD]` - All chat from Allies (dead)
- `[AXIS TEAM]` - Team chat from Axis (alive)
- `[AXIS DEAD]` - Team chat from Axis (dead)
- `[AXIS ALL]` - All chat from Axis (alive)
- `[AXIS ALL DEAD]` - All chat from Axis (dead)
- `[SPECTATE]` - Chat from spectators

## Discord Embed Preview

The webhook sends a beautifully formatted embed containing:

- **Server hostname** as the title
- **Map name, date/time, and message count**
- **Player lists** separated by team (Allies/Axis)
- **Complete chat log** with all messages
- **Custom thumbnails and images**

## Filtering

Messag
