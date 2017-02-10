#include <sourcemod>
#include <geoip>

#define PLUGIN_VERSION "1.1"
#define PLUGIN_NAME "Log Connections"

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Xander (Player 1)",
	description = "This plugin logs players' connect and disconnect times along with their Name, SteamID, and IP Address to a text file at /sourcemod/logs/connections/ seperate from the server logs.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=1845362"
}

new String:g_sFilePath[PLATFORM_MAX_PATH];

public OnPluginStart()
{
	BuildPath(Path_SM, g_sFilePath, sizeof(g_sFilePath), "logs/connections/");
	
	if (!DirExists(g_sFilePath))
	{
		CreateDirectory(g_sFilePath, 511);
		
		if (!DirExists(g_sFilePath))
			SetFailState("Failed to create directory at /sourcemod/logs/connections - Please manually create that path and reload this plugin.");
	}
	
	CreateConVar("sm_log_connections_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY);
	
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public OnMapStart()
{
	decl String:FormatedTime[100],
		String:MapName[100];
		
	new CurrentTime = GetTime();
	
	GetCurrentMap(MapName, 100);
	FormatTime(FormatedTime, 100, "%d_%b_%Y", CurrentTime); //name the file 'day month year'
	
	BuildPath(Path_SM, g_sFilePath, sizeof(g_sFilePath), "/logs/connections/%s.txt", FormatedTime);
	
	new Handle:FileHandle = OpenFile(g_sFilePath, "a+");
	
	FormatTime(FormatedTime, 100, "%X", CurrentTime);
	
	WriteFileLine(FileHandle, "");
	WriteFileLine(FileHandle, "%s - ===== Map change to %s =====", FormatedTime, MapName);
	WriteFileLine(FileHandle, "");
	
	CloseHandle(FileHandle);
}
		
public Action:Event_PlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(5.0, LogConnectionInfo, GetEventInt(event, "userid"));
}

public Action:LogConnectionInfo(Handle:timer, any:UserID)
{
	new client = GetClientOfUserId(UserID); //will return 0 if the client quits, even if a new player takes his slot
	
	if (!client)
	{}
	
	else if (IsFakeClient(client))
	{}
	
	else if (!IsClientAuthorized(client))
		CreateTimer(5.0, LogConnectionInfo, UserID);	//client's steamid isn't known yet; retry in 5 seconds
	
	else
	{
		decl String:PlayerName[64],
			String:Authid[64],
			String:IPAddress[64],
			String:Country[64],
			String:FormatedTime[64];
		
		GetClientName(client, PlayerName, 64);
		GetClientAuthString(client, Authid, 64);
		GetClientIP(client, IPAddress, 64);
		FormatTime(FormatedTime, 64, "%X", GetTime())
		
		if(!GeoipCountry(IPAddress, Country, 64))
			Format(Country, 64, "Unknown");
		
		new Handle:FileHandle = OpenFile(g_sFilePath, "a+");
		
		WriteFileLine(FileHandle, "%s - <%s> <%s> <%s> CONNECTED from <%s>",
								FormatedTime,
								PlayerName,
								Authid,
								IPAddress,
								Country);

		CloseHandle(FileHandle);
	}
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
	{}
	
	else if (IsFakeClient(client))
	{}
	
	else
	{
		new ConnectionTime = -1,
			Handle:FileHandle = OpenFile(g_sFilePath, "a+");
		
		decl String:PlayerName[64],
			String:Authid[64],
			String:IPAddress[64],
			String:FormatedTime[64],
			String:Reason[128];
		
		GetClientName(client, PlayerName, 64);
		GetClientIP(client, IPAddress, 64);
		FormatTime(FormatedTime, 64, "%X", GetTime());
		GetEventString(event, "reason", Reason, 128);
		
		if (!GetClientAuthString(client, Authid, 64))
			Format(Authid, 64, "Unknown SteamID");
		
		if (IsClientInGame(client))
			ConnectionTime = RoundToCeil(GetClientTime(client) / 60);
		
		
		WriteFileLine(FileHandle, "%s - <%s> <%s> <%s> DISCONNECTED after %d minutes. <%s>",
								FormatedTime,
								PlayerName,
								Authid,
								IPAddress,
								ConnectionTime,
								Reason);
		
		CloseHandle(FileHandle);
	}
}