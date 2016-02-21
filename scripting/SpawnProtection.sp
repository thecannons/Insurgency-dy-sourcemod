#include <sourcemod>
#include <sdktools>

#define VERSION "1.5"
#pragma semicolon 1

new TeamSpec;
new TeamUna;
new bool:NoTeams = false;

new Handle:SpawnProtectionEnabled;
new Handle:SpawnProtectionTime;
new Handle:SpawnProtectionNotify;

public Plugin:myinfo = 
{
	name = "Spawn Protection",
	author = "Fredd",
	description = "Adds spawn protection",
	version = VERSION,
	url = "www.sourcemod.net"
}

public OnPluginStart()
{
	CreateConVar("spawnprotection_version", VERSION, "Spawn Protection Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	SpawnProtectionEnabled		= CreateConVar("sp_on", "1");
	SpawnProtectionTime			= CreateConVar("sp_time", "5");
	SpawnProtectionNotify		= CreateConVar("sp_notify", "1");
	
	AutoExecConfig(true, "spawn_protection");
	
	decl String:ModName[21];
	GetGameFolderName(ModName, sizeof(ModName));
	
	if(StrEqual(ModName, "cstrike", false) || StrEqual(ModName, "dod", false) || StrEqual(ModName, "tf", false))
	{
		TeamSpec = 1;
		TeamUna = 0;
		NoTeams = false;
		
	} else if(StrEqual(ModName, "Insurgency", false))
	{
		TeamSpec = 3;
		TeamUna = 0;
		NoTeams = false;
	}
	else if(StrEqual(ModName, "hl2mp", false))
	{
		NoTeams = true;
	} else
	{
		SetFailState("%s is an unsupported mod", ModName);
	}
	HookEvent("player_spawn", OnPlayerSpawn);
}public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(SpawnProtectionEnabled) == 1)
	{
		new client 	= GetClientOfUserId(GetEventInt(event, "userid"));
		new Team 	= GetClientTeam(client);
		
		if(NoTeams == false)
		{
			if(Team == TeamSpec || Team == TeamUna)
				return Plugin_Continue;
		}
		if(!IsPlayerAlive(client) || IsFakeClient(client))
			return Plugin_Continue;
		
		new Float:Time = float(GetConVarInt(SpawnProtectionTime));
		
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		CreateTimer(Time, RemoveProtection, client);
		if(GetConVarInt(SpawnProtectionNotify) > 0)
			PrintToChat(client, "\x04[SpawnProtection] \x01you will be spawn protected for \x04%i \x01seconds", RoundToNearest(Time)); 
	}
	return Plugin_Continue;
}
public Action:RemoveProtection(Handle:timer, any:client)
{
	if(IsClientInGame(client))
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		if(GetConVarInt(SpawnProtectionNotify) > 0)
			PrintToChat(client, "\x04[SpawnProtection] \x01spawn protection is now off..");
	}
}