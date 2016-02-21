#pragma semicolon 1
#pragma unused cvarVersion
#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"
//UPDATE INFO:
// 0.0.2 - INCLUDED SMLIB
//		 - USED SMLIB FUNCTION MATH_GETPERCENTAGE TO CALCULATE PERCENTAGE
// 1.0	 - REMOVED SMLIB DEPENDENCY
//		 - ADDED MAG IS EMPTY RETURN
#define PLUGIN_DESCRIPTION "Shows status of mag when weapon is used."

new Handle:cvarVersion = INVALID_HANDLE; // version cvar!
new Handle:cvarEnabled = INVALID_HANDLE; // are we enabled?
new Handle:cvarShare = INVALID_HANDLE; //share the screen with other plugin?
new i_fullmag[MAXPLAYERS+1];
new Handle:WeaponsTrie;

public Plugin:myinfo = {
	name= "AmmoStatus",
	author = "wribit",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	cvarVersion = CreateConVar("sm_ammo_status_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_DONTRECORD);
	cvarEnabled = CreateConVar("sm_ammo_status_enabled", "1", "sets whether ammo atatus is enabled", FCVAR_NOTIFY | FCVAR_PLUGIN);
	cvarShare = CreateConVar("sm_ammo_status_share", "1", "sets whether the ammo status shares the screen with another plugin. i.e. showhealth", FCVAR_NOTIFY | FCVAR_PLUGIN);

	HookEvent("weapon_reload", Event_WeaponUpdate, EventHookMode_Post);
	//HookEvent("weapon_fire", Event_WeaponUpdate, EventHookMode_Post);
	//HookEvent("weapon_fire", Event_WeaponUpdate, EventHookMode_Pre);
	HookEvent("weapon_pickup", Event_WeaponUpdate);
	HookEvent("weapon_deploy", Event_WeaponUpdate);	
	
	WeaponsTrie = CreateTrie();
	
	//CREATE CONFIG FILE
	AutoExecConfig(true, "plugin.AmmoStatus");
	
	CreateTimer(0.5, Event_WeaponUpdateTimer, _, TIMER_REPEAT);
}

public Action:Event_WeaponUpdate(Handle:event, const String:name[], bool:Broadcast)
{
	if(GetConVarBool(cvarShare))
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		Check_Ammo(client,GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"));
	}
	return Plugin_Handled;
}

public Action:Event_WeaponUpdateTimer(Handle:timer)
{
	if(!GetConVarBool(cvarShare))
	{
		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientObserver(client))
			{
				Check_Ammo(client,GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"));
			}
		}
	}
	return Plugin_Handled;
}

public OnMapStart()
{
	ClearTrie(WeaponsTrie);
}


public Action:Check_Ammo(client, args)
{
	if (!GetConVarBool(cvarEnabled))
	{
		return Plugin_Handled;
	}
	
	new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	if (ActiveWeapon < 0)
	{
		return Plugin_Handled;
	}
	
	Update_Magazine(client,ActiveWeapon);
	
	decl String:sWeapon[32];
	new maxammo;
	GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
	GetTrieValue(WeaponsTrie, sWeapon, maxammo);

	new ammo = GetEntProp(ActiveWeapon, Prop_Send, "m_iClip1", 1);
	new m_bChamberedRound = GetEntData(ActiveWeapon, FindSendPropInfo("CINSWeaponBallistic", "m_bChamberedRound"),1);
	//Add one to count if we have one piped
	if (m_bChamberedRound)
	ammo++;
	
	if(maxammo > 1)
	{
		decl String:sPrint[215];
		
		if(ammo >= maxammo)
		{
			Format(sPrint,sizeof(sPrint),"Mag is at 100PERC");
			ReplaceString(sPrint, sizeof(sPrint), "PERC", "%%%");
			PrintHintText(client, sPrint); 
		}
		else if(ammo < maxammo)
		{
			new buffer;
			buffer = Math_GetPercentage(ammo, maxammo);
			
			if (buffer <=3)
			{
				Format(sPrint,sizeof(sPrint),"Mag is Empty!");
			}
			else
			{
				Format(sPrint,sizeof(sPrint),"Mag is at %iPERC",buffer);
				ReplaceString(sPrint,sizeof(sPrint), "PERC", "%%%");
			}
			
			PrintHintText(client, sPrint); 
		}
	}
	
	return Plugin_Handled;
}



public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponEquip, Weapon_Equip);
}

public Action:Weapon_Equip(client, weapon)
{
	if(GetConVarBool(cvarShare))
	{
		Check_Ammo(client, GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"));
	}
}

public Update_Magazine(client,weapon)
{
	if(IsClientInGame(client) && IsValidEntity(weapon))
	{
		decl String:sWeapon[32];
		GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
		new ammo = GetEntProp(weapon, Prop_Data, "m_iClip1");
		new m_bChamberedRound = GetEntData(weapon, FindSendPropInfo("CINSWeaponBallistic", "m_bChamberedRound"),1);
		if (m_bChamberedRound)
		{
			ammo++;
		}
		
		new maxammo;
		GetTrieValue(WeaponsTrie, sWeapon, maxammo);
	
		if (maxammo < ammo)
		{
			PrintToServer("[AMMOSTATUS] Updated Trie! Changed max ammo for %s from %d to %d",sWeapon,maxammo,ammo);
			maxammo = ammo;
			SetTrieValue(WeaponsTrie, sWeapon, ammo);
		}
		
		i_fullmag[client] = maxammo;
	}
}

//FUNCTION from SMLIB
static Math_GetPercentage(value, all) {
	return RoundToNearest((float(value) / float(all)) * 100.0);
}