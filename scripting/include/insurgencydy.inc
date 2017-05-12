#if defined _insurgencydy_included
  #endinput
#endif
#define _insurgencydy_included

//#include <sourcemod>
//#include <sdktools>
//#include <loghelper>
#if defined REQUIRE_PLUGIN
#undef REQUIRE_PLUGIN
#include <updater>
#include <smlib>
#define REQUIRE_PLUGIN
#else
#include <updater>
#include <smlib>
#endif

#define MAX_DEFINABLE_WEAPONS 256
#define MAX_DEFINABLE_GEAR 256
#define MAX_DEFINABLE_AMMO 256
#define MAX_DEFINABLE_EXPLOSIVES 256
#define MAX_DEFINABLE_WEAPON_UPGRADES 256

#define MAX_WEAPON_LEN 32
#define MAX_SQUAD_LEN 32
#define MAX_CLASS_LEN 64
#define MAX_CONTROLPOINTS 64
#define PREFIX_LEN 7
#define MAX_SQUADS 16
#define SQUAD_SIZE 32
#define MAX_MAPS 256
#define MAX_GAMEMODES 32

native Ins_ObjectiveResource_GetProp(const String:prop[], size=4, element=0);
//native Ins_Log(ELOG_LEVEL:level,const String:format[], any:...);
native Ins_GetMaxClip1(weapon);
native Ins_GetWeaponGetMaxClip1(weapon);
native Ins_GetDefaultClip1(weapon);
native Ins_DecrementAmmo(weapon, value);
//native Ins_AddMags(client, value);
native Float:Ins_ObjectiveResource_GetPropFloat(const String:prop[], size=4, element=0);
native Ins_ObjectiveResource_GetPropEnt(const String:prop[], element=0);
native bool:Ins_ObjectiveResource_GetPropBool(const String:prop[], element=0);
native Ins_ObjectiveResource_GetPropVector(const String:prop[], Float:vec[3], element=0);
native Ins_ObjectiveResource_GetPropString(const String:prop[], String:buffer[], maxlen);

native bool:Ins_InCounterAttack();

native Ins_GetPlayerScore(client);
native Ins_GetPlayerClass(client, String:buffer[], maxlen);
native Ins_GetClassName(squad,squad_slot);
//native GameLogic_();

native Ins_GetWeaponName(weaponid, String:buffer[], maxlen);
native Ins_GetWeaponId(String:weapon_name[]);

new StuckCheck[MAXPLAYERS+1] 	= {0, ...};
new bool:isStuck[MAXPLAYERS+1];

new Float:Step;
new Float:RadiusSize;
new Float:Ground_Velocity[3] = {0.0, 0.0, -300.0};

// Team numbers. This is Insurgency specific right now
// TODO: Add support for DoI style factions, or make it load from a cfg file
enum Teams
{
	TEAM_NONE = 0,
	TEAM_SPECTATORS,
	TEAM_SECURITY,
	TEAM_INSURGENTS,
}

// Round stats for players
enum RoundStatFields
{
	STAT_KILLS = 0,
	STAT_DEATHS,
	STAT_SHOTS,
	STAT_HITS,
	STAT_GRENADES,
	STAT_CAPTURES,
	STAT_CACHES,
	STAT_DMG_GIVEN,
	STAT_DMG_TAKEN,
	STAT_TEAMKILLS,
	STAT_SCORE,
	STAT_SUPPRESSIONS,
	STAT_ACCURACY,
}

// Damage hitgroups
enum Hitgroups
{
	HITGROUP_GENERIC = 0,
	HITGROUP_HEAD,
	HITGROUP_CHEST,
	HITGROUP_STOMACH,
	HITGROUP_LEFTARM,
	HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG,
	HITGROUP_RIGHTLEG,
}

// Weapon stat fields
enum WeaponStatFields
{
	LOG_HIT_SHOTS = 0,
	LOG_HIT_HITS,
	LOG_HIT_KILLS,
	LOG_HIT_HEADSHOTS,
	LOG_HIT_TEAMKILLS,
	LOG_HIT_DAMAGE,
	LOG_HIT_DEATHS,
	LOG_HIT_GENERIC,
	LOG_HIT_HEAD,
	LOG_HIT_CHEST,
	LOG_HIT_STOMACH,
	LOG_HIT_LEFTARM,
	LOG_HIT_RIGHTARM,
	LOG_HIT_LEFTLEG,
	LOG_HIT_RIGHTLEG,
}

// Offset of end of weaponstats/beginning of weaponstats2
#define LOG_HIT_OFFSET 7

// Log levels
enum LOG_LEVEL {
	DEFAULT = 0,
	TRACE,
	DEBUG,
	INFO,
	WARN,
	ERROR
}

// Log level names
new String:g_sLogLevel[6][32] = {
	"default",
	"trace",
	"debug",
	"info",
	"warn",
	"error"
};

// Global log level variable
new LOG_LEVEL:g_iLogLevel;// = sizeof(g_sLogLevel);

/**
 * Log events to console, based upon level
 *
 * @param level
 */
stock InsLog(LOG_LEVEL:level,const String:format[], any:...) {
	if ((level) && (level > g_iLogLevel))
		return;
	decl String:buffer[512],String:sLevel[32];
	String_ToUpper(g_sLogLevel[level],sLevel,sizeof(sLevel));
	VFormat(buffer, sizeof(buffer), format, 3);
	PrintToServer("[%s] [%s] %s",PLUGIN_LOG_PREFIX,sLevel,buffer);
}

/**
 * 
 *
 * @param 
 */
stock AddFolderToDownloadTable(const String:Directory[], bool:recursive=false)
{
	decl String:FileName[64], String:Path[512];
	new Handle:Dir = OpenDirectory(Directory), FileType:Type;
	while(ReadDirEntry(Dir, FileName, sizeof(FileName), Type))
	{
		if(Type == FileType_Directory && recursive)
		{
			FormatEx(Path, sizeof(Path), "%s/%s", Directory, FileName);
			AddFolderToDownloadTable(FileName,recursive);
			continue;
		}
		if (Type != FileType_File)
			continue;
		FormatEx(Path, sizeof(Path), "%s/%s", Directory, FileName);
		AddFileToDownloadsTable(Path);
	}
	return;
}

/* Returns True if the client is an ingame player, False otherwise.
 * Checks are performed in the order least likely to spew an error.
 *
 * @return                  If the client is a valid client.
 */
stock bool:IsValidClient(client) {

  return (client > 0 && client <= MaxClients &&
    IsClientConnected(client) && IsClientInGame(client) &&
    !IsClientReplay(client) && !IsClientSourceTV(client));

}

/**
 * Counts the players in a team, alive or dead.
 *
 * @param team             Team index.
 * @return                 Number of players.
 */
stock Team_CountPlayers(team) {

  new count = 0;
  for (new i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && GetClientTeam(i) == team) {
      count++;
    }
  }
  return count;

}

/**
 * Counts the number of living players in a team.
 *
 * @param team             Team index.
 * @return                 Number of living players.
 */
stock Team_CountAlivePlayers(team) {

   new count = 0;
   for (new i = 1; i <= MaxClients; i++) {
     if (IsValidClient(i) && GetClientTeam(i) == team && IsPlayerAlive(i)) {
       count++;
     }
   }
   return count;

 }
/*
stock Client_IsValid(client, bool:checkConnected)
{
	if (client > 4096) {
		client = EntRefToEntIndex(client);
	}

	if (client < 1 || client > MaxClients) {
		return false;
	}

	if (checkConnected && !IsClientConnected(client)) {
		return false;
	}
	
	return true;
}
*/

/**
 * 
 *
 * @param 
 */
stock bool:ClientCanSeeClient(client, target, Float:distance = 0.0, Float:height = 50.0) {
	new Float:vTargetPosition[3];
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", vTargetPosition);
	return ClientCanSeeVector(client,targetpos,distance,height);
}

/**
 * 
 *
 * @param 
 */
stock bool:ClientCanSeeVector(client, Float:vTargetPosition[3], Float:distance = 0.0, Float:height = 50.0) { 

        new Float:vClientPosition[3];
         
        GetEntPropVector(client, Prop_Send, "m_vecOrigin", vClientPosition); 
        vClientPosition[2] += height; 
         
        if (distance == 0.0 || GetVectorDistance(vClientPosition, vTargetPosition, false) < distance) 
        { 
            new Handle:trace = TR_TraceRayFilterEx(vClientPosition, vTargetPosition, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter); 

            if(TR_DidHit(trace)) 
            { 
                CloseHandle(trace); 
                return (false); 
            } 
             
            CloseHandle(trace); 

            return (true); 
        } 
        return false; 
} 

/**
 * 
 *
 * @param 
 */
public bool:Base_TraceFilter(entity, contentsMask, any:data) { 
    if(entity != data) 
        return (false); 

    return (true); 
}  

/**
 * 
 *
 * @param 
 */
stock bool:IsClientInSightRange(client, target, Float:angle=90.0, Float:distance=0.0, bool:heightcheck=true, bool:negativeangle=false) {
	new Float:targetpos[3];
//	if(!isClientConnectedIngameAlive(target))
//		ThrowError("Target is not Alive.");
	GetClientAbsOrigin(target, targetpos);
	return IsVectorInSightRange(client,targetpos,angle,distance,heightcheck,negativeangle);
}

/**
 * 
 *
 * @param 
 */
stock bool:IsVectorInSightRange(client, Float:targetpos[3], Float:angle=90.0, Float:distance=0.0, bool:heightcheck=true, bool:negativeangle=false) {
	if(angle > 360.0 || angle < 0.0)
		ThrowError("Angle Max : 360 & Min : 0. %d isn't proper angle.", angle);
//	if(!isClientConnectedIngameAlive(client))
//		ThrowError("Client is not Alive.");
		
	decl Float:clientpos[3], Float:anglevector[3], Float:targetvector[3], Float:resultangle, Float:resultdistance;
	
	GetClientEyeAngles(client, anglevector);
	anglevector[0] = anglevector[2] = 0.0;
	GetAngleVectors(anglevector, anglevector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(anglevector, anglevector);
	if(negativeangle)
		NegateVector(anglevector);

	GetClientAbsOrigin(client, clientpos);
	if(heightcheck && distance > 0)
		resultdistance = GetVectorDistance(clientpos, targetpos);
	clientpos[2] = targetpos[2] = 0.0;
	MakeVectorFromPoints(clientpos, targetpos, targetvector);
	NormalizeVector(targetvector, targetvector);
	
	resultangle = RadToDeg(ArcCosine(GetVectorDotProduct(targetvector, anglevector)));
	
	if(resultangle <= angle/2)	
	{
		if(distance > 0)
		{
			if(!heightcheck)
				resultdistance = GetVectorDistance(clientpos, targetpos);
			if(distance >= resultdistance)
				return true;
			else
				return false;
		}
		else
			return true;
	}
	else
		return false;
}

/**
 * 
 *
 * @param 
 */
stock GetSendProp(const String:sNetClass[], const String:sPropName[], iFail=1) {
	int m_iProp = FindSendPropInfo(sNetClass, sPropName);
	if (iFail) {
	       	if (m_iProp == -1) {
        	       	LogError("Can't find %s::%s", sNetClass, sPropName);
	        }
        }
	return m_iProp;
}


//Get and Set Ammo for storing weapons and ammo on death (reference weapon to make sure it exists)
stock GetWeaponAmmo(client, weapon, type)
{
	new PropType:proptype = Prop_Data;
	new ammoOffset = FindSendPropInfo("CINSPlayer", "m_iAmmo");
	new m_iPrimaryAmmoType, ammo;
				
	
	//return GetEntData(client, ammoOffset+(slot*4));
	if (type == 0) // primary
	{
		m_iPrimaryAmmoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		ammo = GetEntProp(client, proptype, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	else if(type == 1) // secondary
	{
		m_iPrimaryAmmoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		ammo = GetEntProp(client, proptype, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	else if (type == 3) // grenades
	{	
		m_iPrimaryAmmoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		//PrintToServer("m_iPrimaryAmmoType %d", m_iPrimaryAmmoType);
		ammo = GetEntProp(client, proptype, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	//PrintToServer("m_iPrimaryAmmoType: %i, Ammo %i", m_iPrimaryAmmoType, ammo);
	return ammo;
}

stock SetWeaponAmmo(client, weapon, ammo, type)
{
	new PropType:proptype = Prop_Data;
	//new ammoOffset = FindSendPropInfo("CINSPlayer", "m_iAmmo");
	new m_ammoType;
	
	//PrintToServer("m_iPrimaryAmmoType: %i, Ammo %i", m_ammoType, ammo);
	//return GetEntData(client, ammoOffset+(slot*4));
	if (type == 0) // primary
	{
		m_ammoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		SetEntProp(client, proptype, "m_iAmmo", ammo, _, m_ammoType);
	}
	else if(type == 1) // secondary
	{
		m_ammoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		SetEntProp(client, proptype, "m_iAmmo", ammo, _, m_ammoType);
	}
	else if (type == 3) // grenades
	{	

	}
}

//Get / Set primary ammo count as it was when died
stock GetPrimaryAmmo(client, weap, type)
{
	//new myweapons = FindSendPropInfo("CCSPlayer", "m_hMyWeapons");
	//new weap = GetEntDataEnt2(client, myweapons+ (slot*4));
	if(IsValidEntity(weap))
	{
		if (type==0)
		{
			return GetEntData(weap, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"));
		}
		else if (type==1)
		{
			return GetEntData(weap, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"));
		}
	}
	return 0;
}

stock SetPrimaryAmmo(client, weap, ammo, type)
{
	new PropType:proptype = Prop_Data;
	//new myweapons = FindSendPropInfo("CCSPlayer", "m_hMyWeapons");
	//new weap = GetEntDataEnt2(client, myweapons+ (slot*4));
	if(IsValidEntity(weap))
	{
		if (type==0)
		{
			return SetEntData(weap, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), ammo, _, true);
		}
		else if (type==1)
		{
			return SetEntData(weap, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), ammo, _, true);
		}
	}
	
	return 0;
}


stock GetGrenadeAmmo(client, grenadeType)
{
	new PropType:proptype = Prop_Data;
	new ammo;
	////PrintToServer("grenadeType %d", grenadeType);
	ammo = GetEntProp(client, proptype, "m_iAmmo", _, grenadeType);
	return ammo;
}

stock SetGrenadeAmmo(client, grenadeType, grenadeAmount)
{
	new PropType:proptype = Prop_Data;
	//PrintToServer("grenadeType %d, amount to set: %d", grenadeType, grenadeAmount);
	SetEntProp(client, proptype, "m_iAmmo", grenadeAmount, _, grenadeType);
}



/*
#define Gren_M67 68
#define Gren_Incen 73
#define Gren_Molot 74
#define Gren_M18 70
#define Gren_Flash 71
#define Gren_F1 69
#define Gren_IED 72
#define Gren_C4 72
#define Gren_AT4 67
#define Gren_RPG7 61
*/



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Stuck START
//									Stuck START
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


StartStuckDetection(iClient)
{
	StuckCheck[iClient]++;
	isStuck[iClient] = false;
	//CheckIfPlayerCanMove(iClient, 0, 500.0, 0.0, 0.0);
	isStuck[iClient] = CheckIfPlayerIsStuck(iClient); // Check if player stuck in prop
	if (isStuck[iClient])
	{
		//Can't fix
		//ForcePlayerSuicide(iClient);
		//AddLifeForStaticKilling(iClient);	
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Stuck Detection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


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


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									More Stuck Detection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



bool:TryFixPosition(iClient, Float:Radius, Float:pos_Z)
{
	decl Float:DegreeAngle;
	decl Float:vecPosition[3];
	decl Float:vecOrigin[3];
	decl Float:vecAngle[3];
	
	GetClientAbsOrigin(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngle);
	vecPosition[2] = vecOrigin[2] + pos_Z;

	DegreeAngle = -180.0;
	while(DegreeAngle < 180.0)
	{
		vecPosition[0] = vecOrigin[0] + Radius * Cosine(DegreeAngle * FLOAT_PI / 180); // convert angle in radian
		vecPosition[1] = vecOrigin[1] + Radius * Sine(DegreeAngle * FLOAT_PI / 180);
		
		TeleportEntity(iClient, vecPosition, vecAngle, Ground_Velocity);
		if(!CheckIfPlayerIsStuck(iClient))
			return true;
		
		DegreeAngle += 10.0; // + 10°
	}
	
	TeleportEntity(iClient, vecOrigin, vecAngle, Ground_Velocity);
	if(Radius <= RadiusSize)
		return TryFixPosition(iClient, Radius + Step, pos_Z);
	
	return false;
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Stuck END
//									Stuck END
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


stock bool:ChangePlayerWeaponSlot(iClient, iSlot) {
    new iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
    if (iWeapon > MaxClients) {
        SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
        return true;
    }

    return false;
}  

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Scream Nades START
//									Scream Nades START
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

stock PlayerGrenadeScreamRand(client)
{
	switch(GetRandomInt(1, 14))
	{
		case 1: EmitSoundToAll("player/voice/botsurvival/leader/incominggrenade9.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 2: EmitSoundToAll("player/voice/botsurvival/subordinate/incominggrenade9.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 3: EmitSoundToAll("player/voice/botsurvival/leader/incominggrenade4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 4: EmitSoundToAll("player/voice/botsurvival/subordinate/incominggrenade4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 5: EmitSoundToAll("player/voice/botsurvival/subordinate/incominggrenade35.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 6: EmitSoundToAll("player/voice/botsurvival/subordinate/incominggrenade34.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 7: EmitSoundToAll("player/voice/botsurvival/subordinate/incominggrenade33.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 8: EmitSoundToAll("player/voice/botsurvival/subordinate/incominggrenade23.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 9: EmitSoundToAll("player/voice/botsurvival/leader/incominggrenade2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 10: EmitSoundToAll("player/voice/botsurvival/leader/incominggrenade13.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 11: EmitSoundToAll("player/voice/botsurvival/leader/incominggrenade12.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 12: EmitSoundToAll("player/voice/botsurvival/leader/incominggrenade11.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 13: EmitSoundToAll("player/voice/botsurvival/leader/incominggrenade10.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 14: EmitSoundToAll("player/voice/botsurvival/leader/incominggrenade18.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
	}
}

stock PlayerFireScreamRand(client)
{
	//PrintToServer("SCREAM FIRE");
	
	switch(GetRandomInt(1, 5))
	{
		case 1: EmitSoundToAll("player/voice/responses/security/subordinate/damage/molotov_incendiary_detonated7.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 2: EmitSoundToAll("player/voice/responses/security/leader/damage/molotov_incendiary_detonated6.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 3: EmitSoundToAll("player/voice/responses/security/subordinate/damage/molotov_incendiary_detonated6.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 4: EmitSoundToAll("player/voice/responses/security/leader/damage/molotov_incendiary_detonated5.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 5: EmitSoundToAll("player/voice/responses/security/leader/damage/molotov_incendiary_detonated4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Scream Nades END
//									Scream Nades END
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


