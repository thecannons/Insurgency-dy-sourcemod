/*
	OM PropSpawn V3.0
 *	Author: Owned|Myself
 *	Contact: Please post on the forums!
 *	
 *	Sorry this took so long!
 */
//Potential prop Lists:
// models\fortifications\barbed_wire_04a.mdl  (barb wire with low center dip in collision mesh)
// models\fortifications\barbed_wire_04.mdl same as above, slight less dip.
// models\fortifications\barbed_wire_04.mdl even, slightly less noticeable edge bars.
// models\props\crate01.mdl if small enough good to climb
// insurgency_models.vpk\models\static_fittings\overhang_03.mdl  ramp for walls?
// \insurgency_models.vpk\models\static_military\sandbag_wall_short_b.mdl snow short sandbag
// insurgency\insurgency_models.vpk\models\fortifications\sandbag_wall_short.mdl  // Same sandbag short
// models\structures\overhang_01.mdl // slight overhand model ramp
// models/iraq/ir_hesco_basket_01.mdl Hesco single like large 4
// \insurgency\insurgency_models.vpk\models\static_afghan\prop_fortification_hesco_large.mdl   Large hesco
// insurgency2\insurgency\insurgency_models.vpk\models\iraq\ir_hesco_basket_01_row.mdl  Large 4 Hesco (need to engineers 10 points each)



// Include the neccesary files
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS

//Make it neccesary to have semicolons at the end of each line
#pragma semicolon 1

//Define keys
#define IN_ATTACK   (1 << 0)
#define IN_JUMP     (1 << 1)
#define IN_BACK    (1 << 3)
#define IN_LEFT     (1 << 7)
#define IN_RIGHT    (1 << 8)
#define IN_MOVELEFT   (1 << 9)
#define IN_MOVERIGHT    (1 << 10)

#define IN_DUCK     (1 << 2) // crouch
#define IN_FORWARD  (1 << 4)
#define IN_USE      (1 << 5)
#define IN_CANCEL   (1 << 6)
#define IN_RUN      (1 << 12)
#define IN_SPEED    (1 << 17) /**< Player is holding the speed key */
#define IN_SPRINT     (1 << 15) // sprint key in insurgency
#define IN_ATTACK2 (1 << 18)
#define IN_RELOAD   (1 << 13)
#define IN_ALT1     (1 << 14)
#define IN_SCORE    (1 << 16)     /**< Used by client.dll for when scoreboard is held down */
#define IN_ZOOM     (1 << 19) /**< Zoom key for HUD zoom */
#define IN_WEAPON1    (1 << 20) /**< weapon defines these bits */
#define IN_WEAPON2    (1 << 21) /**< weapon defines these bits */
#define IN_BULLRUSH   (1 << 22)
#define IN_GRENADE1   (1 << 23) /**< grenade 1 */
#define IN_GRENADE2   (1 << 24) /**< grenade 2 */


// This will be used for checking which team the player is on before repsawning them
#define SPECTATOR_TEAM	0
#define TEAM_SPEC 	1
#define TEAM_1		2
#define TEAM_2		3

#define MAX_BUTTONS 25
new bool:plug_debug = false;

new bool:isStuck[MAXPLAYERS+1];
//Version
new String:sVersion[5] = "3.0.2";
//Prefix
new String:sPrefix[256] = "\x01\x03[\x04PropSpawn\x03]\x01";

//Player properties (credits)
new iDefCredits = 10;
new iCredits[MAXPLAYERS+1];
new iPropNo[MAXPLAYERS+1];//Stores the number of props a player has
new Handle:hCredits = INVALID_HANDLE;
new Handle:g_param1;
new Handle:g_param2;
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
new Handle:hIntegDegrade = INVALID_HANDLE;
new Handle:hIntegRepair = INVALID_HANDLE;
new Handle:ConstructTimers[MAXPLAYERS+1];
new	g_integrityDegrade = 20;
new	g_integrityRepair = 10;
new g_CvarYellChance;

// Status
new
	String:g_client_last_classstring[MAXPLAYERS+1][64],
	Float:g_engineerPos[MAXPLAYERS+1][3],
	g_ConstructDeployTime = 4,
	g_engineerParam[MAXPLAYERS+1],
	g_ConstructRemainingTime[MAXPLAYERS+1],
	g_engInMenu[MAXPLAYERS+1],
	g_propIntegrity[MAXPLAYERS+1],
	bool:g_isSolid[MAXPLAYERS+1],
	g_ConstructPackTime = 1,
	g_LastButtons[MAXPLAYERS+1];

// whether or not the player has an active cooldown, end time for cooldown
new bool:PlayerCooldown[MAXPLAYERS + 1] = {true, ...};
new Float:PlayerTimedone[MAXPLAYERS + 1];

// length of time to wait before yelling can occur again (in seconds)
new Handle:hCvarYellChance;
new Handle:CooldownPeriod;
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

// list of specific files that are decent
new String:BuildSounds[][] = {
	"player/voice/security/command/subordinate/cover1.ogg",
	"player/voice/security/command/subordinate/cover2.ogg",
	"player/voice/security/command/subordinate/cover3.ogg"

};

public OnPluginStart()
{
	// Control ConVars. 1 Team Only, Public Enabled etc.
	hTeamOnly = CreateConVar("om_prop_teamonly", "0", "0 is no team restrictions, 1 is Terrorist and 2 is CT. Default: 2");
	hAdminOnly = CreateConVar("om_prop_public", "0", "0 means anyone can use this plugin. 1 means admins only (no credits used)");
	hIntegDegrade = CreateConVar("om_integrity_degrade", "20", "This is the amount that degrades from the prop when enemy bots are near it per bot, per second");
	hIntegRepair = CreateConVar("om_integrity_repair", "10", "When a engineer is repairing, this amount repairs per second.");
	// Create the version convar!
	CreateConVar("om_propspawn_version", sVersion, "OM Prop Spawn Version",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	// Register the Credits Command
	//RegConsoleCmd("credits", Command_Credits);
	// Hook Player Spawn to restore player credits when they spawn
	HookEvent("player_spawn" , Event_PlayerSpawn);
	// Hook when the player dies so that props can be removed
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_pick_squad", Event_PlayerPickSquad);
	HookEvent("round_end", Event_RoundEnd);
	
	new String:tempCredits[5];
	IntToString(iDefCredits, tempCredits, sizeof(tempCredits));
	// Convar to control the credits players get when they spawn (default above)
	hCredits = CreateConVar("om_prop_credits", "tempCredits", "The number of credits each player should have when they spawn");
	
	/* NEW STUFF */
	hRemoveProps = CreateConVar("om_prop_removeondeath", "0", "0 is keep the props on death, 1 is remove them on death. Default: 1");
	hCreditsOnDeath = CreateConVar("om_prop_addcreditsonkill", "0", "0 is off, 1 is on. Default: 0");
	hDeathCreditNo = CreateConVar("om_prop_killcredits", "0", "Change this number to change the number of credits a player gets when they kill someone");
	hCvarYellChance = CreateConVar("fy_chance", "1.0", "Chance of Yelling [0-1]", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, true, 1.0);
	CooldownPeriod = CreateConVar("fy_cooldown", "3.0", "Cooldown period between yells [>0.0]", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, false);
	
	//Hook all the ConVar changes
	HookConVarChange(hTeamOnly, OnConVarChanged);
	HookConVarChange(hAdminOnly, OnConVarChanged);
	HookConVarChange(hCredits, OnConVarChanged);
	HookConVarChange(hRemoveProps, OnConVarChanged);
	HookConVarChange(hCreditsOnDeath, OnConVarChanged);
	HookConVarChange(hDeathCreditNo, OnConVarChanged);
	HookConVarChange(hIntegDegrade, OnConVarChanged);
	HookConVarChange(hIntegRepair, OnConVarChanged);
	HookConVarChange(hCvarYellChance, OnConVarChanged);
	
	// Register the admin command to add credits (or remove if a minus number is used)
	RegAdminCmd("om_admin_credits", AdminCreditControl, ADMFLAG_SLAY, "Admin Credit Control Command for OM PropSpawn");
	RegAdminCmd("om_remove_prop", AdminRemovePropAim, ADMFLAG_SLAY, "Admin Prop Removal by aim");
	//RegConsoleCmd(sPropCommand, PropCommand);

	AutoExecConfig(true, "sernix_prop_spawn");
}

// On map starts, call initalizing function
public OnMapStart()
{	
	
	PrecacheSound("player/voice/security/command/subordinate/cover1.ogg");
	PrecacheSound("player/voice/security/command/subordinate/cover2.ogg");
	PrecacheSound("player/voice/security/command/subordinate/cover3.ogg");

	CreateTimer(5.0, Timer_MapStart);
}
public Action:Timer_MapStart(Handle:Timer)
{
	CreateTimer(1.0, Timer_Monitor_Props,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
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
	if(convar == g_integrityRepair)
		g_integrityRepair = GetConVarInt(convar);
	if(convar == g_integrityDegrade)
		g_integrityDegrade = GetConVarInt(convar);
	if(convar == hCvarYellChance)
		g_CvarYellChance = GetConVarFloat(convar);
}

public Action:Command_Credits(client, args)
{
	new tempCredits = iCredits[client];
	PrintToChat(client, "You currently have %d credits!", tempCredits);
}

public OnClientPutInServer(client) {

	iCredits[client] = iDefCredits;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamagePre);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{

	//Clear props
	for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
	{
		if (engineerCheck > 0)
		{
			if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
			{
				KillProps(engineerCheck);
			}
		}
	}
}
public Action:Timer_Monitor_Props(Handle:Timer)
{
	//PrintToServer("DEBUG 1");
	for (new client = 1; client <= MaxClients; client++)
	{
		//ENgineer specific
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && (StrContains(g_client_last_classstring[client], "engineer") > -1))
		{
			//PrintToServer("DEBUG 2");
			for(new i=0; i<=iPropNo[client]; i++)
			{
				new String:EntName[MAX_NAME_LENGTH+5];
				Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, i);
				new prop = Entity_FindByName(EntName);
				if(prop != -1)
				{	
					new isNearby = Check_NearbyBots(prop);
					if (isNearby == true)
					{
						//PrintToServer("g_integrityDegrade %d", g_integrityDegrade);
						g_propIntegrity[i] = g_propIntegrity[i] - g_integrityDegrade;
						if (g_propIntegrity[i] <= 0)
						{

							if(prop != -1)
								AcceptEntityInput(prop, "kill");

							//Refund for prop
							new propParam = g_engineerParam[iPropNo[i]];
							new String:prop_choice[255];
							GetMenuItem(om_public_prop_menu, propParam, prop_choice, sizeof(prop_choice));
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
							decl String:textToPrintChat[64];

							if (Price > 0)
							{

									ClientCredits = ClientCredits + Price;
									iCredits[client] = ClientCredits;
									PrintToChat(client, "Your \x04%s has been destroyed. Refuunded \x03%d credits!", prop_choice, Price);
							}

							g_propIntegrity[i] = 0;
							i = -1;
						}
					}
				}
			}
		}
		//All units
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client))
		{

			//PrintToServer("DEBUG 5");

			for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
			{

				if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
				{

					//PrintToServer("DEBUG 6");
					for(new i=0; i<=iPropNo[engineerCheck]; i++)
					{
						new String:EntName[MAX_NAME_LENGTH+5];
						Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", engineerCheck, i);
						new prop = Entity_FindByName(EntName);
						//Need another engineer to test
						if(prop != -1)
						{	
							//PrintToServer("DEBUG 7");
							//Get position of bot and prop
							new Float:plyrOrigin[3];
							new Float:propOrigin[3];
							new Float:fDistance;
					
							GetClientAbsOrigin(client,plyrOrigin);
							GetEntPropVector(prop, Prop_Send, "m_vecOrigin", propOrigin);
							
							//determine distance from the two
							fDistance = GetVectorDistance(propOrigin,plyrOrigin);

							isStuck[client] = false;
							isStuck[client] = IsStuckInEnt(client, prop); // Check if player stuck in prop
							
							if (fDistance <= 250 && isStuck[client] == true)
							{
								if (g_isSolid[iPropNo[i]] == true)
								{
									//PrintToChatAll("Object = NOT SOLID");
									//DispatchKeyValue(prop, "Solid", "0");  
									g_isSolid[iPropNo[i]] = false;
									//PrintToServer("DEBUG 8");
								}
							}

							new propIntegrity = g_propIntegrity[i];

							// Target is prop
							new tPropTarget = GetClientAimTarget(client, false);
							if (tPropTarget != -1)
							{
								new iPropRef = EntIndexToEntRef(tPropTarget);
								new mPropRef = EntIndexToEntRef(prop);

								//PrintToChatAll("EngineerProp: %S, TargetProp: %S", mPropRef, iPropRef);
								if (iPropRef == mPropRef && fDistance <= 400 && !(StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
								{

									decl String:sBuf[255];
									Format(sBuf, 255,"Deployable Owner: [%N] | Integrity: %d", client, propIntegrity);
									PrintHintText(client, "%s", sBuf);	
										//PrintToServer("DEBUG 9");					
								}

								new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
								if (ActiveWeapon < 0)
									continue;
								// Get weapon class name
								decl String:sWeapon[32];
								GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

								if (iPropRef == mPropRef && fDistance <= 120 && (StrContains(g_client_last_classstring[client], "engineer") > -1))
								{
									if (StrContains(sWeapon, "weapon_knife") > -1)
									{
										//PrintToServer("g_integrityRepair: %d | propIntegrity %d", g_integrityRepair, propIntegrity);
										propIntegrity = propIntegrity + g_integrityRepair;
										g_propIntegrity[i] = propIntegrity;
										//PrintToServer("g_propIntegrity[iPropNo[i]]_Repair: %d", g_propIntegrity[i]);
									}
									if (propIntegrity > 100)
									{
										propIntegrity = 100;
										g_propIntegrity[i] = 100;
									}
									decl String:sBuf[255];
									Format(sBuf, 255,"Deployable Owner[%N] | Integrity: %d", engineerCheck, propIntegrity);
									PrintHintText(client, "%s", sBuf);	
										//PrintToServer("DEBUG 9");					
								}
							}
						}
					}
				}
			}
		}

	}

}

// Trace client's view entity
stock TraceClientViewEntity(client)
{
	new Float:m_vecOrigin[3];
	new Float:m_angRotation[3];

	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);

	new Handle:tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TRDontHitSelf, client);
	new pEntity = -1;

	if (TR_DidHit(tr))
	{
		pEntity = TR_GetEntityIndex(tr);
		CloseHandle(tr);
		return pEntity;
	}

	if(tr != INVALID_HANDLE)
	{
		CloseHandle(tr);
	}
	
	return -1;
}
// Check is hit self
public bool:TRDontHitSelf(entity, mask, any:data) // Don't ray trace ourselves -_-"
{
	return (1 <= entity <= MaxClients) && (entity != data);
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Stuck Detection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
stock bool:IsStuckInEnt(client, ent){
    decl Float:vecMin[3], Float:vecMax[3], Float:vecOrigin[3];
    
    GetClientMins(client, vecMin);
    GetClientMaxs(client, vecMax);
    
    GetClientAbsOrigin(client, vecOrigin);
    
    TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_ALL, TraceRayHitOnlyEnt, ent);
    return TR_DidHit();
}

bool:CheckStuckInEntity(entity) 
{ 
    for (new i=0;i<=MaxClients;i++) 
    { 
    	if (i > 0)
    	{
	        if (IsClientInGame(i) && IsPlayerAlive(i) && IsStuckInEnt(i, entity))// && !IsFakeClient(i) 
	            return true; 
    	}
    } 
    return false; 
} 
public bool:TraceRayHitOnlyEnt(entityhit, mask, any:data) {
    return entityhit==data;
}
stock bool:CheckIfPlayerIsStuck(iClient)
{
	decl Float:vecMin[3], Float:vecMax[3], Float:vecOrigin[3];
	
	GetClientMins(iClient, vecMin);
	GetClientMaxs(iClient, vecMax);
	GetClientAbsOrigin(iClient, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceEntityFilterSolid);
	return TR_DidHit();	// head in wall ?
}

public bool:TraceEntityFilterSolid(entity, contentsMask) 
{
	return entity > 1;
}
public Check_NearbyBots(builtProp)
{
	for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
	{
		if (IsClientConnected(enemyBot) && IsClientInGame(enemyBot)) 
		{
			new team = GetClientTeam(enemyBot); 
			if (IsFakeClient(enemyBot) && IsPlayerAlive(enemyBot))// && team == TEAM_2)
			{
				//Get position of bot and prop
				new Float:botOrigin[3];
				new Float:propOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(enemyBot,botOrigin);
				GetEntPropVector(builtProp, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(propOrigin,botOrigin);
				
				if (fDistance <= 260)
				{
					return true;
				}
			}
		}
	}
	return false;
}

public Check_NearbyPlayers(builtProp)
{
	for (new friendlyPlayer = 1; friendlyPlayer <= MaxClients; friendlyPlayer++)
	{
		if (IsClientConnected(friendlyPlayer) && IsClientInGame(friendlyPlayer))
		{
			new team = GetClientTeam(friendlyPlayer);
			if (!IsFakeClient(friendlyPlayer) && IsPlayerAlive(friendlyPlayer) && team == TEAM_2)
			{
				//Get position of bot and prop
				new Float:plyrOrigin[3];
				new Float:propOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(friendlyPlayer,plyrOrigin);
				GetEntPropVector(builtProp, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(propOrigin,plyrOrigin);
				
				if (fDistance <= 210)
				{
					return true;
				}
			}
		}
	}
	return false;
}

public Event_PlayerSpawn(Handle: event , const String: name[] , bool: dontBroadcast)
{

	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	//iCredits[client] = iDefCredits;
	if ((StrContains(g_client_last_classstring[client], "engineer") > -1))
	{
		g_engInMenu[client] = false;
		g_ConstructRemainingTime[client] = g_ConstructDeployTime;
	}
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
	if ((StrContains(g_client_last_classstring[victim], "engineer") > -1))
	{
		g_engInMenu[victim] = false;
		g_ConstructRemainingTime[victim] = g_ConstructDeployTime;
	}
	// if(bCreditsOnDeath)
	// {
	// 	PrintToChat(attacker, "You have been given \x03%d\x01 credits for killing someone!", iDeathCreditNo);
	// 	iCredits[attacker] += iDeathCreditNo;
	// }
	
	// if(bRemoveProps)
	// {
	// 	KillProps(victim);
	// }
}
// When player picked squad, initialize variables
public Action:Event_PlayerPickSquad( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"squad_slot" "byte"
	//"squad" "byte"
	//"userid" "short"
	//"class_template" "string"
	//PrintToServer("##########PLAYER IS PICKING SQUAD!############");
	
	// Get client ID
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	iCredits[client] = iDefCredits;
	// Init variable
	if (client > 0 && !IsFakeClient(client))
	{	
		// Get class name
		decl String:class_template[64];
		GetEventString(event, "class_template", class_template, sizeof(class_template));
		
		// Set class string
		g_client_last_classstring[client] = class_template;
		KillProps(client);
	}
}
public Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	KillProps(client);
	g_LastButtons[client] = 0;
	RemoveCooldown(client);
	g_engInMenu[client] = false;
	g_ConstructRemainingTime[client] = g_ConstructDeployTime;
	
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i=0; i<=MaxClients; i++)
	{
		iPropNo[i] = 0;
	}

	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	iCredits[client] = iDefCredits;
}
public Action:YellOut(client) {

	switch(GetRandomInt(1, 3))
	{
		case 1: EmitSoundToAll("player/voice/security/command/subordinate/cover1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 2: EmitSoundToAll("player/voice/security/command/subordinate/cover2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 3: EmitSoundToAll("player/voice/security/command/subordinate/cover3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
	}
	return Plugin_Continue;
}

public Action:SetCooldown(client) {
	// remove the existing timedone
	RemoveCooldown(client);

	// set timedone for client
	new Float:timedone = GetGameTime() + GetConVarFloat(CooldownPeriod);
	PlayerTimedone[client] = timedone;
	PlayerCooldown[client] = true;

}

public Action:RemoveCooldown(client) {
	PlayerCooldown[client] = false;
	PlayerTimedone[client] = 0.0;

}
stock KillProps(client)
{
	for(new i=0; i<=iPropNo[client]; i++)
	{
		g_propIntegrity[i] = 0;
		new String:EntName[MAX_NAME_LENGTH+5];
		Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, i);
		new prop = Entity_FindByName(EntName);
		if(prop != -1)
			AcceptEntityInput(prop, "kill");
	}
	iPropNo[client] = 0;
	iCredits[client] = iDefCredits;
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
		PrintToChat(client, "You can't delete this prop! It wasn't created by the plugin!");
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
	GetClientAuthId(client, AuthId_SteamID64, SteamID, sizeof(SteamID));
	
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
	PrintToChat(target, "You now have %d credits!", iCredits[target]);
	LogAction(client, -1, "\"%s\" added %d credits to \"%s\"", SteamID, ModCredits, targetName);
	
	return Plugin_Handled;

}

public Action:PropCommand(client, args)
{
	if(!Client_IsValid(client))
		return Plugin_Handled;
		
	// if(iTeam > 0)
	// {
	// 	if(GetClientTeam(client) != iTeam+1)
	// 	{
	// 		PrintToChat(client, "%s Sorry you can't use this command!", sPrefix);
	// 		return Plugin_Handled;
	// 	}
	// }
	// if(bAdminOnly)
	// {
	// 	if(!Client_IsAdmin(client))
	// 	{
	// 		PrintToChat(client, "%s Sorry you can't use this command!", sPrefix);
	// 		return Plugin_Handled;
	// 	}
	// }
	
	// if(!IsPlayerAlive(client))
	// {
	// 	if(!Client_IsAdmin(client))
	// 	{
	// 		PrintToChat(client, "%s Sorry you can't use this command while dead!", sPrefix);
	// 		return Plugin_Handled;
	// 	}
	// }
	
	new String:textPath[255];
	BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
	new Handle:kv = CreateKeyValues("Props");
	FileToKeyValues(kv, textPath);
	om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
	SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
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
					Format(MenuItem, sizeof(MenuItem), "%s - Cost: %s", buffer, price);
					AddMenuItem(om_public_prop_menu, buffer, MenuItem);
				}
			}
			else
			{
				new String:price[256];
				KvGetString(kv, "price", price, sizeof(price), "0");
				new String:MenuItem[256];
				Format(MenuItem, sizeof(MenuItem), "%s - Cost: %s", buffer, price);
				AddMenuItem(om_public_prop_menu, buffer, MenuItem);
			}
		}
		while (KvGotoNextKey(kv));
		CloseHandle(kv);
	}
	AddMenuItem(om_public_prop_menu, "decontruct", "Decontruct All Deployables");
	AddMenuItem(om_public_prop_menu, "fastexit", "Fast Exit");
}

public Action:Timer_Construct(Handle timer, Handle pack)
{
	int client;
	new target;
 	
	/* Set to the beginning and unpack it */
	ResetPack(pack);
	client = ReadPackCell(pack);
	target = ReadPackCell(pack);

	// Get current position
	decl Float:vecPos[3];
	GetClientAbsOrigin(client, vecPos);
	new Float:vectDist;
	new Float:EngCurrentPos[3];
	EngCurrentPos = vecPos;
	vectDist = GetVectorDistance(EngCurrentPos, g_engineerPos[client]);
	new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (ActiveWeapon < 0)
		return Plugin_Stop;
	// Get weapon class name
	decl String:sWeapon[32];
	GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

	if (client > 0 && vectDist < 0 || vectDist > 0 || !IsPlayerAlive(client) || IsClientTimingOut(client) || !(StrContains(sWeapon, "weapon_knife") > -1))
	{
		decl String:textPrintChat[64];
		Format(textPrintChat, sizeof(textPrintChat), "(Deploy Canceled) - You moved and or put knife away");
		PrintHintText(client, textPrintChat);
		PrintToChat(client, textPrintChat);
		g_engInMenu[client] = false;
		return Plugin_Stop;
	}
	if (client > 0 && g_ConstructRemainingTime[client] <= 0 && IsPlayerAlive(client) && !IsClientTimingOut(client) && (StrContains(sWeapon, "weapon_knife") > -1))
	{
		g_ConstructRemainingTime[client] = g_ConstructDeployTime;
		PropSpawn(client, target);
		new String:textPath[255];
		BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
		new Handle:kv = CreateKeyValues("Props");
		FileToKeyValues(kv, textPath);
		om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
		SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
		PopLoop(kv, client);
		DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
		new Float:CurrentTime = GetGameTime();
		if (PlayerCooldown[client]) {
			if (CurrentTime < PlayerTimedone[client]) {
				//return Plugin_Continue;
			} else {
				RemoveCooldown(client);
			}
		}
		else
		{
			// play sound at the player if RNG passes
			//new Float:rn = GetRandomFloat(0.0, 1.0);
			//if (rn <= g_CvarYellChance) {
				YellOut(client);
				SetCooldown(client);
			//}
		}
		return Plugin_Stop;
	}
	g_ConstructRemainingTime[client]--;
	decl String:textToPrint[64];
	decl String:prop_choice[255];
	
	GetMenuItem(om_public_prop_menu, target, prop_choice, sizeof(prop_choice));
	Format(textToPrint, sizeof(textToPrint), "Deploying %s in %d seconds\n(Move to cancel deploy)", prop_choice, g_ConstructRemainingTime[client]);
	PrintHintText(client, textToPrint);
	//g_engInMenu[client] = false;
	return Plugin_Continue;
}

public Public_Prop_Menu_Handler(Handle:menu, MenuAction:action, param1, param2)
{
	// Note to self: param1 is client, param2 is choice.
	if (action == MenuAction_Select)
	{
		//char info[32];
 
		/* Get item info */
		//menu.GetItem(param2, info, sizeof(info))
		if (param2 == 2)
		{
			KillProps(param1);
			PrintHintText(param1, "Deployables Deconstructed");
			PrintToChat(param1, "Deployables Deconstructed");
			 g_ConstructRemainingTime[param1] = g_ConstructDeployTime;

			g_engInMenu[param1] = false;
			// new String:textPath[255];
			// BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
			// new Handle:kv = CreateKeyValues("Props");
			// FileToKeyValues(kv, textPath);
			// om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
			// SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[param1]);
			// PopLoop(kv, param1);
			// DisplayMenu(om_public_prop_menu, param1, MENU_TIME_FOREVER);
			return Plugin_Stop;
		}
		if (param2 == 3)
		{
			g_engInMenu[param1] = false;
			return Plugin_Stop;
		}
		
		new String:prop_choice[255];
	
		GetMenuItem(om_public_prop_menu, param2, prop_choice, sizeof(prop_choice));

		decl String:modelname[255];
		new Price;
		new String:file[255];
		BuildPath(Path_SM, file, 255, "configs/om_public_props.txt");
		new Handle:kv = CreateKeyValues("Props");
		FileToKeyValues(kv, file);
		KvJumpToKey(kv, prop_choice);
		KvGetString(kv, "model", modelname, sizeof(modelname),"");
		Price = KvGetNum(kv, "price", 0);
		new ClientCredits = iCredits[param1];
		decl String:textToPrintChat[64];

		if (Price > 0)
		{
			if (ClientCredits >= Price)
			{
				//Check for sound cooldown
				new Float:CurrentTime = GetGameTime();
				if (PlayerCooldown[param1]) {
					if (CurrentTime < PlayerTimedone[param1]) {
						//return Plugin_Continue;
					} else {
						RemoveCooldown(param1);
					}
				}
				else
				{
					// play sound at the player if RNG passes
					//new Float:rn = GetRandomFloat(0.0, 1.0);
					//if (rn <= g_CvarYellChance) {
						YellOut(param1);
						SetCooldown(param1);
					//}
				}
				// Get current position
				decl Float:vecPos[3];
				GetClientAbsOrigin(param1, vecPos);
				g_engineerPos[param1] = vecPos;
				g_ConstructRemainingTime[param1] = g_ConstructDeployTime;
				// Initiate the Prop Spawning using Client and Choice as the parameters.
				DataPack pack;
				ConstructTimers[param1] = CreateDataTimer(1.0, Timer_Construct, pack, TIMER_REPEAT);
				pack.WriteCell(param1);
				pack.WriteCell(param2);
				//CreateTimer(1.0, Timer_Construct, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				PrintToChat(param1, "You do not have enough credits to deploy that!"); 
				PrintHintText(param1, "You do not have enough credits to deploy that!");
				// new String:textPath[255];
				// BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
				// new Handle:kv = CreateKeyValues("Props");
				// FileToKeyValues(kv, textPath);
				// om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
				// SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[param1]);
				// PopLoop(kv, param1);
				// DisplayMenu(om_public_prop_menu, param1, MENU_TIME_FOREVER);
				g_engInMenu[param1] = false;
				return Plugin_Stop;
			}
		}
	}
	if (action == MenuAction_Cancel)
	{
		g_engInMenu[param1] = false;
		if (ConstructTimers[param1] != null)
		{
			KillTimer(ConstructTimers[param1]);
			ConstructTimers[param1] = null;
		}
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
	decl String:textToPrintChat[64];

	if (Price > 0)
	{
		if (ClientCredits >= Price)
		{
			if(bAdminOnly)
			{
				PrintToChat(client, "You have deployed a \x04%s", prop_choice);
				PrintHintText(client, "You have deployed a %s", prop_choice);
				LogAction(client, -1, "\"%s\" deployed a %s", name, prop_choice);
				PrintToChat(client, "You have deployed a \x04%s for \x03%d credits!", prop_choice, Price);
				Format(textToPrintChat, 255,"\x05%N\x01 deployed a \x04%s", client, prop_choice);
				PrintToChatAll("%s", textToPrintChat);
			}
			else
			{
			
			ClientCredits = ClientCredits - Price;
			iCredits[client] = ClientCredits;
			PrintToChat(client, "You have deployed a \x04%s for \x03%d credits!", prop_choice, Price);
			PrintHintText(client, "You have deployed a %s for %d credits!", prop_choice, Price);
			Format(textToPrintChat, 255,"\x05%N\x01 deployed a \x04%s", client, prop_choice);
			PrintToChatAll("%s", textToPrintChat);
			}
		}
		else
		{
			PrintToChat(client, "You do not have enough credits to deploy that!");
			PrintHintText(client, "You do not have enough credits to deploy that!");


			return;
		}
	}
	
	else
	{
		PrintToChat(client, "You have deployed a \x04%s and your credits have not been reduced!", prop_choice);
	}
	decl Ent;   
	PrecacheModel(modelname,true);
	Ent = CreateEntityByName("prop_dynamic_override"); 
	
	new String:EntName[256];
	Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, iPropNo[client]);
	
	DispatchKeyValue(Ent, "physdamagescale", "0.0");
	DispatchKeyValue(Ent, "model", modelname);
	DispatchKeyValue(Ent, "targetname", EntName);
	DispatchKeyValue(Ent, "Solid", "6");  
	//g_isSolid[iPropNo[client]] = true;
	//AcceptEntityInput(Ent, "DisableCollision");
	DispatchSpawn(Ent);
	
	decl Float:FurnitureOrigin[3];
	//decl Float:FurnitureOriginBackup[3];
	decl Float:ClientOrigin[3];
	decl Float:EyeAngles[3];
	decl FLoat:PropDistGround;
	GetClientEyeAngles(client, EyeAngles);
	GetClientAbsOrigin(client, ClientOrigin);
	//EyeAngles[0] = EyeAngles[0] - 10;
	//TR_TraceRayFilter(ClientOrigin, EyeAngles, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, client);

	//TR_GetEndPosition(FurnitureOrigin, INVALID_HANDLE);
	
	FurnitureOrigin[0] = (ClientOrigin[0] + (50 * Cosine(DegToRad(EyeAngles[1]))));
	FurnitureOrigin[1] = (ClientOrigin[1] + (50 * Sine(DegToRad(EyeAngles[1]))));
	FurnitureOrigin[2] = (ClientOrigin[2] + KvGetNum(kv, "height", 100));
	EyeAngles[0] = 0;
	//FurnitureOriginBackup = FurnitureOrigin;
	TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);
	//Check if ent is stuck in a player prop, kill
	// if (CheckStuckInEntity(Ent))
	// {

	// 	PrintToChat(client, "A person is in the way!");
	// 	PrintHintText(client, "A player in the way!");
	// 	if(Ent != -1)
	// 		AcceptEntityInput(Ent, "kill");

	// 	//Refund
	// 	ClientCredits = ClientCredits + Price;
	// 	iCredits[client] = ClientCredits;
	// }

	// PropDistGround = GetPropDistanceToGround(Ent);
	// if (PropDistGround >= 50)
	// {
	// 	FurnitureOrigin[2] = FurnitureOrigin[2] - PropDistGround;
	// 	TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);
	// }
    
	SetEntityMoveType(Ent, MOVETYPE_NONE);   
	CloseHandle(kv);
	
	g_propIntegrity[iPropNo[client]] = 80;
	//PrintToServer("g_propIntegrity[iPropNo[client]]: %d",g_propIntegrity[iPropNo[client]]);
	//SetEntProp(Ent, Prop_Data, "m_CollisionGroup", 17);  
	g_engineerParam[iPropNo[client]] = param2;
	iPropNo[client] += 1;
	
	return;
}
public bool:TraceRayDontHitSelf(entityhit, mask, any:client) 
{ 
	return (entityhit != client); 

} //is the trace filter so the trace doesn't hit the player's own model
stock GetPropDistanceToGround(prop)
{
    
    new Float:fOrigin[3], Float:fGround[3];
    GetEntPropVector(prop, Prop_Send, "m_vecOrigin", fOrigin);

    fOrigin[2] += 10.0;
    
    TR_TraceRayFilter(fOrigin, Float:{90.0,0.0,0.0}, MASK_SOLID, RayType_Infinite, TraceFilterNoPlayers, prop);
    if (TR_DidHit())
    {
        TR_GetEndPosition(fGround);
        fOrigin[2] -= 10.0;
        return GetVectorDistance(fOrigin, fGround);
    }
    return 0.0;
}

public bool:TraceRayNoPlayers(entity, mask, any:data)
{
    if(entity == data || (entity >= 1 && entity <= MaxClients))
    {
        return false;
    }
    return true;
}  

public bool:TraceFilterNoPlayers(iEnt, iMask, any:Other)
{
    return (iEnt != Other && iEnt > MaxClients);
}
public Action:Event_PlayerDisconnect_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_LastButtons[client] = 0;
}

public bool:Tracer_FilterBlocks(iEntity, contentsMask, any:data)
{
	if(iEntity > MaxClients)
		return true;

	return false;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
  if (!IsFakeClient(client))
  {
    //PrintToServer("BUTTON PRESS DEBUG RUNCMD");
    for (new i = 0; i < MAX_BUTTONS; i++)
    {
        new button = (1 << i);
        if ((buttons & button)) { 
        //     if (!(g_LastButtons[client] & button)) { 
        //         OnButtonPress(client, button); 
        //     } 
        // } else if ((g_LastButtons[client] & button)) { 
        //     OnButtonRelease(client, button); 
        // }  
          OnButtonPress(client, button, buttons); 
        }
    }
      
      g_LastButtons[client] = buttons;
  }
    return Plugin_Continue;
}
//(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
public Action:OnTakeDamagePre(victim, &attacker, &inflictor, &Float:damage, &damagetype) {

	new Float:damageReduction = (damage * 0.30); //Reduce damage here so its a blanket reduction

	if (victim > 0 && IsClientConnected(victim) && IsClientInGame(victim) && !IsFakeClient(victim) && IsPlayerAlive(victim))
	{
		
		//PrintToServer("DEBUG 5");
		for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
		{

			if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
			{

				new loopCount = 0; // Stack damage reduction up to two.
				//PrintToServer("DEBUG 6");
				for(new i=0; i<=iPropNo[engineerCheck]; i++)
				{
					new String:EntName[MAX_NAME_LENGTH+5];
					Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", engineerCheck, i);
					new prop = Entity_FindByName(EntName);
					//Need another engineer to test
					if(prop != -1)
					{	
						//PrintToServer("DEBUG 7");
						//Get position of player and prop
						new Float:plyrOrigin[3];
						new Float:propOrigin[3];
				
						GetClientAbsOrigin(victim,plyrOrigin);
						GetEntPropVector(prop, Prop_Send, "m_vecOrigin", propOrigin);
						
						//determine distance from the two
						new isNearProp = Check_NearbyPlayers(prop);
						if (isNearProp == true && damagetype == DMG_BLAST)
						{
							loopCount++;
							damage -= damageReduction; // Reduce damage by 35%
							//PrintToChat(victim, "DAMAGE REDUCED by 35%");
							if (damage <= 0)
								damage = 10;

							if (loopCount >= 2)
								break;
						}
					}
				}
			}
		}
		return Plugin_Changed;
	}
}

OnButtonPress(client, button, buttons)
{
    new Float:eyepos[3];
    GetClientEyePosition(client, eyepos); // Position of client's eyes.
  	new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (ActiveWeapon < 0)
		return Plugin_Handled;
	// Get weapon class name
	decl String:sWeapon[32];
	GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
	////PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);

    ////PrintToServer("Client Eye Height %f",eyepos[2]);    
   if(button == IN_SPRINT && buttons & IN_DUCK && buttons & IN_CANCEL && (StrContains(g_client_last_classstring[client], "engineer") > -1) && g_engInMenu[client] == false && (StrContains(sWeapon, "weapon_knife") > -1))// && !(buttons & IN_FORWARD) && !(buttons & IN_ATTACK2) && !(buttons & IN_ATTACK))// & !IN_ATTACK2) 
   {
      //PrintToServer("DEBUG PRESSING BUTTONS");    
    
      if(!Client_IsValid(client))
		return Plugin_Handled;
	
		g_engInMenu[client] = true;

		//GetEntityFlags(client) & FL_DUCKING //This is for checking if player is crouching


		// if(iTeam > 0)
		// {
		// 	if(GetClientTeam(client) != iTeam+1)
		// 	{
		// 		PrintToChat(client, "%s Sorry you can't use this command!", sPrefix);
		// 		return Plugin_Handled;
		// 	}
		// }
		// if(bAdminOnly)
		// {
		// 	if(!Client_IsAdmin(client))
		// 	{
		// 		PrintToChat(client, "%s Sorry you can't use this command!", sPrefix);
		// 		return Plugin_Handled;
		// 	}
		// }
		
		// if(!IsPlayerAlive(client))
		// {
		// 	if(!Client_IsAdmin(client))
		// 	{
		// 		PrintToChat(client, "%s Sorry you can't use this command while dead!", sPrefix);
		// 		return Plugin_Handled;
		// 	}
		// }
		
		new String:textPath[255];
		BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
		new Handle:kv = CreateKeyValues("Props");
		FileToKeyValues(kv, textPath);
		om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
		SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
		PopLoop(kv, client);
		DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
		
		return Plugin_Handled;
   }
}

OnButtonRelease(client, button)
{
  ////PrintToServer("BUTTON RELEASE");
  
    // do stuff
}