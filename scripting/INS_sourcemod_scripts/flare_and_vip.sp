#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
    name = "[INS] Flare and VIP",
    description = "Flare respawn and VIP class",
    author = "Neko-",
    version = "1.0.1",
};

#define SPECTATOR_TEAM	0
#define TEAM_SPEC 		1
#define TEAM_SECURITY	2
#define TEAM_INSURGENTS	3

new Handle:g_hForceRespawn;
new Handle:g_hGameConfig;
bool g_nFlareFiredActivated = false;
new bool:g_nPlayer[MAXPLAYERS+1] = {false, ...};
new nShooterID;
new g_nVIP_ID = 0;
new g_nRoundStatus = 0;
new g_nRandomTime = 0;
new bool:g_bVIP_Alive = false;
new bool:g_TimerRunning = false;
int g_nSecond = 0;
int g_nVIP_Kills = 0;
int g_nVIP_TotalKills = 0;
int g_nVIP_TotalKillsTemp;


public OnPluginStart() 
{
	RegConsoleCmd("vip", Cmd_VIP, "Check more VIP info");
	
	
	HookEvent("weapon_fire", WeaponFireEvents, EventHookMode_Pre);
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerRespawnPre, EventHookMode_Pre);
	HookEvent("game_end", Event_GameEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", OnPlayerTeam);
	
	StartPrepSDKCall(SDKCall_Player);
	g_hGameConfig = LoadGameConfigFile("insurgency.games");
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "ForceRespawn");
	g_hForceRespawn = EndPrepSDKCall();
	if (g_hForceRespawn == INVALID_HANDLE)
	{
		SetFailState("Fatal Error: Unable to find signature for \"ForceRespawn\"!");
	}
}

public void OnMapEnd() {
	g_nVIP_ID = 0;
	g_nRoundStatus = 0;
	g_bVIP_Alive = false;
	g_TimerRunning = false;
	g_nSecond = 0;
	g_nVIP_Kills = 0;
}

public OnClientPostAdminCheck(client)
{
	g_nPlayer[client] = false;
}

public OnClientDisconnect(client)
{
	g_nPlayer[client] = false;
	if(client == g_nVIP_ID)
	{
		g_nVIP_ID = 0;
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_nRoundStatus = 1;
	g_nSecond = 0;
	g_nVIP_Kills = 0;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_nRoundStatus = 0;
	g_nSecond = 0;
	g_nVIP_Kills = 0;
}

public Action:Event_GameEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_nRoundStatus = 0;
	g_bVIP_Alive = false;
	g_TimerRunning = false;
	g_nVIP_ID = 0;
	g_nSecond = 0;
	g_nVIP_Kills = 0;
}

public Action:WeaponFireEvents(Event event, const char[] name, bool dontBroadcast)
{
	//Get client
	new clientID = GetEventInt(event, "userid");
	new client = GetClientOfUserId(clientID);
	new health = GetClientHealth(client);
	decl String:UserWeaponClass[64];
	
	//Check if client is fake player and alive
	if(!IsFakeClient(client) && (health > 0))
	{
		//Get weapon classname of client current active weapon in hand
		new CurrentUserWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		GetEdictClassname(CurrentUserWeapon, UserWeaponClass, sizeof(UserWeaponClass));

		//If the person shot using weapon_p2a1 which is flare and is looking up the skybox then continue
		if(IsValidEntity(CurrentUserWeapon) && (StrEqual(UserWeaponClass, "weapon_p2a1")) && (IsLookingAtSkybox(client)))
		{
			//If flare is activate then skip this part
			//To prevent multiple flare shooting up at the sky
			if((!g_nFlareFiredActivated))
			{
				//Set shooter respawn false
				nShooterID = client;
				
				//Start respawning timer
				CreateTimer(1.0, Timer_RespawnPlayer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				PrintHintText(client, "There is already another flare activated");
			}
		}
		else if(IsValidEntity(CurrentUserWeapon) && (StrEqual(UserWeaponClass, "weapon_p2a1")) && (!IsLookingAtSkybox(client)))
		{
			PrintHintText(client, "Drone unable to see your flare. No reinforcements");
		}
	}
	
	//return Plugin_Continue;
}

public Event_PlayerPickSquad_Post(Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsFakeClient(client))
	{
		decl String:class_template[64];
		GetEventString(event, "class_template",class_template,sizeof(class_template));
		//PrintToChat(client, "[Flare Debug by Circleus] Player: True;\nClass: %s", class_template);
		
		if(class_template[0] != EOS)
		{
			g_nPlayer[client] = true;
			//PrintToConsole(client, "[Flare Debug by Circleus] Player: True;\nClass not found");
		}
		else
		{
			g_nPlayer[client] = false;
			//PrintToConsole(client, "[Flare Debug by Circleus] Player: False;\nClass found");
		}
		
		if(StrContains(class_template, "vip") > -1)
		{
			g_nVIP_ID = client;
		}
		
		if((client == g_nVIP_ID) && (StrContains(class_template, "vip") == -1))
		{
			g_nVIP_ID = 0;
		}
	}
}

public Action:OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client  = GetClientOfUserId(GetEventInt(event, "userid"));
	new team    = GetEventInt(event, "team");
	if((team == TEAM_SPEC) && (client == g_nVIP_ID))
	{
		g_nPlayer[client] = false;
		g_nVIP_ID = 0;
		g_nVIP_Kills = 0;
		g_bVIP_Alive = false;
	}
	
	return Plugin_Continue;
}

stock void ReloadPlugin() {
    char filename[PLATFORM_MAX_PATH];
    GetPluginFilename(INVALID_HANDLE, filename, sizeof(filename));
    ServerCommand("sm plugins reload %s", filename);
}  

public Action:Event_PlayerRespawnPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsFakeClient(client))
	{
		//Flare
		if(client == nShooterID)
		{
			nShooterID = 0;
		}
		
		//VIP
		if((client) && (client == g_nVIP_ID) && (g_TimerRunning == false))
		{
			g_bVIP_Alive = true;
			g_TimerRunning = true;
			CreateTimer(1.0, Timer_Check_VIP, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if((client) && (client == g_nVIP_ID))
	{
		g_nVIP_Kills = 0;
		g_bVIP_Alive = false;
	}
	
	//new victimId = GetEventInt(event, "userid");
	new attackerId = GetEventInt(event, "attacker");
	//new victim = GetClientOfUserId(victimId);
	new attacker = GetClientOfUserId(attackerId);
	
	if(g_bVIP_Alive && (attacker == g_nVIP_ID))
	{
		g_nVIP_Kills++;
	}
}

public Action Timer_RespawnPlayer(Handle timer, any client)
{
	static int nSecond = 10;
	if(g_nRoundStatus == 0)
	{
		g_nFlareFiredActivated = false;
		nSecond = 10;
		return Plugin_Stop;
	}
	
	g_nFlareFiredActivated = true;
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	
	if(nSecond <= 0) 
    {
		for(new i = 1; i <= MaxClients; i++)
		{
			if(StrEqual(sGameMode,"checkpoint") && (i != g_nVIP_ID))
			{
				CreateRespawnPlayerTimer(i);
			}
			else if(!StrEqual(sGameMode,"checkpoint"))
			{
				CreateRespawnPlayerTimer(i);
			}
		}
		
		g_nFlareFiredActivated = false;
		//PrintHintTextToAll("Team reinforcements have arrived!");
		PrintHintText(client, "Team reinforcements have arrived!");
		nSecond = 10;
		return Plugin_Stop;
	}
	else
	{
		//PrintHintTextToAll("Team reinforcements inbound in %d", nSecond);
		PrintHintText(client, "Team reinforcements inbound in %d", nSecond);
		nSecond--;
	}
 
	return Plugin_Continue;
}

public CreateRespawnPlayerTimer(client)
{
	CreateTimer(0.0, RespawnPlayer, client);
}

public Action:RespawnPlayer(Handle:Timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	
	new currentPlayerTeam = GetClientTeam(client);
	if((IsValidClient(client)) && (!IsFakeClient(client)) && (!IsPlayerAlive(client)) && (currentPlayerTeam == TEAM_SECURITY) && (IsClientConnected(client)) && (client != nShooterID) && (g_nPlayer[client]))
	{
		SDKCall(g_hForceRespawn, client);
	}
	else
	{
		return;
	}
}

public bool:FilterOutPlayer(entity, contentsMask, any:data)
{
    if (entity == data)
    {
        return false;
    }
    
    return true;
}

bool:IsLookingAtSkybox(client)
{
	decl Float:pos[3], Float:ang[3], Float:EndOrigin[3];
	
	//Get client position
	//GetClientAbsOrigin(client, pos);
	GetClientEyePosition(client, pos);
	
	//Get client angles
	GetClientEyeAngles(client, ang);
	
	//Trace ray to find if the bullet hit the end of the entity
	//Using MASK_SHOT to trace like bullet that hit walls and stuff
	//RayType_Infinite to make the start position to infinite in case if its the sky
	//(Skybox doesn't have end position unless the map maker add invisible wall at the top)
	//TR_TraceRay(pos, ang, MASK_SHOT, RayType_Infinite);
	TR_TraceRayFilter(pos, ang, MASK_SHOT, RayType_Infinite, TraceEntityFilter:FilterOutPlayer, client);
	
	//If it it hit then run the if statement
	if(TR_DidHit())
	{
		//Get the end position of the traceray
		TR_GetEndPosition(EndOrigin);
		
		//Use GetVectorDistance to get the distance between the client and the end position
		if((ang[0] < -30) && (GetVectorDistance(EndOrigin, pos) > 400))
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	return false;
}

public Action Timer_Check_VIP(Handle timer)
{
	if(!IsValidClient(g_nVIP_ID)) return Plugin_Continue; 
	
	new nCurrentPlayerTeam = GetClientTeam(g_nVIP_ID);
	if((g_nVIP_ID == 0) || (nCurrentPlayerTeam != 2))
	{
		g_nVIP_TotalKills = 0;
		g_nRandomTime = 0;
		g_nSecond = 0;
		g_nVIP_ID = 0;
		g_nVIP_Kills = 0;
		g_TimerRunning = false;
		g_bVIP_Alive = false;
		return Plugin_Stop;
	}
	
	// Check round state
	if (g_nRoundStatus == 0) 
	{
		return Plugin_Continue;
	}
	
	if(g_bVIP_Alive == true)
	{
		g_nSecond++;
		
		//PrintToChat(g_nVIP_ID, "Your survival time is %i", nSecond);
		if(g_nRandomTime <= 0)
		{
			g_nRandomTime = GetRandomInt(180, 330);
		}
		
		if(g_nVIP_TotalKills <= 0)
		{
			g_nVIP_TotalKills = GetRandomInt(8, 12);
		}
		
		if(g_nSecond >= g_nRandomTime)
		{
			g_nRandomTime = 0;
			g_nSecond = 0;
			CreateTimer(0.0, RewardSupplyPoint);
		}
		
		if(g_nVIP_Kills >= g_nVIP_TotalKills)
		{
			g_nVIP_Kills = 0;
			g_nVIP_TotalKillsTemp = g_nVIP_TotalKills;
			g_nVIP_TotalKills = 0;
			CreateTimer(0.0, RewardSupplyPointKills);
		}
	}
	else if(g_bVIP_Alive == false)
	{
		g_nRandomTime = 0;
		g_nSecond = 0;
		//CreateTimer(0.0, RemoveSupplyPoint);
		g_TimerRunning = false;
		g_nVIP_Kills = 0;
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:RemoveSupplyPoint(Handle:Timer)
{
	//For Loop to get each client until it reach MaxClients
	for(new client = 1; client <= MaxClients; client++)
	{
		//Get currently client's team
		new nCurrentPlayerTeam = GetClientTeam(client);
		//Check if client is in game and is connected. Make sure its not fake client (Bot). Client must be in team 2 (SECURITY_TEAM)
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)) && (nCurrentPlayerTeam == 2))
		{
			//Create a panel
			new Handle:UserPanel = CreatePanel(INVALID_HANDLE);
			new String:sFirstLinePanel[80];
			new String:sSecondLinePanel[80];
			
			//Get client supply point
			int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
			
			Format(sFirstLinePanel,sizeof(sFirstLinePanel), "Supply Point(Before): %i", nSupplyPoint);
			DrawPanelText(UserPanel, sFirstLinePanel);
			
			//If nSupplyPoint is less than 0 we will keep it at 0
			if(nSupplyPoint <= 0)
			{
				nSupplyPoint = 0;
				PrintHintText(client, "VIP has died\nYou can't lose anymore supply point");
			}
			//Otherwise we get a random supply point 1 to 2 and substract if off from the nSupplyPoint we get from client
			else
			{
				new nRandomPoint = GetRandomInt(1, 2);
				nSupplyPoint -= nRandomPoint;
				PrintHintText(client, "VIP has died\nYou lose %i supply point(s)", nRandomPoint);
			}
			
			Format(sSecondLinePanel,sizeof(sSecondLinePanel), "Supply Point(Now): %i", nSupplyPoint);
			DrawPanelText(UserPanel, sSecondLinePanel);

			//Set client nSupplyPoint
			SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
			
			//Send Panel to client
			SendPanelToClient(UserPanel, client, NullMenuHandler, 2);
		}
	}
	
	return;
}

public Action:RewardSupplyPoint(Handle:Timer)
{
	ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
	new nMaxSupply = GetConVarInt(cvar_tokenmax);
	
	for(new client = 1; client <= MaxClients; client++)
	{
		//new nCurrentPlayerTeam = GetClientTeam(client);
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
		{
			int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
			int nAvailableSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
			
			if(nSupplyPoint <= nMaxSupply)
			{
				new nRandomPoint = GetRandomInt(1, 3);
				nSupplyPoint += nRandomPoint;
				nAvailableSupplyPoint += nRandomPoint;
				//PrintHintText(client, "VIP has survived\nYou have received %i supply point(s) as reward", nRandomPoint);
			}

			//Set client nSupplyPoint
			SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
			SetEntProp(client, Prop_Send, "m_nAvailableTokens", nAvailableSupplyPoint);
		}
	}
	
	return;
}

public Action:RewardSupplyPointKills(Handle:Timer)
{
	ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
	new nMaxSupply = GetConVarInt(cvar_tokenmax);
	
	for(new client = 1; client <= MaxClients; client++)
	{
		//new nCurrentPlayerTeam = GetClientTeam(client);
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
		{
			int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
			int nAvailableSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
			
			if(nSupplyPoint <= nMaxSupply)
			{
				new nRandomPoint = GetRandomInt(1, 3);
				nSupplyPoint += nRandomPoint;
				nAvailableSupplyPoint += nRandomPoint;
				//PrintHintText(client, "VIP has killed %i enemies without dying\nYou have received %i supply point(s) as reward", g_nVIP_TotalKillsTemp, nRandomPoint);
			}

			//Set client nSupplyPoint
			SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
			SetEntProp(client, Prop_Send, "m_nAvailableTokens", nAvailableSupplyPoint);
		}
	}
	
	return;
}

public Action:Cmd_VIP(client, args)
{
	int nPlayerHealth = GetClientHealth(client);
	if((client == g_nVIP_ID) && (nPlayerHealth > 0))
	{
		PrintHintText(client, "Survive %i/%i seconds or %i/%i kills without dying\nbefore your teammates get supply point reward", g_nSecond, g_nRandomTime, g_nVIP_Kills, g_nVIP_TotalKills);
	}
	else if((g_nVIP_ID != 0) && g_bVIP_Alive && (nPlayerHealth > 0))
	{
		PrintHintText(client, "VIP need to survive %i/%i seconds or %i/%i kills without dying", g_nSecond, g_nRandomTime, g_nVIP_Kills, g_nVIP_TotalKills);
	}
	else if((g_nVIP_ID != 0) && (!g_bVIP_Alive) && (client != g_nVIP_ID) && (nPlayerHealth > 0))
	{
		PrintHintText(client, "VIP is dead");
	}
	else if((g_nVIP_ID == 0) && (nPlayerHealth > 0))
	{
		PrintHintText(client, "No VIP available");
	}
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