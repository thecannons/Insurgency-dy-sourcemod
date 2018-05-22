#include <sourcemod>
#include <sdktools>
#include <dynamic>
#include <SteamWorks>
#include <scp>

#define PLUGIN_DESCRIPTION "TeamKill System"
#define PLUGIN_NAME "[INS] TeamKilling"
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_AUTHOR "Neko-"

new g_nPlayerTKCounter[MAXPLAYERS+1];
new g_nPlayerTKGame[MAXPLAYERS+1];
new g_nPlayerBanTime[MAXPLAYERS+1];
new g_nVictimMarker[MAXPLAYERS+1] = {0, ...};
new bool:g_bIsBanned[MAXPLAYERS+1] = {false, ...};
new g_nKickLimit;
new g_nGameID;
new g_nTotalTK, g_nTotalAutoBan, g_nTotalForgive;
new Handle:hConfigFile = INVALID_HANDLE;

new Handle:cvarBanMultiplier = INVALID_HANDLE;
new Handle:cvarBanMaxTime = INVALID_HANDLE;

char gS_WebhookURL[1024];

public Plugin:myinfo = {
	name            = PLUGIN_NAME,
	author          = PLUGIN_AUTHOR,
	description     = PLUGIN_DESCRIPTION,
	version         = PLUGIN_VERSION,
};

public OnPluginStart() 
{
	cvarBanMultiplier = CreateConVar("tk_ban_multiplier", "2.0", "Use the last ban time and multiply it", FCVAR_PROTECTED, true, 2.0, true, 10.0);
	cvarBanMaxTime = CreateConVar("tk_ban_maxtime", "10.0", "Max ban time", FCVAR_PROTECTED);
	
	RegConsoleCmd("tk", Cmd_TK_Info, "Check your own TK count");
	RegConsoleCmd("forgive", Cmd_Forgive, "Forgive your attacker TK");
	RegAdminCmd("tk_data", Cmd_TK_Data, ADMFLAG_KICK, "Team Killing Data");
	HookEvent("player_death", Event_PlayerDeath);
	
	LoadConfig();
	AutoExecConfig(true,"ins.teamkilling");
	
	char[] sError = new char[256];

	if(!LoadConfigDiscord(sError, 256))
	{
		SetFailState("Couldn't load the configuration file. Error: %s", sError);
	}
}

LoadConfig()
{
	if(hConfigFile != INVALID_HANDLE)
	{
		CloseHandle(hConfigFile);
	}
	hConfigFile = CreateKeyValues("teamkilling");
}

bool LoadConfigDiscord(char[] error, int maxlen)
{
	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/discord.cfg");

	Dynamic dConfigFile = Dynamic();

	if(!dConfigFile.ReadKeyValues(sPath))
	{
		dConfigFile.Dispose();

		FormatEx(error, maxlen, "Couldn't access \"%s\". Make sure that the file exists and has correct permissions set.", sPath);

		return false;
	}

	dConfigFile.GetString("WebhookURL", gS_WebhookURL, 1024);

	if(StrContains(gS_WebhookURL, "https://discordapp.com/api/webhooks") == -1)
	{
		FormatEx(error, maxlen, "Please change the value of WebhookURL in the configuration file (\"%s\") to a valid URL. Current value is \"%s\".", sPath, gS_WebhookURL);

		return false;
	}

	return true;
}

public OnMapStart()
{
	g_nKickLimit = GetConVarInt(FindConVar("mp_autokick_tk_limit"));
	g_nGameID = GetRandomInt(1, 99999);
}

public OnClientDisconnect(client)
{
	if(!IsFakeClient(client))
	{
		ResetClientData(client);
		g_nVictimMarker[client] = 0;
	}
}

public OnClientPostAdminCheck(client)
{
	if(!IsFakeClient(client))
	{
		HookClient(client);
		g_nVictimMarker[client] = 0;
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victimId = GetEventInt(event, "userid");
	new attackerId = GetEventInt(event, "attacker");
	
	new victim = GetClientOfUserId(victimId);
	new attacker = GetClientOfUserId(attackerId);
	
	if(IsValidClient(victim) && IsValidClient(attacker))
	{
		if((!IsFakeClient(victim)) && (!IsFakeClient(attacker)) && (GetClientTeam(attacker) == GetClientTeam(victim)) && (victim != attacker))
		{
			char[] sFormat = new char[1024];
			FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game TeamKill System");
	
			g_nVictimMarker[victim] = attacker;
			g_nPlayerTKCounter[attacker]++;
			g_nTotalTK++;
			decl String:strVictim[64];
			decl String:strAttacker[64];
			GetClientName(victim, strVictim, sizeof(strVictim));
			GetClientName(attacker, strAttacker, sizeof(strAttacker));
			
			
			decl String:strVictimAuthID[64];
			GetClientAuthString(victim, strVictimAuthID, 64);
			decl String:strAttackerAuthID[64];
			GetClientAuthString(attacker, strAttackerAuthID, 64);
			
			char[] sNewMessage = new char[1024];
			FormatEx(sNewMessage, 1024, "**[%s] %s** killed a teammate **([%s] %s)**", strAttackerAuthID, strAttacker, strVictimAuthID, strVictim);
			EscapeString(sNewMessage, 1024);
			ReplaceString(sFormat, 1024, "{msg}", sNewMessage);
			
			Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
			SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
			SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
			SteamWorks_SendHTTPRequest(hRequest);

			
			PrintToChatAll("\x01\x07e32d2d%s\x01 killed a teammate (\x01\x07e32d2d%s\x01)\n\x01\x07e32d2d%s\x01 total TK: %i of %i", strAttacker, strVictim, strAttacker, g_nPlayerTKCounter[attacker], g_nKickLimit);
			PrintToServer("[Teamkilling] %s killed a teammate (%s)", strAttacker, strVictim);
			
			new AdminId:admin = GetUserAdmin(attacker);
			if(g_nPlayerTKCounter[attacker] >= g_nKickLimit)
			{
				if((admin != INVALID_ADMIN_ID) && (GetAdminFlag(admin, Admin_Generic, Access_Effective)))
				{
					ServerCommand("kick %s", strAttacker);
					g_nPlayerTKCounter[attacker] = 0;
				}
				else
				{
					new playerId = GetClientUserId(attacker);
					if(!g_bIsBanned[attacker])
					{
						g_nTotalAutoBan++;
						ServerCommand("sm_ban #%i %i \"Team Killing\"", playerId, g_nPlayerBanTime[attacker]);
						PrintToServer("[Teamkilling] %s has been auto banned", strAttacker);
						g_bIsBanned[attacker] = true;
						g_nPlayerBanTime[attacker] = RoundToNearest(g_nPlayerBanTime[attacker] * GetConVarFloat(cvarBanMultiplier));
						if(g_nPlayerBanTime[attacker] > GetConVarFloat(cvarBanMaxTime))
						{
							g_nPlayerBanTime[attacker] = RoundToNearest(GetConVarFloat(cvarBanMaxTime));
						}
						g_nPlayerTKCounter[attacker] = 0;
						
						FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game TeamKill System");
						FormatEx(sNewMessage, 1024, "**[%s] %s** is banned for **%i minutes** (Teamkill Auto-ban)", strAttackerAuthID, strAttacker, g_nPlayerBanTime[attacker]);
						EscapeString(sNewMessage, 1024);
						ReplaceString(sFormat, 1024, "{msg}", sNewMessage);
						
						Handle hRequest1 = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
						SteamWorks_SetHTTPRequestRawPostBody(hRequest1, "application/json", sFormat, strlen(sFormat));
						SteamWorks_SetHTTPCallbacks(hRequest1, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
						SteamWorks_SendHTTPRequest(hRequest1);
					}
				}
			}
			else
			{
				PrintToChat(victim, "\x01\x0759b0f9[INS] \x01\x07ee1fd0[TeamKill]\x01 Type /forgive in your chat to forgive your TKer. Otherwise, they will get ban when they reach %i TKs.", g_nKickLimit);
			}
			
			new String:strAuth[64];
			GetClientAuthString(attacker, strAuth, sizeof(strAuth));
			if(strlen(strAuth) && strcmp(strAuth, "BOT", false ) && strcmp(strAuth, "STEAM_ID_PENDING", false))
			{
				KvRewind(hConfigFile);
				if(KvJumpToKey(hConfigFile, strAuth, true))
				{
					KvSetNum(hConfigFile, "team_kills", g_nPlayerTKCounter[attacker]);
					KvSetNum(hConfigFile, "game_id", g_nGameID);
					KvSetNum(hConfigFile, "ban_time", g_nPlayerBanTime[attacker]);
					KvGoBack(hConfigFile);
				}
			}
		}
	}
}

stock HookClient(client)
{
	ResetClientData(client);
	
	if(0 < client <= MaxClients && IsClientConnected(client))
	{
		new String:strAuth[64];
		GetClientAuthString(client, strAuth, sizeof(strAuth));
		if(strlen(strAuth) && strcmp(strAuth, "BOT", false ) && strcmp(strAuth, "STEAM_ID_PENDING", false))
		{
			KvRewind(hConfigFile);
			if(KvJumpToKey(hConfigFile, strAuth))
			{
				g_nPlayerTKCounter[client] = KvGetNum(hConfigFile, "team_kills", 0);
				g_nPlayerTKGame[client] = KvGetNum(hConfigFile, "game_id", g_nGameID);
				g_nPlayerBanTime[client] = KvGetNum(hConfigFile, "ban_time", 10);
				KvGoBack(hConfigFile);
			}
			else
			{
				g_nPlayerTKCounter[client] = 0;
				g_nPlayerTKGame[client] = g_nGameID;
				g_nPlayerBanTime[client] = 10;
			}
		}
	}
	
	if(g_nPlayerTKGame[client] != g_nGameID)
	{
		g_nPlayerTKCounter[client] = 0;
		g_nPlayerTKGame[client] = g_nGameID;
	}
}

stock ResetClientData(client)
{
	g_nPlayerTKCounter[client] = 0;
	g_nPlayerTKGame[client] = 0;
	g_nPlayerBanTime[client] = 0;
	g_bIsBanned[client] = false;
}

public Action:Cmd_TK_Info(client, args)
{
	new nBanTime = g_nPlayerBanTime[client];
	decl String:strTemp[128];
	if(nBanTime > 60)
	{
		nBanTime = RoundToNearest(nBanTime / 60);
		Format(strTemp, sizeof(strTemp), "%i hours", nBanTime);
	}
	else
	{
		Format(strTemp, sizeof(strTemp), "%i minutes", nBanTime);
	}
	
	PrintToChat(client, "\x01\x0759b0f9[INS] \x01\x07ee1fd0[TeamKill]\x01 Your total TK: %i of %i", g_nPlayerTKCounter[client], g_nKickLimit);
	PrintToChat(client, "\x01\x0759b0f9[INS] \x01\x07ee1fd0[TeamKill]\x01 If you reach %i TKs, you will get ban for %s.", g_nKickLimit, strTemp);
	return Plugin_Handled;
}

public Action:Cmd_Forgive(client, args)
{
	if(g_nVictimMarker[client] > 0)
	{
		if(IsClientInGame(g_nVictimMarker[client]) && (g_nPlayerTKCounter[g_nVictimMarker[client]] > 0))
		{
			new attacker = g_nVictimMarker[client];
			decl String:strVictim[64];
			decl String:strAttacker[64];
			GetClientName(client, strVictim, sizeof(strVictim));
			GetClientName(g_nVictimMarker[client], strAttacker, sizeof(strAttacker));
			
			g_nPlayerTKCounter[attacker]--;
			g_nTotalForgive++;
			
			PrintToChatAll("\x01\x07e32d2d%s\x01 forgive \x01\x07e32d2d%s\x01 \n\x01\x07e32d2d%s\x01 total TK: %i of %i", strVictim, strAttacker, strAttacker, g_nPlayerTKCounter[attacker], g_nKickLimit);
			g_nVictimMarker[client] = 0;
			
			new String:strAuth[64];
			GetClientAuthString(attacker, strAuth, sizeof(strAuth));
			if(strlen(strAuth) && strcmp(strAuth, "BOT", false ) && strcmp(strAuth, "STEAM_ID_PENDING", false))
			{
				KvRewind(hConfigFile);
				if(KvJumpToKey(hConfigFile, strAuth))
				{
					KvSetNum(hConfigFile, "team_kills", g_nPlayerTKCounter[attacker]);
					KvSetNum(hConfigFile, "game_id", g_nGameID);
					KvSetNum(hConfigFile, "ban_time", g_nPlayerBanTime[attacker]);
					KvGoBack(hConfigFile);
				}
			}
		}
		else
		{
			g_nVictimMarker[client] = 0;
		}
	}
	
	return Plugin_Handled;
}

public Action:Cmd_TK_Data(client, args)
{
	PrintToChat(client, "\x01\x0759b0f9[INS] \x01\x07ee1fd0[TeamKill]\x01 Total TK %i, Total Forgive %i, Total Ban %i", g_nTotalTK, g_nTotalForgive, g_nTotalAutoBan);
	return Plugin_Handled;
}

bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}

public NullMenuHandler(Handle:menu, MenuAction:action, param1, param2) 
{
}



//---------------------------------
//	DISCORD
//---------------------------------

void EscapeString(char[] string, int maxlen)
{
	ReplaceString(string, maxlen, "@", "＠");
	ReplaceString(string, maxlen, "'", "＇");
	ReplaceString(string, maxlen, "\"", "＂");
}

public void OnRequestComplete(Handle hRequest, bool bFailed, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	delete hRequest;
}