#include <sourcemod>
#include <sdktools>
#include <ripext>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1"
#define MAX_MESSAGES 500
#define WEBHOOK_URL "https://discord.com/api/webhooks/1459686956308103179/YADUQ9ChAzCdEf-Dn45C1GLibyIg12aSM9No0tGHY2UHm67YZe0eNjKL7lqeSWrqYSJK"

ArrayList g_ChatMessages;
bool g_RoundActive = false;

public Plugin myinfo = 
{
    name = "DoD:S Chat to Discord",
    author = "Your Name",
    description = "Sends end-of-round chat messages to Discord via webhook",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_ChatMessages = new ArrayList(ByteCountToCells(512));
    
    HookEvent("dod_round_start", Event_RoundStart);
    HookEvent("dod_round_win", Event_RoundEnd);
    
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");
    
    PrintToServer("[Chat2Discord] Plugin loaded successfully");
}

public void OnPluginEnd()
{
    delete g_ChatMessages;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_RoundActive = true;
    g_ChatMessages.Clear();
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_RoundActive = false;
    
    int team = event.GetInt("team");
    
    CreateTimer(2.0, Timer_SendToDiscord, team, TIMER_FLAG_NO_MAPCHANGE);
    
    return Plugin_Continue;
}

public Action Command_Say(int client, const char[] command, int argc)
{
    if(!g_RoundActive || !IsValidClient(client))
        return Plugin_Continue;
    
    char message[256];
    char playerName[64];
    char finalMessage[512];
    
    GetCmdArgString(message, sizeof(message));
    StripQuotes(message);
    TrimString(message);
    
    if(strlen(message) == 0)
        return Plugin_Continue;
    
    GetClientName(client, playerName, sizeof(playerName));
    
    bool isTeamChat = StrEqual(command, "say_team", false);
    char chatType[16];
    
    if(isTeamChat)
    {
        int team = GetClientTeam(client);
        switch(team)
        {
            case 2: Format(chatType, sizeof(chatType), "[ALLIES]");
            case 3: Format(chatType, sizeof(chatType), "[AXIS]");
            default: Format(chatType, sizeof(chatType), "[TEAM]");
        }
    }
    else
    {
        Format(chatType, sizeof(chatType), "[ALL]");
    }
    
    Format(finalMessage, sizeof(finalMessage), "%s %s: %s", chatType, playerName, message);
    
    if(g_ChatMessages.Length < MAX_MESSAGES)
    {
        g_ChatMessages.PushString(finalMessage);
    }
    
    return Plugin_Continue;
}

public Action Timer_SendToDiscord(Handle timer, int winningTeam)
{
    if(g_ChatMessages.Length == 0)
    {
        PrintToServer("[Chat2Discord] No messages to send");
        return Plugin_Stop;
    }
    
    char teamName[32];
    switch(winningTeam)
    {
        case 2: teamName = "Allies";
        case 3: teamName = "Axis";
        default: teamName = "Unknown";
    }
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    
    // Get current date and time
    char timeString[64];
    FormatTime(timeString, sizeof(timeString), "%Y-%m-%d %H:%M:%S", GetTime());
    
    // Create Discord embed for a prettier message
    JSONObject embed = new JSONObject();
    embed.SetString("title", "Round Ended");
    embed.SetInt("color", winningTeam == 2 ? 3447003 : 15158332); // Blue for Allies, Red for Axis
    
    // Add fields to embed
    JSONArray fields = new JSONArray();
    
    JSONObject mapField = new JSONObject();
    mapField.SetString("name", "Map");
    mapField.SetString("value", mapName);
    mapField.SetBool("inline", true);
    fields.Push(mapField);
    delete mapField;
    
    JSONObject winnerField = new JSONObject();
    winnerField.SetString("name", "Winner");
    winnerField.SetString("value", teamName);
    winnerField.SetBool("inline", true);
    fields.Push(winnerField);
    delete winnerField;
    
    // Build chat log
    char chatLog[4000];
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
    
    // Trim if necessary (Discord field value limit is 1024)
    if(strlen(chatLog) > 1020)
    {
        chatLog[1017] = '.';
        chatLog[1018] = '.';
        chatLog[1019] = '.';
        chatLog[1020] = '\0';
    }
    
    JSONObject chatField = new JSONObject();
    chatField.SetString("name", "Chat Log");
    chatField.SetString("value", strlen(chatLog) > 0 ? chatLog : "No messages");
    chatField.SetBool("inline", false);
    fields.Push(chatField);
    delete chatField;
    
    embed.Set("fields", fields);
    delete fields;
    
    // Set footer with timestamp
    JSONObject footer = new JSONObject();
    footer.SetString("text", timeString);
    embed.Set("footer", footer);
    delete footer;
    
    // Create main JSON payload
    JSONObject payload = new JSONObject();
    payload.SetString("username", "DoD:S Chat Logger");
    
    JSONArray embeds = new JSONArray();
    embeds.Push(embed);
    payload.Set("embeds", embeds);
    delete embeds;
    delete embed;
    
    // Send to Discord
    HTTPRequest request = new HTTPRequest(WEBHOOK_URL);
    request.Post(payload, OnWebhookResponse);
    
    delete payload;
    
    return Plugin_Stop;
}

public void OnWebhookResponse(HTTPResponse response, any value)
{
    if(response.Status == HTTPStatus_NoContent || response.Status == HTTPStatus_OK)
    {
        PrintToServer("[Chat2Discord] Messages sent successfully to Discord (Status: %d)", response.Status);
    }
    else
    {
        PrintToServer("[Chat2Discord] Failed to send messages. Status: %d", response.Status);
        
        if(response.Data != null)
        {
            char error[256];
            response.Data.ToString(error, sizeof(error));
            PrintToServer("[Chat2Discord] Error details: %s", error);
        }
    }
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}