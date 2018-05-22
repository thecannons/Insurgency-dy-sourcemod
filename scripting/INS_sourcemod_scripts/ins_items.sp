#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new const String:ToxicSmoke[] = "grenade_gas";

enum Teams
{
	TEAM_NONE = 0,
	TEAM_SPECTATORS,
	TEAM_SECURITY,
	TEAM_INSURGENTS,
};

new g_nFireResistance_ID = 8;
new g_nSunglasses_ID = 30;
new g_nDoubleJump_ID = 26;
new g_nSpeedBoost_ID = 27;
new g_nGasMask_ID = 25;

new g_iPlayerEquipGear;
new g_iSpeedOffset;
new g_nClientRunnerID = 0;

new
	Handle:g_cvJumpBoost	= INVALID_HANDLE,
	Handle:g_cvJumpEnable	= INVALID_HANDLE,
	Handle:g_cvJumpMax		= INVALID_HANDLE,
	Float:g_flBoost			= 380.0,
	bool:g_bDoubleJump		= true,
	g_fLastButtons[MAXPLAYERS+1],
	g_fLastFlags[MAXPLAYERS+1],
	g_iJumps[MAXPLAYERS+1],
	g_iJumpMax

public Plugin:myinfo = 
{
	name = "[INS] Items",
	author = "Neko-",
	description = "Custom item ability for INS",
	version = "1.0.2"
};

public OnPluginStart()
{
	//Find player gear offset
	g_iPlayerEquipGear = FindSendPropInfo("CINSPlayer", "m_EquippedGear");
	//Find player speed offset
	g_iSpeedOffset = FindSendPropInfo("CBasePlayer","m_flLaggedMovementValue");

	if(g_iSpeedOffset == -1)
		SetFailState("Offset \"m_flLaggedMovementValue\" not found!");
	
	
	g_cvJumpEnable = CreateConVar(
		"sm_doublejump_enabled", "1",
		"Enables double-jumping.",
		FCVAR_PLUGIN|FCVAR_NOTIFY
	);
	
	g_cvJumpBoost = CreateConVar(
		"sm_doublejump_boost", "380.0",
		"The amount of vertical boost to apply to double jumps.",
		FCVAR_PLUGIN|FCVAR_NOTIFY
	);
	
	g_cvJumpMax = CreateConVar(
		"sm_doublejump_max", "1",
		"The maximum number of re-jumps allowed while already jumping.",
		FCVAR_PLUGIN|FCVAR_NOTIFY
	);
	
	HookConVarChange(g_cvJumpBoost,		convar_ChangeBoost);
	HookConVarChange(g_cvJumpEnable,	convar_ChangeEnable);
	HookConVarChange(g_cvJumpMax,		convar_ChangeMax);
	
	g_bDoubleJump	= GetConVarBool(g_cvJumpEnable);
	g_flBoost		= GetConVarFloat(g_cvJumpBoost);
	g_iJumpMax		= GetConVarInt(g_cvJumpMax);
	
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
	HookEvent("player_blind", Event_OnFlashPlayerPre, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerRespawnPre, EventHookMode_Pre);
	AddCommandListener(ResupplyListener, "inventory_resupply");
}

public OnMapEnd()
{
	g_nClientRunnerID = 0;
}

public OnClientPostAdminCheck(client) 
{
	//If not fake client
    if(!IsFakeClient(client))
	{
		//Hook damage
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage); 
	}
}

public Event_PlayerPickSquad_Post(Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	decl String:class_template[64];
	GetEventString(event, "class_template",class_template,sizeof(class_template));
	if(client && (StrContains(class_template, "runner") > -1))
	{
		g_nClientRunnerID = client;
	}
}

public Action:Event_OnFlashPlayerPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new nCurrentPlayerTeam = GetClientTeam(client);
	//Check if player is connected and is alive and player team is security
	if((IsClientConnected(client)) && (IsPlayerAlive(client)) && (nCurrentPlayerTeam == view_as<int>(TEAM_SECURITY)))
	{
		//Get player the 4th gear item which is accessory (3rd offset with a DWORD(4 bytes))
		new nAccessoryItemID = GetEntData(client, g_iPlayerEquipGear + (4 * 3));
		
		//If accessory is sunglasses item ID)
		if(nAccessoryItemID == g_nSunglasses_ID)
		{
			//Set player flash alpha (Which is the opacity)
			SetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha", 0.5);
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) 
{
	//Get player armor ID
	new nArmorItemID = GetEntData(victim, g_iPlayerEquipGear);
	
	//Get player helmet ID
	new nHelmetItemID = GetEntData(victim, g_iPlayerEquipGear + (4 * 1));
	
	//Get weapon of the attacker
	decl String:sWeapon[32];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));
	
	for (new count=0; count<2; count++)
	{
		//If player armor is FR (Which is fire resistance armor) and attacker weapon is fire
		if((StrEqual(sWeapon, "grenade_anm14") || StrEqual(sWeapon, "grenade_molotov")) && (nArmorItemID == g_nFireResistance_ID))
		{
			//If attack and victim on the same team and player is wearing FR then they take no damage
			if(GetClientTeam(victim) == GetClientTeam(attacker))
			{
				damage = 0.0;
				return Plugin_Changed;
			}
			//Otherwise player take 1.5 damage (Which is 1.5 damage per sec on fire)
			else
			{
				damage = 1.5;
				return Plugin_Changed;
			}
		}
	}
	
	//If player armor is FR (Which is fire resistance armor) and attacker weapon is fire
	if((StrEqual(sWeapon, ToxicSmoke)) && (nHelmetItemID == g_nGasMask_ID))
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action:Event_PlayerRespawnPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	//Check if player is connected and is alive and player team is security
	if(IsClientConnected(client))
	{	
		//Speed boost
		//Get player misc item (5th offset with a DWORD(4 bytes))
		new nPerkSpeedBoostItemID = GetEntData(client, g_iPlayerEquipGear + (4 * 5));
		
		//If item is speed boost ID
		if((nPerkSpeedBoostItemID == g_nSpeedBoost_ID) || (client == g_nClientRunnerID))
		{
			//Increase player speedboost by 20%
			SetEntDataFloat(client, g_iSpeedOffset, 1.20);
		}
		else
		{
			//Reset player speed to 1
			SetEntDataFloat(client, g_iSpeedOffset, 1.0);
		}
	}
}

public Action:ResupplyListener(client, const String:cmd[], argc)
{
	//Get current client team
	new nCurrentPlayerTeam = GetClientTeam(client);
	
	//Check if player is connected and is alive and player team is security
	if((IsClientConnected(client)) && (IsPlayerAlive(client)) && (nCurrentPlayerTeam == view_as<int>(TEAM_SECURITY)))
	{	
		//Speed boost
		//Get player misc item (5th offset with a DWORD(4 bytes))
		new nPerkSpeedBoostItemID = GetEntData(client, g_iPlayerEquipGear + (4 * 5));
		
		//If item is speed boost ID
		if(nPerkSpeedBoostItemID == g_nSpeedBoost_ID)
		{
			//Increase player speedboost by 20%
			SetEntDataFloat(client, g_iSpeedOffset, 1.20);
		}
		else
		{
			//Reset player speed to 1
			SetEntDataFloat(client, g_iSpeedOffset, 1.0);
		}
	}
	
	return Plugin_Continue;
}


//----------------------------------------
//	Start double jump check 
//	Originally coded by someone else
//----------------------------------------

public convar_ChangeBoost(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_flBoost = StringToFloat(newVal)
}

public convar_ChangeEnable(Handle:convar, const String:oldVal[], const String:newVal[]) {
	if (StringToInt(newVal) >= 1) {
		g_bDoubleJump = true
	} else {
		g_bDoubleJump = false
	}
}

public convar_ChangeMax(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_iJumpMax = StringToInt(newVal)
}

public OnGameFrame() {
	if (g_bDoubleJump) {							// double jump active
		for (new i = 1; i <= MaxClients; i++) {		// cycle through players
			if (
				IsClientInGame(i) &&				// is in the game
				IsPlayerAlive(i)					// is alive
			) {
				DoubleJump(i)						// Check for double jumping
			}
		}
	}
}

stock DoubleJump(const any:client) {
	new
		fCurFlags	= GetEntityFlags(client),		// current flags
		fCurButtons	= GetClientButtons(client)		// current buttons
	
	if (g_fLastFlags[client] & FL_ONGROUND) {		// was grounded last frame
		if (
			!(fCurFlags & FL_ONGROUND) &&			// becomes airbirne this frame
			!(g_fLastButtons[client] & IN_JUMP) &&	// was not jumping last frame
			fCurButtons & IN_JUMP					// started jumping this frame
		) {
			OriginalJump(client)					// process jump from the ground
		}
	} else if (										// was airborne last frame
		fCurFlags & FL_ONGROUND						// becomes grounded this frame
	) {
		Landed(client)								// process landing on the ground
	} else if (										// remains airborne this frame
		!(g_fLastButtons[client] & IN_JUMP) &&		// was not jumping last frame
		fCurButtons & IN_JUMP						// started jumping this frame
	) {
		ReJump(client)								// process attempt to double-jump
	}
	
	g_fLastFlags[client]	= fCurFlags				// update flag state for next frame
	g_fLastButtons[client]	= fCurButtons			// update button state for next frame
}

stock OriginalJump(const any:client) {
	g_iJumps[client]++	// increment jump count
}

stock Landed(const any:client) {
	g_iJumps[client] = 0	// reset jumps count
}

stock ReJump(const any:client) {
	//Double jump check with item
	//Get player misc item (5th offset with a DWORD(4 bytes))
	new nPerkItemID = GetEntData(client, g_iPlayerEquipGear + (4 * 5))
	
	//If item is 26 then its double jump perk. Allow player to perform a double jump
	if(nPerkItemID == g_nDoubleJump_ID)
	{
		if ( 1 <= g_iJumps[client] <= g_iJumpMax) {						// has jumped at least once but hasn't exceeded max re-jumps
			g_iJumps[client]++											// increment jump count
			decl Float:vVel[3]
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel)	// get current speeds
			
			vVel[2] = g_flBoost
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel)		// boost player
		}
	}
}

bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}