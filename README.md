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

## Discord Embed Preview

The webhook sends a beautifully formatted embed containing:

![Day of Defeat: Source](https://i.ibb.co/DfxVySfS/image.png)

- **Server hostname** as the title
- **Map name, date/time, and message count**
- **Player lists** separated by team (Allies/Axis)
- **Complete chat log** with all messages
- **Custom thumbnails and images**

## Requirements

- SourceMod 1.11 or higher
- [RipExt Extension](https://github.com/ErikMinekus/sm-ripext) v1.3.2 or higher

## Installation

### Recommended installation procedure [GitHub Releases](https://github.com/pratinha10/sm_dods_chat2discord/releases)

**For Windows:**
1. Extract download the Release package `sm_dods_chat2discord-1.4-windows.zip`
2. Extract and preserve the folder and file structure
3. Goto `addons/sourcemod/configs/ripext/ca-bundle.crt` and open it
4. Click in the button `Install Certificate` and press `OK` button


**For Linux:**
1. Extract download the Release package `sm_dods_chat2discord-1.4-linux.zip`
2. Extract and preserve the folder and file structure

### OR Installation procedure (Code >> Download Zip)

**Install RipExt Extension***
Download the latest version of RipExt from [GitHub Releases](https://github.com/ErikMinekus/sm-ripext/releases)

**For Windows:**
1. Extract `rip.ext.dll` to `addons/sourcemod/extensions/`
2. Extract `rip.ext.dll` (x64) to `addons/sourcemod/extensions/x64/`
3. Install the certificate from `addons/sourcemod/configs/ripext/` (double-click the `ca-bundle.crt` file)

**For Linux:**
1. Extract `rip.ext.so` to `addons/sourcemod/extensions/`
2. Extract `rip.ext.so` (x64) to `addons/sourcemod/extensions/x64/`
3. Extract `ca-bundle.crt` to `addons/sourcemod/configs/ripext/`

### 3. Install the Plugin

1. Download the compiled `sm_dods_chat2discord.smx` to `addons/sourcemod/plugins/`
2. Download the config `chat2discord.cfg` to `addons/sourcemod/configs/`
3. Open and edit the `chat2discord.cfg` with your Discord webhook URL and URL images
4. Restart your server or load the plugin:
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
6. Open `chat2discord.cfg` and replace the `WEBHOOK_URL` with your own:

## Usage

The plugin works automatically:

- **Game Start**: Begins capturing chat messages
- **1 Minute Before End**: Takes a snapshot of all players and their teams
- **Game Over**: Sends all captured chat logs to Discord with player lists

### Admin Commands

- `sm_testwebhook` - Send a test message to Discord to verify the webhook is working
- `sm_chat2discord_reload` - Reload the configuration without restarting the server


## Filtering

Messages containing the `%` symbol are automatically filtered and will not appear in logs. Because most players have binds with `%t` for timeleft, `%h` for health and `%l` for location commands. This is useful for filtering plugin commands or special messages and avoid SPAM.

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