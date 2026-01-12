# Day of Defeat: Source - Chat to Discord

A SourceMod plugin that sends in-game chat logs to Discord via webhook when the game ends.

![Day of Defeat: Source](https://cdn2.steamgriddb.com/thumb/9bd22b60086cdb18845ae061fbd49bdd.jpg)

## Features

- 📝 Captures all chat messages during gameplay (team chat and all chat)
- 🎮 Differentiates between teams (Allies/Axis) and spectators
- 💀 Shows if players were alive or dead when messaging
- 👥 Lists all players by team from 1 minute before game end
- 🔒 Includes Steam IDs for player identification
- 🎨 Beautiful Discord embed with custom images
- ⏰ Timestamps in European format (DD-MM-YYYY)
- 🧪 Test command to verify webhook connectivity

## Preview

![Day of Defeat: Source](https://i.ibb.co/DfxVySfS/image.png)

## Requirements

- SourceMod 1.11 or higher
- [RipExt Extension](https://github.com/ErikMinekus/sm-ripext) v1.3.2 or higher

## Installation

### 1. Install RipExt Extension

Download the latest version of RipExt from [GitHub Releases](https://github.com/ErikMinekus/sm-ripext/releases)

**For Windows:**
1. Extract `rip.ext.dll` to `addons/sourcemod/extensions/`
2. Extract `rip.ext.dll` (x64) to `addons/sourcemod/extensions/x64/`
3. Install the certificate from `addons/sourcemod/configs/ripext/` (double-click the `.crt` file)

**For Linux:**
1. Extract `rip.ext.so` to `addons/sourcemod/extensions/`
2. Extract `rip.ext.so` (x64) to `addons/sourcemod/extensions/x64/`
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

Messages containing the `%` symbol are automatically filtered and will not appear in logs. Because most players have binds with `%t` for timeleft, `%h` for health and `%l` for location. This is useful for filtering plugin commands or special messages and avoid SPAM.

## Troubleshooting

### Plugin shows as "Failed" in `sm plugins list`

- Verify RipExt extension is installed correctly
- Check `sm exts list` - RipExt should show as "Running"
- Ensure the certificate is installed (Windows only)

### Webhook not sending messages

1. Test the webhook with `sm_testwebhook`
2. Check server console for error messages
3. Verify the webhook URL is correct
4. Ensure your server can make outbound HTTPS connections
5. Check firewall settings

### Players not appearing in team lists

- The plugin captures players 1 minute before game end
- Players who join after this snapshot will still be added
- Players who disconnect before game end will still appear (if they were captured)

## Support

If you encounter any issues or have suggestions, please open an issue on [GitHub](https://github.com/pratinha10/sm_dods_chat2discord/issues).

## Credits

- **Author**: pratinha
- **RipExt Extension**: [Erik Minekus](https://github.com/ErikMinekus/sm-ripext)
- **Game**: Day of Defeat: Source by Valve

## License

This project is open source. Feel free to modify and distribute as needed.

---

Made with ❤️ for the Day of Defeat: Source community