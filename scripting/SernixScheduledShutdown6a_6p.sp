
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
public Plugin myinfo =
{
	name = "ScheduledShutdown",
	description = "Shutsdown SRCDS (with options). Special thanks to MikeJS and darklord1474.",
	author = "BR5DY",
	version = "1.0",
	url = "http://br5dy.com/"
};

public void OnPluginStart()
{
	PrintToServer("ScheduledShutdown loaded successfully.");
	CreateConVar("sm_scheduledshutdown_version", "1.0", "ScheduledShutdown version.", 270656, false, 0, false, 0);
	g_hEnabledHint = CreateConVar("sm_scheduledshutdown_hintsay", "1", "Sets whether messages are shown in the hint area", 0, false, 0, false, 0);
	g_hEnabledChat = CreateConVar("sm_scheduledshutdown_chatsay", "1", "Sets whether messages are shown in chat", 0, false, 0, false, 0);
	g_hEnabledCenter = CreateConVar("sm_scheduledshutdown_centersay", "1", "Sets whether messages are shown in the center of the screen", 0, false, 0, false, 0);
	g_hEnabled = CreateConVar("sm_scheduledshutdown", "1", "Enable ScheduledShutdown.", 262144, false, 0, false, 0);
	g_hTime = CreateConVar("sm_scheduledshutdown_time", "0600", "Time to shutdown server.", 262144, false, 0, false, 0);
	HookConVarChange(g_hEnabled, ConVarChanged 3);
	HookConVarChange(g_hTime, ConVarChanged 5);
	return void 0;
}

public void OnMapStart()
{
	CreateTimer(60, CheckTime, any 0, 3);
	return void 0;
}

public void OnConfigsExecuted()
{
	g_bEnabled = GetConVarBool(g_hEnabled);
	char iTime[8];
	GetConVarString(g_hTime, iTime, 8);
	g_iTime = StringToInt(iTime, 10);
	return void 0;
}

public int Cvar_enabled(Handle convar, char oldValue[], char newValue[])
{
	g_bEnabled = GetConVarBool(g_hEnabled);
	return 0;
}

public int Cvar_time(Handle convar, char oldValue[], char newValue[])
{
	char iTime[8];
	GetConVarString(g_hTime, iTime, 8);
	g_iTime = StringToInt(iTime, 10);
	return 0;
}

public Action CheckTime(Handle timer, any useless)
{
	if (g_bEnabled)
	{
		decl String:strtime[8];
		new gettime = GetTime();
		FormatTime(strtime, sizeof(strtime), "%H%M", gettime);
		new time = StringToInt(strtime);

		char strtime[8];
		int gettime = GetTime({0,0});
		FormatTime(strtime, 8, "%H%M", gettime);
		int time = StringToInt(strtime, 10);
		int var1;
		if (time >= 530)
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
		else
		{
			if (time >= 540)
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
			if (time >= 550)
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
			if (time >= 555)
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
			if (time >= 557)
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
			if (time >= 558)
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
			if (time >= 1730)
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
			if (time >= 1740)
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
			if (time >= 1750)
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
			if (time >= 1755)
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
			if (time >= 1757)
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
			if (time >= 1758)
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
	return Action 0;
}

public Action ShutItDown(Handle timer)
{
	KillTimer(timer, false);
	LogAction(0, -1, "Server shutdown.");
	ServerCommand("quit");
	return Action 3;
}

