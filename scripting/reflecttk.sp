//UPDATE INFO
//2.0 - MADE SURE TO SAVE ALL VICTIMS HEALTH WHEN A ROCKET IS USED, OR A GRENADE. ONLY ATTACKER WILL BE PENALISED.

#pragma semicolon 1 

#include <sourcemod>
#include <sdkhooks>
#include <sdktools> 
#define PLUGIN_VERSION "2.0"

// This will be used for checking which team the player is on before repsawning them
#define SPECTATOR_TEAM	0
#define TEAM_SPEC 	1
#define TEAM_1		2
#define TEAM_2		3

new Handle:g_CvarEnabled;
new Handle:ff = INVALID_HANDLE; 
new bool:bLateLoad = false; 

public Plugin:myinfo = 
{
	name = "[INS] ReflectTK",
	author = "wribit",
	description = "simple plugin that reflects the damage caused by a team mate attacking another.",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	CreateConVar("sm_reflecttk_version", PLUGIN_VERSION, "Version of the ReflectTK Plugin", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_CvarEnabled = CreateConVar("sm_reflecttk_enabled","1","Enables(1) or disables(0) the plugin.",FCVAR_NOTIFY);
	ff = FindConVar("mp_friendlyfire"); 
	AutoExecConfig(true,"plugin.reflecttk");
 
	if(bLateLoad) 
	{ 
		for (new i = 1; i <= MaxClients; i++) 
		{ 
			if (IsClientConnected(i) && IsClientInGame(i)) 
			{ 
				OnClientPutInServer(i); 
			} 
		} 
	} 
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{ 
    bLateLoad = late; 
    return APLRes_Success; 
} 

public OnClientPutInServer(client) 
{ 
    SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage); 
} 

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) 
{ 

	if (!GetConVarBool(ff) || attacker < 1 || victim < 1 || attacker > MaxClients || victim > MaxClients || !GetConVarBool(g_CvarEnabled)) 
	{ 
		return Plugin_Continue; 
	}
	
	new iTeam = GetClientTeam(attacker);
	if ((GetClientTeam(attacker) == GetClientTeam(victim)) && (attacker != victim))
	{
		if (iTeam == TEAM_2 || (iTeam == TEAM_1 && IsFakeClient(victim)))
		{
			if(IsPlayerAlive(victim))
			{
				new Float:locDamage = damage;
				new health = GetClientHealth(victim);
				if(health > 0)
				{
					health -= ((locDamage >= 0.0) ? RoundFloat(locDamage) : (RoundFloat(locDamage) * -1));
					if (health <= 0)
					{
						health = 0;
					}
				}
				if (health <= 0 || RoundFloat(locDamage) >= 100) 
				{ 
					// ATTACKER DEAD
					ForcePlayerSuicide(victim); 
				} 
				else
				{
					//ATTACKER HURT
					SetEntityHealth(victim, health);	
				}
			}
			
			return Plugin_Changed;
		}
		else
		{
			//VICTIM
			new Float:locDamage = damage;
			damage = 0.0; //SET DAMAGE TO 0
			//ATTACKER
			if(IsPlayerAlive(attacker))
			{
				new health = GetClientHealth(attacker);
				if(health > 0)
				{
					health -= ((locDamage >= 0.0) ? RoundFloat(locDamage) : (RoundFloat(locDamage) * -1));
					if (health <= 0)
					{
						health = 0;
					}
				}
				
				if (health <= 0 || RoundFloat(locDamage) >= 100) 
				{ 
					// ATTACKER DEAD
					ForcePlayerSuicide(attacker); 
				} 
				else
				{
					//ATTACKER HURT
					SetEntityHealth(attacker, health);	
				}
			}
			
			//LET PLAYERS KNOW WHAT HAPPENED
			new Handle:VictimPanel = CreatePanel(INVALID_HANDLE);
			new Handle:AttackerPanel = CreatePanel(INVALID_HANDLE);
			new String:sVicPrint[80];
			new String:sAttPrint[80];
			
			Format(sAttPrint,sizeof(sAttPrint), "- %i HP for hurting %N", ((locDamage >= 0.0) ? RoundFloat(locDamage) : (RoundFloat(locDamage) * -1)), victim);
			Format(sVicPrint,sizeof(sVicPrint), "%N was penalized for shooting you", attacker);
			//WHAT THE VICTIM SEES
			DrawPanelText(VictimPanel, sVicPrint);
			SendPanelToClient(VictimPanel, victim, NullMenuHandler, 1);
			CloseHandle(VictimPanel);
			//WHAT THE ATTACKER SEES
			DrawPanelText(AttackerPanel, sAttPrint);
			SendPanelToClient(AttackerPanel, attacker, NullMenuHandler, 1);
			CloseHandle(AttackerPanel);
			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public NullMenuHandler(Handle:menu, MenuAction:action, param1, param2) 
{
}