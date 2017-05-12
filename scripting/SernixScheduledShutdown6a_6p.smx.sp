/*
** ATTENTION
** THE PRODUCED CODE, IS NOT ABLE TO COMPILE!
** THE DECOMPILER JUST TRIES TO GIVE YOU A POSSIBILITY
** TO LOOK HOW A PLUGIN DOES IT'S JOB AND LOOK FOR
** POSSIBLE MALICIOUS CODE.
**
** ALL CONVERSIONS ARE WRONG! AT EXAMPLE:
** SetEntityRenderFx(client, RenderFx 0);  →  SetEntityRenderFx(client, view_as<RenderFx>0);  →  SetEntityRenderFx(client, RENDERFX_NONE);
*/

 PlVers __version = 5;
 float NULL_VECTOR[3];
 char NULL_STRING[1];
 Extension __ext_core = 72;
 int MaxClients;
 Extension __ext_sdktools = 1032;
 Handle g_hEnabledChat;
 Handle g_hEnabledHint;
 Handle g_hEnabledCenter;
 Handle g_hEnabled;
 bool g_bEnabled;
 Handle g_hTime;
 int g_iTime;
public Plugin myinfo =
{
	name = "ScheduledShutdown",
	description = "Shutsdown SRCDS (with options). Special thanks to MikeJS and darklord1474.",
	author = "BR5DY",
	version = "1.0",
	url = "http://br5dy.com/"
};
public int __ext_core_SetNTVOptional()
{
	MarkNativeAsOptional("GetFeatureStatus");
	MarkNativeAsOptional("RequireFeature");
	MarkNativeAsOptional("AddCommandListener");
	MarkNativeAsOptional("RemoveCommandListener");
	MarkNativeAsOptional("BfWriteBool");
	MarkNativeAsOptional("BfWriteByte");
	MarkNativeAsOptional("BfWriteChar");
	MarkNativeAsOptional("BfWriteShort");
	MarkNativeAsOptional("BfWriteWord");
	MarkNativeAsOptional("BfWriteNum");
	MarkNativeAsOptional("BfWriteFloat");
	MarkNativeAsOptional("BfWriteString");
	MarkNativeAsOptional("BfWriteEnt");
	MarkNativeAsOptional("BfWriteAngle");
	MarkNativeAsOptional("BfWriteCoord");
	MarkNativeAsOptional("BfWriteVecCoord");
	MarkNativeAsOptional("BfWriteVecNormal");
	MarkNativeAsOptional("BfWriteAngles");
	MarkNativeAsOptional("BfReadBool");
	MarkNativeAsOptional("BfReadByte");
	MarkNativeAsOptional("BfReadChar");
	MarkNativeAsOptional("BfReadShort");
	MarkNativeAsOptional("BfReadWord");
	MarkNativeAsOptional("BfReadNum");
	MarkNativeAsOptional("BfReadFloat");
	MarkNativeAsOptional("BfReadString");
	MarkNativeAsOptional("BfReadEntity");
	MarkNativeAsOptional("BfReadAngle");
	MarkNativeAsOptional("BfReadCoord");
	MarkNativeAsOptional("BfReadVecCoord");
	MarkNativeAsOptional("BfReadVecNormal");
	MarkNativeAsOptional("BfReadAngles");
	MarkNativeAsOptional("BfGetNumBytesLeft");
	MarkNativeAsOptional("PbReadInt");
	MarkNativeAsOptional("PbReadFloat");
	MarkNativeAsOptional("PbReadBool");
	MarkNativeAsOptional("PbReadString");
	MarkNativeAsOptional("PbReadColor");
	MarkNativeAsOptional("PbReadAngle");
	MarkNativeAsOptional("PbReadVector");
	MarkNativeAsOptional("PbReadVector2D");
	MarkNativeAsOptional("PbGetRepeatedFieldCount");
	MarkNativeAsOptional("PbSetInt");
	MarkNativeAsOptional("PbSetFloat");
	MarkNativeAsOptional("PbSetBool");
	MarkNativeAsOptional("PbSetString");
	MarkNativeAsOptional("PbSetColor");
	MarkNativeAsOptional("PbSetAngle");
	MarkNativeAsOptional("PbSetVector");
	MarkNativeAsOptional("PbSetVector2D");
	MarkNativeAsOptional("PbAddInt");
	MarkNativeAsOptional("PbAddFloat");
	MarkNativeAsOptional("PbAddBool");
	MarkNativeAsOptional("PbAddString");
	MarkNativeAsOptional("PbAddColor");
	MarkNativeAsOptional("PbAddAngle");
	MarkNativeAsOptional("PbAddVector");
	MarkNativeAsOptional("PbAddVector2D");
	MarkNativeAsOptional("PbRemoveRepeatedFieldValue");
	MarkNativeAsOptional("PbReadMessage");
	MarkNativeAsOptional("PbReadRepeatedMessage");
	MarkNativeAsOptional("PbAddMessage");
	VerifyCoreVersion();
	return 0;
}

int PrintToChatAll(char format[])
{
	char buffer[192];
	int i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, 192, format, 2);
			PrintToChat(i, "%s", buffer);
			i++;
		}
		i++;
	}
	return 0;
}

int PrintCenterTextAll(char format[])
{
	char buffer[192];
	int i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, 192, format, 2);
			PrintCenterText(i, "%s", buffer);
			i++;
		}
		i++;
	}
	return 0;
}

int PrintHintTextToAll(char format[])
{
	char buffer[192];
	int i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, 192, format, 2);
			PrintHintText(i, "%s", buffer);
			i++;
		}
		i++;
	}
	return 0;
}

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
			int var2;
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
			int var3;
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
			int var4;
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
			int var5;
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
			int var6;
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
			int var7;
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
			int var8;
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
			int var9;
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
			int var10;
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
			int var11;
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
			int var12;
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

