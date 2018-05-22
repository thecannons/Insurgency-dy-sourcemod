#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define TEAM_NONE 0
#define TEAM_SPECTATORS 1

new Handle:SpawnProtectionEnabled;
new Handle:SpawnProtectionTime;
new Handle:SpawnProtectionNotify;
new bool:g_bRoundStarted = false;
new bool:g_bGameStarted = false;

public Plugin:myinfo = 
{
    name = "[INS] SpawnProtection",
    author = "Neko-",
    description = "Adds spawn protection",
    version = "1.0.2"
}

public OnPluginStart()
{
	SpawnProtectionEnabled = CreateConVar("sp_enable", "1.0", "Enable or disable spawn protection", FCVAR_NONE, true, 0.0, true, 1.0);
	SpawnProtectionTime = CreateConVar("sp_time", "10.0", "Enable or disable spawn protection", FCVAR_NONE, true, 1.0, true, 30.0);
	SpawnProtectionNotify = CreateConVar("sp_notify", "1.0", "Enable or disable spawn protection", FCVAR_NONE, true, 0.0, true, 1.0);

	AutoExecConfig(true, "ins.spawn_protection");

	HookEvent("player_spawn", Event_PlayerSpawnPost);
	HookEvent("round_start", Event_RoundStartPost);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
}

public OnMapStart()
{
	g_bGameStarted = true;
}

public Action:Event_RoundStartPost(Handle:event, const String:name[], bool:dontBroadcast)
{
	//When round just start, we set it to false cuz it havn't start yet
	g_bRoundStarted = false;
	
	new nTimerPreround;
	
	//If g_bGameStarted is false, that's mean game havn't start yet. Which will use the first preround timer
	if(!g_bGameStarted)
	{
		nTimerPreround = GetConVarInt(FindConVar("mp_timer_preround_first"));
		CreateTimer(float(nTimerPreround), NoMoreRoundProtection);
	}
	//Else game already started, we will use the normal preround timer
	else
	{
		nTimerPreround = GetConVarInt(FindConVar("mp_timer_preround"));
		CreateTimer(float(nTimerPreround), NoMoreRoundProtection);
	}
}

public Action:Event_PlayerSpawnPost(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(SpawnProtectionEnabled) == 1)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		new clientTeam = GetClientTeam(client);

		//If player is spectator or not in a team (continue)
		if((clientTeam == TEAM_NONE) || (clientTeam == TEAM_SPECTATORS))
			return Plugin_Continue;
		
		//If player alive (continue)
		if(!IsPlayerAlive(client))
			return Plugin_Continue;
		
		//If its a bot (continue)
		//To prevent bot from having protection
		if(IsFakeClient(client))
			return Plugin_Continue;
		
		
		new Float:Time = GetConVarFloat(SpawnProtectionTime);
		
		//If game havn't started, we will use the first preround time and add it to the timer
		if(!g_bGameStarted)
		{
			new Float:nTimerPreround = float(GetConVarInt(FindConVar("mp_timer_preround_first")));
			Time += nTimerPreround;
		}
		//Else if round havn't start yet, we will use the normal preround time and add it to the timer
		else if(!g_bRoundStarted)
		{
			new Float:nTimerPreround = float(GetConVarInt(FindConVar("mp_timer_preround")));
			Time += nTimerPreround;
		}
		
		//Set damage taken to 0 (So player won't take damage)
		SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);
		
		//Create a timer to restore the original damage taken
		CreateTimer(Time, RemoveProtection, client);
		
		//If notify set to 1 then we will notify the player that they have spawn protection
		if(GetConVarInt(SpawnProtectionNotify) > 0)
			//PrintToChat(client, "\x01\x0759b0f9[INS] \x01\x07ee1fd0[SpawnProtection] \x01You have spawn protection for %i seconds", RoundToNearest(Time));
			PrintCenterText(client, "You have spawn protection for %i seconds", RoundToNearest(Time));		
	}
	return Plugin_Continue;
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if((!IsFakeClient(victim)) && (victim == attacker))
	{
		//Create a timer to restore the original damage taken
		CreateTimer(0.0, RemoveProtection, victim);
	}
}

public Action:RemoveProtection(Handle:timer, any:client)
{
	//Get player protection
	new nTakeDamage = GetEntProp(client, Prop_Data, "m_takedamage");
	
	//If player still in game
	if(IsClientInGame(client) && (nTakeDamage == 1))
	{
		//Restore the original damage taken to player
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		
		//If notify set to 1 then we will notify the player that their protection have been removed
		if(GetConVarInt(SpawnProtectionNotify) > 0)
			//PrintToChat(client, "\x01\x0759b0f9[INS] \x01\x07ee1fd0[SpawnProtection] \x01You no longer have spawn protection");
			PrintCenterText(client, "You no longer have spawn protection");
	}
}

public Action:NoMoreRoundProtection(Handle:timer)
{
	//After round started, we set this to true to let it know that our round already started
	g_bRoundStarted = true;
	
	//Set g_bGameStarted to true if its false
	if(!g_bGameStarted)
	{
		g_bGameStarted = true;
	}
}