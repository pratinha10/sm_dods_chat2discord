/**
 * Day of Defeat: Source - Chat to Discord
 * 
 * Automatically sends in-game chat logs to Discord via webhook when the game ends.
 * Captures all chat messages (team chat, all chat, spectator) with player information
 * and team rosters, then sends them in a beautifully formatted Discord embed.
 * 
 * Features:
 * - Captures chat messages during gameplay
 * - Differentiates between team chat, all chat, and spectator messages
 * - Shows if players were alive or dead when messaging
 * - Lists all players by team from round end
 * - Includes Steam IDs for player identification
 * - Configurable via cfg file (webhook URL and embed images)
 * - Ignores messages containing % symbol
 * 
 * Author: pratinha
 * GitHub: https://github.com/pratinha10/sm_dods_chat2discord
 * Version: 1.4
 */

#include <sourcemod>
#include <sdktools>
#include <ripext>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.4"
#define MAX_MESSAGES 500

ConVar g_cvWebhookURL;
ConVar g_cvThumbnailURL;
ConVar g_cvImageURL;
ConVar g_cvFooterIconURL;

ArrayList g_ChatMessages;
ArrayList g_AlliedPlayers;
ArrayList g_AlliedSteamIDs;
ArrayList g_AxisPlayers;
ArrayList g_AxisSteamIDs;
bool g_GameActive = false;
bool g_PlayersCaptured = false;

public Plugin myinfo = 
{
    name = "DoD:S Chat to Discord",
    author = "pratinha",
    description = "Sends end-of-game chat messages to Discord via webhook",
    version = PLUGIN_VERSION,
    url = "https://github.com/pratinha10/sm_dods_chat2discord"
};

public void OnPluginStart()
{
    g_ChatMessages = new ArrayList(ByteCountToCells(512));
    g_AlliedPlayers = new ArrayList(ByteCountToCells(64));
    g_AlliedSteamIDs = new ArrayList(ByteCountToCells(32));
    g_AxisPlayers = new ArrayList(ByteCountToCells(64));
    g_AxisSteamIDs = new ArrayList(ByteCountToCells(32));
    
    HookEvent("dod_game_over", Event_GameOver);
    HookEvent("dod_round_win", Event_RoundWin);
    
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");
    
    RegAdminCmd("sm_testwebhook", Command_TestWebhook, ADMFLAG_ROOT, "Test Discord webhook connection");
    RegAdminCmd("sm_chat2discord_reload", Command_ReloadConfig, ADMFLAG_ROOT, "Reload chat2discord configuration");
    
    g_GameActive = true;
    
    LoadConfig();
    
    PrintToServer("[Chat2Discord] Plugin loaded successfully");
}

public Action Command_ReloadConfig(int client, int args)
{
    LoadConfig();
    ReplyToCommand(client, "[Chat2Discord] Configuration reloaded!");
    return Plugin_Handled;
}

void LoadConfig()
{
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/chat2discord.cfg");
    
    KeyValues kv = new KeyValues("Chat2Discord");
    
    if(!kv.ImportFromFile(configPath))
    {
        PrintToServer("[Chat2Discord] Config file not found, creating default: %s", configPath);
        CreateDefaultConfig(configPath);
        kv.ImportFromFile(configPath);
    }
    
    char buffer[512];
    
    kv.GetString("webhook_url", buffer, sizeof(buffer), "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE");
    delete g_cvWebhookURL;
    g_cvWebhookURL = CreateConVar("sm_chat2discord_webhook_internal", buffer, "", FCVAR_DONTRECORD);
    
    kv.GetString("thumbnail_url", buffer, sizeof(buffer), "https://cdn2.steamgriddb.com/thumb/1cc7df585769791a5a4028abf36af4f5.jpg");
    delete g_cvThumbnailURL;
    g_cvThumbnailURL = CreateConVar("sm_chat2discord_thumbnail_internal", buffer, "", FCVAR_DONTRECORD);
    
    kv.GetString("image_url", buffer, sizeof(buffer), "https://cdn2.steamgriddb.com/hero_thumb/66d4c457e5def18dcc1a88da35522e51.jpg");
    delete g_cvImageURL;
    g_cvImageURL = CreateConVar("sm_chat2discord_image_internal", buffer, "", FCVAR_DONTRECORD);
    
    kv.GetString("footer_icon_url", buffer, sizeof(buffer), "https://cdn2.steamgriddb.com/icon_thumb/d4809f07d773c2013d584ce3ab38108f.png");
    delete g_cvFooterIconURL;
    g_cvFooterIconURL = CreateConVar("sm_chat2discord_footer_internal", buffer, "", FCVAR_DONTRECORD);
    
    delete kv;
    
    PrintToServer("[Chat2Discord] Configuration loaded from: %s", configPath);
}

void CreateDefaultConfig(const char[] path)
{
    KeyValues kv = new KeyValues("Chat2Discord");
    
    kv.SetString("webhook_url", "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE");
    kv.SetString("thumbnail_url", "https://cdn2.steamgriddb.com/thumb/1cc7df585769791a5a4028abf36af4f5.jpg");
    kv.SetString("image_url", "https://cdn2.steamgriddb.com/hero_thumb/66d4c457e5def18dcc1a88da35522e51.jpg");
    kv.SetString("footer_icon_url", "https://cdn2.steamgriddb.com/icon_thumb/d4809f07d773c2013d584ce3ab38108f.png");
    
    kv.ExportToFile(path);
    delete kv;
    
    PrintToServer("[Chat2Discord] Created default config file: %s", path);
}

public void OnPluginEnd()
{
    delete g_ChatMessages;
    delete g_AlliedPlayers;
    delete g_AlliedSteamIDs;
    delete g_AxisPlayers;
    delete g_AxisSteamIDs;
}

public void OnMapStart()
{
    g_GameActive = true;
    g_PlayersCaptured = false;
    g_ChatMessages.Clear();
    g_AlliedPlayers.Clear();
    g_AlliedSteamIDs.Clear();
    g_AxisPlayers.Clear();
    g_AxisSteamIDs.Clear();
    PrintToServer("[Chat2Discord] Map started - chat logging active");
}

public Action Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
    if(g_PlayersCaptured)
        return Plugin_Continue;
    
    // Capture players immediately when round ends (before people disconnect)
    g_AlliedPlayers.Clear();
    g_AlliedSteamIDs.Clear();
    g_AxisPlayers.Clear();
    g_AxisSteamIDs.Clear();
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i))
        {
            int team = GetClientTeam(i);
            char playerName[64];
            char steamID[32];
            GetClientName(i, playerName, sizeof(playerName));
            GetClientAuthId(i, AuthId_Steam2, steamID, sizeof(steamID));
            
            if(team == 2)
            {
                g_AlliedPlayers.PushString(playerName);
                g_AlliedSteamIDs.PushString(steamID);
            }
            else if(team == 3)
            {
                g_AxisPlayers.PushString(playerName);
                g_AxisSteamIDs.PushString(steamID);
            }
        }
    }
    
    g_PlayersCaptured = true;
    
    PrintToServer("[Chat2Discord] Round Win - Players captured: Allied: %d, Axis: %d", 
        g_AlliedPlayers.Length, g_AxisPlayers.Length);
    
    return Plugin_Continue;
}

public Action Event_GameOver(Event event, const char[] name, bool dontBroadcast)
{
    g_GameActive = false;
    
    PrintToServer("[Chat2Discord] Game Over - Sending to Discord in 2 seconds");
    
    // Short delay to ensure scoreboard is visible
    CreateTimer(2.0, Timer_SendToDiscord, 0, TIMER_FLAG_NO_MAPCHANGE);
    
    return Plugin_Continue;
}

public Action Timer_SendToDiscord(Handle timer, any data)
{
    SendChatToDiscord();
    return Plugin_Stop;
}

public Action Timer_CaptureAndSend(Handle timer, any data)
{
    // Fallback: If players weren't captured in round_win, capture them now
    if(!g_PlayersCaptured)
    {
        g_AlliedPlayers.Clear();
        g_AlliedSteamIDs.Clear();
        g_AxisPlayers.Clear();
        g_AxisSteamIDs.Clear();
        
        for(int i = 1; i <= MaxClients; i++)
        {
            if(IsClientInGame(i) && !IsFakeClient(i))
            {
                int team = GetClientTeam(i);
                char playerName[64];
                char steamID[32];
                GetClientName(i, playerName, sizeof(playerName));
                GetClientAuthId(i, AuthId_Steam2, steamID, sizeof(steamID));
                
                if(team == 2)
                {
                    g_AlliedPlayers.PushString(playerName);
                    g_AlliedSteamIDs.PushString(steamID);
                }
                else if(team == 3)
                {
                    g_AxisPlayers.PushString(playerName);
                    g_AxisSteamIDs.PushString(steamID);
                }
            }
        }
        
        PrintToServer("[Chat2Discord] Fallback - Players captured now");
    }
    
    SendChatToDiscord();
    
    return Plugin_Stop;
}

public Action Command_Say(int client, const char[] command, int argc)
{
    if(!IsValidClient(client))
        return Plugin_Continue;
    
    if(!g_GameActive)
        return Plugin_Continue;
    
    char message[256];
    char playerName[64];
    char finalMessage[512];
    
    GetCmdArgString(message, sizeof(message));
    StripQuotes(message);
    TrimString(message);
    
    if(strlen(message) == 0)
        return Plugin_Continue;
    
    if(StrContains(message, "%") != -1)
    {
        PrintToServer("[Chat2Discord] Message ignored (contains %%)");
        return Plugin_Continue;
    }
    
    GetClientName(client, playerName, sizeof(playerName));
    
    bool isTeamChat = StrEqual(command, "say_team", false);
    bool isDead = !IsPlayerAlive(client);
    int team = GetClientTeam(client);
    
    char teamEmoji[20];
    
    // Determine team emoji
    if(team == 2)
        strcopy(teamEmoji, sizeof(teamEmoji), ":green_circle:");
    else if(team == 3)
        strcopy(teamEmoji, sizeof(teamEmoji), ":red_circle:");
    else
        strcopy(teamEmoji, sizeof(teamEmoji), ":white_circle:");
    
    // Format based on chat type and alive status
    if(isTeamChat)
    {
        if(isDead)
        {
            // Team chat morto: :green_circle: (dead)(team) pratinha: mensagem
            Format(finalMessage, sizeof(finalMessage), "%s (dead)(team) %s: %s", teamEmoji, playerName, message);
        }
        else
        {
            // Team chat vivo: :green_circle: pratinha (team): mensagem
            Format(finalMessage, sizeof(finalMessage), "%s %s (team): %s", teamEmoji, playerName, message);
        }
    }
    else
    {
        if(team == 1)
        {
            // Spectate: :white_circle: observer: mensagem
            Format(finalMessage, sizeof(finalMessage), "%s %s: %s", teamEmoji, playerName, message);
        }
        else
        {
            if(isDead)
            {
                // All chat morto: :green_circle: (dead) pratinha (all): mensagem
                Format(finalMessage, sizeof(finalMessage), "%s (dead) %s (all): %s", teamEmoji, playerName, message);
            }
            else
            {
                // All chat vivo: :green_circle: pratinha (all): mensagem
                Format(finalMessage, sizeof(finalMessage), "%s %s (all): %s", teamEmoji, playerName, message);
            }
        }
    }
    
    if(g_ChatMessages.Length < MAX_MESSAGES)
    {
        g_ChatMessages.PushString(finalMessage);
        PrintToServer("[Chat2Discord] Captured: %s (Total: %d)", finalMessage, g_ChatMessages.Length);
    }
    
    return Plugin_Continue;
}

void SendChatToDiscord()
{
    // Don't send if no messages
    if(g_ChatMessages.Length == 0)
    {
        PrintToServer("[Chat2Discord] No messages to send - skipping webhook");
        return;
    }
    
    char webhookURL[512];
    g_cvWebhookURL.GetString(webhookURL, sizeof(webhookURL));
    
    if(strlen(webhookURL) == 0)
    {
        PrintToServer("[Chat2Discord] ERROR: Webhook URL not configured! Set sm_chat2discord_webhook in cfg/sourcemod/chat2discord.cfg");
        return;
    }
    
    PrintToServer("[Chat2Discord] Preparing to send to Discord");
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    
    char timeString[64];
    FormatTime(timeString, sizeof(timeString), "%d-%m-%Y %H:%M:%S", GetTime());
    
    char hostname[128];
    ConVar cvHostname = FindConVar("hostname");
    cvHostname.GetString(hostname, sizeof(hostname));
    
    char alliedPlayers[2048] = "";
    char axisPlayers[2048] = "";
    
    for(int i = 0; i < g_AlliedPlayers.Length; i++)
    {
        char playerName[64];
        char steamID[32];
        g_AlliedPlayers.GetString(i, playerName, sizeof(playerName));
        g_AlliedSteamIDs.GetString(i, steamID, sizeof(steamID));
        
        if(i > 0)
            Format(alliedPlayers, sizeof(alliedPlayers), "%s\n%s | %s", alliedPlayers, playerName, steamID);
        else
            Format(alliedPlayers, sizeof(alliedPlayers), "%s | %s", playerName, steamID);
    }
    
    for(int i = 0; i < g_AxisPlayers.Length; i++)
    {
        char playerName[64];
        char steamID[32];
        g_AxisPlayers.GetString(i, playerName, sizeof(playerName));
        g_AxisSteamIDs.GetString(i, steamID, sizeof(steamID));
        
        if(i > 0)
            Format(axisPlayers, sizeof(axisPlayers), "%s\n%s | %s", axisPlayers, playerName, steamID);
        else
            Format(axisPlayers, sizeof(axisPlayers), "%s | %s", playerName, steamID);
    }
    
    char chatLog[3500];
    strcopy(chatLog, sizeof(chatLog), "");
    
    for(int i = 0; i < g_ChatMessages.Length; i++)
    {
        char msg[512];
        g_ChatMessages.GetString(i, msg, sizeof(msg));
        
        if(strlen(chatLog) + strlen(msg) + 2 < sizeof(chatLog) - 100)
        {
            Format(chatLog, sizeof(chatLog), "%s%s\n", chatLog, msg);
        }
    }
    
    if(strlen(chatLog) > 3400)
    {
        chatLog[3397] = '.';
        chatLog[3398] = '.';
        chatLog[3399] = '.';
        chatLog[3400] = '\0';
    }
    
    JSONObject embed = new JSONObject();
    embed.SetString("title", hostname);
    embed.SetInt("color", 3447003);
    
    char thumbnailURL[256];
    g_cvThumbnailURL.GetString(thumbnailURL, sizeof(thumbnailURL));
    
    if(strlen(thumbnailURL) > 0)
    {
        JSONObject thumbnail = new JSONObject();
        thumbnail.SetString("url", thumbnailURL);
        embed.Set("thumbnail", thumbnail);
        delete thumbnail;
    }
    
    JSONArray fields = new JSONArray();
    
    JSONObject mapField = new JSONObject();
    mapField.SetString("name", "📍 Map");
    mapField.SetString("value", mapName);
    mapField.SetBool("inline", true);
    fields.Push(mapField);
    delete mapField;
    
    JSONObject dateField = new JSONObject();
    dateField.SetString("name", "🕐 Date & Time");
    dateField.SetString("value", timeString);
    dateField.SetBool("inline", true);
    fields.Push(dateField);
    delete dateField;
    
    JSONObject msgField = new JSONObject();
    char msgCount[32];
    Format(msgCount, sizeof(msgCount), "%d messages", g_ChatMessages.Length);
    msgField.SetString("name", "💬 Total Messages");
    msgField.SetString("value", msgCount);
    msgField.SetBool("inline", true);
    fields.Push(msgField);
    delete msgField;
    
    if(g_AlliedPlayers.Length > 0)
    {
        JSONObject alliedField = new JSONObject();
        alliedField.SetString("name", ":green_circle: Allies");
        alliedField.SetString("value", alliedPlayers);
        alliedField.SetBool("inline", false);
        fields.Push(alliedField);
        delete alliedField;
    }
    
    if(g_AxisPlayers.Length > 0)
    {
        JSONObject axisField = new JSONObject();
        axisField.SetString("name", "🔴 Axis");
        axisField.SetString("value", axisPlayers);
        axisField.SetBool("inline", false);
        fields.Push(axisField);
        delete axisField;
    }
    
    JSONObject chatField = new JSONObject();
    chatField.SetString("name", "💭 Chat Log");
    chatField.SetString("value", strlen(chatLog) > 0 ? chatLog : "No messages");
    chatField.SetBool("inline", false);
    fields.Push(chatField);
    delete chatField;
    
    embed.Set("fields", fields);
    delete fields;
    
    char imageURL[256];
    g_cvImageURL.GetString(imageURL, sizeof(imageURL));
    
    if(strlen(imageURL) > 0)
    {
        JSONObject image = new JSONObject();
        image.SetString("url", imageURL);
        embed.Set("image", image);
        delete image;
    }
    
    char footerIconURL[256];
    g_cvFooterIconURL.GetString(footerIconURL, sizeof(footerIconURL));
    
    JSONObject footer = new JSONObject();
    footer.SetString("text", "Ingame Logger");
    if(strlen(footerIconURL) > 0)
        footer.SetString("icon_url", footerIconURL);
    embed.Set("footer", footer);
    delete footer;
    
    JSONObject payload = new JSONObject();
    payload.SetString("username", "DoD:S Chat Logger");
    
    JSONArray embeds = new JSONArray();
    embeds.Push(embed);
    payload.Set("embeds", embeds);
    
    delete embeds;
    delete embed;
    
    HTTPRequest request = new HTTPRequest(webhookURL);
    request.Post(payload, OnWebhookResponse);
    
    delete payload;
    
    PrintToServer("[Chat2Discord] Webhook request sent");
}

public void OnWebhookResponse(HTTPResponse response, any value)
{
    PrintToServer("[Chat2Discord] Webhook response Status: %d", view_as<int>(response.Status));
    
    if(response.Status == HTTPStatus_NoContent || response.Status == HTTPStatus_OK)
    {
        PrintToServer("[Chat2Discord] Messages sent successfully to Discord");
    }
    else
    {
        PrintToServer("[Chat2Discord] Failed to send messages. Status: %d", view_as<int>(response.Status));
        
        if(view_as<int>(response.Status) != 0 && response.Data != null)
        {
            char error[512];
            response.Data.ToString(error, sizeof(error));
            PrintToServer("[Chat2Discord] Error details: %s", error);
        }
        else if(view_as<int>(response.Status) == 0)
        {
            PrintToServer("[Chat2Discord] Connection failed - Check firewall/internet connection");
        }
    }
}

public Action Command_TestWebhook(int client, int args)
{
    char webhookURL[512];
    g_cvWebhookURL.GetString(webhookURL, sizeof(webhookURL));
    
    if(strlen(webhookURL) == 0)
    {
        ReplyToCommand(client, "[Chat2Discord] ERROR: Webhook URL not configured!");
        PrintToServer("[Chat2Discord] ERROR: Set sm_chat2discord_webhook in cfg/sourcemod/chat2discord.cfg");
        return Plugin_Handled;
    }
    
    ReplyToCommand(client, "[Chat2Discord] Sending test message to Discord...");
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    
    char timeString[64];
    FormatTime(timeString, sizeof(timeString), "%d-%m-%Y %H:%M:%S", GetTime());
    
    char hostname[128];
    ConVar cvHostname = FindConVar("hostname");
    cvHostname.GetString(hostname, sizeof(hostname));
    
    JSONObject headerEmbed = new JSONObject();
    headerEmbed.SetString("title", hostname);
    headerEmbed.SetInt("color", 65280);
    
    char description[256];
    Format(description, sizeof(description), "**Map:** %s\n**Date:** %s\n**Status:** ✅ Webhook Test", mapName, timeString);
    headerEmbed.SetString("description", description);
    
    JSONObject testEmbed = new JSONObject();
    testEmbed.SetString("title", "🧪 Test Information");
    testEmbed.SetString("description", "This is a test message from the DoD:S Chat Logger plugin!\n\nIf you can see this, the webhook is working correctly.");
    testEmbed.SetInt("color", 3447003);
    
    JSONObject footer = new JSONObject();
    footer.SetString("text", "Day of Defeat: Source - Test Mode");
    testEmbed.Set("footer", footer);
    delete footer;
    
    JSONObject payload = new JSONObject();
    payload.SetString("username", "DoD:S Chat Logger");
    payload.SetString("content", "🔔 **Webhook Test**");
    
    JSONArray embeds = new JSONArray();
    embeds.Push(headerEmbed);
    embeds.Push(testEmbed);
    payload.Set("embeds", embeds);
    
    delete embeds;
    delete headerEmbed;
    delete testEmbed;
    
    HTTPRequest request = new HTTPRequest(webhookURL);
    request.Post(payload, OnTestWebhookResponse, client);
    
    delete payload;
    
    return Plugin_Handled;
}

public void OnTestWebhookResponse(HTTPResponse response, int client)
{
    PrintToServer("[Chat2Discord] Test response Status: %d", view_as<int>(response.Status));
    
    if(response.Status == HTTPStatus_NoContent || response.Status == HTTPStatus_OK)
    {
        ReplyToCommand(client, "[Chat2Discord] ✅ Test message sent successfully!");
        PrintToServer("[Chat2Discord] Test webhook successful");
    }
    else
    {
        ReplyToCommand(client, "[Chat2Discord] ❌ Failed to send test message. Status: %d", view_as<int>(response.Status));
        PrintToServer("[Chat2Discord] Test webhook failed. Status: %d", view_as<int>(response.Status));
        
        if(view_as<int>(response.Status) != 0 && response.Data != null)
        {
            char error[512];
            response.Data.ToString(error, sizeof(error));
            PrintToServer("[Chat2Discord] Error details: %s", error);
        }
        else if(view_as<int>(response.Status) == 0)
        {
            PrintToServer("[Chat2Discord] Connection failed - Check firewall/internet connection");
            
            char webhookURL[512];
            g_cvWebhookURL.GetString(webhookURL, sizeof(webhookURL));
            PrintToServer("[Chat2Discord] Webhook URL: %s", webhookURL);
        }
    }
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}