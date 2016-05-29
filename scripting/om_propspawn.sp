/*
	OM PropSpawn V3.0
 *	Author: Owned|Myself
 *	Contact: Please post on the forums!
 *	
 *	Sorry this took so long!
 */

// Include the neccesary files
#include <sourcemod>
#include <sdktools>
#include <smlib>

//Make it neccesary to have semicolons at the end of each line
#pragma semicolon 1

new bool:plug_debug = false;

//Version
new String:sVersion[5] = "3.0.2";
//Prefix
new String:sPrefix[256] = "\x01\x03[\x04PropSpawn\x03]\x01";

//Player properties (credits)
new iDefCredits = 20;
new iCredits[MAXPLAYERS+1];
new iPropNo[MAXPLAYERS+1];//Stores the number of props a player has
new Handle:hCredits = INVALID_HANDLE;

//Team Only
// Teams:
// 0 = No restrictions
// 1 = T
// 2 = CT
new iTeam = 2;
//ConVar Handle
new Handle:hTeamOnly = INVALID_HANDLE;
//Admin only
new bool:bAdminOnly = false;
new Handle:hAdminOnly = INVALID_HANDLE;
//Remove props on death
new Handle:hRemoveProps = INVALID_HANDLE;
new bool:bRemoveProps = true;
//Add Credits on death
new Handle:hCreditsOnDeath = INVALID_HANDLE;
new bool:bCreditsOnDeath = false;
new iDeathCreditNo = 5;
new Handle:hDeathCreditNo = INVALID_HANDLE;

// Prop Command String
new String:sPropCommand[256] = "props";

//The Menu
new Handle:om_public_prop_menu = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "OM Prop Spawn",
	author = "Owned|Myself",
	description = "A plugin which allows you to spawn physics props predefined in a text file: Public Version with Credits",
	version = sVersion,
	url = "http://forums.alliedmods.net/showthread.php?t=119238"
};

public OnPluginStart()
{
	// Control ConVars. 1 Team Only, Public Enabled etc.
	hTeamOnly = CreateConVar("om_prop_teamonly", "2", "0 is no team restrictions, 1 is Terrorist and 2 is CT. Default: 2");
	hAdminOnly = CreateConVar("om_prop_public", "0", "0 means anyone can use this plugin. 1 means admins only (no credits used)");

	// Create the version convar!
	CreateConVar("om_propspawn_version", sVersion, "OM Prop Spawn Version",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	// Register the Credits Command
	RegConsoleCmd("credits", Command_Credits);
	// Hook Player Spawn to restore player credits when they spawn
	HookEvent("player_spawn" , Event_PlayerSpawn);
	// Hook when the player dies so that props can be removed
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("round_start", Event_RoundStart);
	
	new String:tempCredits[5];
	IntToString(iDefCredits, tempCredits, sizeof(tempCredits));
	// Convar to control the credits players get when they spawn (default above)
	hCredits = CreateConVar("om_prop_credits", tempCredits, "The number of credits each player should have when they spawn");
	
	/* NEW STUFF */
	hRemoveProps = CreateConVar("om_prop_removeondeath", "1", "0 is keep the props on death, 1 is remove them on death. Default: 1");
	hCreditsOnDeath = CreateConVar("om_prop_addcreditsonkill", "0", "0 is off, 1 is on. Default: 0");
	hDeathCreditNo = CreateConVar("om_prop_killcredits", "5", "Change this number to change the number of credits a player gets when they kill someone");
	
	//Hook all the ConVar changes
	HookConVarChange(hTeamOnly, OnConVarChanged);
	HookConVarChange(hAdminOnly, OnConVarChanged);
	HookConVarChange(hCredits, OnConVarChanged);
	HookConVarChange(hRemoveProps, OnConVarChanged);
	HookConVarChange(hCreditsOnDeath, OnConVarChanged);
	HookConVarChange(hDeathCreditNo, OnConVarChanged);
	
	// Register the admin command to add credits (or remove if a minus number is used)
	RegAdminCmd("om_admin_credits", AdminCreditControl, ADMFLAG_SLAY, "Admin Credit Control Command for OM PropSpawn");
	RegAdminCmd("om_remove_prop", AdminRemovePropAim, ADMFLAG_SLAY, "Admin Prop Removal by aim");
	RegConsoleCmd(sPropCommand, PropCommand);
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar == hTeamOnly)
		iTeam = GetConVarInt(convar);
	if(convar == hAdminOnly)
		bAdminOnly = GetConVarBool(convar);
	if(convar == hCredits)
		iDefCredits = GetConVarInt(convar);
	if(convar == hRemoveProps)
		bRemoveProps = GetConVarBool(convar);
	if(convar == hCreditsOnDeath)
		bCreditsOnDeath = GetConVarBool(convar);
	if(convar == hDeathCreditNo)
		iDeathCreditNo = GetConVarInt(convar);
}

public Action:Command_Credits(client, args)
{
	new tempCredits = iCredits[client];
	PrintToChat(client, "%s You currently have %d credits!", sPrefix, tempCredits);
}

public Event_PlayerSpawn(Handle: event , const String: name[] , bool: dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	iCredits[client] = iDefCredits;
}

public Event_PlayerDeath(Handle: event , const String: name[] , bool: dontBroadcast)
{
	new victimuserid = GetEventInt(event, "userid");
	new victim = GetClientOfUserId(victimuserid);
	new attackeruserid = GetEventInt(event, "attacker");
	new attacker = GetClientOfUserId(attackeruserid);
	
	if(!Client_IsValid(attacker))
	{
		return;
	}
	
	if(bCreditsOnDeath)
	{
		PrintToChat(attacker, "%s You have been given \x03%d\x01 credits for killing someone!", sPrefix, iDeathCreditNo);
		iCredits[attacker] += iDeathCreditNo;
	}
	
	if(bRemoveProps)
	{
		KillProps(victim);
	}
}

public Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	KillProps(client);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i=1; i<=MaxClients; i++)
	{
		iPropNo[i] = 0;
	}
}

stock KillProps(client)
{
	for(new i=0; i<=iPropNo[client]; i++)
	{
		new String:EntName[MAX_NAME_LENGTH+5];
		Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, i);
		new prop = Entity_FindByName(EntName);
		if(prop != -1)
			AcceptEntityInput(prop, "kill");
	}
	iPropNo[client] = 0;
}

public Action:AdminRemovePropAim(client, args)
{
	new prop = GetClientAimTarget(client, false);
	new String:EntName[256];
	Entity_GetName(prop, EntName, sizeof(EntName));
	if(plug_debug)
	{
		PrintToChatAll(EntName);
	}
	
	new validProp = StrContains(EntName, "OMPropSpawnProp");
	
	if(validProp > -1)
	{
		//Remove the prop
		/* Find the client index in the string */
		new String:tempInd[3];
		tempInd[0] = EntName[15];
		tempInd[1] = EntName[16];
		tempInd[2] = EntName[17];
		
		if(plug_debug)
		{
			PrintToChat(client, tempInd);
		}
		
		/* We should now have the numbers somewhere, let's find out where */
		ReplaceString(tempInd, sizeof(tempInd), "_", "");
		if(plug_debug)
		{
			PrintToChat(client, tempInd);
		}
		new clientIndex = StringToInt(tempInd);
		AcceptEntityInput(prop, "kill");
		iPropNo[clientIndex] = iPropNo[clientIndex] - 1;
	}
	else
	{
		PrintToChat(client, "%s You can't delete this prop! It wasn't created by the plugin!", sPrefix);
	}
	
	return Plugin_Handled;
}

public Action:AdminCreditControl(client, args)
{
	if (args < 1)
	{
		PrintToConsole(client, "Usage: om_admin_credits <name> <credits>");
		return Plugin_Handled;
	}
 
	new String:targetName[MAX_NAME_LENGTH];
	GetCmdArg(1, targetName, sizeof(targetName));
	
	new String:SteamID[256];
	GetClientAuthString(client, SteamID, sizeof(SteamID));
	
	new target = Client_FindByName(targetName);
	
	if (target == -1)
	{
		PrintToConsole(client, "Could not find any player with the name: \"%s\"", targetName);
		return Plugin_Handled;
	}

	new String:NewCredits[32];
	GetCmdArg(2, NewCredits, sizeof(NewCredits));
	new ModCredits = StringToInt(NewCredits);
	iCredits[target] += ModCredits;
	PrintToChat(target, "%s You now have %d credits!", sPrefix, iCredits[target]);
	LogAction(client, -1, "\"%s\" added %d credits to \"%s\"", SteamID, ModCredits, targetName);
	
	return Plugin_Handled;

}

public Action:PropCommand(client, args)
{
	if(!Client_IsValid(client))
		return Plugin_Handled;
		
	if(iTeam > 0)
	{
		if(GetClientTeam(client) != iTeam+1)
		{
			PrintToChat(client, "%s Sorry you can't use this command!", sPrefix);
			return Plugin_Handled;
		}
	}
	if(bAdminOnly)
	{
		if(!Client_IsAdmin(client))
		{
			PrintToChat(client, "%s Sorry you can't use this command!", sPrefix);
			return Plugin_Handled;
		}
	}
	
	if(!IsPlayerAlive(client))
	{
		if(!Client_IsAdmin(client))
		{
			PrintToChat(client, "%s Sorry you can't use this command while dead!", sPrefix);
			return Plugin_Handled;
		}
	}
	
	new String:textPath[255];
	BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
	new Handle:kv = CreateKeyValues("Props");
	FileToKeyValues(kv, textPath);
	om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
	SetMenuTitle(om_public_prop_menu, "Prop Menu | Credits: %d", iCredits[client]);
	PopLoop(kv, client);
	DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Make sure you populate the menu, Runs through the keyvalues.
PopLoop(Handle:kv, client)
{
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			new String:buffer[256];
			KvGetSectionName(kv, buffer, sizeof(buffer));
			new admin = KvGetNum(kv, "adminonly", 0);	//New, Allows for admin only props
			if(admin == 1)
			{
				if(Client_IsAdmin(client))
				{
					new String:price[256];
					KvGetString(kv, "price", price, sizeof(price), "0");
					new String:MenuItem[256];
					Format(MenuItem, sizeof(MenuItem), "%s - Price: %s", buffer, price);
					AddMenuItem(om_public_prop_menu, buffer, MenuItem);
				}
			}
			else
			{
				new String:price[256];
				KvGetString(kv, "price", price, sizeof(price), "0");
				new String:MenuItem[256];
				Format(MenuItem, sizeof(MenuItem), "%s - Price: %s", buffer, price);
				AddMenuItem(om_public_prop_menu, buffer, MenuItem);
			}
		}
		while (KvGotoNextKey(kv));
		CloseHandle(kv);
	}
}

public Public_Prop_Menu_Handler(Handle:menu, MenuAction:action, param1, param2)
{
	// Note to self: param1 is client, param2 is choice.
	if (action == MenuAction_Select)
	{
		// Initiate the Prop Spawning using Client and Choice as the parameters.
		PropSpawn(param1, param2);
		new String:textPath[255];
		BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
		new Handle:kv = CreateKeyValues("Props");
		FileToKeyValues(kv, textPath);
		om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
		SetMenuTitle(om_public_prop_menu, "Prop Menu | Credits: %d", iCredits[param1]);
		PopLoop(kv, param1);
		DisplayMenu(om_public_prop_menu, param1, MENU_TIME_FOREVER);
	}
}

// Prop Spawning! This does all the calculations and spawning.
public PropSpawn(client, param2)
{
	new String:prop_choice[255];
	
	GetMenuItem(om_public_prop_menu, param2, prop_choice, sizeof(prop_choice));
	
	new String:name[255];
	GetClientName(client, name, sizeof(name));
	
	decl String:modelname[255];
	new Price;
	new String:file[255];
	BuildPath(Path_SM, file, 255, "configs/om_public_props.txt");
	new Handle:kv = CreateKeyValues("Props");
	FileToKeyValues(kv, file);
	KvJumpToKey(kv, prop_choice);
	KvGetString(kv, "model", modelname, sizeof(modelname),"");
	Price = KvGetNum(kv, "price", 0);
	new ClientCredits = iCredits[client];
	
	if (Price > 0)
	{
		if (ClientCredits >= Price)
		{
			if(bAdminOnly)
			{
				PrintToChat(client, "%s You have spawned a \x04%s", sPrefix, prop_choice);
				LogAction(client, -1, "\"%s\" spawned a %s", name, prop_choice);
			}
			else
			{
			ClientCredits = ClientCredits - Price;
			iCredits[client] = ClientCredits;
			PrintToChat(client, "%s You have spawned a \x04%s for \x03%d credits!", sPrefix, prop_choice, Price);
			}
		}
		else
		{
		PrintToChat(client, "%s You do not have enough credits to spawn that! Try waiting until the next round", sPrefix);
		return;
		}
	}
	
	else
	{
		PrintToChat(client, "%s You have spawned a \x04%s and your credits have not been reduced!", sPrefix, prop_choice);
	}
	decl Ent;   
	PrecacheModel(modelname,true);
	Ent = CreateEntityByName("prop_static"); 
	
	new String:EntName[256];
	Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, iPropNo[client]);
	
	DispatchKeyValue(Ent, "physdamagescale", "0.0");
	DispatchKeyValue(Ent, "model", modelname);
	DispatchKeyValue(Ent, "targetname", EntName);
	DispatchSpawn(Ent);
	
	decl Float:FurnitureOrigin[3];
	decl Float:ClientOrigin[3];
	decl Float:EyeAngles[3];
	GetClientEyeAngles(client, EyeAngles);
	GetClientAbsOrigin(client, ClientOrigin);
	
	FurnitureOrigin[0] = (ClientOrigin[0] + (50 * Cosine(DegToRad(EyeAngles[1]))));
	FurnitureOrigin[1] = (ClientOrigin[1] + (50 * Sine(DegToRad(EyeAngles[1]))));
	FurnitureOrigin[2] = (ClientOrigin[2] + KvGetNum(kv, "height", 100));
	
	TeleportEntity(Ent, FurnitureOrigin, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(Ent, MOVETYPE_NONE);   
    
	CloseHandle(kv);
	
	iPropNo[client] += 1;
	
	return;
}