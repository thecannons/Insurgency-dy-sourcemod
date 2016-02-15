#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.1.alpha"
#define PLUGIN_DESCRIPTION "Make it possible to use coop bots in insurgency"

#define REQUIRE_EXTENSIONS
#include <insurgency>

// This will be used for checking which team the player is on before repsawning them
#define SPECTATOR_TEAM	0
#define TEAM_SPEC 	1
#define TEAM_1		2
#define TEAM_2		3

// This plugin will make it possible to use coop bots in insurgency. But the server will cause lots of craches. This plugin is just an experiment.
public Plugin:info = {
	name = "Coop bot",
	author = "naong",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION
};

new Handle:sm_coopbot_enabled = INVALID_HANDLE;
new Handle:sm_coopbot_quota = INVALID_HANDLE;
new Handle:sm_coopbot_debug = INVALID_HANDLE;
new Handle:g_hGameConfig;
new Handle:g_hPlayerRespawn;
new Float:g_fSpawnPoint[3];
new g_iCoopBotEnabled;
new g_iCoopBotQuota;
new g_iCoopBotDebug;
new g_RoundStatus = 0; //0 is over, 1 is active
new g_IsGameEnded = 0;	//0 is not ended, 1 is ended
//new g_MonitorStatus = 0; //0 is over, 1 is active
//new Handle:h_RagdollTimer[MAXPLAYERS+1];

public void OnPluginStart() {
	// cvars
	sm_coopbot_enabled = CreateConVar("sm_coopbot_enabled", "1", "Coop bot Enabled", FCVAR_NOTIFY);
	sm_coopbot_quota = CreateConVar("sm_coopbot_quota", "4", "Coop bot quota");
	sm_coopbot_debug = CreateConVar("sm_coopbot_debug", "1", "Turn on debug mode");
	
	// register admin commands
	RegAdminCmd("sm_addbot", Command_Addbot, ADMFLAG_SLAY, "sm_addbot <bot_count>");
	RegAdminCmd("sm_balancebot", Command_BalanceBot, ADMFLAG_SLAY, "sm_balancebot");
	
	// hook events
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("game_start", Event_GameStart, EventHookMode_PostNoCopy);
	HookEvent("game_end", Event_GameEnd, EventHookMode_PostNoCopy);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured_Post, EventHookMode_PostNoCopy);
	HookEvent("object_destroyed", Event_ObjectDestroyed, EventHookMode_PostNoCopy);
	//HookEvent("player_death", Event_PlayerDeath);
	
	// hook variables
	HookConVarChange(sm_coopbot_enabled,CvarChange);
	HookConVarChange(sm_coopbot_quota,CvarChange);
	HookConVarChange(sm_coopbot_debug,CvarChange);
	
	// prevent kicking bots
	AddCommandListener(ins_bot_kick, "ins_bot_kick");
	
	// set respawn command
	g_hGameConfig = LoadGameConfigFile("insurgency.games");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "ForceRespawn");
	g_hPlayerRespawn = EndPrepSDKCall();
	
	// create config file
	AutoExecConfig(true, "plugin.coopbot");
	
	// init var
	g_iCoopBotEnabled = GetConVarInt(sm_coopbot_enabled);
	g_iCoopBotQuota = GetConVarInt(sm_coopbot_quota);
	g_iCoopBotDebug = GetConVarInt(sm_coopbot_debug);
}

public Action:ins_bot_kick(client, const String:cmd[], argc)
{
	if (!g_iCoopBotEnabled || g_RoundStatus == 0) 
	{
		PrintToServer("[CoopBot] 'ins_bot_kick' Detected");
		return Plugin_Continue;
	}
	
	if (argc < 1)
	{
		//PrintToServer("[Debug] ins_bot_kick (no option)");
		return Plugin_Continue;
	}
	
	decl String:arg1[16];
	decl String:arg2[16];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	//new iBot = StringToInt(arg1);
	new iTeamId = StringToInt(arg2);
	
	if (iTeamId == 2)
	{
		
		//PrintToServer("[Debug] Prevented 'ins_bot_kick %d %d'", iBot, iTeamId);
		return Plugin_Handled;
	}
	else
	{
		//PrintToServer("[Debug] Continue 'ins_bot_kick %d %d'", iBot, iTeamId);
		return Plugin_Continue;
	}	
}
public Action:Command_Addbot(client, args) {
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addbot <bot_count>");
		return Plugin_Handled;
	}

	new String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	AddBot(StringToInt(arg1));
	PrintToChat(client, "[CoopBot] Adding bot. (Amount: %d)", StringToInt(arg1)); // show chat debug 
	
	return Plugin_Handled;
}
public Action:Command_BalanceBot(client, args) {
	PrintToChat(client, "[CoopBot] Balancing bots."); // show chat debug 
	
	return Plugin_Handled;
}

/*
public OnMapStart()
{	
	if (g_iCoopBotEnabled)
	{
		CreateTimer(5.0, Timer_MonitorBots, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		g_MonitorStatus = 1;
	}
}
public Action:Timer_MonitorBots(Handle:Timer)
{
	if (g_iCoopBotEnabled)
	{
		//PrintToServer("[CoopBot] Monitoring...(Roundstatus: %d)", g_RoundStatus);
		new iRealPlayers = GetRealClientCount();
		
		if (g_IsGameEnded == 0 && iRealPlayers > 0)
		{
			new iSecTeamCount = GetSecTeamCount();
			new iCoopBotCount = GetCoopBotCount();
			
			//PrintToServer("[CoopBot] Monitoring...(SecTeam: %d / Botquota: %d)", iSecTeamCount, g_iCoopBotQuota);
			if (iSecTeamCount < g_iCoopBotQuota || (iSecTeamCount > g_iCoopBotQuota && iCoopBotCount > 0))
			{
				BalanceBotQuota();
				//ReviveCoopAllBots();
				//CreateTimer(1.0 , Timer_ReviveBot);
				
				if (g_iCoopBotDebug)
					PrintToServer("[CoopBot] Bot count is balanced");
			}
		}
	}
	else
	{	
		g_MonitorStatus = 0;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}
*/
public CvarChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	g_iCoopBotEnabled = GetConVarInt(sm_coopbot_enabled);
	g_iCoopBotQuota = GetConVarInt(sm_coopbot_quota);
	g_iCoopBotDebug = GetConVarInt(sm_coopbot_debug);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Reset respawn position
	g_fSpawnPoint[0] = 0.0;
	g_fSpawnPoint[1] = 0.0;
	g_fSpawnPoint[2] = 0.0;
	
	g_RoundStatus = 1;
	
	/*
	if (g_iCoopBotEnabled && g_MonitorStatus)
	{
		CreateTimer(5.0, Timer_MonitorBots, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		g_MonitorStatus = 1;
	}
	*/
	
	if (g_iCoopBotEnabled)
		CreateTimer(15.5 , Timer_BalanceBot);
}
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Reset respawn position
	g_fSpawnPoint[0] = 0.0;
	g_fSpawnPoint[1] = 0.0;
	g_fSpawnPoint[2] = 0.0;
	
	g_RoundStatus = 0;
	CreateTimer(5.0 , Timer_KickAllBots);
}
public Action:Event_GameStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_IsGameEnded = 0;
}
public Action:Event_GameEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_IsGameEnded = 1;
}
public Action:Event_ControlPointCaptured_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:cappers[256];
	GetEventString(event, "cappers", cappers, sizeof(cappers));
	
	new cappersLength = strlen(cappers);
	for (new i = 0 ; i < cappersLength; i++)
	{
		new clientCapper = cappers[i];
		if(clientCapper > 0 && IsClientInGame(clientCapper) && IsValidClient(clientCapper) && IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper))
		{
			new Float:capperPos[3];
			GetClientAbsOrigin(clientCapper, Float:capperPos);

			g_fSpawnPoint = capperPos;
			
			if (g_iCoopBotDebug)
				PrintToServer("[CoopBot] Spawnpoint updated.");
			
			break;
		}
	}
	
	if (g_iCoopBotEnabled)
		CreateTimer(5.0 , Timer_BalanceBot);
}
public Action:Event_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
	//new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new attacker = GetEventInt(event, "attacker");
	
	if (g_iCoopBotDebug)
		PrintToServer("[CoopBot] Attacker: %N.",  attacker);
	if (attacker > 0 && IsValidClient(attacker))
	{
		new Float:attackerPos[3];
		GetClientAbsOrigin(attacker, Float:attackerPos);
		g_fSpawnPoint = attackerPos;
		if (g_iCoopBotDebug)
			PrintToServer("[CoopBot] Spawnpoint updated.");
	}
	else
	{
		if (g_iCoopBotDebug)
			PrintToServer("[CoopBot] Failed to update spawnpoint.");
	}
	
	if (g_iCoopBotEnabled)
		CreateTimer(5.0 , Timer_BalanceBot);
}
public Action:Timer_KickAllBots(Handle:Timer)
{
	KickAllBots();
}
public Action:Timer_BalanceBot(Handle:Timer)
{
	BalanceBotQuota();
}

public Action:Timer_ReviveBot(Handle:Timer)
{
	ReviveCoopAllBots();
}
/*
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new iTeam;
	if (IsClientInGame(client) && IsFakeClient(client))
	{
		iTeam = GetClientTeam(client);
		if (iTeam == TEAM_1)
		{
			h_RagdollTimer[client] = CreateTimer(5.0, DeleteRagdoll, client);
		}
	}
}

public Action:DeleteRagdoll(Handle:Timer, any:client)
{	
	h_RagdollTimer[client] = INVALID_HANDLE;
	if (IsClientInGame(client) && g_RoundStatus == 1 && !IsPlayerAlive(client)) 
	{
		new clientRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	    //This timer safely removes client-side ragdoll
		if(clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll))
		{
			new ref = EntIndexToEntRef(clientRagdoll);
			new entity = EntRefToEntIndex(ref);
			if(entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
			{
				AcceptEntityInput(entity, "Kill");
				clientRagdoll = INVALID_ENT_REFERENCE;
			}
		}
	}
}

public Action:PreReviveTimer(Handle:Timer)
{
	g_RoundStatus = 1;
}
*/

AddBot(iBotCount)
{
	ServerCommand("ins_bot_add %d", iBotCount);
	CreateTimer(1.0 , Timer_ReviveBot);
	PrintToServer("[CoopBot] %d of bots added.",iBotCount);
}
KickAllBots()
{
	new iTeam;
	for (new client = 1; client <= MaxClients; client++)
	{
		if (client > 0 && IsClientInGame(client) && IsFakeClient(client))
		{
			iTeam = GetClientTeam(client);
			if (iTeam == TEAM_1)
			{
				//PrintToServer("[CoopBot] %N is kicked for balancing.",client);
				KickClient(client);
			}
		}
	}
	PrintToServer("[CoopBot] All bots are kicked.");
}
BalanceBotQuota()
{
	if (GetRealClientCount() <= 0 || g_RoundStatus == 0) return;
	static iIsBalancing = 0;
	
	if (iIsBalancing)
		return;
	else
		iIsBalancing = 1;
	
	new iBalance, iSecTeamCount;
	iSecTeamCount = GetSecTeamCount();
	
	if (iSecTeamCount < g_iCoopBotQuota)
	{
		iBalance = g_iCoopBotQuota - iSecTeamCount;
		ServerCommand("ins_bot_add %d", iBalance);
		CreateTimer(1.0 , Timer_ReviveBot);
		PrintToServer("[CoopBot] %d of bots added.",iBalance);
	}
	else if (iSecTeamCount > g_iCoopBotQuota)
	{
		iBalance = iSecTeamCount - g_iCoopBotQuota;
		new iCount = 0;
		new iTeam;
		
		for (new client = 1; client <= MaxClients; client++)
		{
			if (client > 0 && IsClientInGame(client) && IsFakeClient(client))
			{
				iTeam = GetClientTeam(client);
				if (iTeam == TEAM_1)
				{
					PrintToServer("[CoopBot] %N is kicked for balancing.",client);
					KickClient(client);
					iCount++;
					
					if (iBalance <= iCount)
						break;
				}
			}
		}
	}
	
	iIsBalancing = 0;
}
ReviveCoopAllBots()
{
	if (GetRealClientCount() <= 0 || g_RoundStatus == 0) return;
	static iIsReviving = 0;
	
	if (iIsReviving)
		return;
	else
		iIsReviving = 1;
	
	new iTeam;
	for (new client = 1; client <= MaxClients; client++)
    {
		if (client > 0 && IsClientInGame(client) && IsFakeClient(client) && !IsPlayerAlive(client))
		{
			iTeam = GetClientTeam(client);
			if (iTeam == TEAM_1 && g_RoundStatus == 1)
			{
				SDKCall(g_hPlayerRespawn, client);
				
				if (g_fSpawnPoint[0] != 0.0 && g_fSpawnPoint[1] != 0.0 && g_fSpawnPoint[2] != 0.0)
					TeleportEntity(client, g_fSpawnPoint, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	PrintToServer("[CoopBot] Bot revived.");
	iIsReviving = 0;
}

stock GetCoopBotCount()
{
	new iTeam, iCoopBotCount;
	
	for (new client = 1; client <= MaxClients; client++)
    {
		if (client > 0 && IsClientInGame(client) && IsFakeClient(client))
    	{
			iTeam = GetClientTeam(client);
			if (iTeam == TEAM_1)  iCoopBotCount++
		}
	}
	return iCoopBotCount;
}
stock GetSecTeamCount()
{
	new iTeam, iSecTeamCount;
	for (new client = 1; client <= MaxClients; client++)
    {
		if (client > 0 && IsClientInGame(client))
		{
			iTeam = GetClientTeam(client);
			if (iTeam == TEAM_1) iSecTeamCount++
		}
	}
	
	return iSecTeamCount;
}
// Stock to check if client is valid
stock bool:isClientValid(client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client))
		{
			if (!IsFakeClient(client) && !IsClientSourceTV(client))
			{
				// Yeah, the client is valid
				return true;
			}
		}
	}

	// No he isn't valid
	return false;
}
stock GetRealClientCount( bool:inGameOnly = true ) {
	new clients = 0;
	new iTeam;
	for( new i = 1; i <= GetMaxClients(); i++ ) {
		if(((inGameOnly) ? IsClientInGame(i) : IsClientConnected(i) ) && !IsFakeClient(i)) {
			iTeam = GetClientTeam(i);
			if (iTeam == TEAM_1) clients++;
		}
	}
	return clients;
}