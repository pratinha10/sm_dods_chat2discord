#include <sourcemod>
#include <sdktools>
#include <ripext>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2"
#define MAX_MESSAGES 500
#define WEBHOOK_URL "https://discord.com/api/webhooks/1459686956308103179/YADUQ9ChAzCdEf-Dn45C1GLibyIg12aSM9No0tGHY2UHm67YZe0eNjKL7lqeSWrqYSJK"

ArrayList g_ChatMessages;
ArrayList g_AlliedPlayers;
ArrayList g_AxisPlayers;
bool g_GameActive = false;
bool g_PlayersSnapshot = false;

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
    g_AxisPlayers = new ArrayList(ByteCountToCells(64));
    
    HookEvent("dod_game_over", Event_GameOver);
    
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");
    
    RegAdminCmd("sm_testwebhook", Command_TestWebhook, ADMFLAG_ROOT, "Test Discord webhook connection");
    
    g_GameActive = true;
    
    PrintToServer("[Chat2Discord] Plugin loaded successfully");
}

public void OnPluginEnd()
{
    delete g_ChatMessages;
    delete g_AlliedPlayers;
    delete g_AxisPlayers;
}

public void OnMapStart()
{
    g_GameActive = true;
    g_PlayersSnapshot = false;
    g_ChatMessages.Clear();
    g_AlliedPlayers.Clear();
    g_AxisPlayers.Clear();
    PrintToServer("[Chat2Discord] Map started - chat logging active");
    
    // Create timer to capture players 1 minute before map end
    int timeleft;
    if(GetMapTimeLeft(timeleft) && timeleft > 60)
    {
        CreateTimer(float(timeleft - 60), Timer_CapturePlayersSnapshot, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_CapturePlayersSnapshot(Handle timer)
{
    g_AlliedPlayers.Clear();
    g_AxisPlayers.Clear();
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i))
        {
            int team = GetClientTeam(i);
            char playerName[64];
            GetClientName(i, playerName, sizeof(playerName));
            
            if(team == 2) // Allies
            {
                g_AlliedPlayers.PushString(playerName);
            }
            else if(team == 3) // Axis
            {
                g_AxisPlayers.PushString(playerName);
            }
        }
    }
    
    g_PlayersSnapshot = true;
    PrintToServer("[Chat2Discord] Players snapshot captured - Allies: %d, Axis: %d", g_AlliedPlayers.Length, g_AxisPlayers.Length);
    
    return Plugin_Stop;
}

public void OnClientPutInServer(int client)
{
    if(!IsFakeClient(client) && g_PlayersSnapshot)
    {
        // If snapshot already taken and new player joins, add them
        CreateTimer(3.0, Timer_CheckPlayerTeam, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_CheckPlayerTeam(Handle timer, int userid)
{
    if(!g_PlayersSnapshot)
        return Plugin_Stop;
    
    int client = GetClientOfUserId(userid);
    if(client == 0 || !IsClientInGame(client))
        return Plugin_Stop;
    
    int team = GetClientTeam(client);
    char playerName[64];
    GetClientName(client, playerName, sizeof(playerName));
    
    if(team == 2) // Allies
    {
        if(g_AlliedPlayers.FindString(playerName) == -1)
        {
            g_AlliedPlayers.PushString(playerName);
        }
    }
    else if(team == 3) // Axis
    {
        if(g_AxisPlayers.FindString(playerName) == -1)
        {
            g_AxisPlayers.PushString(playerName);
        }
    }
    
    return Plugin_Stop;
}

public Action Event_GameOver(Event event, const char[] name, bool dontBroadcast)
{
    g_GameActive = false;
    
    PrintToServer("[Chat2Discord] Game Over - Captured messages: %d", g_ChatMessages.Length);
    
    CreateTimer(1.0, Timer_SendToDiscord, 0, TIMER_FLAG_NO_MAPCHANGE);
    
    return Plugin_Continue;
}

public Action Command_Say(int client, const char[] command, int argc)
{
    if(!IsValidClient(client))
    {
        return Plugin_Continue;
    }
    
    if(!g_GameActive)
    {
        return Plugin_Continue;
    }
    
    char message[256];
    char playerName[64];
    char finalMessage[512];
    char steamID[32];
    
    GetCmdArgString(message, sizeof(message));
    StripQuotes(message);
    TrimString(message);
    
    if(strlen(message) == 0)
        return Plugin_Continue;
    
    // Ignore messages containing %
    if(StrContains(message, "%") != -1)
    {
        PrintToServer("[Chat2Discord] Message ignored (contains %%)");
        return Plugin_Continue;
    }
    
    GetClientName(client, playerName, sizeof(playerName));
    GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
    
    bool isTeamChat = StrEqual(command, "say_team", false);
    bool isDead = !IsPlayerAlive(client);
    char chatType[32];
    int team = GetClientTeam(client);
    
    if(isTeamChat)
    {
        switch(team)
        {
            case 2: Format(chatType, sizeof(chatType), isDead ? "[ALLIED DEAD]" : "[ALLIED TEAM]");
            case 3: Format(chatType, sizeof(chatType), isDead ? "[AXIS DEAD]" : "[AXIS TEAM]");
            case 1: Format(chatType, sizeof(chatType), "[SPECTATE]");
            default: Format(chatType, sizeof(chatType), isDead ? "[TEAM DEAD]" : "[TEAM]");
        }
    }
    else
    {
        if(team == 1)
        {
            Format(chatType, sizeof(chatType), "[SPECTATE]");
        }
        else if(team == 2)
        {
            Format(chatType, sizeof(chatType), isDead ? "[ALLIED ALL DEAD]" : "[ALLIED ALL]");
        }
        else if(team == 3)
        {
            Format(chatType, sizeof(chatType), isDead ? "[AXIS ALL DEAD]" : "[AXIS ALL]");
        }
        else
        {
            Format(chatType, sizeof(chatType), isDead ? "[ALL DEAD]" : "[ALL]");
        }
    }
    
    Format(finalMessage, sizeof(finalMessage), "%s %s | %s: %s", chatType, steamID, playerName, message);
    
    if(g_ChatMessages.Length < MAX_MESSAGES)
    {
        g_ChatMessages.PushString(finalMessage);
        PrintToServer("[Chat2Discord] Captured: %s (Total: %d)", finalMessage, g_ChatMessages.Length);
    }
    
    return Plugin_Continue;
}

public Action Timer_SendToDiscord(Handle timer, any data)
{
    PrintToServer("[Chat2Discord] Timer triggered - Preparing to send %d messages", g_ChatMessages.Length);
    
    if(g_ChatMessages.Length == 0)
    {
        PrintToServer("[Chat2Discord] No messages to send");
        return Plugin_Stop;
    }
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    
    char timeString[64];
    FormatTime(timeString, sizeof(timeString), "%d-%m-%Y %H:%M:%S", GetTime());
    
    char hostname[128];
    ConVar cvHostname = FindConVar("hostname");
    cvHostname.GetString(hostname, sizeof(hostname));
    
    // Get players by team from stored lists
    char alliedPlayers[1024] = "";
    char axisPlayers[1024] = "";
    
    // Build Allied players list
    for(int i = 0; i < g_AlliedPlayers.Length; i++)
    {
        char playerName[64];
        g_AlliedPlayers.GetString(i, playerName, sizeof(playerName));
        
        if(i > 0)
            Format(alliedPlayers, sizeof(alliedPlayers), "%s, %s", alliedPlayers, playerName);
        else
            strcopy(alliedPlayers, sizeof(alliedPlayers), playerName);
    }
    
    // Build Axis players list
    for(int i = 0; i < g_AxisPlayers.Length; i++)
    {
        char playerName[64];
        g_AxisPlayers.GetString(i, playerName, sizeof(playerName));
        
        if(i > 0)
            Format(axisPlayers, sizeof(axisPlayers), "%s, %s", axisPlayers, playerName);
        else
            strcopy(axisPlayers, sizeof(axisPlayers), playerName);
    }
    
    // Build chat log
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
    
    // Create single embed
    JSONObject embed = new JSONObject();
    embed.SetString("title", hostname);
    embed.SetInt("color", 3447003); // Blue
    
    // Add thumbnail
    JSONObject thumbnail = new JSONObject();
    thumbnail.SetString("url", "https://i.ibb.co/chCK7fS8/ANIMATED-LOGO.gif");
    embed.Set("thumbnail", thumbnail);
    delete thumbnail;
    
    // Create fields
    JSONArray fields = new JSONArray();
    
    // Map and date info
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
    
    // Teams
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
    
    // Chat log
    JSONObject chatField = new JSONObject();
    chatField.SetString("name", "💭 Chat Log");
    chatField.SetString("value", strlen(chatLog) > 0 ? chatLog : "No messages");
    chatField.SetBool("inline", false);
    fields.Push(chatField);
    delete chatField;
    
    embed.Set("fields", fields);
    delete fields;
    
    // Add image after chat log
    JSONObject image = new JSONObject();
    image.SetString("url", "https://i.ibb.co/p6MztFbC/Howto-MIX-DODGLOBAL.gif");
    embed.Set("image", image);
    delete image;
    
    // Footer with image
    JSONObject footer = new JSONObject();
    footer.SetString("text", "Ingame Logger");
    footer.SetString("icon_url", "https://cdn2.steamgriddb.com/icon/2555b8e9861b4b0e141181b725fb1b3b/32/1024x1024.png");
    embed.Set("footer", footer);
    delete footer;
    
    // Create payload
    JSONObject payload = new JSONObject();
    payload.SetString("username", "DoD:S Chat Logger");
    
    JSONArray embeds = new JSONArray();
    embeds.Push(embed);
    payload.Set("embeds", embeds);
    
    delete embeds;
    delete embed;
    
    HTTPRequest request = new HTTPRequest(WEBHOOK_URL);
    request.Post(payload, OnWebhookResponse);
    
    delete payload;
    
    PrintToServer("[Chat2Discord] Webhook request sent");
    
    return Plugin_Stop;
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
    ReplyToCommand(client, "[Chat2Discord] Sending test message to Discord...");
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    
    char timeString[64];
    FormatTime(timeString, sizeof(timeString), "%d-%m-%Y %H:%M:%S", GetTime());
    
    char hostname[128];
    ConVar cvHostname = FindConVar("hostname");
    cvHostname.GetString(hostname, sizeof(hostname));
    
    // Header embed
    JSONObject headerEmbed = new JSONObject();
    headerEmbed.SetString("title", hostname);
    headerEmbed.SetInt("color", 65280); // Green for test
    
    char description[256];
    Format(description, sizeof(description), "**Map:** %s\n**Date:** %s\n**Status:** ✅ Webhook Test", mapName, timeString);
    headerEmbed.SetString("description", description);
    
    // Test info embed
    JSONObject testEmbed = new JSONObject();
    testEmbed.SetString("title", "🧪 Test Information");
    testEmbed.SetString("description", "This is a test message from the DoD:S Chat Logger plugin!\n\nIf you can see this, the webhook is working correctly.");
    testEmbed.SetInt("color", 3447003); // Blue
    
    JSONObject footer = new JSONObject();
    footer.SetString("text", "Day of Defeat: Source - Test Mode");
    testEmbed.Set("footer", footer);
    delete footer;
    
    // Create payload
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
    
    HTTPRequest request = new HTTPRequest(WEBHOOK_URL);
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
            PrintToServer("[Chat2Discord] Webhook URL: %s", WEBHOOK_URL);
        }
    }
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}