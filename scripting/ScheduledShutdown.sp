/* 
* 	Scheduled Shutdown/Restart
* 	By [BR5DY]
* 
*	This plugin could not have been made without the help of MikeJS's plugin and darklord1474's plugin.
* 
* 	Automatically shuts down the server at the specified time, warning all players ahead of time.
*	Will restart automatically if you run some type of server checker or batch script :-)
* 
* 	Very basic commands - it issues the "quit" command to SRCDS at the specified time
* 
*   Cvars:
*	sm_scheduledshutdown_hintsay 1		//Sets whether messages are shown in the hint area
*	sm_scheduledshutdown_chatsay  1		//Sets whether messages are shown in chat
*	sm_scheduledshutdown_centersay 1	//Sets whether messages are shown in the center of the screen
*	sm_scheduledshutdown_time 0500		//Sets the time to shutdown the server
*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#define PL_VERSION "1.0"

new Handle:g_hEnabledChat;
new Handle:g_hEnabledHint;
new Handle:g_hEnabledCenter;
new Handle:g_hEnabled = INVALID_HANDLE;
new bool:g_bEnabled;
new Handle:g_hTime = INVALID_HANDLE;
new g_iTime;
public Plugin:myinfo = 
{
	name = "ScheduledShutdown",
	author = "BR5DY",
	description = "Shutsdown SRCDS (with options). Special thanks to MikeJS and darklord1474.",
	version = PL_VERSION,
	url = "http://br5dy.com/"
}
public OnPluginStart() {
	PrintToServer("ScheduledShutdown loaded successfully.");
	CreateConVar("sm_scheduledshutdown_version", PL_VERSION, "ScheduledShutdown version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_hEnabledHint= CreateConVar("sm_scheduledshutdown_hintsay", "1", "Sets whether messages are shown in the hint area");
	g_hEnabledChat= CreateConVar("sm_scheduledshutdown_chatsay", "1", "Sets whether messages are shown in chat");
	g_hEnabledCenter = CreateConVar("sm_scheduledshutdown_centersay", "1", "Sets whether messages are shown in the center of the screen");
	g_hEnabled = CreateConVar("sm_scheduledshutdown", "1", "Enable ScheduledShutdown.", FCVAR_PLUGIN);
	g_hTime = CreateConVar("sm_scheduledshutdown_time", "0600", "Time to shutdown server.", FCVAR_PLUGIN);
	HookConVarChange(g_hEnabled, Cvar_enabled);
	HookConVarChange(g_hTime, Cvar_time);
}
public OnMapStart() {
	CreateTimer(60.0, CheckTime, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
public OnConfigsExecuted() {
	g_bEnabled = GetConVarBool(g_hEnabled);
	decl String:iTime[8];
	GetConVarString(g_hTime, iTime, sizeof(iTime));
	g_iTime = StringToInt(iTime);
}
public Cvar_enabled(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_bEnabled = GetConVarBool(g_hEnabled);
}
public Cvar_time(Handle:convar, const String:oldValue[], const String:newValue[]) {
	decl String:iTime[8];
	GetConVarString(g_hTime, iTime, sizeof(iTime));
	g_iTime = StringToInt(iTime);
}
public Action:CheckTime(Handle:timer, any:useless) {
	if(g_bEnabled) {
		decl String:strtime[8];
		new gettime = GetTime();
		FormatTime(strtime, sizeof(strtime), "%H%M", gettime);
		new time = StringToInt(strtime);
		if (time == 530)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 30 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 30 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 30 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 540)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 20 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 20 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 20 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 550)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 10 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 10 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 10 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 555)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 5 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 5 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 5 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 557)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 3 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 3 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 3 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 558)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 1 minute...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 1 minute...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 1 minute...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 1530)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 30 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 30 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 30 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 1540)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 20 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 20 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 20 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 1550)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 10 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 10 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 10 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 1555)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 5 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 5 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 5 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 1557)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 3 minutes...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 3 minutes...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 3 minutes...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
		if (time == 1558)
		{
			if (GetConVarInt(g_hEnabledHint) >= 1)
			{
				PrintHintTextToAll("Server Auto-Restarts in 1 minute...");
			}
			if (GetConVarInt(g_hEnabledChat) >= 1)
			{
				PrintToChatAll("Server Auto-Restarts in 1 minute...");
			}
			if (GetConVarInt(g_hEnabledCenter) >= 1)
			{
				PrintCenterTextAll("Server Auto-Restarts in 1 minute...");
			}
			LogAction(0, -1, "Server shutdown warning.");
		}
	}
}

public Action:ShutItDown(Handle:timer) {
	KillTimer(Handle:timer);
	LogAction(0, -1, "Server shutdown.");
	ServerCommand("quit");
	return Plugin_Handled;
}