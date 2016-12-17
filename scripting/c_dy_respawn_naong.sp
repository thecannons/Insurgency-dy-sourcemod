/**
 *	[INS] Player Respawn Script - Player and BOT respawn script for sourcemod plugin.
 *	
 *	This program is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

//#pragma dynamic 32768	// Increase heap size
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <insurgencydy>

#undef REQUIRE_EXTENSIONS
#include <cstrike>
#include <tf2>
#include <tf2_stocks>
#define REQUIRE_EXTENSIONS

//#include <navmesh>
//#include <insurgency>

// Define grenade index value
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
//LUA Healing define values
#define Healthkit_Timer_Tickrate			0.5		// Basic Sound has 0.8 loop
#define Healthkit_Timer_Timeout				360.0 //6 minutes
#define Healthkit_Radius					120.0
#define Revive_Indicator_Radius				100.0
#define Healthkit_Remove_Type				"1"
#define Healthkit_Healing_Per_Tick_Min		1
#define Healthkit_Healing_Per_Tick_Max		3

//Lua Healing Variables
new g_iBeaconBeam;
new g_iBeaconHalo;
new Float:g_fLastHeight[2048] = {0.0, ...};
new Float:g_fTimeCheck[2048] = {0.0, ...};
new g_iTimeCheckHeight[2048] = {0, ...};
new g_healthPack_Amount[2048] = {0, ...};

// This will be used for checking which team the player is on before repsawning them
#define SPECTATOR_TEAM	0
#define TEAM_SPEC 	1
#define TEAM_1		2
#define TEAM_2		3

// Navmesh Init 
#define MAX_OBJECTIVES 13
#define MAX_HIDING_SPOTS 4096
#define MIN_PLAYER_DISTANCE 128.0

// Counter-Attack Music
#define COUNTER_ATTACK_MUSIC_DURATION 68.0

// Handle for revive
new Handle:g_hForceRespawn;
new Handle:g_hGameConfig;

// Player respawn
new
	g_iEnableRevive = 0,
	g_iRespawnTimeRemaining[MAXPLAYERS+1],
	g_iReviveRemainingTime[MAXPLAYERS+1],
	g_iReviveNonMedicRemainingTime[MAXPLAYERS+1],
	g_iPlayerRespawnTimerActive[MAXPLAYERS+1],
	g_iSpawnTokens[MAXPLAYERS+1],
	g_iHurtFatal[MAXPLAYERS+1],
	g_iClientRagdolls[MAXPLAYERS+1],
	g_iNearestBody[MAXPLAYERS+1],
	g_botStaticGlobal[MAXPLAYERS+1],
	g_iRespawnCount[4],
	g_huntReinforceCacheAdd = 120,
	bool:g_huntCacheDestroyed = false,
	bool:g_playersReady = false,
	Float:g_fPlayerPosition[MAXPLAYERS+1][3],
	Float:g_fDeadPosition[MAXPLAYERS+1][3],
	Float:g_fRagdollPosition[MAXPLAYERS+1][3],
	Float:g_vecOrigin[MAXPLAYERS+1][3],
	Float:g_fRespawnPosition[3];

//Ammo Amounts
new
	playerClip[MAXPLAYERS + 1][2], // Track primary and secondary ammo
	playerAmmo[MAXPLAYERS + 1][4], // track player ammo based on weapon slot 0 - 4
	playerPrimary[MAXPLAYERS + 1],
	playerSecondary[MAXPLAYERS + 1];
//	playerGrenadeType[MAXPLAYERS + 1][10], //track player grenade types
//	playerRole[MAXPLAYERS + 1]; // tracks player role so if it changes while wounded, he dies

new Handle:g_playerArrayList;
// Navmesh Init
new
	Handle:g_hHidingSpots = INVALID_HANDLE,
	g_iHidingSpotCount,
	m_iNumControlPoints,
	g_iCPHidingSpots[MAX_OBJECTIVES][MAX_HIDING_SPOTS],
	g_iCPHidingSpotCount[MAX_OBJECTIVES],
	g_iCPLastHidingSpot[MAX_OBJECTIVES],
	Float:m_vCPPositions[MAX_OBJECTIVES][3];

// Status
new
	g_isMapInit,
	g_iRoundStatus = 0, //0 is over, 1 is active
	bool:g_bIsCounterAttackTimerActive = false,
	g_clientDamageDone[MAXPLAYERS+1],
	playerPickSquad[MAXPLAYERS + 1],
	bool:playerRevived[MAXPLAYERS + 1],
	bool:g_preRoundInitial = false,
	String:g_client_last_classstring[MAXPLAYERS+1][64],
	String:g_client_org_nickname[MAXPLAYERS+1][64],
	Float:g_enemyTimerPos[MAXPLAYERS+1][3],	// Kill Stray Enemy Bots Globals
	Float:g_enemyTimerAwayPos[MAXPLAYERS+1][3],	// Kill Stray Enemy Bots Globals
	g_plyrGrenScreamCoolDown[MAXPLAYERS+1],
	g_plyrFireScreamCoolDown[MAXPLAYERS+1],
	g_playerMedicHealsAccumulated[MAXPLAYERS+1],
	g_playerNonMedicHealsAccumulated[MAXPLAYERS+1],
	g_playerNonMedicRevive[MAXPLAYERS+1],
	g_playerWoundType[MAXPLAYERS+1],
	g_playerWoundTime[MAXPLAYERS+1],
	g_playerFirstJoin[MAXPLAYERS+1];

// Player Distance Plugin //Credits to author = "Popoklopsi", url = "http://popoklopsi.de"
// unit to use 1 = feet, 0 = meters
new g_iUnitMetric;

// Handle for config
new
	Handle:sm_respawn_enabled = INVALID_HANDLE,
	
	// Respawn delay time
	Handle:sm_respawn_delay_team_ins = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_01 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_02 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_03 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_04 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_05 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_06 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_07 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_08 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_09 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_10 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_11 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_12 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_13 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_14 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_15 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_16 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_17 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_18 = INVALID_HANDLE,
	
	// Respawn type
	Handle:sm_respawn_type_team_ins = INVALID_HANDLE,
	Handle:sm_respawn_type_team_sec = INVALID_HANDLE,
	
	// Respawn lives
	Handle:sm_respawn_lives_team_sec = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_01 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_02 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_03 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_04 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_05 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_06 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_07 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_08 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_09 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_10 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_11 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_12 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_13 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_14 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_15 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_16 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_17 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_18 = INVALID_HANDLE,
	
	// Fatal dead
	Handle:sm_respawn_fatal_chance = INVALID_HANDLE,
	Handle:sm_respawn_fatal_head_chance = INVALID_HANDLE,
	Handle:sm_respawn_fatal_limb_dmg = INVALID_HANDLE,
	Handle:sm_respawn_fatal_head_dmg = INVALID_HANDLE,
	Handle:sm_respawn_fatal_burn_dmg = INVALID_HANDLE,
	Handle:sm_respawn_fatal_explosive_dmg = INVALID_HANDLE,
	Handle:sm_respawn_fatal_chest_stomach = INVALID_HANDLE,
	
	// Counter-attack
	Handle:sm_respawn_counterattack_type = INVALID_HANDLE,
	Handle:sm_respawn_final_counterattack_type = INVALID_HANDLE,
	Handle:sm_respawn_security_on_counter = INVALID_HANDLE,
	Handle:sm_respawn_counter_chance = INVALID_HANDLE,
	Handle:sm_respawn_min_counter_dur_sec = INVALID_HANDLE,
	Handle:sm_respawn_max_counter_dur_sec = INVALID_HANDLE,
	Handle:sm_respawn_final_counter_dur_sec = INVALID_HANDLE,
	
	//Dynamic Respawn Mechanics
	Handle:sm_respawn_dynamic_distance_multiplier = INVALID_HANDLE,
	Handle:sm_respawn_dynamic_spawn_counter_percent = INVALID_HANDLE,
	Handle:sm_respawn_dynamic_spawn_percent = INVALID_HANDLE,

	// Misc
	Handle:sm_respawn_reset_type = INVALID_HANDLE,
	Handle:sm_respawn_enable_track_ammo = INVALID_HANDLE,
	
	// Reinforcements
	Handle:sm_respawn_reinforce_time = INVALID_HANDLE,
	Handle:sm_respawn_reinforce_time_subsequent = INVALID_HANDLE,
	Handle:sm_respawn_reinforce_multiplier = INVALID_HANDLE,
	Handle:sm_respawn_reinforce_multiplier_base = INVALID_HANDLE,
	
	// Monitor static enemy
	Handle:sm_respawn_check_static_enemy = INVALID_HANDLE,
	Handle:sm_respawn_check_static_enemy_counter = INVALID_HANDLE,
	
	// Donor tag
	Handle:sm_respawn_enable_donor_tag = INVALID_HANDLE,
	
	// Related to 'RoundEnd_Protector' plugin
	Handle:sm_remaininglife = INVALID_HANDLE,

	// Medic specific
	Handle:sm_revive_seconds = INVALID_HANDLE,
	Handle:sm_revive_bonus = INVALID_HANDLE,
	Handle:sm_revive_distance_metric = INVALID_HANDLE,
	Handle:sm_heal_bonus = INVALID_HANDLE,
	Handle:sm_heal_cap_for_bonus = INVALID_HANDLE,
	Handle:sm_heal_amount_medpack = INVALID_HANDLE,
	Handle:sm_heal_amount_paddles = INVALID_HANDLE,
	Handle:sm_non_medic_heal_amt = INVALID_HANDLE,
	Handle:sm_non_medic_revive_hp = INVALID_HANDLE,
	Handle:sm_medic_minor_revive_hp = INVALID_HANDLE,
	Handle:sm_medic_moderate_revive_hp = INVALID_HANDLE,
	Handle:sm_medic_critical_revive_hp = INVALID_HANDLE,
	Handle:sm_minor_wound_dmg = INVALID_HANDLE,
	Handle:sm_moderate_wound_dmg = INVALID_HANDLE,
	Handle:sm_medic_heal_self_max = INVALID_HANDLE,
	Handle:sm_non_medic_max_heal_other = INVALID_HANDLE,
	Handle:sm_minor_revive_time = INVALID_HANDLE,
	Handle:sm_moderate_revive_time = INVALID_HANDLE,
	Handle:sm_critical_revive_time = INVALID_HANDLE,
	Handle:sm_non_medic_revive_time = INVALID_HANDLE,
	Handle:sm_medpack_health_amount = INVALID_HANDLE,
	Handle:sm_multi_loadout_enabled = INVALID_HANDLE,
	Handle:sm_bombers_only = INVALID_HANDLE,
	Handle:sm_non_medic_heal_self_max = INVALID_HANDLE,

	// NAV MESH SPECIFIC CVARS
	Handle:cvarSpawnMode = INVALID_HANDLE, //1 = Spawn in ins_spawnpoints, 2 = any spawnpoints that meets criteria, 0 = only at normal spawnpoints at next objective
	Handle:cvarMinCounterattackDistance = INVALID_HANDLE, //Min distance from counterattack objective to spawn
	Handle:cvarMinPlayerDistance = INVALID_HANDLE, //Min/max distance from players to spawn
	Handle:cvarSpawnAttackDelay = INVALID_HANDLE, //Attack delay for spawning bots
	Handle:cvarMinObjectiveDistance = INVALID_HANDLE, //Min/max distance from next objective to spawn
	Handle:cvarMaxObjectiveDistance = INVALID_HANDLE, //Min/max distance from next objective to spawn
	Handle:cvarMaxObjectiveDistanceNav = INVALID_HANDLE, //Min/max distance from next objective to spawn using nav
	Handle:cvarCanSeeVectorMultiplier = INVALID_HANDLE, //CanSeeVector Multiplier divide this by cvarMaxPlayerDistance
	Handle:cvarMaxPlayerDistance = INVALID_HANDLE; //Min/max distance from players to spawn

// Init global variables
new
	g_iCvar_respawn_enable,
	Float:g_respawn_counter_chance,
	g_counterAttack_min_dur_sec,
	g_counterAttack_max_dur_sec,
	g_iCvar_respawn_type_team_ins,
	g_iCvar_respawn_type_team_sec,
	g_iCvar_respawn_reset_type,
	Float:g_fCvar_respawn_delay_team_ins,
	g_iCvar_enable_track_ammo,
	g_iCvar_counterattack_type,
	g_iCvar_final_counterattack_type,
	g_iCvar_SpawnMode,
	
	//Dynamic Respawn cvars 
	g_DynamicRespawn_Distance_mult,
	g_dynamicSpawnCounter_Perc,
	g_dynamicSpawn_Perc,

	// Fatal dead
	Float:g_fCvar_fatal_chance,
	Float:g_fCvar_fatal_head_chance,
	g_iCvar_fatal_limb_dmg,
	g_iCvar_fatal_head_dmg,
	g_iCvar_fatal_burn_dmg,
	g_iCvar_fatal_explosive_dmg,
	g_iCvar_fatal_chest_stomach,
	//Dynamic Loadouts
	g_iCvar_bombers_only,
	g_iCvar_multi_loadout_enabled,

	g_checkStaticAmt,
	g_checkStaticAmtCntr,
	g_checkStaticAmtAway,
	g_checkStaticAmtCntrAway,
	g_iReinforceTime,
	g_iRemaining_lives_team_sec,
	g_iRemaining_lives_team_ins,
	g_iRespawn_lives_team_sec,
	g_iRespawn_lives_team_ins,
	g_iReviveSeconds,
	g_iRespawnSeconds,
	g_iHeal_amount_paddles,
	g_iHeal_amount_medPack,
	g_nonMedicHeal_amount,
	g_nonMedicRevive_hp,
	g_minorWoundRevive_hp,
	g_modWoundRevive_hp,
	g_critWoundRevive_hp,
	g_minorWound_dmg,
	g_moderateWound_dmg,
	g_medicHealSelf_max,
	g_nonMedicHealSelf_max,
	g_nonMedic_maxHealOther,
	g_minorRevive_time,
	g_modRevive_time,
	g_critRevive_time,
	g_nonMedRevive_time,
	g_medpack_health_amt,
	g_botsReady,
	g_isConquer,
	g_isOutpost,
	g_isCheckpoint,
	g_isHunt,
	Float:g_flMinPlayerDistance,
	Float:g_flMaxPlayerDistance,
	Float:g_flCanSeeVectorMultiplier, 
	Float:g_flMinObjectiveDistance,
	Float:g_flMaxObjectiveDistance,
	Float:g_flMaxObjectiveDistanceNav,
	Float:g_flSpawnAttackDelay,
	Float:g_flMinCounterattackDistance,
	// Insurgency implements
	g_iObjResEntity, String:g_iObjResEntityNetClass[32],
	g_iLogicEntity, String:g_iLogicEntityNetClass[32];

enum SpawnModes
{
	SpawnMode_Normal = 0,
	SpawnMode_HidingSpots,
	SpawnMode_SpawnPoints,
};


new m_hMyWeapons, m_flNextPrimaryAttack, m_flNextSecondaryAttack;
/////////////////////////////////////
// Rank System (Based on graczu's Simple CS:S Rank - https://forums.alliedmods.net/showthread.php?p=523601)
//
/*
MySQL Query:

CREATE TABLE `ins_rank`(
`rank_id` int(64) NOT NULL auto_increment,
`steamId` varchar(32) NOT NULL default '',
`nick` varchar(128) NOT NULL default '',
`score` int(12) NOT NULL default '0',
`kills` int(12) NOT NULL default '0',
`deaths` int(12) NOT NULL default '0',
`headshots` int(12) NOT NULL default '0',
`sucsides` int(12) NOT NULL default '0',
`revives` int(12) NOT NULL default '0',
`heals` int(12) NOT NULL default '0',
`last_active` int(12) NOT NULL default '0',
`played_time` int(12) NOT NULL default '0',
PRIMARY KEY  (`rank_id`)) ENGINE=INNODB  DEFAULT CHARSET=utf8;

database.cfg

	"insrank"
	{
		"driver"			"default"
		"host"				"127.0.0.1"
		"database"			"database_name"
		"user"				"database_user"
		"pass"				"PASSWORD"
		//"timeout"			"0"
		"port"			"3306"
	}
*/

// KOLOROWE KREDKI
#define YELLOW 0x01
#define GREEN 0x04

// DEBUG MODE (1 = ON, 0 = OFF)
new DEBUG = 0;

// SOME DEFINES
#define MAX_LINE_WIDTH 60
#define PLUGIN_VERSION "1.4"

// STATS TIME (SET DAYS AFTER STATS ARE DELETE OF NONACTIVE PLAYERS)
#define PLAYER_STATSOLD 30

// STATS DEFINATION FOR PLAYERS
new g_iStatScore[MAXPLAYERS+1];
new g_iStatKills[MAXPLAYERS+1];
new g_iStatDeaths[MAXPLAYERS+1];
new g_iStatHeadShots[MAXPLAYERS+1];
new g_iStatSuicides[MAXPLAYERS+1];
new g_iStatRevives[MAXPLAYERS+1];
new g_iStatHeals[MAXPLAYERS+1];
new g_iUserInit[MAXPLAYERS+1];
new g_iUserFlood[MAXPLAYERS+1];
new g_iUserPtime[MAXPLAYERS+1];
new String:g_sSteamIdSave[MAXPLAYERS+1][255];
new g_iRank[MAXPLAYERS+1];

// HANDLE OF DATABASE
new Handle:g_hDB;
//
/////////////////////////////////////

#define PLUGIN_VERSION "1.7.0"
#define PLUGIN_DESCRIPTION "Respawn dead players via admincommand or by queues"
#define UPDATE_URL	"http://ins.jballou.com/sourcemod/update-respawn.txt"

// Plugin info
public Plugin:myinfo =
{
	name = "[INS] Player Respawn",
	author = "Jared Ballou (Contributor: Daimyo, naong)",
	version = PLUGIN_VERSION,
	description = PLUGIN_DESCRIPTION,
	url = "http://jballou.com"
};

// Start plugin
public OnPluginStart()
{
	//Create player array list
	g_playerArrayList = CreateArray(64);
	CreateConVar("sm_respawn_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);
	sm_respawn_enabled = CreateConVar("sm_respawn_enabled", "1", "Automatically respawn players when they die; 0 - disabled, 1 - enabled");
	
	// Nav Mesh Botspawn specific START
	cvarSpawnMode = CreateConVar("sm_botspawns_spawn_mode", "1", "Only normal spawnpoints at the objective, the old way (0), spawn in hiding spots following rules (1)", FCVAR_NOTIFY);
	cvarMinCounterattackDistance = CreateConVar("sm_botspawns_min_counterattack_distance", "3600.0", "Min distance from counterattack objective to spawn", FCVAR_NOTIFY);
	cvarMinPlayerDistance = CreateConVar("sm_botspawns_min_player_distance", "16.0", "Min distance from players to spawn", FCVAR_NOTIFY);
	cvarMaxPlayerDistance = CreateConVar("sm_botspawns_max_player_distance", "16000.0", "Max distance from players to spawn", FCVAR_NOTIFY);
	cvarCanSeeVectorMultiplier = CreateConVar("sm_botpawns_can_see_vect_mult", "1.5", "Divide this with sm_botspawns_max_player_distance to get CanSeeVector allowed distance for bot spawning in LOS", FCVAR_NOTIFY);
	cvarMinObjectiveDistance = CreateConVar("sm_botspawns_min_objective_distance", "1", "Min distance from next objective to spawn", FCVAR_NOTIFY);
	cvarMaxObjectiveDistance = CreateConVar("sm_botspawns_max_objective_distance", "12000", "Max distance from next objective to spawn", FCVAR_NOTIFY);
	cvarMaxObjectiveDistanceNav = CreateConVar("sm_botspawns_max_objective_distance_nav", "2000", "Max distance from next objective to spawn", FCVAR_NOTIFY);

	cvarSpawnAttackDelay = CreateConVar("sm_botspawns_spawn_attack_delay", "2", "Delay in seconds for spawning bots to wait before firing.", FCVAR_NOTIFY);

	// Nav Mesh Botspawn specific END
	
	// Respawn delay time
	sm_respawn_delay_team_ins = CreateConVar("sm_respawn_delay_team_ins", 
		"1.0", "How many seconds to delay the respawn (bots)");
	sm_respawn_delay_team_sec = CreateConVar("sm_respawn_delay_team_sec", 
		"30.0", "How many seconds to delay the respawn (If not set 'sm_respawn_delay_team_sec_player_count_XX' uses this value)");
	sm_respawn_delay_team_sec_player_count_01 = CreateConVar("sm_respawn_delay_team_sec_player_count_01", 
		"5.0", "How many seconds to delay the respawn (when player count is 1)");
	sm_respawn_delay_team_sec_player_count_02 = CreateConVar("sm_respawn_delay_team_sec_player_count_02", 
		"10.0", "How many seconds to delay the respawn (when player count is 2)");
	sm_respawn_delay_team_sec_player_count_03 = CreateConVar("sm_respawn_delay_team_sec_player_count_03", 
		"20.0", "How many seconds to delay the respawn (when player count is 3)");
	sm_respawn_delay_team_sec_player_count_04 = CreateConVar("sm_respawn_delay_team_sec_player_count_04", 
		"30.0", "How many seconds to delay the respawn (when player count is 4)");
	sm_respawn_delay_team_sec_player_count_05 = CreateConVar("sm_respawn_delay_team_sec_player_count_05", 
		"60.0", "How many seconds to delay the respawn (when player count is 5)");
	sm_respawn_delay_team_sec_player_count_06 = CreateConVar("sm_respawn_delay_team_sec_player_count_06",
		"60.0", "How many seconds to delay the respawn (when player count is 6)");
	sm_respawn_delay_team_sec_player_count_07 = CreateConVar("sm_respawn_delay_team_sec_player_count_07", 
		"70.0", "How many seconds to delay the respawn (when player count is 7)");
	sm_respawn_delay_team_sec_player_count_08 = CreateConVar("sm_respawn_delay_team_sec_player_count_08", 
		"70.0", "How many seconds to delay the respawn (when player count is 8)");
	sm_respawn_delay_team_sec_player_count_09 = CreateConVar("sm_respawn_delay_team_sec_player_count_09", 
		"80.0", "How many seconds to delay the respawn (when player count is 9)");
	sm_respawn_delay_team_sec_player_count_10 = CreateConVar("sm_respawn_delay_team_sec_player_count_10", 
		"80.0", "How many seconds to delay the respawn (when player count is 10)");
	sm_respawn_delay_team_sec_player_count_11 = CreateConVar("sm_respawn_delay_team_sec_player_count_11", 
		"90.0", "How many seconds to delay the respawn (when player count is 11)");
	sm_respawn_delay_team_sec_player_count_12 = CreateConVar("sm_respawn_delay_team_sec_player_count_12", 
		"90.0", "How many seconds to delay the respawn (when player count is 12)");
	sm_respawn_delay_team_sec_player_count_13 = CreateConVar("sm_respawn_delay_team_sec_player_count_13", 
		"100.0", "How many seconds to delay the respawn (when player count is 13)");
	sm_respawn_delay_team_sec_player_count_14 = CreateConVar("sm_respawn_delay_team_sec_player_count_14", 
		"100.0", "How many seconds to delay the respawn (when player count is 14)");
	sm_respawn_delay_team_sec_player_count_15 = CreateConVar("sm_respawn_delay_team_sec_player_count_15", 
		"110.0", "How many seconds to delay the respawn (when player count is 15)");
	sm_respawn_delay_team_sec_player_count_16 = CreateConVar("sm_respawn_delay_team_sec_player_count_16", 
		"110.0", "How many seconds to delay the respawn (when player count is 16)");
	sm_respawn_delay_team_sec_player_count_17 = CreateConVar("sm_respawn_delay_team_sec_player_count_17", 
		"120.0", "How many seconds to delay the respawn (when player count is 17)");
	sm_respawn_delay_team_sec_player_count_18 = CreateConVar("sm_respawn_delay_team_sec_player_count_18", 
		"120.0", "How many seconds to delay the respawn (when player count is 18)");
	
	// Respawn type
	sm_respawn_type_team_sec = CreateConVar("sm_respawn_type_team_sec", 
		"1", "1 - individual lives, 2 - each team gets a pool of lives used by everyone, sm_respawn_lives_team_sec must be > 0");
	sm_respawn_type_team_ins = CreateConVar("sm_respawn_type_team_ins", 
		"2", "1 - individual lives, 2 - each team gets a pool of lives used by everyone, sm_respawn_lives_team_ins must be > 0");
	
	// Respawn lives
	sm_respawn_lives_team_sec = CreateConVar("sm_respawn_lives_team_sec", 
		"-1", "Respawn players this many times (-1: Disables player respawn)");
	sm_respawn_lives_team_ins = CreateConVar("sm_respawn_lives_team_ins", 
		"10", "If 'sm_respawn_type_team_ins' set 1, respawn bots this many times. If 'sm_respawn_type_team_ins' set 2, total bot count (If not set 'sm_respawn_lives_team_ins_player_count_XX' uses this value)");
	sm_respawn_lives_team_ins_player_count_01 = CreateConVar("sm_respawn_lives_team_ins_player_count_01", 
		"5", "Total bot count (when player count is 1)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_02 = CreateConVar("sm_respawn_lives_team_ins_player_count_02", 
		"10", "Total bot count (when player count is 2)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_03 = CreateConVar("sm_respawn_lives_team_ins_player_count_03", 
		"15", "Total bot count (when player count is 3)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_04 = CreateConVar("sm_respawn_lives_team_ins_player_count_04", 
		"20", "Total bot count (when player count is 4)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_05 = CreateConVar("sm_respawn_lives_team_ins_player_count_05", 
		"25", "Total bot count (when player count is 5)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_06 = CreateConVar("sm_respawn_lives_team_ins_player_count_06", 
		"30", "Total bot count (when player count is 6)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_07 = CreateConVar("sm_respawn_lives_team_ins_player_count_07", 
		"35", "Total bot count (when player count is 7)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_08 = CreateConVar("sm_respawn_lives_team_ins_player_count_08", 
		"40", "Total bot count (when player count is 8)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_09 = CreateConVar("sm_respawn_lives_team_ins_player_count_09", 
		"45", "Total bot count (when player count is 9)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_10 = CreateConVar("sm_respawn_lives_team_ins_player_count_10", 
		"50", "Total bot count (when player count is 10)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_11 = CreateConVar("sm_respawn_lives_team_ins_player_count_11", 
		"55", "Total bot count (when player count is 11)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_12 = CreateConVar("sm_respawn_lives_team_ins_player_count_12", 
		"60", "Total bot count (when player count is 12)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_13 = CreateConVar("sm_respawn_lives_team_ins_player_count_13", 
		"65", "Total bot count (when player count is 13)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_14 = CreateConVar("sm_respawn_lives_team_ins_player_count_14", 
		"70", "Total bot count (when player count is 14)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_15 = CreateConVar("sm_respawn_lives_team_ins_player_count_15", 
		"75", "Total bot count (when player count is 15)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_16 = CreateConVar("sm_respawn_lives_team_ins_player_count_16", 
		"80", "Total bot count (when player count is 16)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_17 = CreateConVar("sm_respawn_lives_team_ins_player_count_17", 
		"85", "Total bot count (when player count is 17)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_18 = CreateConVar("sm_respawn_lives_team_ins_player_count_18", 
		"90", "Total bot count (when player count is 18)(sm_respawn_type_team_ins must be 2)");
	
	// Fatally death
	sm_respawn_fatal_chance = CreateConVar("sm_respawn_fatal_chance", "0.20", "Chance for a kill to be fatal, 0.6 default = 60% chance to be fatal (To disable set 0.0)");
	sm_respawn_fatal_head_chance = CreateConVar("sm_respawn_fatal_head_chance", "0.30", "Chance for a headshot kill to be fatal, 0.6 default = 60% chance to be fatal");
	sm_respawn_fatal_limb_dmg = CreateConVar("sm_respawn_fatal_limb_dmg", "80", "Amount of damage to fatally kill player in limb");
	sm_respawn_fatal_head_dmg = CreateConVar("sm_respawn_fatal_head_dmg", "100", "Amount of damage to fatally kill player in head");
	sm_respawn_fatal_burn_dmg = CreateConVar("sm_respawn_fatal_burn_dmg", "50", "Amount of damage to fatally kill player in burn");
	sm_respawn_fatal_explosive_dmg = CreateConVar("sm_respawn_fatal_explosive_dmg", "200", "Amount of damage to fatally kill player in explosive");
	sm_respawn_fatal_chest_stomach = CreateConVar("sm_respawn_fatal_chest_stomach", "100", "Amount of damage to fatally kill player in chest/stomach");
	
	// Counter attack
	sm_respawn_counter_chance = CreateConVar("sm_respawn_counter_chance", "0.5", "Percent chance that a counter attack will happen def: 50%");
	sm_respawn_counterattack_type = CreateConVar("sm_respawn_counterattack_type", "2", "Respawn during counterattack? (0: no, 1: yes, 2: infinite)");
	sm_respawn_final_counterattack_type = CreateConVar("sm_respawn_final_counterattack_type", "2", "Respawn during final counterattack? (0: no, 1: yes, 2: infinite)");
	sm_respawn_security_on_counter = CreateConVar("sm_respawn_security_on_counter", "1", "0/1 When a counter attack starts, spawn all dead players and teleport them to point to defend");
	sm_respawn_min_counter_dur_sec = CreateConVar("sm_respawn_min_counter_dur_sec", "66", "Minimum randomized counter attack duration");
	sm_respawn_max_counter_dur_sec = CreateConVar("sm_respawn_max_counter_dur_sec", "126", "Maximum randomized counter attack duration");
	sm_respawn_final_counter_dur_sec = CreateConVar("sm_respawn_final_counter_dur_sec", "180", "Final counter attack duration");
	
	//Dynamic respawn mechanics
	sm_respawn_dynamic_distance_multiplier = CreateConVar("sm_respawn_dynamic_distance_multiplier", "2", "This multiplier is used to make bot distance from points on/off counter attacks more dynamic by making distance closer/farther when bots respawn");
	sm_respawn_dynamic_spawn_counter_percent = CreateConVar("sm_respawn_dynamic_spawn_counter_percent", "0.4", "Percent of bots that will spawn farther away on a counter attack (basically their more ideal normal spawns)");
	sm_respawn_dynamic_spawn_percent = CreateConVar("sm_respawn_dynamic_spawn_percent", "0.5", "Percent of bots that will spawn farther away NOT on a counter (basically their more ideal normal spawns)");
	
	// Misc
	sm_respawn_reset_type = CreateConVar("sm_respawn_reset_type", "0", "Set type of resetting player respawn counts: each round or each objective (0: each round, 1: each objective)");
	sm_respawn_enable_track_ammo = CreateConVar("sm_respawn_enable_track_ammo", "1", "0/1 Track ammo on death to revive (may be buggy if using a different theatre that modifies ammo)");
	
	// Reinforcements
	sm_respawn_reinforce_time = CreateConVar("sm_respawn_reinforce_time", "200", "When enemy forces are low on lives, how much time til they get reinforcements?");
	sm_respawn_reinforce_time_subsequent = CreateConVar("sm_respawn_reinforce_time_subsequent", "140", "When enemy forces are low on lives and already reinforced, how much time til they get reinforcements on subsequent reinforcement?");
	sm_respawn_reinforce_multiplier = CreateConVar("sm_reinforce_multiplier", "4", "Division multiplier to determine when to start reinforce timer for bots based on team pool lives left over");
	sm_respawn_reinforce_multiplier_base = CreateConVar("sm_respawn_reinforce_multiplier_base", "10", "This is the base int number added to the division multiplier, so (10 * reinforce_mult + base_mult)");
	
	// Control static enemy
	sm_respawn_check_static_enemy = CreateConVar("sm_respawn_check_static_enemy", "120", "Seconds amount to check if an AI has moved probably stuck");
	sm_respawn_check_static_enemy_counter = CreateConVar("sm_respawn_check_static_enemy_counter", "10", "Seconds amount to check if an AI has moved during counter");
	
	// Donor tag
	sm_respawn_enable_donor_tag = CreateConVar("sm_respawn_enable_donor_tag", "1", "If player has an access to reserved slot, add [DONOR] tag.");
	
	// Related to 'RoundEnd_Protector' plugin
	sm_remaininglife = CreateConVar("sm_remaininglife", "-1", "Returns total remaining life.");
	
	// Medic Revive
	sm_revive_seconds = CreateConVar("sm_revive_seconds", "5", "Time in seconds medic needs to stand over body to revive");
	sm_revive_bonus = CreateConVar("sm_revive_bonus", "1", "Bonus revive score(kill count) for medic");
	sm_revive_distance_metric = CreateConVar("sm_revive_distance_metric", "1", "Distance metric (0: meters / 1: feet)");
	sm_heal_bonus = CreateConVar("sm_heal_bonus", "1", "Bonus heal score(kill count) for medic");
	sm_heal_cap_for_bonus = CreateConVar("sm_heal_cap_for_bonus", "50", "Amount of health given to other players to gain a kill");
	sm_heal_amount_medpack = CreateConVar("sm_heal_amount_medpack", "5", "Heal amount per 0.5 seconds when using medpack");
	sm_heal_amount_paddles = CreateConVar("sm_heal_amount_paddles", "3", "Heal amount per 0.5 seconds when using paddles");
	
	sm_non_medic_heal_amt = CreateConVar("sm_non_medic_heal_amt", "2", "Heal amount per 0.5 seconds when non-medic");
	sm_non_medic_revive_hp = CreateConVar("sm_non_medic_revive_hp", "10", "Health given to target revive when non-medic reviving");
	sm_medic_minor_revive_hp = CreateConVar("sm_medic_minor_revive_hp", "75", "Health given to target revive when medic reviving minor wound");
	sm_medic_moderate_revive_hp = CreateConVar("sm_medic_moderate_revive_hp", "50", "Health given to target revive when medic reviving moderate wound");
	sm_medic_critical_revive_hp = CreateConVar("sm_medic_critical_revive_hp", "25", "Health given to target revive when medic reviving critical wound");
	sm_minor_wound_dmg = CreateConVar("sm_minor_wound_dmg", "100", "Any amount of damage <= to this is considered a minor wound when killed");
	sm_moderate_wound_dmg = CreateConVar("sm_moderate_wound_dmg", "200", "Any amount of damage <= to this is considered a minor wound when killed.  Anything greater is CRITICAL");
	sm_medic_heal_self_max = CreateConVar("sm_medic_heal_self_max", "75", "Max medic can heal self to with med pack");
	sm_non_medic_heal_self_max = CreateConVar("sm_non_medic_heal_self_max", "25", "Max non-medic can heal self to with med pack");
	sm_non_medic_max_heal_other = CreateConVar("sm_non_medic_max_heal_other", "25", "Heal amount per 0.5 seconds when using paddles");
	sm_minor_revive_time = CreateConVar("sm_minor_revive_time", "4", "Seconds it takes medic to revive minor wounded");
	sm_moderate_revive_time = CreateConVar("sm_moderate_revive_time", "7", "Seconds it takes medic to revive moderate wounded");
	sm_critical_revive_time = CreateConVar("sm_critical_revive_time", "10", "Seconds it takes medic to revive critical wounded");
	sm_non_medic_revive_time = CreateConVar("sm_non_medic_revive_time", "30", "Seconds it takes non-medic to revive minor wounded, requires medpack");
	sm_medpack_health_amount = CreateConVar("sm_medpack_health_amount", "500", "Amount of health a deployed healthpack has");
	sm_bombers_only = CreateConVar("sm_bombers_only", "0", "bombers ONLY?");
	sm_multi_loadout_enabled = CreateConVar("sm_multi_loadout_enabled", "0", "Use Sernix Variety Bot Loadout? - Default OFF");

	CreateConVar("Lua_Ins_Healthkit", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_DONTRECORD);
	

	if ((m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons")) == -1) {
		SetFailState("Fatal Error: Unable to find property offset \"CBasePlayer::m_hMyWeapons\" !");
	}

	if ((m_flNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack")) == -1) {
		SetFailState("Fatal Error: Unable to find property offset \"CBaseCombatWeapon::m_flNextPrimaryAttack\" !");
	}

	if ((m_flNextSecondaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack")) == -1) {
		SetFailState("Fatal Error: Unable to find property offset \"CBaseCombatWeapon::m_flNextSecondaryAttack\" !");
	}

	// Add admin respawn console command
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_SLAY, "sm_respawn <#userid|name>");
	
	// Add reload config console command for admin
	RegAdminCmd("sm_respawn_reload", Command_Reload, ADMFLAG_SLAY, "sm_respawn_reload");
	
	// Event hooking
	//Lua Specific
	HookEvent("grenade_thrown", Event_GrenadeThrown);

	//For ins_spawnpoint spawning
	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_spawn", Event_SpawnPost, EventHookMode_Post);

	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_end", Event_RoundEnd_Pre, EventHookMode_Pre);
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("object_destroyed", Event_ObjectDestroyed_Pre, EventHookMode_Pre);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	HookEvent("object_destroyed", Event_ObjectDestroyed_Post, EventHookMode_Post);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured_Pre, EventHookMode_Pre);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured_Post, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_connect", Event_PlayerConnect);
	
	// NavMesh Botspawn Specific Start
	HookConVarChange(cvarSpawnMode,CvarChange);
	// NavMesh Botspawn Specific End
	
	// Revive/Heal specific
	HookConVarChange(sm_revive_seconds, CvarChange);
	HookConVarChange(sm_heal_amount_medpack, CvarChange);

	HookConVarChange(sm_non_medic_heal_amt, CvarChange);
	HookConVarChange(sm_non_medic_revive_hp, CvarChange);
	HookConVarChange(sm_medic_minor_revive_hp, CvarChange);
	HookConVarChange(sm_medic_moderate_revive_hp, CvarChange);
	HookConVarChange(sm_medic_critical_revive_hp, CvarChange);
	HookConVarChange(sm_minor_wound_dmg, CvarChange);
	HookConVarChange(sm_moderate_wound_dmg, CvarChange);
	HookConVarChange(sm_medic_heal_self_max, CvarChange);
	HookConVarChange(sm_non_medic_heal_self_max, CvarChange);
	HookConVarChange(sm_non_medic_max_heal_other, CvarChange);
	HookConVarChange(sm_minor_revive_time, CvarChange);
	HookConVarChange(sm_moderate_revive_time, CvarChange);
	HookConVarChange(sm_critical_revive_time, CvarChange);
	HookConVarChange(sm_non_medic_revive_time, CvarChange);
	HookConVarChange(sm_medpack_health_amount, CvarChange);
	// Respawn specific
	HookConVarChange(sm_respawn_enabled, EnableChanged);
	HookConVarChange(sm_respawn_delay_team_sec, CvarChange);
	HookConVarChange(sm_respawn_delay_team_ins, CvarChange);
	HookConVarChange(sm_respawn_lives_team_sec, CvarChange);
	HookConVarChange(sm_respawn_lives_team_ins, CvarChange);
	HookConVarChange(sm_respawn_reset_type, CvarChange);
	HookConVarChange(sm_respawn_type_team_sec, CvarChange);
	HookConVarChange(sm_respawn_type_team_ins, CvarChange);
	HookConVarChange(cvarMinPlayerDistance,CvarChange);
	HookConVarChange(cvarMaxPlayerDistance,CvarChange);
	HookConVarChange(cvarCanSeeVectorMultiplier,CvarChange);
	HookConVarChange(cvarMinObjectiveDistance,CvarChange);
	HookConVarChange(cvarMaxObjectiveDistance,CvarChange);
	HookConVarChange(cvarMaxObjectiveDistanceNav,CvarChange);
	//Dynamic respawning
	HookConVarChange(sm_respawn_dynamic_distance_multiplier,CvarChange);
	HookConVarChange(sm_respawn_dynamic_spawn_counter_percent,CvarChange);
	HookConVarChange(sm_respawn_dynamic_spawn_percent,CvarChange);

	//Dynamic Loadouts
	HookConVarChange(sm_bombers_only, CvarChange);
	HookConVarChange(sm_multi_loadout_enabled, CvarChange);

	// Tags
	HookConVarChange(FindConVar("sv_tags"), TagsChanged);

	// Init respawn function
	// Next 14 lines of text are taken from Andersso's DoDs respawn plugin. Thanks :)
	g_hGameConfig = LoadGameConfigFile("insurgency.games");
	
	if (g_hGameConfig == INVALID_HANDLE)
		SetFailState("Fatal Error: Missing File \"insurgency.games\"!");

	StartPrepSDKCall(SDKCall_Player);
	decl String:game[40];
	GetGameFolderName(game, sizeof(game));
	if (StrEqual(game, "insurgency")) {
		//PrintToServer("[RESPAWN] ForceRespawn for Insurgency");
		PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "ForceRespawn");
	}
	if (StrEqual(game, "doi")) {
		//PrintToServer("[RESPAWN] ForceRespawn for DoI");
		PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "ForceRespawn");
	}
	g_hForceRespawn = EndPrepSDKCall();
	if (g_hForceRespawn == INVALID_HANDLE) {
		SetFailState("Fatal Error: Unable to find signature for \"ForceRespawn\"!");
	}
	// Load localization file
	LoadTranslations("common.phrases");
	LoadTranslations("respawn.phrases");
	LoadTranslations("nearest_player.phrases.txt");
	
	// Init plugin
	CreateTimer(2.0, Timer_MapStart);
	
	// Init variables
	g_iLogicEntity = -1;
	g_iObjResEntity = -1;
	
	/////////////////////////
	// Rank System
	RegConsoleCmd("say", Command_Say);			// Monitor say 
	SQL_TConnect(LoadMySQLBase, "insrank");		// Connect to DB
	//
	/////////////////////////
	
	AutoExecConfig(true, "respawn");
}

//End Plugin
public OnPluginEnd()
{
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "healthkit")) > MaxClients && IsValidEntity(ent))
	{
		StopSound(ent, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		AcceptEntityInput(ent, "Kill");
	}
}

// Init config
public OnConfigsExecuted()
{
	if (GetConVarBool(sm_respawn_enabled))
		TagsCheck("respawntimes");
	else
		TagsCheck("respawntimes", true);
}

// When cvar changed
public EnableChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new intNewValue = StringToInt(newValue);
	new intOldValue = StringToInt(oldValue);

	if(intNewValue == 1 && intOldValue == 0)
	{
		TagsCheck("respawntimes");
		//HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	}
	else if(intNewValue == 0 && intOldValue == 1)
	{
		TagsCheck("respawntimes", true);
		//UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	}
}

// When cvar changed
public CvarChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	UpdateRespawnCvars();
}

// Update cvars
void UpdateRespawnCvars()
{

	//Counter attack chance based on number of points
	g_respawn_counter_chance = GetConVarFloat(sm_respawn_counter_chance);

	g_counterAttack_min_dur_sec = GetConVarInt(sm_respawn_min_counter_dur_sec);
	g_counterAttack_max_dur_sec = GetConVarInt(sm_respawn_max_counter_dur_sec);
	// The number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");

	if (ncp < 6)
	{
		//Add to minimum dur as well.
		new fRandomInt = GetRandomInt(15, 30);
		new fRandomInt2 = GetRandomInt(6, 12);
		g_counterAttack_min_dur_sec += fRandomInt;
		g_counterAttack_max_dur_sec += fRandomInt2;
		g_respawn_counter_chance += 0.2;
	}
	else if (ncp >= 6 && ncp <= 8)
	{
		//Add to minimum dur as well.
		new fRandomInt = GetRandomInt(10, 20);
		new fRandomInt2 = GetRandomInt(4, 8);
		g_counterAttack_min_dur_sec += fRandomInt;
		g_counterAttack_max_dur_sec += fRandomInt2;
		g_respawn_counter_chance += 0.1;
	}


	// Update Cvars
	g_iCvar_respawn_enable = GetConVarInt(sm_respawn_enabled);
	
	// Bot spawn mode
	g_iCvar_SpawnMode = GetConVarInt(cvarSpawnMode);
	
	// Tracking ammo
	g_iCvar_enable_track_ammo = GetConVarInt(sm_respawn_enable_track_ammo);
	
	// Respawn type
	g_iCvar_respawn_type_team_ins = GetConVarInt(sm_respawn_type_team_ins);
	g_iCvar_respawn_type_team_sec = GetConVarInt(sm_respawn_type_team_sec);
	
	// Type of resetting respawn token
	g_iCvar_respawn_reset_type = GetConVarInt(sm_respawn_reset_type);
	
	//Dynamic Respawns
	g_DynamicRespawn_Distance_mult = GetConVarFloat(sm_respawn_dynamic_distance_multiplier);
	g_dynamicSpawnCounter_Perc = GetConVarFloat(sm_respawn_dynamic_spawn_counter_percent);
	g_dynamicSpawn_Perc = GetConVarFloat(sm_respawn_dynamic_spawn_percent);
	
	//Revive counts
	g_iReviveSeconds = GetConVarInt(sm_revive_seconds);
	
	// Heal Amount
	g_iHeal_amount_medPack = GetConVarInt(sm_heal_amount_medpack);
	g_iHeal_amount_paddles = GetConVarInt(sm_heal_amount_paddles);
	g_nonMedicHeal_amount = GetConVarInt(sm_non_medic_heal_amt);
	
	//HP when revived from wound
	g_nonMedicRevive_hp = GetConVarInt(sm_non_medic_revive_hp);
	g_minorWoundRevive_hp = GetConVarInt(sm_medic_minor_revive_hp);
	g_modWoundRevive_hp = GetConVarInt(sm_medic_moderate_revive_hp);
	g_critWoundRevive_hp = GetConVarInt(sm_medic_critical_revive_hp);

	//New Revive Mechanics
	g_minorWound_dmg = GetConVarInt(sm_minor_wound_dmg);
	g_moderateWound_dmg = GetConVarInt(sm_moderate_wound_dmg);
	g_medicHealSelf_max = GetConVarInt(sm_medic_heal_self_max);
	g_nonMedicHealSelf_max = GetConVarInt(sm_non_medic_heal_self_max);
	g_nonMedic_maxHealOther = GetConVarInt(sm_non_medic_max_heal_other);
	g_minorRevive_time = GetConVarInt(sm_minor_revive_time);
	g_modRevive_time = GetConVarInt(sm_moderate_revive_time);
	g_critRevive_time = GetConVarInt(sm_critical_revive_time);
	g_nonMedRevive_time = GetConVarInt(sm_non_medic_revive_time);
	g_medpack_health_amt = GetConVarInt(sm_medpack_health_amount);
	// Fatal dead
	g_fCvar_fatal_chance = GetConVarFloat(sm_respawn_fatal_chance);
	g_fCvar_fatal_head_chance = GetConVarFloat(sm_respawn_fatal_head_chance);
	g_iCvar_fatal_limb_dmg = GetConVarInt(sm_respawn_fatal_limb_dmg);
	g_iCvar_fatal_head_dmg = GetConVarInt(sm_respawn_fatal_head_dmg);
	g_iCvar_fatal_burn_dmg = GetConVarInt(sm_respawn_fatal_burn_dmg);
	g_iCvar_fatal_explosive_dmg = GetConVarInt(sm_respawn_fatal_explosive_dmg);
	g_iCvar_fatal_chest_stomach = GetConVarInt(sm_respawn_fatal_chest_stomach);
	
	//Dynamic Loadouts
	g_iCvar_bombers_only = GetConVarInt(sm_bombers_only);
	g_iCvar_multi_loadout_enabled = GetConVarInt(sm_multi_loadout_enabled);
	

	// Nearest body distance metric
	g_iUnitMetric = GetConVarInt(sm_revive_distance_metric);
	
	// Set respawn delay time
	g_iRespawnSeconds = -1;
	switch (GetTeamSecCount())
	{
		case 0: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_01);
		case 1: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_01);
		case 2: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_02);
		case 3: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_03);
		case 4: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_04);
		case 5: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_05);
		case 6: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_06);
		case 7: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_07);
		case 8: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_08);
		case 9: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_09);
		case 10: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_10);
		case 11: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_11);
		case 12: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_12);
		case 13: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_13);
		case 14: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_14);
		case 15: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_15);
		case 16: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_16);
		case 17: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_17);
		case 18: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_18);
	}
	// If not set use default
	if (g_iRespawnSeconds == -1)
		g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec);
		
	// Respawn delay for team ins
	g_fCvar_respawn_delay_team_ins = GetConVarFloat(sm_respawn_delay_team_ins);
	
	// Respawn type 1
	g_iRespawnCount[2] = GetConVarInt(sm_respawn_lives_team_sec);
	g_iRespawnCount[3] = GetConVarInt(sm_respawn_lives_team_ins);
		
	// Respawn type 2 for players
	if (g_iCvar_respawn_type_team_sec == 2)
	{
		g_iRespawn_lives_team_sec = GetConVarInt(sm_respawn_lives_team_sec);
	}
	// Respawn type 2 for bots
	else if (g_iCvar_respawn_type_team_ins == 2)
	{
		// Set base value of remaining lives for team insurgent
		g_iRespawn_lives_team_ins = -1;
		switch (GetTeamSecCount())
		{
			case 0: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_01);
			case 1: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_01);
			case 2: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_02);
			case 3: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_03);
			case 4: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_04);
			case 5: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_05);
			case 6: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_06);
			case 7: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_07);
			case 8: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_08);
			case 9: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_09);
			case 10: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_10);
			case 11: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_11);
			case 12: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_12);
			case 13: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_13);
			case 14: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_14);
			case 15: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_15);
			case 16: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_16);
			case 17: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_17);
			case 18: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_18);
		}
		
		// If not set, use default
		if (g_iRespawn_lives_team_ins == -1)
			g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins);
	}
	
	// Counter attack
	g_flMinCounterattackDistance = GetConVarFloat(cvarMinCounterattackDistance);
	g_flMinPlayerDistance = GetConVarFloat(cvarMinPlayerDistance);
	g_flMaxPlayerDistance = GetConVarFloat(cvarMaxPlayerDistance);
	g_flCanSeeVectorMultiplier = GetConVarFloat(cvarCanSeeVectorMultiplier);
	g_iCvar_counterattack_type = GetConVarInt(sm_respawn_counterattack_type);
	g_iCvar_final_counterattack_type = GetConVarInt(sm_respawn_final_counterattack_type);

	g_flMinObjectiveDistance = GetConVarFloat(cvarMinObjectiveDistance);
	g_flMaxObjectiveDistance = GetConVarFloat(cvarMaxObjectiveDistance);
	g_flMaxObjectiveDistanceNav = GetConVarFloat(cvarMaxObjectiveDistanceNav);
	g_flSpawnAttackDelay = GetConVarFloat(cvarSpawnAttackDelay);

	//Disable on conquer
	if (g_isConquer || g_isOutpost)
		g_iCvar_SpawnMode = 0;

	//Hunt specific
	if (g_isHunt == 1)
	{
		
		new secTeamCount = GetTeamSecCount();
		g_iCvar_SpawnMode = 0;
		//Increase reinforcements
		g_iRespawn_lives_team_ins = ((g_iRespawn_lives_team_ins * secTeamCount) / 4);
	}
}

// When tags changed
public TagsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (GetConVarBool(sm_respawn_enabled))
		TagsCheck("respawntimes");
	else
		TagsCheck("respawntimes", true);
}

// On map starts, call initalizing function
public OnMapStart()
{	
	//Clear player array
	ClearArray(g_playerArrayList);

	//Dynamic Loadouts
	g_iCvar_bombers_only = GetConVarInt(sm_bombers_only);
	g_iCvar_multi_loadout_enabled = GetConVarInt(sm_multi_loadout_enabled);

	//Load Dynamic Loadouts?
	//if (g_iCvar_multi_loadout_enabled == 1)
		Dynamic_Loadouts();

	//Wait until players ready to enable spawn checking
	g_playersReady = false;
	g_botsReady = 0;
	//Lua onmap start
	//g_iBeaconBeam = PrecacheModel("sprites/glow_fluorescent01.vmt");
	//g_iBeaconHalo = PrecacheModel("sprites/glow_dusty.vmt");
	
	g_iBeaconBeam = PrecacheModel("sprites/laserbeam.vmt");
	g_iBeaconHalo = PrecacheModel("sprites/halo01.vmt");

	// Healing sounds
	//PrecacheSound("Lua_sounds/healthkit_complete.wav");
	//PrecacheSound("Lua_sounds/healthkit_healing.wav");
	// Destory, Flip sounds
	PrecacheSound("soundscape/emitters/oneshot/radio_explode.ogg");
	PrecacheSound("ui/sfx/cl_click.wav");
	// Deploying sounds
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/need_backup1.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/need_backup2.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/need_backup3.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/holdposition2.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/holdposition3.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/moving2.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/backup3.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/holdposition1.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/holdposition2.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/holdposition3.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/holdposition4.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/moving3.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/ontheway1.ogg");
	PrecacheSound("player/voice/security/command/leader/located4.ogg");
	PrecacheSound("player/voice/security/command/leader/setwaypoint1.ogg");
	PrecacheSound("player/voice/security/command/leader/setwaypoint2.ogg");
	PrecacheSound("player/voice/security/command/leader/setwaypoint3.ogg");
	PrecacheSound("player/voice/security/command/leader/setwaypoint4.ogg");

	PrecacheSound("weapons/universal/uni_crawl_l_01.wav");
	PrecacheSound("weapons/universal/uni_crawl_l_04.wav");
	PrecacheSound("weapons/universal/uni_crawl_l_02.wav");
	PrecacheSound("weapons/universal/uni_crawl_r_03.wav");
	PrecacheSound("weapons/universal/uni_crawl_r_05.wav");
	PrecacheSound("weapons/universal/uni_crawl_r_06.wav");

	//Grenade Call Out
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade9.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade9.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade4.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade4.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade35.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade34.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade33.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade23.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade2.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade13.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade12.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade11.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade10.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade18.ogg");
	
	//Molotov/Incen Callout
	PrecacheSound("player/voice/responses/security/subordinate/damage/molotov_incendiary_detonated7.ogg");
	PrecacheSound("player/voice/responses/security/leader/damage/molotov_incendiary_detonated6.ogg");
	PrecacheSound("player/voice/responses/security/subordinate/damage/molotov_incendiary_detonated6.ogg");
	PrecacheSound("player/voice/responses/security/leader/damage/molotov_incendiary_detonated5.ogg");
	PrecacheSound("player/voice/responses/security/leader/damage/molotov_incendiary_detonated4.ogg");

	// AddFileToDownloadsTable("materials/models/items/healthkit01.vmt");
	// AddFileToDownloadsTable("materials/models/items/healthkit01.vtf");
	// AddFileToDownloadsTable("materials/models/items/healthkit01_mask.vtf");
	// AddFileToDownloadsTable("models/items/healthkit.dx80.vtx");
	// AddFileToDownloadsTable("models/items/healthkit.dx90.vtx");
	// AddFileToDownloadsTable("models/items/healthkit.mdl");
	// AddFileToDownloadsTable("models/items/healthkit.phy");
	// AddFileToDownloadsTable("models/items/healthkit.sw.vtx");
	// AddFileToDownloadsTable("models/items/healthkit.vvd");
	// AddFileToDownloadsTable("sound/Lua_sounds/healthkit_complete.wav");
	// AddFileToDownloadsTable("sound/Lua_sounds/healthkit_healing.wav");

	// Wait for navmesh
	CreateTimer(2.0, Timer_MapStart);
	g_preRoundInitial = true;
	// Update entity
	GetObjResEnt(1);
	GetLogicEnt(1);
}

//Dynamic Loadouts
void Dynamic_Loadouts()
{
	new Float:fRandom = GetRandomFloat(0.0, 1.0);
	new Handle:hTheaterOverride = FindConVar("mp_theater_override");	
	// Occurs counter attack
	if (fRandom >= 0.0 && fRandom < 0.24)
	{
		SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc", true, false);
	}
	else if (fRandom >= 0.24 && fRandom < 0.48)
	{
		SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_isis", true, false);
	}
	else if (fRandom >= 0.48 && fRandom < 0.72)
	{
		//Desert is just diff skins
		new Float:fRandom_mil = GetRandomFloat(0.0, 1.0);
		if (fRandom >= 0.5)
			SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_military", true, false);
		else
			SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_military_des", true, false);
	}
	else if (fRandom >= 0.72 && fRandom < 0.96)
	{
		SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_rebels", true, false);
	}
	else if (fRandom >= 0.96)
	{
		SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_bomber", true, false);
	}
	//Its a good day to die
	if (g_iCvar_bombers_only == 1)
		SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_bomber", true, false);
}

// Initializing
public Action:Timer_MapStart(Handle:Timer)
{
	// Check is map initialized
	if (g_isMapInit == 1) 
	{
		//PrintToServer("[RESPPAWN] Prevented repetitive call");
		return;
	}
	g_isMapInit = 1;

	// Update cvars
	UpdateRespawnCvars();
	
	g_isConquer = 0;
	g_isHunt = 0;
	g_isCheckpoint = 0;
	g_isOutpost = 0;
	// Reset hiding spot
	new iEmptyArray[MAX_OBJECTIVES];
	g_iCPHidingSpotCount = iEmptyArray;
	
	// Check gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	if (StrEqual(sGameMode,"hunt")) // if Hunt?
	{
		g_isHunt = 1;
		g_iCvar_SpawnMode = 0;
	   	//SetConVarFloat(sm_respawn_fatal_chance, 0.1, true, false);
	   	//SetConVarFloat(sm_respawn_fatal_head_chance, 0.2, true, false);
	}
	if (StrEqual(sGameMode,"conquer")) // if conquer?
	{
		g_isConquer = 1;
		g_iCvar_SpawnMode = 0;
	   	//SetConVarFloat(sm_respawn_fatal_chance, 0.4, true, false);
	   	//SetConVarFloat(sm_respawn_fatal_head_chance, 0.4, true, false);
	}
	if (StrEqual(sGameMode,"outpost")) // if conquer?
	{
		g_isOutpost = 1;
		g_iCvar_SpawnMode = 0;
	   	//SetConVarFloat(sm_respawn_fatal_chance, 0.4, true, false);
	   	//SetConVarFloat(sm_respawn_fatal_head_chance, 0.4, true, false);
	}
	if (StrEqual(sGameMode,"checkpoint")) // if Hunt?
	{
		g_isCheckpoint = 1;
	}
	
	// Init respawn count
	new reinforce_time = GetConVarInt(sm_respawn_reinforce_time);
	g_iReinforceTime = reinforce_time;
	
	g_iEnableRevive = 0;
	// BotSpawn Nav Mesh initialize #################### END
	
	// Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	
	// Ammo tracking timer
	if (GetConVarInt(sm_respawn_enable_track_ammo) == 1)
		CreateTimer(1.0, Timer_GearMonitor,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Enemy reinforcement announce timer
	if (g_isConquer != 1 && g_isOutpost != 1) 
		CreateTimer(1.0, Timer_EnemyReinforce,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Enemy remaining announce timer
	if (g_isConquer != 1 && g_isOutpost != 1) 
		CreateTimer(30.0, Timer_Enemies_Remaining,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Player status check timer
	CreateTimer(1.0, Timer_PlayerStatus,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Revive monitor
	CreateTimer(1.0, Timer_ReviveMonitor, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Heal monitor
	CreateTimer(0.5, Timer_MedicMonitor, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Display nearest body for medics
	CreateTimer(0.2, Timer_NearestBody, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Static enemy check timer
	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy);
	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
	//Temp testing
	g_checkStaticAmtAway = 30;
	g_checkStaticAmtCntrAway = 12;

	CreateTimer(1.0, Timer_CheckEnemyStatic,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	if (g_isCheckpoint)
		CreateTimer(1.0, Timer_CheckEnemyAway,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Player timeout check timer
	//CreateTimer(1.0, Timer_PlayerTimeout,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	//		##############NAV INIT SPAWNING################
	//########### NOTHING BELOW THIS, IF THIS CODE CRASHES, NOTHING UNDER RUNS #######
	/*
	// Get hiding spot count
	g_hHidingSpots = NavMesh_GetHidingSpots();//try NavMesh_GetAreas(); or //NavMesh_GetPlaces(); // or NavMesh_GetEncounterPaths();
	if (g_hHidingSpots != INVALID_HANDLE)
		g_iHidingSpotCount = GetArraySize(g_hHidingSpots);
	else
		g_iHidingSpotCount = 0;
	
	// Get the number of control points
	m_iNumControlPoints = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	//PrintToServer("[BOTSPAWNS] m_iNumControlPoints %d",m_iNumControlPoints);
	for (new i = 0; i < m_iNumControlPoints; i++)
	{
		Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[i],i);
		//PrintToServer("[BOTSPAWNS] i %d (%f,%f,%f)",i,m_vCPPositions[i][0],m_vCPPositions[i][1],m_vCPPositions[i][2]);
	}
	// Init last hiding spot variable
	for (new iCP = 0; iCP < m_iNumControlPoints; iCP++)
	{
		g_iCPLastHidingSpot[iCP] = 0;
	}
	// Retrive hiding spot by control point
	if (g_iHidingSpotCount)
	{
		//PrintToServer("[BOTSPAWNS] g_iHidingSpotCount: %d",g_iHidingSpotCount);
		for (new iIndex = 0, iSize = g_iHidingSpotCount; iIndex < iSize; iIndex++)
		{
			new Float:flHidingSpot[3];//, iHidingSpotFlags;
			flHidingSpot[0] = GetArrayCell(g_hHidingSpots, iIndex, NavMeshHidingSpot_X);
			flHidingSpot[1] = GetArrayCell(g_hHidingSpots, iIndex, NavMeshHidingSpot_Y);
			flHidingSpot[2] = GetArrayCell(g_hHidingSpots, iIndex, NavMeshHidingSpot_Z);
			new Float:dist,Float:closest = -1.0,pointidx=-1;
			for (new i = 0; i < m_iNumControlPoints; i++)
			{
				dist = GetVectorDistance(flHidingSpot,m_vCPPositions[i]);
				if ((dist < closest) || (closest == -1.0))
				{
					closest = dist;
					pointidx = i;
				}
			}
			if (pointidx > -1)
			{
				g_iCPHidingSpots[pointidx][g_iCPHidingSpotCount[pointidx]] = iIndex;
				g_iCPHidingSpotCount[pointidx]++;
			}
		}
		//PrintToServer("[BOTSPAWNS] Found hiding count: a %d b %d c %d d %d e %d f %d g %d h %d i %d j %d k %d l %d m %d",g_iCPHidingSpotCount[0],g_iCPHidingSpotCount[1],g_iCPHidingSpotCount[2],g_iCPHidingSpotCount[3],g_iCPHidingSpotCount[4],g_iCPHidingSpotCount[5],g_iCPHidingSpotCount[6],g_iCPHidingSpotCount[7],g_iCPHidingSpotCount[8],g_iCPHidingSpotCount[9],g_iCPHidingSpotCount[10],g_iCPHidingSpotCount[11],g_iCPHidingSpotCount[12]);
		//LogMessage("Found hiding count: a %d b %d c %d d %d e %d f %d g %d h %d i %d j %d k %d l %d m %d",g_iCPHidingSpotCount[0],g_iCPHidingSpotCount[1],g_iCPHidingSpotCount[2],g_iCPHidingSpotCount[3],g_iCPHidingSpotCount[4],g_iCPHidingSpotCount[5],g_iCPHidingSpotCount[6],g_iCPHidingSpotCount[7],g_iCPHidingSpotCount[8],g_iCPHidingSpotCount[9],g_iCPHidingSpotCount[10],g_iCPHidingSpotCount[11],g_iCPHidingSpotCount[12]);
	}
	else
	{
		//LogMessage("Hiding spot is not found.");
	}
	*/
	//PrintToServer("[REVIVE_DEBUG] MAP STARTED");	
	//##########NOTHING BELOW THIS POINT##########
}

public OnMapEnd()
{
	// Reset variable
	//PrintToServer("[REVIVE_DEBUG] MAP ENDED");	
	
	// Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	
	g_isMapInit = 0;
}

// Console command for reload config
public Action:Command_Reload(client, args)
{
	ServerCommand("exec sourcemod/respawn.cfg");
	
	// Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	
	//PrintToServer("[RESPAWN] %N reloaded respawn config.", client);
	ReplyToCommand(client, "[SM] Reloaded 'sourcemod/respawn.cfg' file.");
}

// Respawn function for console command
public Action:Command_Respawn(client, args)
{
	// Check argument
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_player_respawn <#userid|name>");
		return Plugin_Handled;
	}

	// Retrive argument
	new String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MaxClients], target_count, bool:tn_is_ml;
	
	// Get target count
	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					COMMAND_FILTER_DEAD,
					target_name,
					sizeof(target_name),
					tn_is_ml);
					
	// Check target count
	if(target_count <= COMMAND_TARGET_NONE) 	// If we don't have dead players
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	// Team filter dead players, re-order target_list array with new_target_count
	new target, team, new_target_count;

	// Check team
	for (new i = 0; i < target_count; i++)
	{
		target = target_list[i];
		team = GetClientTeam(target);

		if(team >= 2)
		{
			target_list[new_target_count] = target; // re-order
			new_target_count++;
		}
	}

	// Check target count
	if(new_target_count == COMMAND_TARGET_NONE) // No dead players from  team 2 and 3
	{
		ReplyToTargetError(client, new_target_count);
		return Plugin_Handled;
	}
	target_count = new_target_count; // re-set new value.

	// If target exists
	if (tn_is_ml)
		ShowActivity2(client, "[SM] ", "%t", "Toggled respawn on target", target_name);
	else
		ShowActivity2(client, "[SM] ", "%t", "Toggled respawn on target", "_s", target_name);
	
	// Process respawn
	for (new i = 0; i < target_count; i++)
		RespawnPlayer(client, target_list[i]);

	return Plugin_Handled;
}

// Respawn player
void RespawnPlayer(client, target)
{
	new team = GetClientTeam(target);
	if(IsClientInGame(target) && !IsClientTimingOut(target) && g_client_last_classstring[target][0] && playerPickSquad[target] == 1 && !IsPlayerAlive(target) && team == TEAM_1)
	{
		// Write a log
		LogAction(client, target, "\"%L\" respawned \"%L\"", client, target);
		
		// Call forcerespawn fucntion
		SDKCall(g_hForceRespawn, target);
	}
}

/*
// Check player timeout
public OnGameFrame()
{
	static Float:player_time[MAXPLAYERS+1];
	static i;
	for (i = 1; i < MaxClients; i++)
	{
		if (i > 0 && IsClientInGame(i) && !IsFakeClient(i))
		{
			if (IsClientTimingOut(i))
			{
				if (player_time[i])
				{
					// timed out
					if ((GetGameTime() - player_time[i]) >= g_fInterval)
					{
						KickClient(i, "%N crashed from server!", i);
						player_time[i] = 0.0;
						//PrintToServer("Kicking timed out player: %N ", i);
						LogToGame("Kicking timed out player: %N ", i);
					}
				}
				else
				{
					player_time[i] = GetGameTime();
				}
			}
			else if (player_time[i])
			{
				player_time[i] = 0.0;
			}
		}
	}
}  
*/

// Check and inform player status
public Action:Timer_PlayerStatus(Handle:Timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client) && playerPickSquad[client] == 1)
		{
			new team = GetClientTeam(client);
			g_plyrGrenScreamCoolDown[client]--;
			if (g_plyrGrenScreamCoolDown[client] <= 0)
				g_plyrGrenScreamCoolDown[client] = 0;

			g_plyrFireScreamCoolDown[client]--;
			if (g_plyrFireScreamCoolDown[client] <= 0)
				g_plyrFireScreamCoolDown[client] = 0;

			if (g_iPlayerRespawnTimerActive[client] == 0 && !IsPlayerAlive(client) && !IsClientTimingOut(client) && IsClientObserver(client) && team == TEAM_1 && g_iEnableRevive == 1 && g_iRoundStatus == 1) //
			{
				// Player connected or changed squad
				if (g_iHurtFatal[client] == -1)
				{
					PrintCenterText(client, "You changed your role in the squad. You can no longer be revived and must wait til next respawn!");
				}

				new String:woundType[128];
				woundType = "WOUNDED";
				if (g_playerWoundType[client] == 0)
					woundType = "MINORLY WOUNDED";
				else if (g_playerWoundType[client] == 1)
					woundType = "MODERATELY WOUNDED";
				else if (g_playerWoundType[client] == 2)
					woundType = "CRITCALLY WOUNDED";

				if (!g_iCvar_respawn_enable || g_iRespawnCount[2] == -1 || g_iSpawnTokens[client] <= 0)
				{
					// Player was killed fatally
					if (g_iHurtFatal[client] == 1)
					{
						decl String:fatal_hint[255];
						Format(fatal_hint, 255,"You were fatally killed for %i damage and must wait til next objective to spawn (out of lives)", g_clientDamageDone[client]);
						PrintCenterText(client, "%s", fatal_hint);
					}
					// Player was killed
					else if (g_iHurtFatal[client] == 0 && !Ins_InCounterAttack())
					{
						decl String:wound_hint[255];
						Format(wound_hint, 255,"[You're %s for %d damage]..wait patiently for a medic..do NOT mic/chat spam! (out of lives)", woundType, g_clientDamageDone[client]);
						PrintCenterText(client, "%s", wound_hint);
					}
					// Player was killed during counter attack
					else if (g_iHurtFatal[client] == 0 && Ins_InCounterAttack())
					{
						decl String:wound_hint[255];
						Format(wound_hint, 255,"You're %s during a Counter-Attack for %d damage..if its close to ending..dont bother asking for a medic! (out of lives)", woundType, g_clientDamageDone[client]);
						PrintCenterText(client, "%s", wound_hint);
					}
				}
			}
		}
	}
}

// Announce enemies remaining
public Action:Timer_Enemies_Remaining(Handle:Timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Check enemy count
	new alive_insurgents;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && IsFakeClient(i))
		{
			alive_insurgents++;
		}
	}
	// Announce
	decl String:textToPrintChat[64];
	decl String:textToPrint[64];
	Format(textToPrintChat, sizeof(textToPrintChat), "Enemies alive: %d | Enemy reinforcements remaining: %d", alive_insurgents, g_iRemaining_lives_team_ins);
	Format(textToPrint, sizeof(textToPrint), "Enemies alive: %d | Enemy reinforcements remaining: %d", alive_insurgents ,g_iRemaining_lives_team_ins);
	PrintHintTextToAll(textToPrint);
	PrintToChatAll(textToPrintChat);
	
	return Plugin_Continue;
}

// This timer reinforces bot team if you do not capture point
public Action:Timer_EnemyReinforce(Handle:Timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	new iReinforce_multiplier = GetConVarInt(sm_respawn_reinforce_multiplier);
	new iReinforce_multiplier_base = GetConVarInt(sm_respawn_reinforce_multiplier_base);
	
	// Retrive config
	new reinforce_time_subsequent = GetConVarInt(sm_respawn_reinforce_time_subsequent);
	
	// Check enemy remaining
	if (g_iRemaining_lives_team_ins <= (g_iRespawn_lives_team_ins / iReinforce_multiplier) + iReinforce_multiplier_base)
	{
		g_iReinforceTime = g_iReinforceTime - 1;
		
		// Announce every 10 seconds
		if (g_iReinforceTime % 10 == 0 && g_iReinforceTime > 10)
		{
			decl String:textToPrintChat[64];
			decl String:textToPrint[64];
			Format(textToPrintChat, sizeof(textToPrintChat), "Friendlies spawn on Counter-Attacks, Capture the Point!");
			if (g_isHunt == 1)
				Format(textToPrint, sizeof(textToPrint), "Enemies reinforce in %d seconds | Kill remaining/blow cache!", g_iReinforceTime);
			else
				Format(textToPrint, sizeof(textToPrint), "Enemies reinforce in %d seconds | Capture the point soon!", g_iReinforceTime);

			PrintHintTextToAll(textToPrint);
			if (g_iReinforceTime <= 60)
			{
				PrintToChatAll(textToPrint);
			}
		}
		// Anncount every 1 second
		if (g_iReinforceTime <= 10)
		{
			decl String:textToPrintChat[64];
			decl String:textToPrint[64];
			Format(textToPrintChat, sizeof(textToPrintChat), "Friendlies spawn on Counter-Attacks, Capture the Point!");
			if (g_isHunt == 1)
				Format(textToPrint, sizeof(textToPrint), "Enemies reinforce in %d seconds | Kill remaining/blow cache!", g_iReinforceTime);
			else
				Format(textToPrint, sizeof(textToPrint), "Enemies reinforce in %d seconds | Capture the point soon!", g_iReinforceTime);

			PrintHintTextToAll(textToPrint);
			//PrintToChatAll(textToPrintChat);
		}
		// Process reinforcement
		if (g_iReinforceTime <= 0)
		{
			// If enemy reinforcement is not over, add it
			if (g_iRemaining_lives_team_ins > 0)
			{

				decl String:textToPrint[64];
				//Only add more reinforcements if under certain amount so its not endless.
				if (g_iRemaining_lives_team_ins < (g_iRespawn_lives_team_ins / iReinforce_multiplier) + iReinforce_multiplier_base)
				{
					// Get bot count
					new iBotCount = GetTeamInsCount();
					// Add bots	
					g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + iBotCount;
					Format(textToPrint, sizeof(textToPrint), "Enemy Reinforcements Added to Existing Reinforcements!");
					PrintHintTextToAll(textToPrint);
					g_iReinforceTime = reinforce_time_subsequent;
					if (g_isHunt == 1)
						 g_iReinforceTime = reinforce_time_subsequent * iReinforce_multiplier;
					//if (g_huntCacheDestroyed == true && g_isHunt == 1)
					//	 g_iReinforceTime = g_iReinforceTime + g_huntReinforceCacheAdd;
					// Add bots
					for (new client = 1; client <= MaxClients; client++)
					{
						if (client > 0 && IsClientInGame(client))
						{
							new m_iTeam = GetClientTeam(client);
							if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2)
							{
								g_iRemaining_lives_team_ins++;
								g_iReinforceTime = reinforce_time_subsequent;
								CreateBotRespawnTimer(client);
							}
						}
					}

				}
				else
				{
					Format(textToPrint, sizeof(textToPrint), "Enemy Reinforcements at Maximum Capacity");
					PrintHintTextToAll(textToPrint);

					// Reset reinforce time
					new reinforce_time = GetConVarInt(sm_respawn_reinforce_time);
					g_iReinforceTime = reinforce_time;
					if (g_isHunt == 1)
						 g_iReinforceTime = reinforce_time * iReinforce_multiplier;
					//if (g_huntCacheDestroyed == true && g_isHunt == 1)
					//	g_iReinforceTime = g_iReinforceTime + g_huntReinforceCacheAdd;
				}

			}
			// Respawn enemies
			else
			{
				// Get bot count
				new minBotCount = (g_iRespawn_lives_team_ins / 8);
				g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;
				
				// Add bots
				for (new client = 1; client <= MaxClients; client++)
				{
					if (client > 0 && IsClientInGame(client))
					{
						new m_iTeam = GetClientTeam(client);
						if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2)
						{
							g_iRemaining_lives_team_ins++;
							g_iReinforceTime = reinforce_time_subsequent;
							CreateBotRespawnTimer(client);
						}
					}
				}
				// Get random duration
				//new fRandomInt = GetRandomInt(1, 4);
				
				decl String:textToPrint[64];
				Format(textToPrint, sizeof(textToPrint), "Enemy Reinforcements Have Arrived!");
				PrintHintTextToAll(textToPrint);
			}
		}
	}
	
	return Plugin_Continue;
}


// Check enemy is stuck
public Action:Timer_CheckEnemyStatic(Handle:Timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	if (Ins_InCounterAttack())
	{
		g_checkStaticAmtCntr = g_checkStaticAmtCntr - 1;
		if (g_checkStaticAmtCntr <= 0)
		{
			for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
			{	
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot))
				{
					new m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2)
					{
						// Get current position
						decl Float:enemyPos[3];
						GetClientAbsOrigin(enemyBot, Float:enemyPos);
						
						// Get distance
						new Float:tDistance;
						new Float:capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerPos[enemyBot]);
						if (g_isCheckpoint == 1)
						{
							new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos,m_vCPPositions[m_nActivePushPointIndex]);
						}
						else 
							capDistance = 801;
						// If enemy position is static, kill him
						if (tDistance <= 4 && (capDistance > 800 || g_botStaticGlobal[enemyBot] > 120)) 
						{
							//PrintToServer("ENEMY STATIC - KILLING");
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
						}
						// Update current position
						else
						{
							g_enemyTimerPos[enemyBot] = enemyPos;
							g_botStaticGlobal[enemyBot]++;
						}
					}
				}
			}
			g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
		}
	}
	else
	{
		g_checkStaticAmt = g_checkStaticAmt - 1;
		if (g_checkStaticAmt <= 0)
		{
			for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
			{	
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot))
				{
					new m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2)
					{
						// Get current position
						decl Float:enemyPos[3];
						GetClientAbsOrigin(enemyBot, Float:enemyPos);
						
						// Get distance
						new Float:tDistance;
						new Float:capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerPos[enemyBot]);
						//Check point distance
						if (g_isCheckpoint == 1)
						{
							new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos,m_vCPPositions[m_nActivePushPointIndex]);
						}
						else 
							capDistance = 801;
						// If enemy position is static, kill him
						if (tDistance <= 4 && (capDistance > 800))// || g_botStaticGlobal[enemyBot] > 120)) 
						{
							//PrintToServer("ENEMY STATIC - KILLING");
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
						}
						// Update current position
						else
						{ 
							g_enemyTimerPos[enemyBot] = enemyPos;
							//g_botStaticGlobal[enemyBot]++;
						}
					}
				}
			}
			g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy); 
		}
	}
	
	return Plugin_Continue;
}
// Check enemy is stuck
public Action:Timer_CheckEnemyAway(Handle:Timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	if (Ins_InCounterAttack())
	{
		g_checkStaticAmtCntrAway = g_checkStaticAmtCntrAway - 1;
		if (g_checkStaticAmtCntrAway <= 0)
		{
			for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
			{	
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot))
				{
					new m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2)
					{
						// Get current position
						decl Float:enemyPos[3];
						GetClientAbsOrigin(enemyBot, Float:enemyPos);
						
						// Get distance
						new Float:tDistance;
						new Float:capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerAwayPos[enemyBot]);
						if (g_isCheckpoint == 1)
						{
							new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos,m_vCPPositions[m_nActivePushPointIndex]);
						}
						else 
							capDistance = 801;
						// If enemy position is static, kill him
						if (tDistance <= 150 && capDistance > 1000) 
						{
							//PrintToServer("ENEMY STATIC - KILLING");
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
						}
						// Update current position
						else
						{
							g_enemyTimerAwayPos[enemyBot] = enemyPos;
						}
					}
				}
			}
			g_checkStaticAmtCntrAway = 12;
		}
	}
	else
	{
		g_checkStaticAmtAway = g_checkStaticAmtAway - 1;
		if (g_checkStaticAmtAway <= 0)
		{
			for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
			{	
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot))
				{
					new m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2)
					{
						// Get current position
						decl Float:enemyPos[3];
						GetClientAbsOrigin(enemyBot, Float:enemyPos);
						
						// Get distance
						new Float:tDistance;
						new Float:capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerAwayPos[enemyBot]);
						//Check point distance
						if (g_isCheckpoint == 1)
						{
							new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos,m_vCPPositions[m_nActivePushPointIndex]);
						}
						// If enemy position is static, kill him
						if (tDistance <= 150 && capDistance > 1200) 
						{
							//PrintToServer("ENEMY STATIC - KILLING");
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
						}
						// Update current position
						else
						{ 
							g_enemyTimerAwayPos[enemyBot] = enemyPos;
						}
					}
				}
			}
			g_checkStaticAmtAway = 30; 
		}
	}
	
	return Plugin_Continue;
}
void AddLifeForStaticKilling(client)
{
	// Respawn type 1
	new team = GetClientTeam(client);
	if (g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2 && g_iRespawn_lives_team_ins > 0)
	{
		g_iSpawnTokens[client]++;
	}
	else if (g_iCvar_respawn_type_team_ins == 2 && team == TEAM_2 && g_iRespawn_lives_team_ins > 0)
	{
		g_iRemaining_lives_team_ins++;
	}
}

// Monitor player's gear
public Action:Timer_GearMonitor(Handle:Timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (client > 0 && IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client) && !IsClientObserver(client))
		{
		   if (g_iEnableRevive == 1 && g_iRoundStatus == 1 && g_iCvar_enable_track_ammo == 1)
			{	   
				GetPlayerAmmo(client);
			}
		}
	}
}

// Update player's gear
void SetPlayerAmmo(client)
{
	if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
	{
		//PrintToServer("SETWEAPON ########");
		new primaryWeapon = GetPlayerWeaponSlot(client, 0);
		new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
		new playerGrenades = GetPlayerWeaponSlot(client, 3);
		//Lets get weapon classname, we need this to create weapon entity if primary does not fit secondary
		//Make sure IsValidEntity is not only for entities
		//decl String:weaponClassname[32];
		// if (secondaryWeapon != playerSecondary[client] && playerSecondary[client] != -1 && IsValidEntity(playerSecondary[client]))
		// {
		// 	GetEdictClassname(playerSecondary[client], weaponClassname, sizeof(weaponClassname));
		// 	RemovePlayerItem(client,secondaryWeapon);
		// 	AcceptEntityInput(secondaryWeapon, "kill");
		// 	GivePlayerItem(client, weaponClassname);
		// 	secondaryWeapon = playerSecondary[client];
		// }
		// if (primaryWeapon != playerPrimary[client] && playerPrimary[client] != -1 && IsValidEntity(playerPrimary[client]))
		// {
		// 	GetEdictClassname(playerPrimary[client], weaponClassname, sizeof(weaponClassname));
		// 	RemovePlayerItem(client,primaryWeapon);
		// 	AcceptEntityInput(primaryWeapon, "kill");
		// 	GivePlayerItem(client, weaponClassname);
		// 	EquipPlayerWeapon(client, playerPrimary[client]); 
		// 	primaryWeapon = playerPrimary[client];
		// }
		
		// Check primary weapon
		if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
		{
			//PrintToServer("PlayerClip %i, playerAmmo %i, PrimaryWeapon %d",playerClip[client][0],playerAmmo[client][0], primaryWeapon); 
			SetPrimaryAmmo(client, primaryWeapon, playerClip[client][0], 0); //primary clip
			//SetWeaponAmmo(client, primaryWeapon, playerAmmo[client][0], 0); //primary
			//PrintToServer("SETWEAPON 1");
		}
		
		// Check secondary weapon
		if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
		{
			//PrintToServer("PlayerClip %i, playerAmmo %i, PrimaryWeapon %d",playerClip[client][1],playerAmmo[client][1], primaryWeapon); 
			SetPrimaryAmmo(client, secondaryWeapon, playerClip[client][1], 1); //secondary clip
			//SetWeaponAmmo(client, secondaryWeapon, playerAmmo[client][1], 1); //secondary
			//PrintToServer("SETWEAPON 2");
		}
		
		// Check grenades
		if (playerGrenades != -1 && IsValidEntity(playerGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
		{
			while (playerGrenades != -1 && IsValidEntity(playerGrenades)) // since we only have 3 slots in current theate
			{
				playerGrenades = GetPlayerWeaponSlot(client, 3);
				if (playerGrenades != -1 && IsValidEntity(playerGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 1
				{
					// Remove grenades but not pistols
					decl String:weapon[32];
					GetEntityClassname(playerGrenades, weapon, sizeof(weapon));
					RemovePlayerItem(client,playerGrenades);
					AcceptEntityInput(playerGrenades, "kill");
					
				}
			}
			
			/*
			If we need to track grenades (since they drop them on death, its a no)
			SetGrenadeAmmo(client, Gren_M67, playerGrenadeType[client][0]);
			SetGrenadeAmmo(client, Gren_Incen, playerGrenadeType[client][1]);
			SetGrenadeAmmo(client, Gren_Molot, playerGrenadeType[client][2]);
			SetGrenadeAmmo(client, Gren_M18, playerGrenadeType[client][3]);
			SetGrenadeAmmo(client, Gren_Flash, playerGrenadeType[client][4]);
			SetGrenadeAmmo(client, Gren_F1, playerGrenadeType[client][5]);
			SetGrenadeAmmo(client, Gren_IED, playerGrenadeType[client][6]);
			SetGrenadeAmmo(client, Gren_C4, playerGrenadeType[client][7]);
			SetGrenadeAmmo(client, Gren_AT4, playerGrenadeType[client][8]);
			SetGrenadeAmmo(client, Gren_RPG7, playerGrenadeType[client][9]);
			*/
			//PrintToServer("SETWEAPON 3");
		}
		if (!IsFakeClient(client))
			playerRevived[client] = false;
	}
}
// Retrive player's gear
void GetPlayerAmmo(client)
{
	if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
	{
		//CONSIDER IF PLAYER CHOOSES DIFFERENT CLASS
		new primaryWeapon = GetPlayerWeaponSlot(client, 0);
		new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
		//new playerGrenades = GetPlayerWeaponSlot(client, 3);

		playerPrimary[client] = primaryWeapon;
		playerSecondary[client] = secondaryWeapon;
		//Get ammo left in clips for primary and secondary
		playerClip[client][0] = GetPrimaryAmmo(client, primaryWeapon, 0);
		playerClip[client][1] = GetPrimaryAmmo(client, secondaryWeapon, 1); // m_iClip2 for secondary if this doesnt work? would need GetSecondaryAmmo
		//Get Magazines left on player
		if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
			playerAmmo[client][0] = GetWeaponAmmo(client, primaryWeapon, 0); //primary
		if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
			playerAmmo[client][1] = GetWeaponAmmo(client, secondaryWeapon, 1); //secondary	
		/*
		if (playerGrenades != -1 && IsValidEntity(playerGrenades))
		{
			 //PrintToServer("[GEAR] CLIENT HAS VALID GRENADES");
			 playerGrenadeType[client][0] = GetGrenadeAmmo(client, Gren_M67);
			 playerGrenadeType[client][1] = GetGrenadeAmmo(client, Gren_Incen);
			 playerGrenadeType[client][2] = GetGrenadeAmmo(client, Gren_Molot);
			 playerGrenadeType[client][3] = GetGrenadeAmmo(client, Gren_M18);
			 playerGrenadeType[client][4] = GetGrenadeAmmo(client, Gren_Flash);
			 playerGrenadeType[client][5] = GetGrenadeAmmo(client, Gren_F1);
			 playerGrenadeType[client][6] = GetGrenadeAmmo(client, Gren_IED);
			 playerGrenadeType[client][7] = GetGrenadeAmmo(client, Gren_C4);
			 playerGrenadeType[client][8] = GetGrenadeAmmo(client, Gren_AT4);
			 playerGrenadeType[client][9] = GetGrenadeAmmo(client, Gren_RPG7);
		}
		*/
		//PrintToServer("G: %i, G: %i, G: %i, G: %i, G: %i, G: %i, G: %i, G: %i, G: %i, G: %i",playerGrenadeType[client][0], playerGrenadeType[client][1], playerGrenadeType[client][2],playerGrenadeType[client][3],playerGrenadeType[client][4],playerGrenadeType[client][5],playerGrenadeType[client][6],playerGrenadeType[client][7],playerGrenadeType[client][8],playerGrenadeType[client][9]); 
	}
}

/*
#####################################################################
#####################################################################
#####################################################################
# Jballous INS_SPAWNPOINT SPAWNING START ############################
# Jballous INS_SPAWNPOINT SPAWNING START ############################
#####################################################################
#####################################################################
#####################################################################
*/
stock GetInsSpawnGround(spawnPoint, Float:vecSpawn[3])
{
    new Float:fGround[3];
    vecSpawn[2] += 15.0;
    
    TR_TraceRayFilter(vecSpawn, Float:{90.0,0.0,0.0}, MASK_PLAYERSOLID, RayType_Infinite, TRDontHitSelf, spawnPoint);
    if (TR_DidHit())
    {
        TR_GetEndPosition(fGround);
        return fGround;
    }
    return vecSpawn;
}
stock GetClientGround(client)
{
    
    new Float:fOrigin[3], Float:fGround[3];
	GetClientAbsOrigin(client,fOrigin);

    fOrigin[2] += 15.0;
    
    TR_TraceRayFilter(fOrigin, Float:{90.0,0.0,0.0}, MASK_PLAYERSOLID, RayType_Infinite, TRDontHitSelf, client);
    if (TR_DidHit())
    {
        TR_GetEndPosition(fGround);
        fOrigin[2] -= 15.0;
        return fGround[2];
    }
    return 0.0;
}
 
CheckSpawnPoint(Float:vecSpawn[3],client,Float:tObjectiveDistance) {
//Ins_InCounterAttack
	new m_iTeam = GetClientTeam(client);
	new Float:distance,Float:furthest,Float:closest=-1.0;
	new Float:vecOrigin[3];
	GetClientAbsOrigin(client,vecOrigin);
	//Update player spawns before we check against them
	UpdatePlayerOrigins();
	//Lets go through checks to find a valid spawn point
	for (new iTarget = 1; iTarget < MaxClients; iTarget++) {
		if (!IsValidClient(iTarget))
			continue;
		if (!IsClientInGame(iTarget))
			continue;
		if (!IsPlayerAlive(iTarget)) 
			continue;
		new tTeam = GetClientTeam(iTarget);
		if (tTeam != TEAM_1)
			continue;
		////InsLog(DEBUG, "Distance from %N to iSpot %d is %f",iTarget,iSpot,distance);
		distance = GetVectorDistance(vecSpawn,g_vecOrigin[iTarget]);
		if (distance > furthest)
			furthest = distance;
		if ((distance < closest) || (closest < 0))
			closest = distance;
		
		if (GetClientTeam(iTarget) != m_iTeam) {
			// If we are too close
			if (distance < g_flMinPlayerDistance) {
				 return 0;
			}
			// If the player can see the spawn point (divided CanSeeVector to slightly reduce strictness)
			//(IsVectorInSightRange(iTarget, vecSpawn, 120.0)) ||  / g_flCanSeeVectorMultiplier
			if (ClientCanSeeVector(iTarget, vecSpawn, (g_flMinPlayerDistance * g_flCanSeeVectorMultiplier))) {
				return 0; 
			}
		}
	}
	//If any player is too far
	if (closest > g_flMaxPlayerDistance) {
		return 0; 
	}
	//Spawns dynamic

	new fRandomFloat = GetRandomFloat(0, 1.0);
	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	
	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	//Check last point
	if ((acp+1) == ncp)
		m_nActivePushPointIndex--;

	Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
	distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
	if (distance > tObjectiveDistance) {// && (fRandomFloat <= g_dynamicSpawn_Perc)) {
		 return 0;
	} 
	else if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult)) {
		 return 0;
	}

	
	// Check distance to point in counterattack
	// if (Ins_InCounterAttack() && ((acp+1) == ncp)) {
	// 	new m_nActivePushPointIndex2 = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// 	Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex2],m_nActivePushPointIndex2);
	// 	distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex2]);
	// 	if (distance < g_flMinCounterattackDistance) {
	// 		 return 0;
	// 	}
	// // 	if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult) && (fRandomFloat <= g_dynamicSpawnCounter_Perc)) {
	// // 		 return 0;

	// // 	} 
	// // 	else if (distance > tObjectiveDistance) {
	// // 		 return 0;
	// // 	}
	//  }		
	return 1;
} 
CheckSpawnPointPlayers(Float:vecSpawn[3],client) {
//Ins_InCounterAttack
	new m_iTeam = GetClientTeam(client);
	new Float:distance,Float:furthest,Float:closest=-1.0;
	new Float:vecOrigin[3];
	GetClientAbsOrigin(client,vecOrigin);
	//Update player spawns before we check against them
	UpdatePlayerOrigins();
	//Lets go through checks to find a valid spawn point
	for (new iTarget = 1; iTarget < MaxClients; iTarget++) {
		if (!IsValidClient(iTarget))
			continue;
		if (!IsClientInGame(iTarget))
			continue;
		if (!IsPlayerAlive(iTarget)) 
			continue;
		new tTeam = GetClientTeam(iTarget);
		if (tTeam != TEAM_1)
			continue;
		////InsLog(DEBUG, "Distance from %N to iSpot %d is %f",iTarget,iSpot,distance);
		distance = GetVectorDistance(vecSpawn,g_vecOrigin[iTarget]);
		if (distance > furthest)
			furthest = distance;
		if ((distance < closest) || (closest < 0))
			closest = distance;
		
		if (GetClientTeam(iTarget) != m_iTeam) {
			// If we are too close
			if (distance < g_flMinPlayerDistance) {
				 return 0;
			}
			// If the player can see the spawn point (divided CanSeeVector to slightly reduce strictness)
			//(IsVectorInSightRange(iTarget, vecSpawn, 120.0)) ||  / g_flCanSeeVectorMultiplier
			if (ClientCanSeeVector(iTarget, vecSpawn, (g_flMinPlayerDistance * g_flCanSeeVectorMultiplier))) {
				return 0; 
			}
		}
	}

	//If any player is too far
	if (closest > g_flMaxPlayerDistance) {
		return 0; 
	}

	// new fRandomFloat = GetRandomFloat(0, 1.0);
	// // Check distance to point in counterattack
	// if (Ins_InCounterAttack()) {
	// 	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// 	Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
	// 	distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
		
	// 	if (distance < g_flMinCounterattackDistance) {
	// 		 return 0;
	// 	}
	// 	if (distance > (g_flMaxObjectiveDistance * g_DynamicRespawn_Distance_mult) && (fRandomFloat <= g_dynamicSpawnCounter_Perc)) {
	// 		 return 0;

	// 	} 
	// 	else if (distance > g_flMaxObjectiveDistance) { 
	// 		 return 0;
	// 	}
		
		
	// }
	return 1;
}
float GetSpawnPoint_SpawnPoint(client) {
	int m_iTeam = GetClientTeam(client);
	int m_iTeamNum;
	float vecSpawn[3];
	float vecOrigin[3];
	GetClientAbsOrigin(client,vecOrigin);
	new point = FindEntityByClassname(-1, "ins_spawnpoint");
	new Float:tObjectiveDistance = g_flMaxObjectiveDistance;
	while (point != -1) {
		// Check to make sure it is the same team
		m_iTeamNum = GetEntProp(point, Prop_Send, "m_iTeamNum");
		if (m_iTeamNum == m_iTeam) {
			GetEntPropVector(point, Prop_Send, "m_vecOrigin", vecSpawn);
			if (CheckSpawnPoint(vecSpawn,client,tObjectiveDistance)) {
				vecSpawn = GetInsSpawnGround(point, vecSpawn);
				new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
				Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
				new Float:distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
				PrintToServer("FOUND! %N (%d) spawnpoint %d Distance: %f tObjectiveDistance: %f g_flMaxObjectiveDistance %f at (%f, %f, %f)", client, client, point, distance, tObjectiveDistance, g_flMaxObjectiveDistance, vecSpawn[0], vecSpawn[1], vecSpawn[2]);
				return vecSpawn;
			}
			else
			{
				tObjectiveDistance = tObjectiveDistance + 2.0;
			}
		}
		point = FindEntityByClassname(point, "ins_spawnpoint");
	}
	PrintToServer("1st Pass: Could not find acceptable ins_spawnzone for %N (%d)", client, client);
	//Lets try again but wider range
	new point2 = FindEntityByClassname(-1, "ins_spawnpoint");
	tObjectiveDistance = ((g_flMaxObjectiveDistance + 100) * 2);
	while (point2 != -1) {
		// Check to make sure it is the same team
		m_iTeamNum = GetEntProp(point2, Prop_Send, "m_iTeamNum");
		if (m_iTeamNum == m_iTeam) {
			GetEntPropVector(point2, Prop_Send, "m_vecOrigin", vecSpawn);
			if (CheckSpawnPoint(vecSpawn,client,tObjectiveDistance)) {
				vecSpawn = GetInsSpawnGround(point2, vecSpawn);
				new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
				Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
				new Float:distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
				PrintToServer("FOUND! %N (%d) spawnpoint %d Distance: %f tObjectiveDistance: %f g_flMaxObjectiveDistance %f at (%f, %f, %f)", client, client, point2, distance, tObjectiveDistance, g_flMaxObjectiveDistance, vecSpawn[0], vecSpawn[1], vecSpawn[2]);
				return vecSpawn;
			}
			else
			{
				tObjectiveDistance = tObjectiveDistance + 2.0;
			}
		}
		point2 = FindEntityByClassname(point2, "ins_spawnpoint");
	}
	PrintToServer("2nd Pass: Could not find acceptable ins_spawnzone for %N (%d)", client, client);
	//Lets try again but wider range
	new point3 = FindEntityByClassname(-1, "ins_spawnpoint");
	tObjectiveDistance = ((g_flMaxObjectiveDistance + 100) * 3);
	while (point3 != -1) {
		// Check to make sure it is the same team
		m_iTeamNum = GetEntProp(point3, Prop_Send, "m_iTeamNum");
		if (m_iTeamNum == m_iTeam) {
			GetEntPropVector(point3, Prop_Send, "m_vecOrigin", vecSpawn);
			if (CheckSpawnPoint(vecSpawn,client,tObjectiveDistance)) {
				vecSpawn = GetInsSpawnGround(point3, vecSpawn);
				new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
				Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
				new Float:distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
				PrintToServer("FOUND! %N (%d) spawnpoint %d Distance: %f tObjectiveDistance: %f g_flMaxObjectiveDistance %f at (%f, %f, %f)", client, client, point3, distance, tObjectiveDistance, g_flMaxObjectiveDistance, vecSpawn[0], vecSpawn[1], vecSpawn[2]);
				return vecSpawn;
			}
			else
			{
				tObjectiveDistance = tObjectiveDistance + 2.0;
			}
		}
		point3 = FindEntityByClassname(point3, "ins_spawnpoint");
	}
	PrintToServer("3rd Pass: Could not find acceptable ins_spawnzone for %N (%d)", client, client);
	return vecOrigin;
}
float GetSpawnPoint(client) {
	new Float:vecSpawn[3];
/*
	if ((g_iHidingSpotCount) && (g_iSpawnMode == _:SpawnMode_HidingSpots)) {
		vecSpawn = GetSpawnPoint_HidingSpot(client);
	} else {
*/
	vecSpawn = GetSpawnPoint_SpawnPoint(client);
//	}
	//InsLog(DEBUG, "Could not find spawn point for %N (%d)", client, client);
	return vecSpawn;
}
//Lets begin to find a valid spawnpoint after spawned
public TeleportClient(client) {
	new Float:vecSpawn[3];
	vecSpawn = GetSpawnPoint(client);

	//decl FLoat:ClientGroundPos;
	//ClientGroundPos = GetClientGround(client);
	//vecSpawn[2] = ClientGroundPos;
	TeleportEntity(client, vecSpawn, NULL_VECTOR, NULL_VECTOR);
	SetNextAttack(client);
}
public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	//Redirect all bot spawns
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//For first joining players 
	if (g_playerFirstJoin[client] == 1 && !IsFakeClient(client))
	{
		g_playerFirstJoin[client] = 0;
		// Get SteamID to verify is player has connected before.
		decl String:steamId[64];
		//GetClientAuthString(client, steamId, sizeof(steamId));
		GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
		new isPlayerNew = FindStringInArray(g_playerArrayList, steamId);

		if (isPlayerNew == -1)
		{
			PushArrayString(g_playerArrayList, steamId);
			PrintToServer("SPAWN: Player %N is new! | SteamID: %s | PlayerArrayList Size: %d", client, steamId, GetArraySize(g_playerArrayList));
		}
	}
	if (!g_iCvar_respawn_enable) {
		return Plugin_Continue;
	}
	if (!IsClientConnected(client)) {
		return Plugin_Continue;
	}
	if (!IsClientInGame(client)) {
		return Plugin_Continue;
	}
	if (!IsValidClient(client)) {
		return Plugin_Continue;
	}
	if (!IsFakeClient(client)) {
		return Plugin_Continue;
	}
	if (g_isCheckpoint == 0) {
		return Plugin_Continue;
	}
	
	//Reset this global timer everytime a bot spawns
	g_botStaticGlobal[client] = 0;

	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	new Float:vecOrigin[3];
	GetClientAbsOrigin(client,vecOrigin);
	if  (g_playersReady && g_botsReady == 1)
	{
		int iCanSpawn = CheckSpawnPointPlayers(vecOrigin,client);
		new fRandomFloat = GetRandomFloat(0, 1.0);
		//InsLog(DEBUG, "Event_Spawn iCanSpawn %d", iCanSpawn);
		if (!iCanSpawn && (!Ins_InCounterAttack() || (acp+1) == ncp)) { // && (!Ins_InCounterAttack() || fRandomFloat < 0.1)) {

			TeleportClient(client);
			if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && IsClientConnected(client))
			{
				StuckCheck[client] = 0;
				StartStuckDetection(client);
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_SpawnPost(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	////InsLog(DEBUG, "Event_Spawn called");
	if (!IsFakeClient(client)) {
		return Plugin_Continue;
	}
	SetNextAttack(client);
	new Float:fRandom = GetRandomFloat(0.0, 1.0);

	// Check grenades
	if (fRandom >= 0.5)
	{
		new botGrenades = GetPlayerWeaponSlot(client, 3);
		if (botGrenades != -1 && IsValidEntity(botGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
		{
			while (botGrenades != -1 && IsValidEntity(botGrenades)) // since we only have 3 slots in current theate
			{
				botGrenades = GetPlayerWeaponSlot(client, 3);
				if (botGrenades != -1 && IsValidEntity(botGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 1
				{
					// Remove grenades but not pistols
					decl String:weapon[32];
					GetEntityClassname(botGrenades, weapon, sizeof(weapon));
					RemovePlayerItem(client,botGrenades);
					AcceptEntityInput(botGrenades, "kill");
				}
			}
		}
	}
	if (!g_iCvar_respawn_enable) {
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public UpdatePlayerOrigins() {
	for (new i = 1; i < MaxClients; i++) {
		if (IsValidClient(i)) {
			GetClientAbsOrigin(i,g_vecOrigin[i]);
		}
	}
}
//This delays bot from attacking once spawned
SetNextAttack(client) {
	float flTime = GetGameTime();
	float flDelay = g_flSpawnAttackDelay;

// Loop through entries in m_hMyWeapons.
	for(new offset = 0; offset < 128; offset += 4) {
		new weapon = GetEntDataEnt2(client, m_hMyWeapons + offset);
		if (weapon < 0) {
			continue;
		}
//		//InsLog(DEBUG, "SetNextAttack weapon %d", weapon);
		SetEntDataFloat(weapon, m_flNextPrimaryAttack, flTime + flDelay);
		SetEntDataFloat(weapon, m_flNextSecondaryAttack, flTime + flDelay);
	}
}
/*
#####################################################################
#####################################################################
#####################################################################
# Jballous INS_SPAWNPOINT SPAWNING END ##############################
# Jballous INS_SPAWNPOINT SPAWNING END ##############################
#####################################################################
#####################################################################
#####################################################################
*/


/*
#####################################################################
# NAV MESH BOT SPAWNS FUNCTIONS START ###############################
# NAV MESH BOT SPAWNS FUNCTIONS START ###############################
#####################################################################
*/

/*
// Check whether current bot position or given hiding point is best position to spawn
int CheckHidingSpotRules(m_nActivePushPointIndex, iCPHIndex, iSpot, client)
{
	// Get Team
	new m_iTeam = GetClientTeam(client);
	
	// Init variables
	new Float:distance,Float:furthest,Float:closest=-1.0,Float:flHidingSpot[3];
	new Float:vecOrigin[3];
	new needSpawn = 0;
	
	// Get current position
	GetClientAbsOrigin(client,vecOrigin);
	
	// Get current hiding point
	flHidingSpot[0] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_X);
	flHidingSpot[1] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_Y);
	flHidingSpot[2] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_Z);
	// new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// distance = GetVectorDistance(flHidingSpot,m_vCPPositions[m_nActivePushPointIndex]);
	// if (distance > g_flMaxObjectiveDistanceNav) {
	// 	return 0;
	// } 
	// Check players
	for (new iTarget = 1; iTarget < MaxClients; iTarget++)
	{
		if (!IsClientInGame(iTarget) || !IsClientConnected(iTarget))
			continue;
		
		// Get distance from player
		distance = GetVectorDistance(flHidingSpot,g_fPlayerPosition[iTarget]);
		//PrintToServer("[BOTSPAWNS] Distance from %N to iSpot %d is %f",iTarget,iSpot,distance);
		
		// Check distance from player
		if (GetClientTeam(iTarget) != m_iTeam)
		{
			// If player is furthest, update furthest variable
			if (distance > furthest)
				furthest = distance;
			
			// If player is closest, update closest variable
			if ((distance < closest) || (closest < 0))
				closest = distance;
			// If any player is close enough to telefrag
			// if (distance < g_flMinPlayerDistance) {
			// 	 //PrintToServer("DEBUG 1"); return 0;
			// }
			// If the distance is shorter than cvarMinPlayerDistance
			//(IsVectorInSightRange(iTarget, flHidingSpot, 120.0, g_flMinPlayerDistance)) || 
			if (((ClientCanSeeVector(iTarget, flHidingSpot, (g_flMaxPlayerDistance)))))
			{
				//PrintToServer("[BOTSPAWNS] Cannot spawn %N at iSpot %d since it is in sight of %N",client,iSpot,iTarget);
				return 0;
			}
		}
	}
	
	// If closest player is further than cvarMaxPlayerDistance
	if (closest > g_flMaxPlayerDistance)
	{
		//PrintToServer("[BOTSPAWNS] iSpot %d is too far from nearest player distance %f",iSpot,closest);
		return 0;
	}
	
	
	// During counter attack
	// if (Ins_InCounterAttack()) {
	// 	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// 	distance = GetVectorDistance(flHidingSpot,m_vCPPositions[m_nActivePushPointIndex]);
	// 	if (distance < g_flMinCounterattackDistance) {
	// 		return 0;
	// 	}
		
	// }
	
	// Current hiding point is the best place
	//distance = GetVectorDistance(flHidingSpot,vecOrigin);
	//PrintToServer("[BOTSPAWNS] Selected spot for %N, iCPHIndex %d iSpot %d distance %f",client,iCPHIndex,iSpot,distance);
	return 1;
}

// Get best hiding spot
int GetBestHidingSpot(client, iteration=0)
{
	// Refrash players position
	UpdatePlayerOrigins();
	
	// Get current push point
	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	// If current push point is not available return -1
	if (m_nActivePushPointIndex < 0) return -1;
	
	// Set minimum hiding point index
	new minidx = (iteration) ? 0 : g_iCPLastHidingSpot[m_nActivePushPointIndex];
	
	// Set maximum hiding point index
	new maxidx = (iteration) ? g_iCPLastHidingSpot[m_nActivePushPointIndex] : g_iCPHidingSpotCount[m_nActivePushPointIndex];
	
	// Loop hiding point index
	for (new iCPHIndex = minidx; iCPHIndex < maxidx; iCPHIndex++)
	{
		// Check given hiding point is best point
		new iSpot = g_iCPHidingSpots[m_nActivePushPointIndex][iCPHIndex];
		if (CheckHidingSpotRules(m_nActivePushPointIndex,iCPHIndex,iSpot,client))
		{
			// Update last hiding spot
			g_iCPLastHidingSpot[m_nActivePushPointIndex] = iCPHIndex;
			return iSpot;
		}
	}
	
	// If this call is iteration and couldn't find hiding spot, return -1
	if (iteration)
		return -1;
	
	// If this call is the first try, call again
	//return GetBestHidingSpot(client,1);
	return -1;
}
*/

/*
#####################################################################
# NAV MESH BOT SPAWNS FUNCTIONS END #################################
# NAV MESH BOT SPAWNS FUNCTIONS END #################################
#####################################################################
*/

// When player connected server, intialize variable
public OnClientPutInServer(client)
{
	if (!IsFakeClient(client))
	{
		playerPickSquad[client] = 0;
		g_iHurtFatal[client] = -1;
		g_playerFirstJoin[client] = 1;
		g_iPlayerRespawnTimerActive[client] = 0;
	}
	
	new String:sNickname[64];
	Format(sNickname, sizeof(sNickname), "%N", client);
	g_client_org_nickname[client] = sNickname;
}

// When player connected server, intialize variables
public Action:Event_PlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsFakeClient(client))
	{
		playerPickSquad[client] = 0;
		g_iHurtFatal[client] = -1;
		g_playerFirstJoin[client] = 1;
		g_iPlayerRespawnTimerActive[client] = 0;
	}

	//Update RespawnCvars when players join
	UpdateRespawnCvars();
}

// When player disconnected server, intialize variables
public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && IsClientInGame(client))
	{
		// Reset player status
		g_client_last_classstring[client] = ""; //reset his class model
		// Remove network ragdoll associated with player
		new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
		if (playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
			RemoveRagdoll(client);
		
		// Update cvar
		UpdateRespawnCvars();
	}
	return Plugin_Continue;
}

// When player spawns, intialize variable
public Action:Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );

	if (client > 0 && IsClientInGame(client))
	{
		g_iPlayerRespawnTimerActive[client] = 0;
		
		//remove network ragdoll associated with player
		new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
		if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
			RemoveRagdoll(client);
		
		g_iHurtFatal[client] = 0;
	}
	return Plugin_Continue;
}

// When round starts, intialize variables
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy);
	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
	// Reset respawn position
	g_fRespawnPosition[0] = 0.0;
	g_fRespawnPosition[1] = 0.0;
	g_fRespawnPosition[2] = 0.0;
	
	// Reset remaining life
	new Handle:hCvar = INVALID_HANDLE;
	hCvar = FindConVar("sm_remaininglife");
	SetConVarInt(hCvar, -1);
	
	// Reset respawn token
	ResetInsurgencyLives();
	ResetSecurityLives();
	
	// Reset reinforce time
	new reinforce_time = GetConVarInt(sm_respawn_reinforce_time);
	g_iReinforceTime = reinforce_time;
	
	//Hunt specific
	if (g_isHunt == 1)
	{
		new iReinforce_multiplier = GetConVarInt(sm_respawn_reinforce_multiplier); 
		new iReinforce_multiplier_base = GetConVarInt(sm_respawn_reinforce_multiplier_base);
		g_iReinforceTime = (reinforce_time * iReinforce_multiplier) + iReinforce_multiplier_base;
	}

	// Check gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	//PrintToServer("[REVIVE_DEBUG] ROUND STARTED");
	
	// Warming up revive
	g_iEnableRevive = 0;
	new iPreRoundFirst = GetConVarInt(FindConVar("mp_timer_preround_first"));
	new iPreRound = GetConVarInt(FindConVar("mp_timer_preround"));
	if (g_preRoundInitial == true)
	{
		CreateTimer(float(iPreRoundFirst), PreReviveTimer);
		iPreRoundFirst = iPreRoundFirst + 5;
		CreateTimer(float(iPreRoundFirst), BotsReady_Timer);
		g_preRoundInitial = false;
	}
	else
	{
		CreateTimer(float(iPreRound), PreReviveTimer);
		iPreRoundFirst = iPreRound + 5;
		CreateTimer(float(iPreRound), BotsReady_Timer);
	}


	return Plugin_Continue;
}

// Round starts
public Action:PreReviveTimer(Handle:Timer)
{
	//h_PreReviveTimer = INVALID_HANDLE;
	//PrintToServer("ROUND STATUS AND REVIVE ENABLED********************");
	g_iRoundStatus = 1;
	g_iEnableRevive = 1;
	
	// Update remaining life cvar
	new Handle:hCvar = INVALID_HANDLE;
	new iRemainingLife = GetRemainingLife();
	hCvar = FindConVar("sm_remaininglife");
	SetConVarInt(hCvar, iRemainingLife);
}
// Botspawn trigger
public Action:BotsReady_Timer(Handle:Timer)
{
	//h_PreReviveTimer = INVALID_HANDLE;
	//PrintToServer("ROUND STATUS AND REVIVE ENABLED********************");
	g_botsReady = 1;
}
// When round ends, intialize variables
public Action:Event_RoundEnd_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Stop counter-attack music
	//StopCounterAttackMusic();
}

// When round ends, intialize variables
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Set client command for round end music
	// int iWinner = GetEventInt(event, "winner");
	// decl String:sMusicCommand[128];
	// if (iWinner == TEAM_1)
	// 	Format(sMusicCommand, sizeof(sMusicCommand), "playgamesound Music.WonGame_Security");
	// else
	// 	Format(sMusicCommand, sizeof(sMusicCommand), "playgamesound Music.LostGame_Insurgents");
	
	// // Play round end music
	// for (int i = 1; i <= MaxClients; i++)
	// {
	// 	if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
	// 	{
	// 		ClientCommand(i, "%s", sMusicCommand);
	// 	}
	// }
	
	// Reset respawn position
	g_fRespawnPosition[0] = 0.0;
	g_fRespawnPosition[1] = 0.0;
	g_fRespawnPosition[2] = 0.0;
	
	// Reset remaining life
	new Handle:hCvar = INVALID_HANDLE;
	hCvar = FindConVar("sm_remaininglife");
	SetConVarInt(hCvar, -1);
	
	//PrintToServer("[REVIVE_DEBUG] ROUND ENDED");	
	// Cooldown revive
	g_iEnableRevive = 0;
	g_iRoundStatus = 0;
	
	// Reset respawn token
	ResetInsurgencyLives();
	ResetSecurityLives();
	
	// Update entity
	GetObjResEnt();
	
	////////////////////////
	// Rank System
	if (g_hDB != INVALID_HANDLE)
	{
		for (new client=1; client<=MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				saveUser(client);
				CreateTimer(0.5, Timer_GetMyRank, client);
			}
		}
	}
	////////////////////////

	//Lua Healing kill sound
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "healthkit")) > MaxClients && IsValidEntity(ent))
	{
		//StopSound(ent, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		AcceptEntityInput(ent, "Kill");
	}

}

// Check occouring counter attack when control point captured
public Action:Event_ControlPointCaptured_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy);
	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost) return Plugin_Continue;

	// Get gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));

	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	
	// Init variables
	new Handle:cvar;
	
	// Set minimum and maximum counter attack duration tim
	g_counterAttack_min_dur_sec = GetConVarInt(sm_respawn_min_counter_dur_sec);
	g_counterAttack_max_dur_sec = GetConVarInt(sm_respawn_max_counter_dur_sec);
	new final_ca_dur = GetConVarInt(sm_respawn_final_counter_dur_sec);

	// Get random duration
	new fRandomInt = GetRandomInt(g_counterAttack_min_dur_sec, g_counterAttack_max_dur_sec);
	
	// Set counter attack duration to server
	new Handle:cvar_ca_dur;
	
	// Final counter attack
	if ((acp+1) == ncp)
	{
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration_finale");
		SetConVarInt(cvar_ca_dur, final_ca_dur, true, false);
	}
	// Normal counter attack
	else
	{
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration");
		SetConVarInt(cvar_ca_dur, fRandomInt, true, false);
	}
	
	// Get counter attack chance
	//new Float:ins_ca_chance = GetConVarFloat(sm_respawn_counter_chance);
	
	// Get ramdom value for occuring counter attack
	new Float:fRandom = GetRandomFloat(0.0, 1.0);
	PrintToServer("Counter Chance = %f", g_respawn_counter_chance);
	// Occurs counter attack
	if (fRandom < g_respawn_counter_chance && StrEqual(sGameMode, "checkpoint") && ((acp+1) != ncp))
	{
		cvar = INVALID_HANDLE;
		//PrintToServer("COUNTER YES");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 1, true, false);
		
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
		
		// Call counter-attack end timer
		if (!g_bIsCounterAttackTimerActive)
		{
			g_bIsCounterAttackTimerActive = true;
			CreateTimer(1.0, Timer_CounterAttackEnd, _, TIMER_REPEAT);
			//PrintToServer("[RESPAWN] Counter-attack timer started. (Normal counter-attack)");
		}
	}
	// If last capture point
	else if (StrEqual(sGameMode, "checkpoint") && ((acp+1) == ncp))
	{
		cvar = INVALID_HANDLE;
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 1, true, false);
		
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
		
		// Call counter-attack end timer
		if (!g_bIsCounterAttackTimerActive)
		{
			g_bIsCounterAttackTimerActive = true;
			CreateTimer(1.0, Timer_CounterAttackEnd, _, TIMER_REPEAT);
			//PrintToServer("[RESPAWN] Counter-attack timer started. (Last counter-attack)");
		}
	}
	// Not occurs counter attack
	else
	{
		cvar = INVALID_HANDLE;
		//PrintToServer("COUNTER NO");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 1, true, false);
	}
	
	return Plugin_Continue;
}

// Play music during counter-attack
public Action:Timer_CounterAttackSound(Handle:event)
{
	if (g_iRoundStatus == 0 || !Ins_InCounterAttack())
		return;
	
	// Play music
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			//ClientCommand(i, "playgamesound Music.StartCounterAttack");
			//ClientCommand(i, "play *cues/INS_GameMusic_AboutToAttack_A.ogg");
		}
	}
	
	// Loop
	//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
}

// When control point captured, reset variables
public Action:Event_ControlPointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost == 1) return Plugin_Continue;
	
	// Reset reinforcement time
	new reinforce_time = GetConVarInt(sm_respawn_reinforce_time);
	g_iReinforceTime = reinforce_time;
	
	// Reset respawn tokens
	ResetInsurgencyLives();
	if (g_iCvar_respawn_reset_type)
		ResetSecurityLives();

	//PrintToServer("CONTROL POINT CAPTURED");
	
	return Plugin_Continue;
}

// When control point captured, update respawn point and respawn all players
public Action:Event_ControlPointCaptured_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost == 1) return Plugin_Continue; 
	
	// Get client who captured control point.
	decl String:cappers[256];
	GetEventString(event, "cappers", cappers, sizeof(cappers));
	new cappersLength = strlen(cappers);
	for (new i = 0 ; i < cappersLength; i++)
	{
		new clientCapper = cappers[i];
		if(clientCapper > 0 && IsClientInGame(clientCapper) && IsClientConnected(clientCapper) && IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper))
		{
			// Get player's position
			new Float:capperPos[3];
			GetClientAbsOrigin(clientCapper, Float:capperPos);
			
			// Update respawn position
			g_fRespawnPosition = capperPos;
			
			break;
		}
	}
	
	// Respawn all players
	if (GetConVarInt(sm_respawn_security_on_counter) == 1)
	{
		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsClientConnected(client))
			{
				new team = GetClientTeam(client);
				if(IsClientInGame(client) && playerPickSquad[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1 /*&& !IsClientTimingOut(client) && playerFirstDeath[client] == true*/ )
				{
					if (!IsFakeClient(client))
					{
						if (!IsClientTimingOut(client))
							CreateCounterRespawnTimer(client);
					}
					else
					{
						CreateCounterRespawnTimer(client);
					}
				}
			}
		}
	}
	
	//PrintToServer("CONTROL POINT CAPTURED POST");
	
	return Plugin_Continue;
}


// When ammo cache destroyed, update respawn position and reset variables
public Action:Event_ObjectDestroyed_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy);
	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost == 1) return Plugin_Continue;

	// Get gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));

	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	
	// Init variables
	new Handle:cvar;
	
	// Set minimum and maximum counter attack duration tim
	g_counterAttack_min_dur_sec = GetConVarInt(sm_respawn_min_counter_dur_sec);
	g_counterAttack_max_dur_sec = GetConVarInt(sm_respawn_max_counter_dur_sec);
	new final_ca_dur = GetConVarInt(sm_respawn_final_counter_dur_sec);

	// Get random duration
	new fRandomInt = GetRandomInt(g_counterAttack_min_dur_sec, g_counterAttack_max_dur_sec);
	
	// Set counter attack duration to server
	new Handle:cvar_ca_dur;
	
	// Final counter attack
	if ((acp+1) == ncp)
	{
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration_finale");
		SetConVarInt(cvar_ca_dur, final_ca_dur, true, false);
	}
	// Normal counter attack
	else
	{
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration");
		SetConVarInt(cvar_ca_dur, fRandomInt, true, false);
	}
	
	// Get counter attack chance
	//new Float:ins_ca_chance = GetConVarFloat(sm_respawn_counter_chance);
	
	// Get ramdom value for occuring counter attack
	new Float:fRandom = GetRandomFloat(0.0, 1.0);
	PrintToServer("Counter Chance = %f", g_respawn_counter_chance);
	// Occurs counter attack
	if (fRandom < g_respawn_counter_chance && StrEqual(sGameMode, "checkpoint") && ((acp+1) != ncp))
	{
		cvar = INVALID_HANDLE;
		//PrintToServer("COUNTER YES");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 1, true, false);
		
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
		
		// Call counter-attack end timer
		if (!g_bIsCounterAttackTimerActive)
		{
			g_bIsCounterAttackTimerActive = true;
			CreateTimer(1.0, Timer_CounterAttackEnd, _, TIMER_REPEAT);
			//PrintToServer("[RESPAWN] Counter-attack timer started. (Normal counter-attack)");
		}
	}
	// If last capture point
	else if (StrEqual(sGameMode, "checkpoint") && ((acp+1) == ncp))
	{
		cvar = INVALID_HANDLE;
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 1, true, false);
		
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
		
		// Call counter-attack end timer
		if (!g_bIsCounterAttackTimerActive)
		{
			g_bIsCounterAttackTimerActive = true;
			CreateTimer(1.0, Timer_CounterAttackEnd, _, TIMER_REPEAT);
			//PrintToServer("[RESPAWN] Counter-attack timer started. (Last counter-attack)");
		}
	}
	// Not occurs counter attack
	else
	{
		cvar = INVALID_HANDLE;
		//PrintToServer("COUNTER NO");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 1, true, false);
	}
}

// When ammo cache destroyed, update respawn position and reset variables
public Action:Event_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_isHunt == 1)
	{
		g_huntCacheDestroyed = true;
		//g_iReinforceTime = g_iReinforceTime + g_huntReinforceCacheAdd;
		PrintHintTextToAll("Cache destroyed! Kill all enemies and reinforcements to win!");
		PrintToChatAll("Cache destroyed! Kill all enemies and reinforcements to win!");
		
	}
	// Checkpoint
	if (g_isCheckpoint == 1)
	{
		// Update respawn position
		new attacker = GetEventInt(event, "attacker");
		if (attacker > 0 && IsClientInGame(attacker) && IsClientConnected(attacker))
		{
			new Float:attackerPos[3];
			GetClientAbsOrigin(attacker, Float:attackerPos);
			g_fRespawnPosition = attackerPos;
		}
		
		// Reset reinforcement time
		new reinforce_time = GetConVarInt(sm_respawn_reinforce_time);
		g_iReinforceTime = reinforce_time;
		
		// Reset respawn token
		ResetInsurgencyLives();
		if (g_iCvar_respawn_reset_type)
			ResetSecurityLives();
	}
	
	// Conquer, Respawn all players
	else if (g_isConquer == 1 || g_isHunt == 1)
	{
		for (new client = 1; client <= MaxClients; client++)
		{	
			if (IsClientConnected(client) && !IsFakeClient(client) && IsClientConnected(client))
			{
				new team = GetClientTeam(client);
				if(IsClientInGame(client) && !IsClientTimingOut(client) && playerPickSquad[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1)
				{
					CreateCounterRespawnTimer(client);
				}
			}
		}
	}
	
	return Plugin_Continue;
}
// When control point captured, update respawn point and respawn all players
public Action:Event_ObjectDestroyed_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost == 1) return Plugin_Continue; 
	
	// Get client who captured control point.
	decl String:cappers[256];
	GetEventString(event, "cappers", cappers, sizeof(cappers));
	new cappersLength = strlen(cappers);
	for (new i = 0 ; i < cappersLength; i++)
	{
		new clientCapper = cappers[i];
		if(clientCapper > 0 && IsClientInGame(clientCapper) && IsClientConnected(clientCapper) && IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper))
		{
			// Get player's position
			new Float:capperPos[3];
			GetClientAbsOrigin(clientCapper, Float:capperPos);
			
			// Update respawn position
			g_fRespawnPosition = capperPos;
			
			break;
		}
	}
	
	// Respawn all players
	if (GetConVarInt(sm_respawn_security_on_counter) == 1)
	{
		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsClientConnected(client))
			{
				new team = GetClientTeam(client);
				if(IsClientInGame(client) && playerPickSquad[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1 /*&& !IsClientTimingOut(client) && playerFirstDeath[client] == true*/ )
				{
					if (!IsFakeClient(client))
					{
						if (!IsClientTimingOut(client))
							CreateCounterRespawnTimer(client);
					}
					else
					{
						CreateCounterRespawnTimer(client);
					}
				}
			}
		}
	}
	
	//PrintToServer("CONTROL POINT CAPTURED POST");
	
	return Plugin_Continue;
}
// When counter-attack end, reset reinforcement time
public Action:Timer_CounterAttackEnd(Handle:Timer)
{
	// If round end, exit
	if (g_iRoundStatus == 0)
	{
		// Stop counter-attack music
		//StopCounterAttackMusic();
		
		// Reset variable
		g_bIsCounterAttackTimerActive = false;
		return Plugin_Stop;
	}
	
	// Check counter-attack end
	if (!Ins_InCounterAttack())
	{
		// Reset reinforcement time
		new reinforce_time = GetConVarInt(sm_respawn_reinforce_time);
		g_iReinforceTime = reinforce_time;
		
		// Reset respawn token
		ResetInsurgencyLives();
		if (g_iCvar_respawn_reset_type)
			ResetSecurityLives();
		
		// Stop counter-attack music
		//StopCounterAttackMusic();
		
		// Reset variable
		g_bIsCounterAttackTimerActive = false;
		
		new Handle:cvar = INVALID_HANDLE;
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 0, true, false);
		
		//PrintToServer("[RESPAWN] Counter-attack is over.");
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

// Stop couter-attack music
void StopCounterAttackMusic()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			//ClientCommand(i, "snd_restart");
			//FakeClientCommand(i, "snd_restart");
			StopSound(i, SNDCHAN_STATIC, "*cues/INS_GameMusic_AboutToAttack_A.ogg");
		}
	}
}

//Run this to mark a bot as ready to spawn. Add tokens if you want them to be able to spawn.
void ResetSecurityLives()
{
	// Disable if counquer
	if (g_isConquer == 1 || g_isOutpost == 1) return;
	
	// Return if respawn is disabled
	if (!g_iCvar_respawn_enable) return;
	
	// Update cvars
	UpdateRespawnCvars();
	
	// Individual lives
	if (g_iCvar_respawn_type_team_sec == 1)
	{
		for (new client=1; client<=MaxClients; client++)
		{
			// Check valid player
			if (client > 0 && IsClientInGame(client))
			{
				// Check Team
				new iTeam = GetClientTeam(client);
				if (iTeam != TEAM_1)
					continue;
				
				// Reset individual lives
				g_iSpawnTokens[client] = g_iRespawnCount[iTeam];
			}
		}
	}
	
	// Team lives
	if (g_iCvar_respawn_type_team_sec == 2)
	{
		// Reset remaining lives for player
		g_iRemaining_lives_team_sec = g_iRespawn_lives_team_sec;
	}
}

//Run this to mark a bot as ready to spawn. Add tokens if you want them to be able to spawn.
void ResetInsurgencyLives()
{
	// Disable if counquer
	if (g_isConquer == 1 || g_isOutpost == 1) return;
	
	// Return if respawn is disabled
	if (!g_iCvar_respawn_enable) return;
	
	// Update cvars
	UpdateRespawnCvars();
	
	// Individual lives
	if (g_iCvar_respawn_type_team_ins == 1)
	{
		for (new client=1; client<=MaxClients; client++)
		{
			// Check valid player
			if (client > 0 && IsClientInGame(client))
			{
				// Check Team
				new iTeam = GetClientTeam(client);
				if (iTeam != TEAM_2)
					continue;
				
				// Reset individual lives
				g_iSpawnTokens[client] = g_iRespawnCount[iTeam];
			}
		}
	}
	
	// Team lives
	if (g_iCvar_respawn_type_team_ins == 2)
	{
		// Reset remaining lives for bots
		g_iRemaining_lives_team_ins = g_iRespawn_lives_team_ins;
	}
}

// When player picked squad, initialize variables
public Action:Event_PlayerPickSquad_Post( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"squad_slot" "byte"
	//"squad" "byte"
	//"userid" "short"
	//"class_template" "string"
	//PrintToServer("##########PLAYER IS PICKING SQUAD!############");
	
	// Get client ID
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	if( client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;	
	// Init variable
	playerPickSquad[client] = 1;
	
	// If player changed squad and remain ragdoll
	new team = GetClientTeam(client);
	if (client > 0 && IsClientInGame(client) && IsClientObserver(client) && !IsPlayerAlive(client) && g_iHurtFatal[client] == 0 && team == TEAM_1)
	{
		// Remove ragdoll
		new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
		if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
			RemoveRagdoll(client);
		
		// Init variable
		g_iHurtFatal[client] = -1;
	}
	
		
	// Get class name
	decl String:class_template[64];
	GetEventString(event, "class_template", class_template, sizeof(class_template));
	
	// Set class string
	g_client_last_classstring[client] = class_template;
	
	// Get player nickname
	decl String:sNewNickname[64];
	
	// Medic class
	if (StrContains(g_client_last_classstring[client], "medic") > -1)
	{
		// Admin medic
		if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_ROOT))
			Format(sNewNickname, sizeof(sNewNickname), "[ADMIN][MEDIC] %s", g_client_org_nickname[client]);
		// Donor medic
		else if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_RESERVATION))
			Format(sNewNickname, sizeof(sNewNickname), "[DONOR][MEDIC] %s", g_client_org_nickname[client]);
		// Normal medic
		else
			Format(sNewNickname, sizeof(sNewNickname), "[MEDIC] %s", g_client_org_nickname[client]);
	}
	// Normal class
	else
	{
		// Admin
		if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_ROOT))
			Format(sNewNickname, sizeof(sNewNickname), "[ADMIN] %s", g_client_org_nickname[client]);
		// Donor
		else if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_RESERVATION))
			Format(sNewNickname, sizeof(sNewNickname), "[DONOR] %s", g_client_org_nickname[client]);
		// Normal player
		else
			Format(sNewNickname, sizeof(sNewNickname), "%s", g_client_org_nickname[client]);
	}
	
	// Set player nickname
	decl String:sCurNickname[64];
	Format(sCurNickname, sizeof(sCurNickname), "%N", client);
	if (!StrEqual(sCurNickname, sNewNickname))
		SetClientName(client, sNewNickname);
	
	g_playersReady = true;

	//Allow new players to use lives to respawn on join
	if (g_iRoundStatus == 1 && g_playerFirstJoin[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1)
	{
		// Get SteamID to verify is player has connected before.
		decl String:steamId[64];
		//GetClientAuthString(client, steamId, sizeof(steamId));
		GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
		new isPlayerNew = FindStringInArray(g_playerArrayList, steamId);

		if (isPlayerNew != -1)
		{
			PrintToServer("Player %N has reconnected! | SteamID: %s | Index: %d", client, steamId, isPlayerNew);
		}
		else
		{
			PushArrayString(g_playerArrayList, steamId);
			PrintToServer("Player %N is new! | SteamID: %s | PlayerArrayList Size: %d", client, steamId, GetArraySize(g_playerArrayList));
			// Give individual lives to new player (no longer just at beginning of round)
			if (g_iCvar_respawn_type_team_sec == 1)
			{
				// Check valid player
				//if (client > 0 && IsClientInGame(client))
				//{
					g_iSpawnTokens[client] = g_iRespawnCount[team];
				//}
			}
			CreatePlayerRespawnTimer(client);
		}
	}

	//Update RespawnCvars when player picks squad
	UpdateRespawnCvars();
}

// Triggers when player hurt
public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new dmg_taken = GetEventInt(event, "dmg_health");
	if (g_fCvar_fatal_chance > 0.0)
	{
		// Get information for event structure
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new hitgroup = GetEventInt(event, "hitgroup");
		
		// Update last damege (related to 'hurt_fatal')
		g_clientDamageDone[victim] = dmg_taken;
		
		// Get weapon
		decl String:weapon[32];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		
		//PrintToServer("[DAMAGE TAKEN] Weapon used: %s, Damage done: %i",weapon, dmg_taken);
		
		// Check is team attack
		new attackerTeam;
		if (attacker > 0 && IsClientInGame(attacker) && IsClientConnected(attacker))
			attackerTeam = GetClientTeam(attacker);
		
		// Get fatal chance
		new Float:fRandom = GetRandomFloat(0.0, 1.0);
		
		// Is client valid
		if (IsClientInGame(victim))
		{
			// Explosive
			if (hitgroup == 0)
			{
				//explosive list
				//incens
				//grenade_molotov, grenade_anm14
				//PrintToServer("[HITGROUP HURT BURN]");
				//grenade_m67, grenade_f1, grenade_ied, grenade_c4, rocket_rpg7, rocket_at4, grenade_gp25_he, grenade_m203_he	
				// flame
				if (StrEqual(weapon, "grenade_anm14", false) || StrEqual(weapon, "grenade_molotov", false))
				{
					//PrintToServer("[SUICIDE] incen/molotov DETECTED!");
					if (dmg_taken >= g_iCvar_fatal_burn_dmg && (fRandom <= g_fCvar_fatal_chance))
					{
						// Hurt fatally
						g_iHurtFatal[victim] = 1;
						
						//PrintToServer("[PLAYER HURT BURN]");
					}
				}
				// explosive
				else if (StrEqual(weapon, "grenade_m67", false) || 
					StrEqual(weapon, "grenade_f1", false) || 
					StrEqual(weapon, "grenade_ied", false) || 
					StrEqual(weapon, "grenade_c4", false) || 
					StrEqual(weapon, "rocket_rpg7", false) || 
					StrEqual(weapon, "rocket_at4", false) || 
					StrEqual(weapon, "grenade_gp25_he", false) || 
					StrEqual(weapon, "grenade_m203_he", false))
				{
					//PrintToServer("[HITGROUP HURT EXPLOSIVE]");
					if (dmg_taken >= g_iCvar_fatal_explosive_dmg && (fRandom <= g_fCvar_fatal_chance))
					{
						// Hurt fatally
						g_iHurtFatal[victim] = 1;
						
						//PrintToServer("[PLAYER HURT EXPLOSIVE]");
					}
				}
				//PrintToServer("[SUICIDE] HITRGOUP 0 [GENERIC]");
			}
			// Headshot
			else if (hitgroup == 1)
			{
				//PrintToServer("[PLAYER HURT HEAD]");
				if (dmg_taken >= g_iCvar_fatal_head_dmg && (fRandom <= g_fCvar_fatal_head_chance) && attackerTeam != TEAM_1)
				{
					// Hurt fatally
					g_iHurtFatal[victim] = 1;
					
					//PrintToServer("[BOTSPAWNS] BOOM HEADSHOT");
				}
			}
			// Chest
			else if (hitgroup == 2 || hitgroup == 3)
			{
				//PrintToServer("[HITGROUP HURT CHEST]");
				if (dmg_taken >= g_iCvar_fatal_chest_stomach && (fRandom <= g_fCvar_fatal_chance))
				{
					// Hurt fatally
					g_iHurtFatal[victim] = 1;
					
					//PrintToServer("[PLAYER HURT CHEST]");
				}
			}
			// Limbs
			else if (hitgroup == 4 || hitgroup == 5  || hitgroup == 6 || hitgroup == 7)
			{
				//PrintToServer("[HITGROUP HURT LIMBS]");
				if (dmg_taken >= g_iCvar_fatal_limb_dmg && (fRandom <= g_fCvar_fatal_chance))
				{
					// Hurt fatally
					g_iHurtFatal[victim] = 1;
					
					//PrintToServer("[PLAYER HURT LIMBS]");
				}
			}
		}
	}
	//Track wound type (minor, moderate, critical)
	if (g_iHurtFatal[victim] != 1)
	{
		if (dmg_taken <= g_minorWound_dmg)
		{
			g_playerWoundTime[victim] = g_minorRevive_time;
			g_playerWoundType[victim] = 0;
		}
		else if (dmg_taken > g_minorWound_dmg && dmg_taken <= g_moderateWound_dmg)
		{
			g_playerWoundTime[victim] = g_modRevive_time;
			g_playerWoundType[victim] = 1;
		}
		else if (dmg_taken > g_moderateWound_dmg)
		{
			g_playerWoundTime[victim] = g_critRevive_time;
			g_playerWoundType[victim] = 2;
		}
	}
	else
	{
		g_playerWoundTime[victim] = -1;
		g_playerWoundType[victim] = -1;
	}

	// Tracking ammo
	if (g_iEnableRevive == 1 && g_iRoundStatus == 1 && g_iCvar_enable_track_ammo == 1)
	{
		//PrintToServer("### GET PLAYER WEAPONS ###");
		//CONSIDER IF PLAYER CHOOSES DIFFERENT CLASS
		
		// Get weapons
		new primaryWeapon = GetPlayerWeaponSlot(victim, 0);
		new secondaryWeapon = GetPlayerWeaponSlot(victim, 1);
		//new playerGrenades = GetPlayerWeaponSlot(victim, 3);
		
		// Set weapons to variables
		playerPrimary[victim] = primaryWeapon;
		playerSecondary[victim] = secondaryWeapon;
		
		//Get ammo left in clips for primary and secondary
		playerClip[victim][0] = GetPrimaryAmmo(victim, primaryWeapon, 0);
		playerClip[victim][1] = GetPrimaryAmmo(victim, secondaryWeapon, 1); // m_iClip2 for secondary if this doesnt work? would need GetSecondaryAmmo
		
		//Get Magazines left on player
		if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
			playerAmmo[victim][0] = GetWeaponAmmo(victim, primaryWeapon, 0); //primary
		if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
			playerAmmo[victim][1] = GetWeaponAmmo(victim, secondaryWeapon, 1); //secondary	  

		//PrintToServer("PlayerClip_1 %i, PlayerClip_2 %i, playerAmmo_1 %i, playerAmmo_2 %i, playerGrenades %i",playerClip[victim][0], playerClip[victim][1], playerAmmo[victim][0], playerAmmo[victim][1], playerAmmo[victim][2]); 
		// if (playerGrenades != -1 && IsValidEntity(playerGrenades))
		// {
		// 	 playerGrenadeType[victim][0] = GetGrenadeAmmo(victim, Gren_M67);
		// 	 playerGrenadeType[victim][1] = GetGrenadeAmmo(victim, Gren_Incen);
		// 	 playerGrenadeType[victim][2] = GetGrenadeAmmo(victim, Gren_Molot);
		// 	 playerGrenadeType[victim][3] = GetGrenadeAmmo(victim, Gren_M18);
		// 	 playerGrenadeType[victim][4] = GetGrenadeAmmo(victim, Gren_Flash);
		// 	 playerGrenadeType[victim][5] = GetGrenadeAmmo(victim, Gren_F1);
		// 	 playerGrenadeType[victim][6] = GetGrenadeAmmo(victim, Gren_IED);
		// 	 playerGrenadeType[victim][7] = GetGrenadeAmmo(victim, Gren_C4);
		// 	 playerGrenadeType[victim][8] = GetGrenadeAmmo(victim, Gren_AT4);
		// 	 playerGrenadeType[victim][9] = GetGrenadeAmmo(victim, Gren_RPG7);
		// }
	}
	
	////////////////////////
	// Rank System
	new attackerId = GetEventInt(event, "attacker");
	new hitgroup = GetEventInt(event,"hitgroup");

	new attacker = GetClientOfUserId(attackerId);

	if ( hitgroup == 1 )
	{
		g_iStatHeadShots[attacker]++;
	}
	////////////////////////
	
	return Plugin_Continue;
}

// Trigged when player die
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	////////////////////////
	// Rank System
	new victimId = GetEventInt(event, "userid");
	new attackerId = GetEventInt(event, "attacker");
	
	new victim = GetClientOfUserId(victimId);
	new attacker = GetClientOfUserId(attackerId);

	if(victim != attacker){
		g_iStatKills[attacker]++;
		g_iStatDeaths[victim]++;

	} else {
		g_iStatSuicides[victim]++;
		g_iStatDeaths[victim]++;
	}
	//
	////////////////////////
	
	// Get player ID
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Check client valid
	if (!IsClientInGame(client)) return Plugin_Continue;
	
	// Set variable
	new dmg_taken = GetEventInt(event, "damagebits");
	if (dmg_taken <= 0)
	{
		g_playerWoundTime[client] = g_minorRevive_time;
		g_playerWoundType[client] = 0;
	}
	//PrintToServer("[PLAYERDEATH] Client %N has %d lives remaining", client, g_iSpawnTokens[client]);
	
	// Get gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	
	// Check enables
	if (g_iCvar_respawn_enable)
	{
		// Convert ragdoll
		new team = GetClientTeam(client);
		if (team == TEAM_1)
		{
			// Get current position
			decl Float:vecPos[3];
			GetClientAbsOrigin(client, Float:vecPos);
			g_fDeadPosition[client] = vecPos;
			
			// Call ragdoll timer
			if (g_iEnableRevive == 1 && g_iRoundStatus == 1)
				CreateTimer(5.0, ConvertDeleteRagdoll, client);
		}
		
		// Client should be TEAM_1 or TEAM_2
		if (team == TEAM_1 || team == TEAM_2)
		{
			// The number of control points
			new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
			
			// Active control poin
			new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
			
			// Do not decrease life in counterattack
			if (StrEqual(sGameMode,"checkpoint") && Ins_InCounterAttack() && 
				(((acp+1) == ncp &&  g_iCvar_final_counterattack_type == 2) || 
				((acp+1) != ncp && g_iCvar_counterattack_type == 2))
			)
			{
				// Respawn type 1 bots
				if ((g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2))
				{
					if ((g_iSpawnTokens[client] < g_iRespawnCount[team]))
						g_iSpawnTokens[client] = (g_iRespawnCount[team] + 1);
					
					// Call respawn timer
					CreateBotRespawnTimer(client);
				}
				// Respawn type 1 player (individual lives)
				else if (g_iCvar_respawn_type_team_sec == 1 && team == TEAM_1)
				{
					if (g_iSpawnTokens[client] > 0)
					{
						if (team == TEAM_1)
						{
							CreatePlayerRespawnTimer(client);
						}
					}
					else if (g_iSpawnTokens[client] <= 0 && g_iRespawnCount[team] > 0)
					{
						// Cannot respawn anymore
						decl String:sChat[128];
						Format(sChat, 128,"You cannot be respawned anymore. (out of lives)");
						PrintToChat(client, "%s", sChat);
					}
				}
				// Respawn type 2 for players
				else if (team == TEAM_1 && g_iCvar_respawn_type_team_sec == 2 && g_iRespawn_lives_team_sec > 0)
				{
					g_iRemaining_lives_team_sec = g_iRespawn_lives_team_sec + 1;
					
					// Call respawn timer
					CreateCounterRespawnTimer(client);
				}
				// Respawn type 2 for bots
				else if (team == TEAM_2 && g_iCvar_respawn_type_team_ins == 2 && g_iRespawn_lives_team_ins > 0)
				{
					g_iRemaining_lives_team_ins = g_iRespawn_lives_team_ins + 1;
					
					// Call respawn timer
					CreateBotRespawnTimer(client);
				}
			}
			// Normal respawn
			else if ((g_iCvar_respawn_type_team_sec == 1 && team == TEAM_1) || (g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2))
			{
				if (g_iSpawnTokens[client] > 0)
				{
					if (team == TEAM_1)
					{
						CreatePlayerRespawnTimer(client);
					}
					else if (team == TEAM_2)
					{
						CreateBotRespawnTimer(client);
					}
				}
				else if (g_iSpawnTokens[client] <= 0 && g_iRespawnCount[team] > 0)
				{
					// Cannot respawn anymore
					decl String:sChat[128];
					Format(sChat, 128,"You cannot be respawned anymore. (out of lives)");
					PrintToChat(client, "%s", sChat);
				}
			}
			// Respawn type 2 for players
			else if (g_iCvar_respawn_type_team_sec == 2 && team == TEAM_1)
			{
				if (g_iRemaining_lives_team_sec > 0)
				{
					CreatePlayerRespawnTimer(client);
				}
				else if (g_iRemaining_lives_team_sec <= 0 && g_iRespawn_lives_team_sec > 0)
				{
					// Cannot respawn anymore
					decl String:sChat[128];
					Format(sChat, 128,"You cannot be respawned anymore. (out of team lives)");
					PrintToChat(client, "%s", sChat);
				}
			}
			// Respawn type 2 for bots
			else if (g_iCvar_respawn_type_team_ins == 2 && g_iRemaining_lives_team_ins >  0 && team == TEAM_2)
			{
				CreateBotRespawnTimer(client);
			}
		}
	}
	
	// Init variables
	decl String:wound_hint[64];
	decl String:fatal_hint[64];
	decl String:woundType[64];
	if (g_playerWoundType[client] == 0)
		woundType = "MINORLY WOUNDED";
	else if (g_playerWoundType[client] == 1)
		woundType = "MODERATELY WOUNDED";
	else if (g_playerWoundType[client] == 2)
		woundType = "CRITCALLY WOUNDED";
	
	// Display death message
	if (g_fCvar_fatal_chance > 0.0)
	{
		if (g_iHurtFatal[client] == 1 && !IsFakeClient(client))
		{
			Format(fatal_hint, 255,"You were fatally killed for %i damage", g_clientDamageDone[client]);
			PrintHintText(client, "%s", fatal_hint);
			PrintToChat(client, "%s", fatal_hint);
		}
		else
		{
			Format(wound_hint, 255,"You're %s for %i damage, call a medic for revive!", woundType, g_clientDamageDone[client]);
			PrintHintText(client, "%s", wound_hint);
			PrintToChat(client, "%s", wound_hint);
		}
	}
	else
	{
		Format(wound_hint, 255,"You're %s for %i damage, call a medic for revive!", woundType, g_clientDamageDone[client]);
		PrintHintText(client, "%s", wound_hint);
		PrintToChat(client, "%s", wound_hint);
	}
		
	// Update remaining life
	new Handle:hCvar = INVALID_HANDLE;
	new iRemainingLife = GetRemainingLife();
	hCvar = FindConVar("sm_remaininglife");
	SetConVarInt(hCvar, iRemainingLife);
	
	return Plugin_Continue;
}

// Convert dead body to new ragdoll
public Action:ConvertDeleteRagdoll(Handle:Timer, any:client)
{	
	if (IsClientInGame(client) && g_iRoundStatus == 1 && !IsPlayerAlive(client)) 
	{
		//PrintToServer("CONVERT RAGDOLL********************");
		//new clientRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		//TeleportEntity(clientRagdoll, g_fDeadPosition[client], NULL_VECTOR, NULL_VECTOR);
		
		// Get dead body
		new clientRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		
		//This timer safely removes client-side ragdoll
		if(clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll) && g_iEnableRevive == 1)
		{
			// Get dead body's entity
			new ref = EntIndexToEntRef(clientRagdoll);
			new entity = EntRefToEntIndex(ref);
			if(entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
			{
				// Remove dead body's entity
				AcceptEntityInput(entity, "Kill");
				clientRagdoll = INVALID_ENT_REFERENCE;
			}
		}
		
		// Check is fatally dead
		if (g_iHurtFatal[client] != 1)
		{
			// Create new ragdoll
			new tempRag = CreateEntityByName("prop_ragdoll");
			
			// Set client's new ragdoll
			g_iClientRagdolls[client]  = EntIndexToEntRef(tempRag);
			
			// Set position
			g_fDeadPosition[client][2] = g_fDeadPosition[client][2] + 50;
			
			// If success initialize ragdoll
			if(tempRag != -1)
			{
				// Get model name
				decl String:sModelName[64];
				GetClientModel(client, sModelName, sizeof(sModelName));
				
				// Set model
				SetEntityModel(tempRag, sModelName);
				DispatchSpawn(tempRag);
				
				// Set collisiongroup
				SetEntProp(tempRag, Prop_Send, "m_CollisionGroup", 17);
				
				// Teleport to current position
				TeleportEntity(tempRag, g_fDeadPosition[client], NULL_VECTOR, NULL_VECTOR);
				
				// Set vector
				GetEntPropVector(tempRag, Prop_Send, "m_vecOrigin", g_fRagdollPosition[client]);
				
				// Set revive time remaining
				g_iReviveRemainingTime[client] = g_playerWoundTime[client];
				g_iReviveNonMedicRemainingTime[client] = g_nonMedRevive_time;
				// Start revive checking timer
				/*
				new Handle:revivePack;
				CreateDataTimer(1.0 , Timer_RevivePeriod, revivePack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	
				WritePackCell(revivePack, client);
				WritePackCell(revivePack, tempRag);
				*/
			}
			else
			{
				// If failed to create ragdoll, remove entity
				if(tempRag > 0 && IsValidEdict(tempRag) && IsValidEntity(tempRag))
					RemoveRagdoll(client);
			}
		}
	}
}

// Remove ragdoll
void RemoveRagdoll(client)
{
	//new ref = EntIndexToEntRef(g_iClientRagdolls[client]);
	new entity = EntRefToEntIndex(g_iClientRagdolls[client]);
	if(entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
		g_iClientRagdolls[client] = INVALID_ENT_REFERENCE;
	}	
}

// This handles revives by medics
public CreateReviveTimer(client)
{
	CreateTimer(0.0, RespawnPlayerRevive, client);
}

// Handles spawns when counter attack starts
public CreateCounterRespawnTimer(client)
{
	CreateTimer(0.0, RespawnPlayerCounter, client);
}

// Respawn bot
public CreateBotRespawnTimer(client)
{
	CreateTimer(g_fCvar_respawn_delay_team_ins, RespawnBot, client);
}

// Respawn player
public CreatePlayerRespawnTimer(client)
{
	// Check is respawn timer active
	if (g_iPlayerRespawnTimerActive[client] == 0)
	{
		// Set timer active
		g_iPlayerRespawnTimerActive[client] = 1;
		
		// Set remaining timer for respawn
		g_iRespawnTimeRemaining[client] = g_iRespawnSeconds;
		
		// Call respawn timer
		CreateTimer(1.0, Timer_PlayerRespawn, client, TIMER_REPEAT);
	}
}

// Revive player
public Action:RespawnPlayerRevive(Handle:Timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	if (IsPlayerAlive(client) || g_iRoundStatus == 0) return;
	
	//PrintToServer("[REVIVE_RESPAWN] REVIVING client %N who has %d lives remaining", client, g_iSpawnTokens[client]);
	// Call forcerespawn fucntion
	SDKCall(g_hForceRespawn, client);
	
	// If set 'sm_respawn_enable_track_ammo', restore player's ammo
	if (playerRevived[client] == true && g_iCvar_enable_track_ammo == 1)
		SetPlayerAmmo(client);
	
	//Set wound health
	new iHealth = GetClientHealth(client);
	if (g_playerNonMedicRevive[client] == 0)
	{
		if (g_playerWoundType[client] == 0)
			iHealth = g_minorWoundRevive_hp;
		else if (g_playerWoundType[client] == 1)
			iHealth = g_modWoundRevive_hp;
		else if (g_playerWoundType[client] == 2)
			iHealth = g_critWoundRevive_hp;
	}
	else if (g_playerNonMedicRevive[client] == 1)
	{
		//NonMedic Revived
		iHealth = g_nonMedicRevive_hp;
	}

	SetEntityHealth(client, iHealth);
	
	// Get player's ragdoll
	new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
	
	//Remove network ragdoll
	if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
		RemoveRagdoll(client);
	
	//Do the post-spawn stuff like moving to final "spawnpoint" selected
	//CreateTimer(0.0, RespawnPlayerRevivePost, client);
	RespawnPlayerRevivePost(INVALID_HANDLE, client);
	
}

// Do post revive stuff
public Action:RespawnPlayerRevivePost(Handle:timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	
	//PrintToServer("[REVIVE_DEBUG] called RespawnPlayerRevivePost for client %N (%d)",client,client);
	TeleportEntity(client, g_fRagdollPosition[client], NULL_VECTOR, NULL_VECTOR);
	
	// Reset ragdoll position
	g_fRagdollPosition[client][0] = 0.0;
	g_fRagdollPosition[client][1] = 0.0;
	g_fRagdollPosition[client][2] = 0.0;
}

// Respawn player in counter attack
public Action:RespawnPlayerCounter(Handle:Timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	if (IsPlayerAlive(client) || g_iRoundStatus == 0) return;
	
	//PrintToServer("[Counter Respawn] Respawning client %N who has %d lives remaining", client, g_iSpawnTokens[client]);
	// Call forcerespawn fucntion
	SDKCall(g_hForceRespawn, client);

	// Get player's ragdoll
	new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
	
	//Remove network ragdoll
	if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
		RemoveRagdoll(client);
	
	//Do the post-spawn stuff like moving to final "spawnpoint" selected
	//CreateTimer(0.0, RespawnPlayerPost, client);
	RespawnPlayerPost(INVALID_HANDLE, client);
}

// Do the post respawn stuff in counter attack
public Action:RespawnPlayerPost(Handle:timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	
	// If set 'sm_respawn_enable_track_ammo', restore player's ammo
	if (g_iCvar_enable_track_ammo == 1)
		SetPlayerAmmo(client);
	
	// Teleport to avtive counter attack point
	//PrintToServer("[REVIVE_DEBUG] called RespawnPlayerPost for client %N (%d)",client,client);
	if (g_fRespawnPosition[0] != 0.0 && g_fRespawnPosition[1] != 0.0 && g_fRespawnPosition[2] != 0.0)
		TeleportEntity(client, g_fRespawnPosition, NULL_VECTOR, NULL_VECTOR);
	
	// Reset ragdoll position
	g_fRagdollPosition[client][0] = 0.0;
	g_fRagdollPosition[client][1] = 0.0;
	g_fRagdollPosition[client][2] = 0.0;
}

// Respawn bot
public Action:RespawnBot(Handle:Timer, any:client)
{

	// Exit if client is not in game
	if (!IsClientInGame(client) || g_iRoundStatus == 0) return;

	decl String:sModelName[64];
	GetClientModel(client, sModelName, sizeof(sModelName));
	if (StrEqual(sModelName, ""))
	{
		//PrintToServer("Invalid model: %s", sModelName);
		return; //check if model is blank
	}
	else
	{
		//PrintToServer("Valid model: %s", sModelName);
	}
	
	// Check respawn type
	if (g_iCvar_respawn_type_team_ins == 1 && g_iSpawnTokens[client] > 0)
		g_iSpawnTokens[client]--;
	
	else if (g_iCvar_respawn_type_team_ins == 2)
	{
		if (g_iRemaining_lives_team_ins > 0)
		{
			g_iRemaining_lives_team_ins--;
			
			if (g_iRemaining_lives_team_ins <= 0)
				g_iRemaining_lives_team_ins = 0;
			//PrintToServer("######################TEAM 2 LIVES REMAINING %i", g_iRemaining_lives_team_ins);
		}
	}
	//PrintToServer("######################TEAM 2 LIVES REMAINING %i", g_iRemaining_lives_team_ins);
	//PrintToServer("######################TEAM 2 LIVES REMAINING %i", g_iRemaining_lives_team_ins);
	//PrintToServer("[RESPAWN] Respawning client %N who has %d lives remaining", client, g_iSpawnTokens[client]);
	
	// Call forcerespawn fucntion
	SDKCall(g_hForceRespawn, client);

	//ins_spawnpoint forcerespawn
	//TeleportClient(client);

	//Do the post-spawn stuff like moving to final "spawnpoint" selected
	// if (g_iCvar_SpawnMode == 1)
	// {
	// 	//CreateTimer(0.0, RespawnBotPost, client);
	// 	RespawnBotPost(INVALID_HANDLE, client);
	// }
	
}

//Handle any work that needs to happen after the client is in the game
public Action:RespawnBotPost(Handle:timer, any:client)
{
	/*
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;

	//PrintToServer("[BOTSPAWNS] called RespawnBotPost for client %N (%d)",client,client);
	//g_iSpawning[client] = 0;
	
	if ((g_iHidingSpotCount) && !Ins_InCounterAttack())
	{	
		//PrintToServer("[BOTSPAWNS] HAS g_iHidingSpotCount COUNT");
		
		//Older Nav Spawning
		// Get hiding point - Nav Spawning - Commented for Rehaul
		new Float:flHidingSpot[3];
		new iSpot = GetBestHidingSpot(client);

		//PrintToServer("[BOTSPAWNS] FOUND Hiding spot %d",iSpot);
		
		//If found hiding spot
		if (iSpot > -1)
		{
			// Set hiding spot
			flHidingSpot[0] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_X);
			flHidingSpot[1] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_Y);
			flHidingSpot[2] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_Z);
			
			// Debug message
			//new Float:vecOrigin[3];
			//GetClientAbsOrigin(client,vecOrigin);
			//new Float:distance = GetVectorDistance(flHidingSpot,vecOrigin);
			//PrintToServer("[BOTSPAWNS] Teleporting %N to hiding spot %d at %f,%f,%f distance %f", client, iSpot, flHidingSpot[0], flHidingSpot[1], flHidingSpot[2], distance);
			
			// Teleport to hiding spot
			TeleportEntity(client, flHidingSpot, NULL_VECTOR, NULL_VECTOR);
		}
	}
	*/
	
}

// Player respawn timer
public Action:Timer_PlayerRespawn(Handle:Timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return Plugin_Stop; // empty class name
	
	if (!IsPlayerAlive(client) && g_iRoundStatus == 1)
	{
		if (g_iRespawnTimeRemaining[client] > 0)
		{	
			if (g_playerFirstJoin[client] == 1)
			{
				// Print remaining time to center text area
				if (!IsFakeClient(client))
				{
					decl String:sRemainingTime[256];
					Format(sRemainingTime, sizeof(sRemainingTime),"This is your first time joining.  You will be respawned in %d second%s (%d lives left) ", g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
					PrintCenterText(client, sRemainingTime);
				}
			}
			else
			{
				new String:woundType[128];
				if (g_iHurtFatal[client] == 1)
				{
					woundType = "fatally killed";
				}
				else
				{
					woundType = "WOUNDED";
					if (g_playerWoundType[client] == 0)
						woundType = "MINORLY WOUNDED";
					else if (g_playerWoundType[client] == 1)
						woundType = "MODERATELY WOUNDED";
					else if (g_playerWoundType[client] == 2)
						woundType = "CRITCALLY WOUNDED";
				}
				// Print remaining time to center text area
				if (!IsFakeClient(client))
				{
					decl String:sRemainingTime[256];
					Format(sRemainingTime, sizeof(sRemainingTime),"[You're %s for %d damage]..wait patiently for a medic..do NOT mic/chat spam!\n\n                You will be respawned in %d second%s (%d lives left) ", woundType, g_clientDamageDone[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
					PrintCenterText(client, sRemainingTime);
				}
			}
			
			// Decrease respawn remaining time
			g_iRespawnTimeRemaining[client]--;
		}
		else
		{
			// Decrease respawn token
			if (g_iCvar_respawn_type_team_sec == 1)
				g_iSpawnTokens[client]--;
			else if (g_iCvar_respawn_type_team_sec == 2)
				g_iRemaining_lives_team_sec--;
			
			// Call forcerespawn function
				SDKCall(g_hForceRespawn, client);
			
			// Print remaining time to center text area
			if (!IsFakeClient(client))
				PrintCenterText(client, "You are respawned! (%d lives left)", g_iSpawnTokens[client]);
			
			// Get ragdoll position
			new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
			
			// Remove network ragdoll
			if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
				RemoveRagdoll(client);
			
			// Do the post-spawn stuff like moving to final "spawnpoint" selected
			//CreateTimer(0.0, RespawnPlayerPost, client);
			RespawnPlayerPost(INVALID_HANDLE, client);
			
			// Announce respawn
			PrintToChatAll("\x05%N\x01 is respawned..", client);
			
			// Reset variable
			g_iPlayerRespawnTimerActive[client] = 0;
			
			return Plugin_Stop;
		}
	}
	else
	{
		// Reset variable
		g_iPlayerRespawnTimerActive[client] = 0;
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}


// Handles reviving for medics and non-medics
public Action:Timer_ReviveMonitor(Handle:timer, any:data)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	
	// Init variables
	new Float:fReviveDistance = 65.0;
	new iInjured;
	new iInjuredRagdoll;
	new Float:fRagPos[3];
	new Float:fMedicPos[3];
	new Float:fDistance;
	
	// Search medics
	for (new iMedic = 1; iMedic <= MaxClients; iMedic++)
	{
		if (!IsClientInGame(iMedic) || IsFakeClient(iMedic))
			continue;
		
		// Is valid iMedic?
		if (IsPlayerAlive(iMedic) && (StrContains(g_client_last_classstring[iMedic], "medic") > -1))
		{
			// Check is there nearest body
			iInjured = g_iNearestBody[iMedic];
			
			// Valid nearest body
			if (iInjured > 0 && IsClientInGame(iInjured) && !IsPlayerAlive(iInjured) && g_iHurtFatal[iInjured] == 0 
				&& iInjured != iMedic && GetClientTeam(iMedic) == GetClientTeam(iInjured)
			)
			{
				// Get found medic position
				GetClientAbsOrigin(iMedic, fMedicPos);
				
				// Get player's entity index
				iInjuredRagdoll = EntRefToEntIndex(g_iClientRagdolls[iInjured]);
				
				// Check ragdoll is valid
				if(iInjuredRagdoll > 0 && iInjuredRagdoll != INVALID_ENT_REFERENCE
					&& IsValidEdict(iInjuredRagdoll) && IsValidEntity(iInjuredRagdoll)
				)
				{
					// Get player's ragdoll position
					GetEntPropVector(iInjuredRagdoll, Prop_Send, "m_vecOrigin", fRagPos);
					
					// Update ragdoll position
					g_fRagdollPosition[iInjured] = fRagPos;
					
					// Get distance from iMedic
					fDistance = GetVectorDistance(fRagPos,fMedicPos);
				}
				else
					// Ragdoll is not valid
					continue;
				
				// Jareds pistols only code to verify iMedic is carrying knife
				new ActiveWeapon = GetEntPropEnt(iMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;
				
				// Get weapon class name
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
				//PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);
				
				// If iMedic can see ragdoll and using defib or knife
				if (fDistance < fReviveDistance && (ClientCanSeeVector(iMedic, fRagPos, fReviveDistance)) 
					&& ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1))
				)
				{
					//PrintToServer("[REVIVE_DEBUG] Distance from %N to %N is %f Seconds %d", iInjured, iMedic, fDistance, g_iReviveRemainingTime[iInjured]);		
					decl String:sBuf[255];
					
					// Need more time to reviving
					if (g_iReviveRemainingTime[iInjured] > 0)
					{

						decl String:woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "Minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "Moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "Critical wound";

						// Hint to iMedic
						Format(sBuf, 255,"Reviving %N in: %i seconds (%s)", iInjured, g_iReviveRemainingTime[iInjured], woundType);
						PrintHintText(iMedic, "%s", sBuf);
						
						// Hint to victim
						Format(sBuf, 255,"%N is reviving you in: %i seconds (%s)", iMedic, g_iReviveRemainingTime[iInjured], woundType);
						PrintHintText(iInjured, "%s", sBuf);
						
						// Decrease revive remaining time
						g_iReviveRemainingTime[iInjured]--;
					}
					// Revive player
					else if (g_iReviveRemainingTime[iInjured] <= 0)
					{	
						decl String:woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "critical wound";

						// Chat to all
						Format(sBuf, 255,"\x05%N\x01 revived \x03%N from a %s", iMedic, iInjured, woundType);
						PrintToChatAll("%s", sBuf);
						
						// Hint to iMedic
						Format(sBuf, 255,"You revived %N from a %s", iInjured, woundType);
						PrintHintText(iMedic, "%s", sBuf);
						
						// Hint to victim
						Format(sBuf, 255,"%N revived you from a %s", iMedic, woundType);
						PrintHintText(iInjured, "%s", sBuf);
						
						// Add kill bonus to iMedic
						new iBonus = GetConVarInt(sm_revive_bonus);
						new iScore = GetClientFrags(iMedic) + iBonus;
						SetEntProp(iMedic, Prop_Data, "m_iFrags", iScore);
						
						/////////////////////////
						// Rank System
						g_iStatRevives[iMedic]++;
						//
						/////////////////////////
						
						// Add score bonus to iMedic (doesn't work)
						iScore = GetPlayerScore(iMedic);
						//PrintToServer("[SCORE] score: %d", iScore + 10);
						SetPlayerScore(iMedic, iScore + 10);

						decl String:sBuf2[255];
						if (iBonus > 1)
							Format(sBuf2, 255,"Awarded %i kills and %i score for revive", iBonus, 10);
						else
							Format(sBuf2, 255,"Awarded %i kill and %i score for revive", iBonus, 10);
						
						PrintToChat(iMedic, "%s", sBuf2);

						// Update ragdoll position
						g_fRagdollPosition[iInjured] = fRagPos;

						//Reward nearby medics who asssisted
						Check_NearbyMedicsRevive(iMedic, iInjured);
						
						// Reset revive counter
						playerRevived[iInjured] = true;
						
						// Call revive function
						g_playerNonMedicRevive[iInjured] = 0;
						CreateReviveTimer(iInjured);
						
						//PrintToServer("##########PLAYER REVIVED %s ############", playerRevived[iInjured]);
						continue;
					}
				}
			}
		}
		//Non Medics with Medic Pack
		else if (IsPlayerAlive(iMedic) && !(StrContains(g_client_last_classstring[iMedic], "medic") > -1))
		{
			//PrintToServer("Non-Medic Reviving..");
			// Check is there nearest body
			iInjured = g_iNearestBody[iMedic];
			
			// Valid nearest body
			if (iInjured > 0 && IsClientInGame(iInjured) && !IsPlayerAlive(iInjured) && g_iHurtFatal[iInjured] == 0 
				&& iInjured != iMedic && GetClientTeam(iMedic) == GetClientTeam(iInjured)
			)
			{
				// Get found medic position
				GetClientAbsOrigin(iMedic, fMedicPos);
				
				// Get player's entity index
				iInjuredRagdoll = EntRefToEntIndex(g_iClientRagdolls[iInjured]);
				
				// Check ragdoll is valid
				if(iInjuredRagdoll > 0 && iInjuredRagdoll != INVALID_ENT_REFERENCE
					&& IsValidEdict(iInjuredRagdoll) && IsValidEntity(iInjuredRagdoll)
				)
				{
					// Get player's ragdoll position
					GetEntPropVector(iInjuredRagdoll, Prop_Send, "m_vecOrigin", fRagPos);
					
					// Update ragdoll position
					g_fRagdollPosition[iInjured] = fRagPos;
					
					// Get distance from iMedic
					fDistance = GetVectorDistance(fRagPos,fMedicPos);
				}
				else
					// Ragdoll is not valid
					continue;
				
				// Jareds pistols only code to verify iMedic is carrying knife
				new ActiveWeapon = GetEntPropEnt(iMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;
				
				// Get weapon class name
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
				//PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);
				
				// If NON Medic can see ragdoll and using healthkit
				if (fDistance < fReviveDistance && (ClientCanSeeVector(iMedic, fRagPos, fReviveDistance)) 
					&& ((StrContains(sWeapon, "weapon_healthkit") > -1))
				)
				{
					//PrintToServer("[REVIVE_DEBUG] Distance from %N to %N is %f Seconds %d", iInjured, iMedic, fDistance, g_iReviveNonMedicRemainingTime[iInjured]);		
					decl String:sBuf[255];
					
					// Need more time to reviving
					if (g_iReviveNonMedicRemainingTime[iInjured] > 0)
					{

						//PrintToServer("NONMEDIC HAS TIME");
						if (g_playerWoundType[iInjured] == 0)
						{
							decl String:woundType[64];
							if (g_playerWoundType[iInjured] == 0)
								woundType = "Minor wound";
							else if (g_playerWoundType[iInjured] == 1)
								woundType = "Moderate wound";
							else if (g_playerWoundType[iInjured] == 2)
								woundType = "Critical wound";
							// Hint to NonMedic
							Format(sBuf, 255,"Reviving %N in: %i seconds (%s)", iInjured, g_iReviveNonMedicRemainingTime[iInjured], woundType);
							PrintHintText(iMedic, "%s", sBuf);
							
							// Hint to victim
							Format(sBuf, 255,"%N is reviving you in: %i seconds (%s)", iMedic, g_iReviveNonMedicRemainingTime[iInjured], woundType);
							PrintHintText(iInjured, "%s", sBuf);
							
							// Decrease revive remaining time
							g_iReviveNonMedicRemainingTime[iInjured]--;
						}
						else if (g_playerWoundType[iInjured] == 1 || g_playerWoundType[iInjured] == 2)
						{
							decl String:woundType[64];
							if (g_playerWoundType[iInjured] == 1)
								woundType = "moderately wounded";
							else if (g_playerWoundType[iInjured] == 2)
								woundType = "critically wounded";
							// Hint to NonMedic
							Format(sBuf, 255,"%N is %s and can only be revived by a medic!", iInjured, woundType);
							PrintHintText(iMedic, "%s", sBuf);
						}
					}
					// Revive player
					else if (g_iReviveNonMedicRemainingTime[iInjured] <= 0)
					{	
						decl String:woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "critical wound";

						// Chat to all
						Format(sBuf, 255,"\x05%N\x01 revived \x03%N from a %s", iMedic, iInjured, woundType);
						PrintToChatAll("%s", sBuf);
						
						// Hint to iMedic
						Format(sBuf, 255,"You revived %N from a %s", iInjured, woundType);
						PrintHintText(iMedic, "%s", sBuf);
						
						// Hint to victim
						Format(sBuf, 255,"%N revived you from a %s", iMedic, woundType);
						PrintHintText(iInjured, "%s", sBuf);
						
						// Add kill bonus to iMedic
						new iBonus = GetConVarInt(sm_revive_bonus);
						new iScore = GetClientFrags(iMedic) + iBonus;
						SetEntProp(iMedic, Prop_Data, "m_iFrags", iScore);
						
						
						/////////////////////////
						// Rank System
						g_iStatRevives[iMedic]++;
						//
						/////////////////////////
						
						// Add score bonus to iMedic (doesn't work)
						iScore = GetPlayerScore(iMedic);
						//PrintToServer("[SCORE] score: %d", iScore + 10);
						SetPlayerScore(iMedic, iScore + 10);
						
						decl String:sBuf2[255];
						if (iBonus > 1)
							Format(sBuf2, 255,"Awarded %i kills and %i score for revive", iBonus, 10);
						else
							Format(sBuf2, 255,"Awarded %i kill and %i score for revive", iBonus, 10);
						
						PrintToChat(iMedic, "%s", sBuf2);

						
						// Update ragdoll position
						g_fRagdollPosition[iInjured] = fRagPos;
						
						//Reward nearby medics who asssisted
						Check_NearbyMedicsRevive(iMedic, iInjured);

						// Reset revive counter
						playerRevived[iInjured] = true;
						
						g_playerNonMedicRevive[iInjured] = 1;
						// Call revive function
						CreateReviveTimer(iInjured);
						RemovePlayerItem(iMedic,ActiveWeapon);
						//Switch to knife after removing kit
						ChangePlayerWeaponSlot(iMedic, 2);
						//PrintToServer("##########PLAYER REVIVED %s ############", playerRevived[iInjured]);
						continue;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

// Handles medic functions (Inspecting health, healing)
public Action:Timer_MedicMonitor(Handle:timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Search medics
	for(new medic = 1; medic <= MaxClients; medic++)
	{
		if (!IsClientInGame(medic) || IsFakeClient(medic))
			continue;
		
		// Medic only can inspect health.
		new iTeam = GetClientTeam(medic);
		if (iTeam == TEAM_1 && IsPlayerAlive(medic) && StrContains(g_client_last_classstring[medic], "medic") > -1)
		{
			// Target is teammate and alive.
			new iTarget = TraceClientViewEntity(medic);
			if(iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && iTeam == GetClientTeam(iTarget))
			{
				// Check distance
				new bool:bCanHealPaddle = false;
				new bool:bCanHealMedpack = false;
				new Float:fReviveDistance = 80.0;
				new Float:vecMedicPos[3];
				new Float:vecTargetPos[3];
				new Float:tDistance;
				GetClientAbsOrigin(medic, Float:vecMedicPos);
				GetClientAbsOrigin(iTarget, Float:vecTargetPos);
				tDistance = GetVectorDistance(vecMedicPos,vecTargetPos);
				
				if (tDistance < fReviveDistance && ClientCanSeeVector(medic, vecTargetPos, fReviveDistance))
				{
					// Check weapon
					new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
					if (ActiveWeapon < 0)
						continue;
					decl String:sWeapon[32];
					GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
					
					if ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1))
					{
						bCanHealPaddle = true;
					}
					if ((StrContains(sWeapon, "weapon_healthkit") > -1))
					{
						bCanHealMedpack = true;
					}
				}

				// Check heal
				new iHealth = GetClientHealth(iTarget);

				if (tDistance < 400.0)
				{
					PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
				}

				if (bCanHealPaddle)
				{
					if (iHealth < 100)
					{
						iHealth += g_iHeal_amount_paddles;
						g_playerMedicHealsAccumulated[medic] += g_iHeal_amount_paddles;
						new iHealthCap = GetConVarInt(sm_heal_cap_for_bonus);
						//Reward player for healing
						if (g_playerMedicHealsAccumulated[medic] >= iHealthCap)
						{
							g_playerMedicHealsAccumulated[medic] = 0;
							new iBonus = GetConVarInt(sm_heal_bonus);
							new iScore = GetClientFrags(medic) + iBonus;
							SetEntProp(medic, Prop_Data, "m_iFrags", iScore);
							decl String:sBuf2[255];
							if (iBonus > 1)
								Format(sBuf2, 255,"Awarded %i kills for healing %i in HP of other players.", iBonus, iHealthCap);
							else
								Format(sBuf2, 255,"Awarded %i kill for healing %i in HP of other players.", iBonus, iHealthCap);
							
							PrintToChat(medic, "%s", sBuf2);
							////////////////////////
							// Rank System
							g_iStatHeals[medic]++;
							//
							////////////////////////
						}
						
						if (iHealth >= 100)
						{
							iHealth = 100;
							//Client_PrintToChatAll(false, "{OG}%N{N} healed {OG}%N", medic, iTarget);
							PrintToChatAll("\x05%N\x01 healed \x05%N", medic, iTarget);
							PrintHintText(iTarget, "You were healed by %N (HP: %i)", medic, iHealth);
						}
						else
						{
							PrintHintText(iTarget, "DON'T MOVE! %N is healing you.(HP: %i)", medic, iHealth);
						}
						
						SetEntityHealth(iTarget, iHealth);
						PrintHintText(medic, "%N\nHP: %i\n\nHealing with paddles for: %i", iTarget, iHealth, g_iHeal_amount_paddles);
					}
					else
					{
						PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
					}
				}
				else if (bCanHealMedpack)
				{
					if (iHealth < 100)
					{
						iHealth += g_iHeal_amount_medPack;
						g_playerMedicHealsAccumulated[medic] += g_iHeal_amount_medPack;
						new iHealthCap = GetConVarInt(sm_heal_cap_for_bonus);
						//Reward player for healing
						if (g_playerMedicHealsAccumulated[medic] >= iHealthCap)
						{
							g_playerMedicHealsAccumulated[medic] = 0;
							new iBonus = GetConVarInt(sm_heal_bonus);
							new iScore = GetClientFrags(medic) + iBonus;
							SetEntProp(medic, Prop_Data, "m_iFrags", iScore);
							decl String:sBuf2[255];
							if (iBonus > 1)
								Format(sBuf2, 255,"Awarded %i kills for healing %i in HP of other players.", iBonus, iHealthCap);
							else
								Format(sBuf2, 255,"Awarded %i kill for healing %i in HP of other players.", iBonus, iHealthCap);

							PrintToChat(medic, "%s", sBuf2);
							////////////////////////
							// Rank System
							g_iStatHeals[medic]++;
							//
							////////////////////////
						}

						if (iHealth >= 100)
						{
							iHealth = 100;
							
							//Client_PrintToChatAll(false, "{OG}%N{N} healed {OG}%N", medic, iTarget);
							PrintToChatAll("\x05%N\x01 healed \x05%N", medic, iTarget);
							PrintHintText(iTarget, "You were healed by %N (HP: %i)", medic, iHealth);
						}
						else
						{
							PrintHintText(iTarget, "DON'T MOVE! %N is healing you.(HP: %i)", medic, iHealth);
						}
						
						SetEntityHealth(iTarget, iHealth);
						PrintHintText(medic, "%N\nHP: %i\n\nHealing with medpack for: %i", iTarget, iHealth, g_iHeal_amount_medPack);
					}
					else
					{
						PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
					}
				}
			}
			else //Heal Self
			{
				// Check distance
				new bool:bCanHealMedpack = false;
				
				// Check weapon
				new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

				if ((StrContains(sWeapon, "weapon_healthkit") > -1))
				{
					bCanHealMedpack = true;
				}
				
				// Check heal
				new iHealth = GetClientHealth(medic);
				if (bCanHealMedpack)
				{
					if (iHealth < g_medicHealSelf_max)
					{
						iHealth += g_iHeal_amount_paddles;
						if (iHealth >= g_medicHealSelf_max)
						{
							iHealth = g_medicHealSelf_max;
							PrintHintText(medic, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_medicHealSelf_max);
						}
						else
						{
							PrintHintText(medic, "Healing Self (HP: %i) | MAX: %i", iHealth, g_medicHealSelf_max);
						}
						SetEntityHealth(medic, iHealth);
					}
				}
			}
		}
		else if (iTeam == TEAM_1 && IsPlayerAlive(medic) && !(StrContains(g_client_last_classstring[medic], "medic") > -1))
		{
			// Check weapon for non medics outside
			new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
			if (ActiveWeapon < 0)
				continue;
			decl String:checkWeapon[32];
			GetEdictClassname(ActiveWeapon, checkWeapon, sizeof(checkWeapon));
			if ((StrContains(checkWeapon, "weapon_healthkit") > -1))
			{
				// Target is teammate and alive.
				new iTarget = TraceClientViewEntity(medic);
				if(iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && iTeam == GetClientTeam(iTarget))
				{
					// Check distance
					new bool:bCanHealMedpack = false;
					new Float:fReviveDistance = 80.0;
					new Float:vecMedicPos[3];
					new Float:vecTargetPos[3];
					new Float:tDistance;
					GetClientAbsOrigin(medic, Float:vecMedicPos);
					GetClientAbsOrigin(iTarget, Float:vecTargetPos);
					tDistance = GetVectorDistance(vecMedicPos,vecTargetPos);
					
					if (tDistance < fReviveDistance && ClientCanSeeVector(medic, vecTargetPos, fReviveDistance))
					{
						// Check weapon
						new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
						if (ActiveWeapon < 0)
							continue;

						decl String:sWeapon[32];
						GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
						if ((StrContains(sWeapon, "weapon_healthkit") > -1))
						{
							bCanHealMedpack = true;
						}
					}
					// Check heal
					new iHealth = GetClientHealth(iTarget);

					if (tDistance < 400.0)
					{
						PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
					}
					if (bCanHealMedpack)
					{
						if (iHealth < g_nonMedic_maxHealOther)
						{
							iHealth += g_nonMedicHeal_amount;
							g_playerNonMedicHealsAccumulated[medic] += g_nonMedicHeal_amount;
							new iHealthCap = GetConVarInt(sm_heal_cap_for_bonus);
							//Reward player for healing
							if (g_playerNonMedicHealsAccumulated[medic] >= iHealthCap)
							{
								g_playerNonMedicHealsAccumulated[medic] = 0;
								new iBonus = GetConVarInt(sm_heal_bonus);
								new iScore = GetClientFrags(medic) + iBonus;
								SetEntProp(medic, Prop_Data, "m_iFrags", iScore);
								decl String:sBuf2[255];
								if (iBonus > 1)
									Format(sBuf2, 255,"Awarded %i kills for healing %i in HP of other players.", iBonus, iHealthCap);
								else
									Format(sBuf2, 255,"Awarded %i kill for healing %i in HP of other players.", iBonus, iHealthCap);
								
								PrintToChat(medic, "%s", sBuf2);
								////////////////////////
								// Rank System
								g_iStatHeals[medic]++;
								//
								////////////////////////
							}

							if (iHealth >= g_nonMedic_maxHealOther)
							{
								iHealth = g_nonMedic_maxHealOther;
								
								//Client_PrintToChatAll(false, "{OG}%N{N} healed {OG}%N", medic, iTarget);
								//PrintToChatAll("\x05%N\x01 healed \x05%N", medic, iTarget);
								PrintHintText(iTarget, "Non-Medic %N can only heal you for %i HP!)", medic, iHealth);
							}
							else
							{
								PrintHintText(iTarget, "DON'T MOVE! %N is healing you.(HP: %i)", medic, iHealth);
							}
							
							SetEntityHealth(iTarget, iHealth);
							PrintHintText(medic, "%N\nHP: %i\n\nHealing.", iTarget, iHealth);
						}
						else
						{
							if (iHealth < g_nonMedic_maxHealOther)
							{
								PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
							}
							else if (iHealth >= g_nonMedic_maxHealOther)
								PrintHintText(medic, "%N\nHP: %i (MAX YOU CAN HEAL)", iTarget, iHealth);

						}
					}
				}
				else //Heal Self
				{
					// Check distance
					new bool:bCanHealMedpack = false;
					
					// Check weapon
					new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
					if (ActiveWeapon < 0)
						continue;
					decl String:sWeapon[32];
					GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

					if ((StrContains(sWeapon, "weapon_healthkit") > -1))
					{
						bCanHealMedpack = true;
					}
					
					// Check heal
					new iHealth = GetClientHealth(medic);
					if (bCanHealMedpack)
					{
						if (iHealth < g_nonMedicHealSelf_max)
						{
							iHealth += g_nonMedicHeal_amount;
							if (iHealth >= g_nonMedicHealSelf_max)
							{
								iHealth = g_nonMedicHealSelf_max;
								PrintHintText(medic, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
							}
							else
							{
								PrintHintText(medic, "Healing Self (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
							}
							
							SetEntityHealth(medic, iHealth);
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue; 
}

// Check for nearest player
public Action:Timer_NearestBody(Handle:timer, any:data)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Variables to store
	new Float:fMedicPosition[3];
	new Float:fMedicAngles[3];
	new Float:fInjuredPosition[3];
	new Float:fNearestDistance;
	new Float:fTempDistance;

	// iNearestInjured client
	new iNearestInjured;
	
	decl String:sDirection[64];
	decl String:sDistance[64];

	// Client loop
	for (new medic = 1; medic <= MaxClients; medic++)
	{
		if (!IsClientInGame(medic) || IsFakeClient(medic))
			continue;
		
		// Valid medic?
		if (IsPlayerAlive(medic) && (StrContains(g_client_last_classstring[medic], "medic") > -1))
		{
			// Reset variables
			iNearestInjured = 0;
			fNearestDistance = 0.0;
			
			// Get medic position
			GetClientAbsOrigin(medic, fMedicPosition);

			//PrintToServer("MEDIC DETECTED ********************");
			// Search dead body
			for (new search = 1; search <= MaxClients; search++)
			{
				if (!IsClientInGame(search) || IsFakeClient(search) || IsPlayerAlive(search))
					continue;
				
				// Check if valid
				if (g_iHurtFatal[search] == 0 && search != medic && GetClientTeam(medic) == GetClientTeam(search))
				{
					// Get found client's ragdoll
					new clientRagdoll = EntRefToEntIndex(g_iClientRagdolls[search]);
					if (clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll) && clientRagdoll != INVALID_ENT_REFERENCE)
					{
						// Get ragdoll's position
						fInjuredPosition = g_fRagdollPosition[search];
						
						// Get distance from ragdoll
						fTempDistance = GetVectorDistance(fMedicPosition, fInjuredPosition);

						// Is he more fNearestDistance to the player as the player before?
						if (fNearestDistance == 0.0)
						{
							fNearestDistance = fTempDistance;
							iNearestInjured = search;
						}
						// Set new distance and new iNearestInjured player
						else if (fTempDistance < fNearestDistance)
						{
							fNearestDistance = fTempDistance;
							iNearestInjured = search;
						}
					}
				}
			}
			
			// Found a dead body?
			if (iNearestInjured != 0)
			{
				// Set iNearestInjured body
				g_iNearestBody[medic] = iNearestInjured;
				
				// Get medic angle
				GetClientAbsAngles(medic, fMedicAngles);
				
				// Get direction string (if it cause server lag, remove this)
				sDirection = GetDirectionString(fMedicAngles, fMedicPosition, fInjuredPosition);
				
				// Get distance string
				sDistance = GetDistanceString(fNearestDistance);
				
				// Print iNearestInjured dead body's distance and direction text
				//PrintCenterText(medic, "Nearest dead: %N (%s)", iNearestInjured, sDistance);
				PrintCenterText(medic, "Nearest dead: %N ( %s | %s )", iNearestInjured, sDistance, sDirection);
				new Float:beamPos[3];
				beamPos = fInjuredPosition;
				beamPos[2] += 0.3;
				if (fTempDistance >= 300)
				{
					//Attack markers option
					//Effect_SetMarkerAtPos(medic,beamPos,1.0,{255, 0, 0, 255}); 

					//Beam dead when farther
					TE_SetupBeamRingPoint(beamPos, 1.0, Revive_Indicator_Radius, g_iBeaconBeam, g_iBeaconHalo, 0, 15, 5.0, 3.0, 5.0, {255, 0, 0, 255}, 1, (FBEAM_FADEIN, FBEAM_FADEOUT));
					//void TE_SetupBeamRingPoint(const float center[3], float Start_Radius, float End_Radius, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float Amplitude, const int Color[4], int Speed, int Flags)
					TE_SendToClient(medic);
				}
			}
			else
			{
				// Reset iNearestInjured body
				g_iNearestBody[medic] = -1;
			}
		}
		else if (IsPlayerAlive(medic) && !(StrContains(g_client_last_classstring[medic], "medic") > -1))
		{
			// Reset variables
			iNearestInjured = 0;
			fNearestDistance = 0.0;
			
			// Get medic position
			GetClientAbsOrigin(medic, fMedicPosition);

			//PrintToServer("MEDIC DETECTED ********************");
			// Search dead body
			for (new search = 1; search <= MaxClients; search++)
			{
				if (!IsClientInGame(search) || IsFakeClient(search) || IsPlayerAlive(search))
					continue;
				
				// Check if valid
				if (g_iHurtFatal[search] == 0 && search != medic && GetClientTeam(medic) == GetClientTeam(search))
				{
					// Get found client's ragdoll
					new clientRagdoll = EntRefToEntIndex(g_iClientRagdolls[search]);
					if (clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll) && clientRagdoll != INVALID_ENT_REFERENCE)
					{
						// Get ragdoll's position
						fInjuredPosition = g_fRagdollPosition[search];
						
						// Get distance from ragdoll
						fTempDistance = GetVectorDistance(fMedicPosition, fInjuredPosition);

						// Is he more fNearestDistance to the player as the player before?
						if (fNearestDistance == 0.0)
						{
							fNearestDistance = fTempDistance;
							iNearestInjured = search;
						}
						// Set new distance and new iNearestInjured player
						else if (fTempDistance < fNearestDistance)
						{
							fNearestDistance = fTempDistance;
							iNearestInjured = search;
						}
					}
				}
			}
			
			// Found a dead body?
			if (iNearestInjured != 0)
			{
				// Set iNearestInjured body
				g_iNearestBody[medic] = iNearestInjured;
				
			}
			else
			{
				// Reset iNearestInjured body
				g_iNearestBody[medic] = -1;
			}
		}
	}
	
	return Plugin_Continue;
}

/**
 * Get direction string for nearest dead body
 *
 * @param fClientAngles[3]		Client angle
 * @param fClientPosition[3]	Client position
 * @param fTargetPosition[3]	Target position
 * @Return						direction string.
 */
String:GetDirectionString(Float:fClientAngles[3], Float:fClientPosition[3], Float:fTargetPosition[3])
{
	new
		Float:fTempAngles[3],
		Float:fTempPoints[3];
		
	decl String:sDirection[64];

	// Angles from origin
	MakeVectorFromPoints(fClientPosition, fTargetPosition, fTempPoints);
	GetVectorAngles(fTempPoints, fTempAngles);
	
	// Differenz
	new Float:fDiff = fClientAngles[1] - fTempAngles[1];
	
	// Correct it
	if (fDiff < -180)
		fDiff = 360 + fDiff;

	if (fDiff > 180)
		fDiff = 360 - fDiff;
	
	// Now geht the direction
	// Up
	if (fDiff >= -22.5 && fDiff < 22.5)
		Format(sDirection, sizeof(sDirection), "FWD");//"\xe2\x86\x91");
	// right up
	else if (fDiff >= 22.5 && fDiff < 67.5)
		Format(sDirection, sizeof(sDirection), "FWD-RIGHT");//"\xe2\x86\x97");
	// right
	else if (fDiff >= 67.5 && fDiff < 112.5)
		Format(sDirection, sizeof(sDirection), "RIGHT");//"\xe2\x86\x92");
	// right down
	else if (fDiff >= 112.5 && fDiff < 157.5)
		Format(sDirection, sizeof(sDirection), "BACK-RIGHT");//"\xe2\x86\x98");
	// down
	else if (fDiff >= 157.5 || fDiff < -157.5)
		Format(sDirection, sizeof(sDirection), "BACK");//"\xe2\x86\x93");
	// down left
	else if (fDiff >= -157.5 && fDiff < -112.5)
		Format(sDirection, sizeof(sDirection), "BACK-LEFT");//"\xe2\x86\x99");
	// left
	else if (fDiff >= -112.5 && fDiff < -67.5)
		Format(sDirection, sizeof(sDirection), "LEFT");//"\xe2\x86\x90");
	// left up
	else if (fDiff >= -67.5 && fDiff < -22.5)
		Format(sDirection, sizeof(sDirection), "FWD-LEFT");//"\xe2\x86\x96");
	
	return sDirection;
}

// Return distance string
String:GetDistanceString(Float:fDistance)
{
	// Distance to meters
	new Float:fTempDistance = fDistance * 0.01905;
	decl String:sResult[64];

	// Distance to feet?
	if (g_iUnitMetric == 1)
	{
		fTempDistance = fTempDistance * 3.2808399;

		// Feet
		Format(sResult, sizeof(sResult), "%.0f feet", fTempDistance);
	}
	else
	{
		// Meter
		Format(sResult, sizeof(sResult), "%.0f meter", fTempDistance);
	}
	
	return sResult;
}

// Check tags
stock TagsCheck(const String:tag[], bool:remove = false)
{
	new Handle:hTags = FindConVar("sv_tags");
	decl String:tags[255];
	GetConVarString(hTags, tags, sizeof(tags));

	if (StrContains(tags, tag, false) == -1 && !remove)
	{
		decl String:newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		ReplaceString(newTags, sizeof(newTags), ",,", ",", false);
		SetConVarString(hTags, newTags);
		GetConVarString(hTags, tags, sizeof(tags));
	}
	else if (StrContains(tags, tag, false) > -1 && remove)
	{
		ReplaceString(tags, sizeof(tags), tag, "", false);
		ReplaceString(tags, sizeof(tags), ",,", ",", false);
		SetConVarString(hTags, tags);
	}
}

// Get tesm2 player count
stock GetTeamSecCount() {
	new clients = 0;
	new iTeam;
	for( new i = 1; i <= GetMaxClients(); i++ ) {
		if (IsClientInGame(i) && IsClientConnected(i))
		{
			iTeam = GetClientTeam(i);
			if(iTeam == TEAM_1)
				clients++;
		}
	}
	return clients;
}

// Get real client count
stock GetRealClientCount( bool:inGameOnly = true ) {
	new clients = 0;
	for( new i = 1; i <= GetMaxClients(); i++ ) {
		if(((inGameOnly)?IsClientInGame(i):IsClientConnected(i)) && !IsFakeClient(i)) {
			clients++;
		}
	}
	return clients;
}

// Get insurgent team bot count
stock GetTeamInsCount() {
	new clients;
	for(new i = 1; i <= GetMaxClients(); i++ ) {
		if (IsClientInGame(i) && IsClientConnected(i) && IsFakeClient(i)) {
			clients++;
		}
	}
	return clients;
}

// Get remaining life
stock GetRemainingLife()
{
	new iResult;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i > 0 && IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			if (g_iSpawnTokens[i] > 0)
				iResult = iResult + g_iSpawnTokens[i];
		}
	}
	
	return iResult;
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

// Get player score (works fine)
int GetPlayerScore(client)
{
	// Get player manager class
	new iPlayerManager, String:iPlayerManagerNetClass[32];
	iPlayerManager = FindEntityByClassname(0,"ins_player_manager");
	GetEntityNetClass(iPlayerManager, iPlayerManagerNetClass, sizeof(iPlayerManagerNetClass));
	
	// Check result
	if (iPlayerManager < 1)
	{
		//PrintToServer("[SCORE] Unable to find ins_player_manager");
		return -1;
	}
	
	// Debug result
	//PrintToServer("[SCORE] iPlayerManagerNetClass %s", iPlayerManagerNetClass);
	
	// Get player score structure
	new m_iPlayerScore = FindSendPropInfo(iPlayerManagerNetClass, "m_iPlayerScore");
	
	// Check result
	if (m_iPlayerScore < 1) {
		//PrintToServer("[SCORE] Unable to find ins_player_manager property m_iPlayerScore");
		return -1;
	}
	
	// Get score
	new iScore = GetEntData(iPlayerManager, m_iPlayerScore + (4 * client));
	
	return iScore;
}

// Set player score (doesn't work)	
void SetPlayerScore(client, iScore)
{
	// Get player manager class
	new iPlayerManager, String:iPlayerManagerNetClass[32];
	iPlayerManager = FindEntityByClassname(0,"ins_player_manager");
	GetEntityNetClass(iPlayerManager, iPlayerManagerNetClass, sizeof(iPlayerManagerNetClass));
	
	// Check result
	if (iPlayerManager < 1)
	{
		//PrintToServer("[SCORE] Unable to find ins_player_manager");
		return;
	}
	
	// Debug result
	//PrintToServer("[SCORE] iPlayerManagerNetClass %s", iPlayerManagerNetClass);
	
	// Get player score
	new m_iPlayerScore = FindSendPropInfo(iPlayerManagerNetClass, "m_iPlayerScore");
	
	// Check result
	if (m_iPlayerScore < 1) {
		//PrintToServer("[SCORE] Unable to find ins_player_manager property m_iPlayerScore");
		return;
	}
	
	// Set score
	SetEntData(iPlayerManager, m_iPlayerScore + (4 * client), iScore, _, true);
}


int Ins_ObjectiveResource_GetProp(String:prop[32], size = 0, element = 0)
{
	new result = -1;
	GetObjResEnt();
	if (g_iObjResEntity > 0)
	{
		result = GetEntData(g_iObjResEntity, FindSendPropInfo(g_iObjResEntityNetClass, prop) + (size * element));
	}
	return result;
}
void Ins_ObjectiveResource_GetPropVector(String:prop[32], Float:array[3], element = 0)
{
	new size = 12;
	GetObjResEnt();
	if (g_iObjResEntity > 0)
	{
		new Float:result[3];
		GetEntDataVector(g_iObjResEntity, FindSendPropInfo(g_iObjResEntityNetClass, prop) + (size * element), result);
		array[0] = result[0];
		array[1] = result[1];
		array[2] = result[2];
	}
}
bool Ins_InCounterAttack()
{
	GetLogicEnt();
	new bool:result;
	if (g_iLogicEntity > 0)
	{
		result = bool:GetEntData(g_iLogicEntity, FindSendPropInfo(g_iLogicEntityNetClass, "m_bCounterAttack"));
	}
	return result;
}
int GetLogicEnt(always=0) {
	if (((g_iLogicEntity < 1) || !IsValidEntity(g_iLogicEntity)) || (always))
	{
		new String:sGameMode[32],String:sLogicEnt[64];
		GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
		Format (sLogicEnt,sizeof(sLogicEnt),"logic_%s",sGameMode);
		if (!StrEqual(sGameMode,"checkpoint")) return -1;
		g_iLogicEntity = FindEntityByClassname(-1,sLogicEnt);
		GetEntityNetClass(g_iLogicEntity, g_iLogicEntityNetClass, sizeof(g_iLogicEntityNetClass));
	}
	if (g_iLogicEntity)
		return g_iLogicEntity;
	return -1;
}
int GetObjResEnt(always=0)
{
	if (((g_iObjResEntity < 1) || !IsValidEntity(g_iObjResEntity)) || (always))
	{
		g_iObjResEntity = FindEntityByClassname(0,"ins_objective_resource");
		GetEntityNetClass(g_iObjResEntity, g_iObjResEntityNetClass, sizeof(g_iObjResEntityNetClass));
	}
	if (g_iObjResEntity)
		return g_iObjResEntity;
	return -1;
}
//Explaining different MASK types: https://wiki.garrysmod.com/page/Enums/MASK
bool:ClientCanSeeVector(client, Float:vTargetPosition[3], Float:distance = 0.0, Float:height = 50.0) 
{ 
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
public bool:Base_TraceFilter(entity, contentsMask, any:data) 
{ 
    if(entity != data) 
        return (false); 

    return (true); 
} 


// ================================================================================
// Start Rank System
// ================================================================================
// Load data from database
public LoadMySQLBase(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	// Check DB
	if (hndl == INVALID_HANDLE)
	{
		//PrintToServer("Failed to connect: %s", error);
		g_hDB = INVALID_HANDLE;
		return;
	} else {
		//PrintToServer("DEBUG: DatabaseInit (CONNECTED)");
	}
	
	
	g_hDB = hndl;
	decl String:sQuery[1024];
	
	// Set UTF8
	FormatEx(sQuery, sizeof(sQuery), "SET NAMES \"UTF8\"");
	SQL_TQuery(g_hDB, SQLErrorCheckCallback, sQuery);
	
	// Get 'last_active'
	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM ins_rank WHERE last_active <= %i", GetTime() - PLAYER_STATSOLD * 12 * 60 * 60);
	SQL_TQuery(g_hDB, SQLErrorCheckCallback, sQuery);
}

// Init Client
public OnClientAuthorized(client, const String:auth[])
{
	InitializeClient(client);
}

// Init Client
public InitializeClient( client )
{
	if ( !IsFakeClient(client) )
	{
		// Init stats
		g_iStatScore[client]=0;
		g_iStatKills[client]=0;
		g_iStatDeaths[client]=0;
		g_iStatHeadShots[client]=0;
		g_iStatSuicides[client]=0;
		g_iStatRevives[client]=0;
		g_iStatHeals[client]=0;
		g_iUserFlood[client]=0;
		g_iUserPtime[client]=GetTime();
		
		// Get SteamID
		decl String:steamId[64];
		//GetClientAuthString(client, steamId, sizeof(steamId));
		GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
		g_sSteamIdSave[client] = steamId;
		
		// Process Init
		CreateTimer(1.0, initPlayerBase, client);
	}
}

// Init player
public Action:initPlayerBase(Handle:timer, any:client){
	if (g_hDB != INVALID_HANDLE)
	{
		// Check player's data existance
		decl String:buffer[200];
		Format(buffer, sizeof(buffer), "SELECT * FROM ins_rank WHERE steamId = '%s'", g_sSteamIdSave[client]);
		if(DEBUG == 1){
			//PrintToServer("DEBUG: Action:initPlayerBase (%s)", buffer);
		}
		SQL_TQuery(g_hDB, SQLUserLoad, buffer, client);
	}
	else
	{
		// Join message
		PrintToChatAll("\x04%N\x01 joined the fight.", client);
	}
}

/*
// Add kills and deaths
public EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{

	new victimId = GetEventInt(event, "userid");
	new attackerId = GetEventInt(event, "attacker");
	
	new victim = GetClientOfUserId(victimId);
	new attacker = GetClientOfUserId(attackerId);

	if(victim != attacker){
		g_iStatKills[attacker]++;
		g_iStatDeaths[victim]++;

	} else {
		g_iStatSuicides[victim]++;
		g_iStatDeaths[victim]++;
	}
}

// Add headshots
public EventPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attackerId = GetEventInt(event, "attacker");
	new hitgroup = GetEventInt(event,"hitgroup");

	new attacker = GetClientOfUserId(attackerId);

	if ( hitgroup == 1 )
	{
		g_iStatHeadShots[attacker]++;
	}
}
*/

// Save stats when player disconnect
public OnClientDisconnect (client)
{
	if ( !IsFakeClient(client) && g_iUserInit[client] == 1)
	{		
		if (g_hDB != INVALID_HANDLE)
		{
			saveUser(client);
			g_iUserInit[client] = 0;
		}
	}
}

// Save stats
public saveUser(client){
	if ( !IsFakeClient(client) && g_iUserInit[client] == 1)
	{		
		if (g_hDB != INVALID_HANDLE)
		{
			new String:buffer[200];
			Format(buffer, sizeof(buffer), "SELECT * FROM ins_rank WHERE steamId = '%s'", g_sSteamIdSave[client]);
			if(DEBUG == 1){
				//PrintToServer("DEBUG: saveUser (%s)", buffer);
			}
			SQL_TQuery(g_hDB, SQLUserSave, buffer, client);
		}
	}
}

// Monitor say command
public Action:Command_Say(client, args)
{
	// Init variables
	decl String:text[192], String:command[64];
	new startidx = 0;
	
	// Get cmd string
	GetCmdArgString(text, sizeof(text));
	
	// Check string
	if (text[strlen(text)-1] == '"')
	{		
		text[strlen(text)-1] = '\0';
		startidx = 1;	
	} 	
	if (strcmp(command, "say2", false) == 0)
	
	// Set start point
	startidx += 4;
	
	// Check commands for stats
	// Rank
	if (strcmp(text[startidx], "/rank", false) == 0 || strcmp(text[startidx], "!rank", false) == 0 || strcmp(text[startidx], "rank", false) == 0)	{
		if(g_iUserFlood[client] != 1){
			saveUser(client);
			//GetMyRank(client);
			CreateTimer(0.5, Timer_GetMyRank, client);
			g_iUserFlood[client]=1;
			CreateTimer(10.0, removeFlood, client);
		} else {
			PrintToChat(client,"%cDo not flood the server!", GREEN);
		}
	}
	// Top10
	else if (strcmp(text[startidx], "/top10", false) == 0 || strcmp(text[startidx], "!top10", false) == 0 || strcmp(text[startidx], "top10", false) == 0)
	{		
		if(g_iUserFlood[client] != 1){
			saveUser(client);
			showTOP(client);
			g_iUserFlood[client]=1;
			CreateTimer(10.0, removeFlood, client);
		} else {
			PrintToChat(client,"%cDo not flood the server!", GREEN);
		}
	}
	// Top10
	else if (strcmp(text[startidx], "/topmedics", false) == 0 || strcmp(text[startidx], "!topmedics", false) == 0 || strcmp(text[startidx], "topmedics", false) == 0)
	{		
		if(g_iUserFlood[client] != 1){
			saveUser(client);
			showTOPMedics(client);
			g_iUserFlood[client]=1;
			CreateTimer(10.0, removeFlood, client);
		} else {
			PrintToChat(client,"%cDo not flood the server!", GREEN);
		}
	}
	// Headhunters
	else if (strcmp(text[startidx], "/headhunters", false) == 0 || strcmp(text[startidx], "!headhunters", false) == 0 || strcmp(text[startidx], "headhunters", false) == 0)
	{		
		if(g_iUserFlood[client] != 1){
			saveUser(client);
			showTOPHeadHunter(client);
			g_iUserFlood[client]=1;
			CreateTimer(10.0, removeFlood, client);
		} else {
			PrintToChat(client,"%cDo not flood the server!", GREEN);
		}
	}
	return Plugin_Continue;
}

// Get My Rank
public Action:Timer_GetMyRank(Handle:timer, any:client){
	if (IsClientInGame(client))
		GetMyRank(client);
}

// Remove flood flag
public Action:removeFlood(Handle:timer, any:client){
	g_iUserFlood[client]=0;
}

// Get my rank
public GetMyRank(client){
	// Check DB
	if (g_hDB != INVALID_HANDLE)
	{
		// Check player init
		if(g_iUserInit[client] == 1){
			// Get stat data from DB
			decl String:buffer[200];
			Format(buffer, sizeof(buffer), "SELECT `score`, `kills`, `deaths`, `headshots`, `sucsides`, `revives`, `heals` FROM `ins_rank` WHERE `steamId` = '%s' LIMIT 1", g_sSteamIdSave[client]);
			if(DEBUG == 1){
				//PrintToServer("DEBUG: GetMyRank (%s)", buffer);
			}
			SQL_TQuery(g_hDB, SQLGetMyRank, buffer, client);
		}
		else
		{
			PrintToChat(client,"%cWait for system load you from database", GREEN);
		}
	}
	else
	{
		PrintToChat(client, "%cRank System is now not available", GREEN);
	}
}

// Get Top10
public showTOP(client){
	// Check DB
	if (g_hDB != INVALID_HANDLE)
	{
		// Get Top10
		decl String:buffer[200];
		//Format(buffer, sizeof(buffer), "SELECT *, (`deaths`/`kills`) / `played_time` AS rankn FROM `ins_rank` WHERE `kills` > 0 AND `deaths` > 0 ORDER BY rankn ASC LIMIT 10");
		Format(buffer, sizeof(buffer), "SELECT *, `score` AS rankn FROM `ins_rank` WHERE `score` > 0 ORDER BY rankn DESC LIMIT 10");
		if(DEBUG == 1){
			//PrintToServer("DEBUG: showTOP (%s)", buffer);
		}
		SQL_TQuery(g_hDB, SQLTopShow, buffer, client);
	} else {
		PrintToChat(client, "%cRank System is now not avilable", GREEN);
	}
}

// Get Top Medics
public showTOPMedics(client){
	// Check DB
	if (g_hDB != INVALID_HANDLE)
	{
		// Get HadHunters
		decl String:buffer[200];
		Format(buffer, sizeof(buffer), "SELECT * FROM ins_rank ORDER BY revives, heals DESC LIMIT 10");
		if(DEBUG == 1){
			//PrintToServer("DEBUG: showTOPMedics (%s)", buffer);
		}
		SQL_TQuery(g_hDB, SQLTopShowMedic, buffer, client);
	} else {
		PrintToChat(client, "%cRank System is now not avilable", GREEN);
	}
}

// Get HeadHunters
public showTOPHeadHunter(client){
	// Check DB
	if (g_hDB != INVALID_HANDLE)
	{
		// Get HadHunters
		decl String:buffer[200];
		Format(buffer, sizeof(buffer), "SELECT * FROM ins_rank ORDER BY headshots DESC LIMIT 10");
		if(DEBUG == 1){
			//PrintToServer("DEBUG: showTOPHeadHunter (%s)", buffer);
		}
		SQL_TQuery(g_hDB, SQLTopShowHS, buffer, client);
	} else {
		PrintToChat(client, "%cRank System is now not avilable", GREEN);
	}
}
// Dummy menu
public TopMenu(Handle:menu, MenuAction:action, param1, param2)
{
}

// SQL Callback (Check errors)
public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(!StrEqual("", error))
	{
		//PrintToServer("Last Connect SQL Error: %s", error);
	}
}

// Check existance of player's data. If not add new.
public SQLUserLoad(Handle:owner, Handle:hndl, const String:error[], any:client){
	if(SQL_FetchRow(hndl))
	{
		// Found player's data
		decl String:name[MAX_LINE_WIDTH];
		GetClientName( client, name, sizeof(name) );
		
		// Remove special cheracters
		ReplaceString(name, sizeof(name), "'", "");
		ReplaceString(name, sizeof(name), "<", "");
		ReplaceString(name, sizeof(name), "\"", "");
		
		// Update last active
		decl String:buffer[512];
		Format(buffer, sizeof(buffer), "UPDATE ins_rank SET nick = '%s', last_active = '%i' WHERE steamId = '%s'", name, GetTime(), g_sSteamIdSave[client]);
		if(DEBUG == 1){
			//PrintToServer("DEBUG: SQLUserLoad (%s)", buffer);
		}
		SQL_TQuery(g_hDB, SQLErrorCheckCallback, buffer);
		
		// Init completed
		g_iUserInit[client] = 1;
	}
	else
	{
		// Add new record
		decl String:name[MAX_LINE_WIDTH];
		decl String:buffer[200];
		
		// Get nickname
		GetClientName( client, name, sizeof(name) );
		
		// Remove special cheracters
		ReplaceString(name, sizeof(name), "'", "");
		ReplaceString(name, sizeof(name), "<", "");
		ReplaceString(name, sizeof(name), "\"", "");
		
		// Add new record
		Format(buffer, sizeof(buffer), "INSERT INTO ins_rank (steamId, nick, last_active) VALUES('%s', '%s', '%i')", g_sSteamIdSave[client], name, GetTime());
		if(DEBUG == 1){
			//PrintToServer("DEBUG: SQLUserLoad (%s)", buffer);
		}
		SQL_TQuery(g_hDB, SQLErrorCheckCallback, buffer);
		
		// Init completed
		g_iUserInit[client] = 1;
	}
	
	// Join message
	SQLDisplayJoinMessage(client);
}

// Display join message - Get score
void SQLDisplayJoinMessage(client)
{
	// Get current score
	decl String:buffer[512];
	Format(buffer, sizeof(buffer), "SELECT score FROM ins_rank WHERE steamId = '%s'", g_sSteamIdSave[client]);
	SQL_TQuery(g_hDB, SQLJoinMsgGetScore, buffer, client);
}

// Display join message - Get rank
public SQLJoinMsgGetScore(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		PrintToChatAll("\x04%N\x01 joined the fight.", client);
		return;
	}
	
	// Get data
	if(SQL_FetchRow(hndl))
	{
		// Get score
		new iScore = SQL_FetchInt(hndl, 0);
		
		// Get player count
		decl String:buffer[512];
		Format(buffer, sizeof(buffer),"SELECT COUNT(*) FROM ins_rank WHERE score >= %i", iScore);
		SQL_TQuery(g_hDB, SQLJoinMsgGetRank, buffer, client);
	}
	else
	{
		PrintToChatAll("\x04%N\x01 joined the fight.", client);
	}
}

// Display join message - Get player count
public SQLJoinMsgGetRank(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		PrintToChatAll("\x04%N\x01 joined the fight.", client);
		return;
	}
	
	// Get data
	if(SQL_FetchRow(hndl))
	{
		// Get score
		new iRank = SQL_FetchInt(hndl, 0);
		g_iRank[client] = iRank;
		
		// Get player count
		SQL_TQuery(g_hDB, SQLJoinMsgGetPlayerCount, "SELECT COUNT(*) FROM ins_rank", client);
	}
	else
	{
		PrintToChatAll("\x04%N\x01 joined the fight.", client);
	}
}
// Display join message - Print to chat all
public SQLJoinMsgGetPlayerCount(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		PrintToChatAll("\x04%N\x01 joined the fight.", client);
		return;
	}
	
	// Get data
	if(SQL_FetchRow(hndl))
	{
		// Get player count
		new iPlayerCount = SQL_FetchInt(hndl, 0);
		
		// Display join message
		PrintToChatAll("\x04%N\x01 joined the fight. \x05(Rank: %i of %i)", client, g_iRank[client], iPlayerCount);
		//PrintToServer("%N joined the fight. (Rank: %i of %i)", client, g_iRank[client], iPlayerCount);
	}
	else
	{
		PrintToChatAll("\x04%N\x01 joined the fight.", client);
	}
}

// Save stats
public SQLUserSave(Handle:owner, Handle:hndl, const String:error[], any:client){
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	
	// Declare variables
	decl QueryReadRow_SCORE;
	decl QueryReadRow_KILL;
	decl QueryReadRow_DEATHS;
	decl QueryReadRow_HEADSHOTS;
	decl QueryReadRow_SUCSIDES;
	decl QueryReadRow_REVIVES;
	decl QueryReadRow_HEALS;
	decl QueryReadRow_PTIME;
	
	// Get record
	if(SQL_FetchRow(hndl)) 
	{
		
		// Calculate score
		QueryReadRow_SCORE=GetPlayerScore(client) - g_iStatScore[client];
		if (QueryReadRow_SCORE < 0) QueryReadRow_SCORE=0;
		QueryReadRow_SCORE=SQL_FetchInt(hndl,3) + QueryReadRow_SCORE + (g_iStatRevives[client] * 20) + (g_iStatHeals[client] * 10);
		
		QueryReadRow_KILL=SQL_FetchInt(hndl,4) + g_iStatKills[client];
		QueryReadRow_DEATHS=SQL_FetchInt(hndl,5) + g_iStatDeaths[client];
		QueryReadRow_HEADSHOTS=SQL_FetchInt(hndl,6) + g_iStatHeadShots[client];
		QueryReadRow_SUCSIDES=SQL_FetchInt(hndl,7) + g_iStatSuicides[client];
		QueryReadRow_REVIVES=SQL_FetchInt(hndl,8) + g_iStatRevives[client];
		QueryReadRow_HEALS=SQL_FetchInt(hndl,9) + g_iStatHeals[client];
		QueryReadRow_PTIME=SQL_FetchInt(hndl,11) + GetTime() - g_iUserPtime[client];
		
		// Reset stats
		g_iStatScore[client] = GetPlayerScore(client);
		g_iStatKills[client] = 0;
		g_iStatDeaths[client] = 0;
		g_iStatHeadShots[client] = 0;
		g_iStatSuicides[client] = 0;
		g_iStatRevives[client] = 0;
		g_iStatHeals[client] = 0;
		g_iUserPtime[client] = GetTime();
		
		// Update database
		decl String:buffer[512];
		Format(buffer, sizeof(buffer), "UPDATE ins_rank SET score = '%i', kills = '%i', deaths = '%i', headshots = '%i', sucsides = '%i', revives = '%i', heals = '%i', played_time = '%i' WHERE steamId = '%s'", QueryReadRow_SCORE, QueryReadRow_KILL, QueryReadRow_DEATHS, QueryReadRow_HEADSHOTS, QueryReadRow_SUCSIDES, QueryReadRow_REVIVES, QueryReadRow_HEALS, QueryReadRow_PTIME, g_sSteamIdSave[client]);
		
		if(DEBUG == 1){
			//PrintToServer("DEBUG: SQLUserSave (%s)", buffer);
		}
		
		SQL_TQuery(g_hDB, SQLErrorCheckCallback, buffer);
	}
}

// Get my rank
public SQLGetMyRank(Handle:owner, Handle:hndl, const String:error[], any:client){
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
    
	// Declare variables
	decl RAscore;
	decl RAkills;
	decl RAdeaths;
	decl RAheadshots;
	decl RAsucsides;
	decl RArevives;
	decl RAheals;

	// Get record
	if(SQL_FetchRow(hndl)) 
	{
		// Get stats
		RAscore=SQL_FetchInt(hndl, 0);
		RAkills=SQL_FetchInt(hndl, 1);
		RAdeaths=SQL_FetchInt(hndl, 2);
		RAheadshots=SQL_FetchInt(hndl, 3);
		RAsucsides=SQL_FetchInt(hndl, 4);
		RArevives=SQL_FetchInt(hndl, 5);
		RAheals=SQL_FetchInt(hndl, 6);
		
		decl String:buffer[512];
		//test
		// 0.00027144
		//STEAM_0:1:13462423
		//Format(buffer, sizeof(buffer), "SELECT ((`deaths`/`kills`)/`played_time`) AS rankn FROM `ins_rank` WHERE (`kills` > 0 AND `deaths` > 0) AND ((`deaths`/`kills`)/`played_time`) < (SELECT ((`deaths`/`kills`)/`played_time`) FROM `ins_rank` WHERE steamId = '%s' LIMIT 1) AND `steamId` != '%s' ORDER BY rankn ASC", g_sSteamIdSave[client], g_sSteamIdSave[client]);
		
		// Get rank
		Format(buffer, sizeof(buffer), "SELECT COUNT(*) FROM ins_rank WHERE score >= %i", RAscore);
		SQL_TQuery(g_hDB, SQLGetRank, buffer, client);
		
		PrintToChat(client,"%cScore: %i | Kills: %i | Revives: %i | Heals: %i | Deaths: %i | Headshots: %i | Sucsides: %i", GREEN, RAscore, RAkills, RArevives, RAheals, RAdeaths, RAheadshots, RAsucsides);
	} else {
		PrintToChat(client, "%cYour rank is not avlilable!", GREEN);
	}
}

// Get my rank - Get rank
public SQLGetRank(Handle:owner, Handle:hndl, const String:error[], any:client){
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	
	// Get record
	if(SQL_FetchRow(hndl)) 
	{
		// Get rank
		new iRank = SQL_FetchInt(hndl, 0);
		g_iRank[client] = iRank;
		
		// Get player count
		SQL_TQuery(g_hDB, SQLShowRankToChat, "SELECT COUNT(*) FROM ins_rank", client);
	} else {
		PrintToChat(client, "%cYour rank is not avlilable!", GREEN);
	}
}

// Get my rank - Get player count
public SQLShowRankToChat(Handle:owner, Handle:hndl, const String:error[], any:client){
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	
	// Get record
	if(SQL_FetchRow(hndl)) 
	{
		// Get player count
		new iPlayerCount = SQL_FetchInt(hndl, 0);
		
		// Display rank
		PrintToChat(client,"%cYour rank is: %i (of %i).", GREEN, g_iRank[client], iPlayerCount);
	} else {
		PrintToChat(client, "%cYour rank is not avlilable!", GREEN);
	}
}

// Show top 10
public SQLTopShow(Handle:owner, Handle:hndl, const String:error[], any:client){
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	
	// Init panel
	new Handle:hPanel = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
	new String:text[128];
	Format(text,127,"Top 10 Players");
	SetPanelTitle(hPanel,text);
	
	// Init variables
	decl row;
	decl String:name[64];
	decl score;
	decl kills;
	decl deaths;
	
	// Check result
	if (SQL_HasResultSet(hndl))
	{
		// Loop players
		while (SQL_FetchRow(hndl))
		{
			row++;
			// Nickname
			SQL_FetchString(hndl, 2, name, sizeof(name));
			
			// Stats
			score=SQL_FetchInt(hndl,3);
			kills=SQL_FetchInt(hndl,4);
			deaths=SQL_FetchInt(hndl,5);
			
			// Set text
			Format(text,127,"[%d] %s", row, name);
			DrawPanelText(hPanel, text);
			Format(text,127," - Score: %i | Kills: %i | Deaths: %i", score, kills, deaths);
			DrawPanelText(hPanel, text);
		}
	} else {
			Format(text,127,"TOP 10 is empty!");
			DrawPanelText(hPanel, text);
	}
	
	// Draw panel
	DrawPanelItem(hPanel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	Format(text,59,"Exit");
	DrawPanelItem(hPanel, text);
	
	SendPanelToClient(hPanel, client, TopMenu, 20);

	CloseHandle(hPanel);
}

// Show Top medics
public SQLTopShowMedic(Handle:owner, Handle:hndl, const String:error[], any:client){
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	
	// Init panel
	new Handle:hPanel = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
	new String:text[128];
	Format(text,127,"Top Medics");
	SetPanelTitle(hPanel,text);
	
	// Init variables
	decl row;
	decl String:name[64];
	decl revives;
	decl heals;
	
	// Check result
	if (SQL_HasResultSet(hndl))
	{
		// Loop players
		while (SQL_FetchRow(hndl))
		{
			row++;
			// Nickname
			SQL_FetchString(hndl, 2, name, sizeof(name));
			
			// Stats
			revives=SQL_FetchInt(hndl,8);
			heals=SQL_FetchInt(hndl,9);
			
			// Set text
			Format(text,127,"[%d] %s", row, name);
			DrawPanelText(hPanel, text);
			Format(text,127," - Revives: %i | Heals: %i", revives, heals);
			DrawPanelText(hPanel, text);
		}
	} else {
			Format(text,127,"TOP Medics is empty!");
			DrawPanelText(hPanel, text);
	}
	
	// Draw panel
	DrawPanelItem(hPanel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	Format(text,59,"Exit");
	DrawPanelItem(hPanel, text);
	
	SendPanelToClient(hPanel, client, TopMenu, 20);

	CloseHandle(hPanel);
}
// Show Headhunters
public SQLTopShowHS(Handle:owner, Handle:hndl, const String:error[], any:client){
	// Check DB
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		//PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	
	// Init panel
	new Handle:hPanel = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
	new String:text[128];
	Format(text,127,"Top 10 Headhunters");
	SetPanelTitle(hPanel,text);
	
	// Init variables
	decl row;
	decl String:name[64];
	decl shoths;
	decl ptimed;
	decl String:textime[64];
	
	// Check result
	if (SQL_HasResultSet(hndl))
	{
		// Loop players
		while (SQL_FetchRow(hndl))
		{
			row++;
			// Nickname
			SQL_FetchString(hndl, 2, name, sizeof(name));
			
			// Stats
			shoths=SQL_FetchInt(hndl,6);
			ptimed=SQL_FetchInt(hndl,11);
			
			// Calc
			if(ptimed <= 3600){
				Format(textime,63,"%i m.", ptimed / 60);
			} else if(ptimed <= 43200){
				Format(textime,63,"%i h.", ptimed / 60 / 60);
			} else if(ptimed <= 1339200){
				Format(textime,63,"%i d.", ptimed / 60 / 60 / 12);
			} else {
				Format(textime,63,"%i mo.", ptimed / 60 / 60 / 12 / 31);
			}
			
			// Set text
			Format(text,127,"[%d] %s", row, name);
			DrawPanelText(hPanel, text);
			Format(text,127," - HS: %i - In Time: %s", shoths, textime);
			DrawPanelText(hPanel, text);
		}
	} else {
		Format(text,127,"TOP Headhunters is empty!");
		DrawPanelText(hPanel, text);
	}
	
	// Display panel
	DrawPanelItem(hPanel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	Format(text,59,"Exit");
	DrawPanelItem(hPanel, text);
	
	SendPanelToClient(hPanel, client, TopMenu, 20);

	CloseHandle(hPanel);
}

/*
PrintQueryData(Handle:query)
{
	if (!SQL_HasResultSet(query))
	{
		//PrintToServer("Query Handle %x has no results", query)
		return
	}
	
	new rows = SQL_GetRowCount(query)
	new fields = SQL_GetFieldCount(query)
	
	decl String:fieldNames[fields][32]
	//PrintToServer("Fields: %d", fields)
	for (new i=0; i<fields; i++)
	{
		SQL_FieldNumToName(query, i, fieldNames[i], 32)
		//PrintToServer("-> Field %d: \"%s\"", i, fieldNames[i])
	}
	
	//PrintToServer("Rows: %d", rows)
	decl String:result[255]
	new row
	while (SQL_FetchRow(query))
	{
		row++
		//PrintToServer("Row %d:", row)
		for (new i=0; i<fields; i++)
		{
			SQL_FetchString(query, i, result, sizeof(result))
			//PrintToServer(" [%s] %s", fieldNames[i], result)
		}
	}
}
*/


/*
########################LUA HEALING INTEGRATION######################
#	This portion of the script adds in health packs from Lua 		#
##############################START##################################
#####################################################################
*/
public Action:Event_GrenadeThrown(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new nade_id = GetEventInt(event, "entityid");
	if (nade_id > -1 && client > -1)
	{
		if (IsPlayerAlive(client))
		{
			decl String:grenade_name[32];
			GetEntityClassname(nade_id, grenade_name, sizeof(grenade_name));
			if (StrEqual(grenade_name, "healthkit"))
			{
				switch(GetRandomInt(1, 18))
				{
					case 1: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/need_backup1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 2: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/need_backup2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 3: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/need_backup3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 4: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/holdposition2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 5: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/holdposition3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 6: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/moving2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 7: EmitSoundToAll("player/voice/radial/security/leader/suppressed/backup3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 8: EmitSoundToAll("player/voice/radial/security/leader/suppressed/holdposition1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 9: EmitSoundToAll("player/voice/radial/security/leader/suppressed/holdposition2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 10: EmitSoundToAll("player/voice/radial/security/leader/suppressed/holdposition3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 11: EmitSoundToAll("player/voice/radial/security/leader/suppressed/holdposition4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 12: EmitSoundToAll("player/voice/radial/security/leader/suppressed/moving3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 13: EmitSoundToAll("player/voice/radial/security/leader/suppressed/ontheway1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 14: EmitSoundToAll("player/voice/security/command/leader/located4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 15: EmitSoundToAll("player/voice/security/command/leader/setwaypoint1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 16: EmitSoundToAll("player/voice/security/command/leader/setwaypoint2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 17: EmitSoundToAll("player/voice/security/command/leader/setwaypoint3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 18: EmitSoundToAll("player/voice/security/command/leader/setwaypoint4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
				}
			}
		}
	}
}

//Healthkit Start

public OnEntityDestroyed(entity)
{
	if (entity > MaxClients)
	{
		decl String:classname[255];
		GetEntityClassname(entity, classname, 255);
		if (StrEqual(classname, "healthkit"))
		{
			//StopSound(entity, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		}
    }
}

public OnEntityCreated(entity, const String:classname[])
{
	if (StrEqual(classname, "healthkit"))
	{
		new Handle:hDatapack;

		g_healthPack_Amount[entity] = g_medpack_health_amt;
		CreateDataTimer(Healthkit_Timer_Tickrate, Healthkit, hDatapack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(hDatapack, entity);
		WritePackFloat(hDatapack, GetGameTime()+Healthkit_Timer_Timeout);
		g_fLastHeight[entity] = -9999.0;
		g_iTimeCheckHeight[entity] = -9999;
		SDKHook(entity, SDKHook_VPhysicsUpdate, HealthkitGroundCheck);
		CreateTimer(0.1, HealthkitGroundCheckTimer, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (StrEqual(classname, "grenade_m67") || StrEqual(classname, "grenade_f1"))
	{
		CreateTimer(0.5, GrenadeScreamCheckTimer, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (StrEqual(classname, "grenade_molotov") || StrEqual(classname, "grenade_anm14"))
		CreateTimer(0.2, FireScreamCheckTimer, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
public Action:FireScreamCheckTimer(Handle:timer, any:entity)
{
	new Float:fGrenOrigin[3];
	new Float:fPlayerOrigin[3];
	new Float:fPlayerEyeOrigin[3];
	new owner;
	if (IsValidEntity(entity) && entity > 0)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fGrenOrigin);
		owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	}
	else
		KillTimer(timer);


	
 
	for (new client = 1;client <= MaxClients;client++)
	{
		if (client <= 0 || !IsClientInGame(client) || !IsClientConnected(client))
			continue;
		if (owner <= 0 || !IsClientInGame(owner) || !IsClientConnected(owner))
			continue;
		if (IsFakeClient(client))
			continue;

		if (IsPlayerAlive(client) && GetClientTeam(client) == 2 && GetClientTeam(owner) == 3)
		{

			GetClientEyePosition(client, fPlayerEyeOrigin);
			GetClientAbsOrigin(client,fPlayerOrigin);
			//new Handle:trace = TR_TraceRayFilterEx(fPlayerEyeOrigin, fGrenOrigin, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter); 

			if (GetVectorDistance(fPlayerOrigin, fGrenOrigin) <= 300 &&  g_plyrFireScreamCoolDown[client] <= 0)// && TR_DidHit(trace) && fGrenOrigin[2] > 0)
			{
				//PrintToServer("SCREAM FIRE");
				PlayerFireScreamRand(client);
				new fRandomInt = GetRandomInt(20, 30);
				g_plyrFireScreamCoolDown[client] = fRandomInt;
				//CloseHandle(trace); 
			}
		}
	}

	if (!IsValidEntity(entity) || !(entity > 0))
		KillTimer(timer);
}
public Action:GrenadeScreamCheckTimer(Handle:timer, any:entity)
{
	new Float:fGrenOrigin[3];
	new Float:fPlayerOrigin[3];
	new Float:fPlayerEyeOrigin[3];
	new owner;
	if (IsValidEntity(entity) && entity > 0)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fGrenOrigin);
		owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	}
	else
		KillTimer(timer);

	for (new client = 1;client <= MaxClients;client++)
	{
		if (client <= 0 || !IsClientInGame(client) || !IsClientConnected(client))
			continue;

		if (IsFakeClient(client))
			continue;

		if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2 && GetClientTeam(owner) == 3)
		{

			GetClientEyePosition(client, fPlayerEyeOrigin);
			GetClientAbsOrigin(client,fPlayerOrigin);			
			//new Handle:trace = TR_TraceRayFilterEx(fPlayerEyeOrigin, fGrenOrigin, MASK_VISIBLE, RayType_EndPoint, Base_TraceFilter); 

			if (GetVectorDistance(fPlayerOrigin, fGrenOrigin) <= 240 &&  g_plyrGrenScreamCoolDown[client] <= 0)// && TR_DidHit(trace) && fGrenOrigin[2] > 0)
			{
				PlayerGrenadeScreamRand(client);
				new fRandomInt = GetRandomInt(6, 12);
				g_plyrGrenScreamCoolDown[client] = fRandomInt;
				//CloseHandle(trace); 
			} 
		}
	}

	if (!IsValidEntity(entity) || !(entity > 0))
		KillTimer(timer);
}
public Action:HealthkitGroundCheck(entity, activator, caller, UseType:type, Float:value)
{
	new Float:fOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
	new iRoundHeight = RoundFloat(fOrigin[2]);
	if (iRoundHeight != g_iTimeCheckHeight[entity])
	{
		g_iTimeCheckHeight[entity] = iRoundHeight;
		g_fTimeCheck[entity] = GetGameTime();
	}
}

public Action:HealthkitGroundCheckTimer(Handle:timer, any:entity)
{
	if (entity > MaxClients && IsValidEntity(entity))
	{
		new Float:fGameTime = GetGameTime();
		if (fGameTime-g_fTimeCheck[entity] >= 1.0)
		{
			new Float:fOrigin[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
			new iRoundHeight = RoundFloat(fOrigin[2]);
			if (iRoundHeight == g_iTimeCheckHeight[entity])
			{
				g_fTimeCheck[entity] = GetGameTime();
				SDKUnhook(entity, SDKHook_VPhysicsUpdate, HealthkitGroundCheck);
				SDKHook(entity, SDKHook_VPhysicsUpdate, OnEntityPhysicsUpdate);
				KillTimer(timer);
			}
		}
	}
	else KillTimer(timer);
}

public Action:OnEntityPhysicsUpdate(entity, activator, caller, UseType:type, Float:value)
{
	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
}

public Action:Healthkit(Handle:timer, Handle:hDatapack)
{
	ResetPack(hDatapack);
	new entity = ReadPackCell(hDatapack);
	new Float:fEndTime = ReadPackFloat(hDatapack);
	new Float:fGameTime = GetGameTime();
	//PrintToServer("fGameTime %i",fGameTime);
	//PrintToServer("g_healthPack_Amount %i",g_healthPack_Amount[entity]);
	if (entity > 0 && IsValidEntity(entity) && fGameTime > fEndTime)
	{
		RemoveHealthkit(entity);
		KillTimer(timer);
		return Plugin_Stop;
	}
	if (g_healthPack_Amount[entity] > 0)
	{	
			//PrintToServer("DEBUG 1");
		if (entity > 0 && IsValidEntity(entity))
		{
			//PrintToServer("DEBUG 2");
			new Float:fOrigin[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
			if (g_fLastHeight[entity] == -9999.0)
			{
				g_fLastHeight[entity] = 0.0;
				//Play sound
				
				//PrintToServer("DEBUG 3");
			}
			fOrigin[2] += 1.0;
			TE_SetupBeamRingPoint(fOrigin, 1.0, Healthkit_Radius*1.95, g_iBeaconBeam, g_iBeaconHalo, 0, 30, 5.0, 3.0, 0.0, {0, 200, 0, 255}, 1, (FBEAM_FADEOUT));
			//void TE_SetupBeamRingPoint(const float center[3], float Start_Radius, float End_Radius, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float Amplitude, const int Color[4], int Speed, int Flags)
			TE_SendToAll();
			fOrigin[2] -= 16.0;
			if (fOrigin[2] != g_fLastHeight[entity])
			{
				g_fLastHeight[entity] = fOrigin[2];
			}
			else
			{
				new Float:fAng[3];
				GetEntPropVector(entity, Prop_Send, "m_angRotation", fAng);
				if (fAng[1] > 89.0 || fAng[1] < -89.0)
					fAng[1] = 90.0;
				if (fAng[2] > 89.0 || fAng[2] < -89.0)
				{
					fAng[2] = 0.0;
					fOrigin[2] -= 6.0;
					TeleportEntity(entity, fOrigin, fAng, Float:{0.0, 0.0, 0.0});
					fOrigin[2] += 6.0;
					EmitSoundToAll("ui/sfx/cl_click.wav", entity, SNDCHAN_STATIC, _, _, 1.0);
				}
			}
			for (new client = 1;client <= MaxClients;client++)
			{
				if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
				{
					//non medic area heal self
					if (!(StrContains(g_client_last_classstring[client], "medic") > -1))
					{ 
						decl Float:fPlayerOrigin[3];
						GetClientEyePosition(client, fPlayerOrigin);
						if (GetVectorDistance(fPlayerOrigin, fOrigin) <= Healthkit_Radius)
						{
									//PrintToServer("DEBUG 5");
							//g_medpack_health_amt
							new Handle:hData = CreateDataPack();
							WritePackCell(hData, entity);
							WritePackCell(hData, client);
							//fOrigin[2] += 6.0;
							//new Handle:trace = TR_TraceRayFilterEx(fPlayerOrigin, fOrigin, MASK_SOLID, RayType_EndPoint, Filter_ClientSelf, hData);
							CloseHandle(hData);
							new isMedicNearby = Check_NearbyMedics(client);
							//if (!TR_DidHit(trace))
							if (isMedicNearby)
							{	
									//PrintToServer("DEBUG 4");
								new iHealth = GetClientHealth(client);
								//new iMaxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
								//new iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
								if (iHealth < 100)
								{
									//PrintToServer("DEBUG 6");
									iHealth += g_iHeal_amount_paddles;
									g_healthPack_Amount[entity] -= g_iHeal_amount_paddles;
									if (iHealth >= 100)
									{
										//EmitSoundToAll("Lua_sounds/healthkit_complete.wav", client, SNDCHAN_STATIC, _, _, 1.0);
										iHealth = 100;
										PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
										PrintHintText(client, "A medic assisted in healing you (HP: %i)", iHealth);
									}
									else 
									{
										PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
										PrintHintText(client, "Medic area healing you (HP: %i)", iHealth);
										switch(GetRandomInt(1, 6))
										{
											case 1: EmitSoundToAll("weapons/universal/uni_crawl_l_01.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											case 2: EmitSoundToAll("weapons/universal/uni_crawl_l_04.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											case 3: EmitSoundToAll("weapons/universal/uni_crawl_l_02.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											case 4: EmitSoundToAll("weapons/universal/uni_crawl_r_03.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											case 5: EmitSoundToAll("weapons/universal/uni_crawl_r_05.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											case 6: EmitSoundToAll("weapons/universal/uni_crawl_r_06.wav", client, SNDCHAN_STATIC, _, _, 1.0);
										}
									}

									SetEntityHealth(client, iHealth);
								}
							}
							else
							{
									//PrintToServer("DEBUG 7");
								//Get weapon
								decl String:sWeapon[32];
								new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
								if (ActiveWeapon < 0)
									continue;

								GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
								new iHealth = GetClientHealth(client);
								if ((StrContains(sWeapon, "weapon_knife") > -1))
								{
									//PrintToServer("DEBUG 8");
									if (iHealth < g_nonMedicHealSelf_max)
									{
									//PrintToServer("DEBUG 9");
										iHealth += g_nonMedicHeal_amount;
										g_healthPack_Amount[entity] -= g_nonMedicHeal_amount;
										if (iHealth >= g_nonMedicHealSelf_max)
										{
									//PrintToServer("DEBUG 10");
											//EmitSoundToAll("Lua_sounds/healthkit_complete.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											iHealth = g_nonMedicHealSelf_max;
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
										}
										else 
										{
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "Healing Self (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
										}

										SetEntityHealth(client, iHealth);
									}
									else 
									{
										PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
										PrintHintText(client, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
									}

								}
								else if (iHealth < g_nonMedicHealSelf_max && !(StrContains(sWeapon, "weapon_knife") > -1))
								{
										PrintHintText(client, "No medics nearby! Pull knife out to heal! (HP: %i)", iHealth);
								}
							}
							
						}
					} //Medic assist area heal and self heal
					else if ((StrContains(g_client_last_classstring[client], "medic") > -1))
					{
						 decl Float:fPlayerOrigin[3];
						GetClientEyePosition(client, fPlayerOrigin);
						if (GetVectorDistance(fPlayerOrigin, fOrigin) <= Healthkit_Radius)
						{
							//g_medpack_health_amt
							new Handle:hData = CreateDataPack();
							WritePackCell(hData, entity);
							WritePackCell(hData, client);
							fOrigin[2] += 32.0;
							//new Handle:trace = TR_TraceRayFilterEx(fPlayerOrigin, fOrigin, MASK_SOLID, RayType_EndPoint, Filter_ClientSelf, hData);
							CloseHandle(hData);

							new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
							if (ActiveWeapon < 0)
								continue;

							// Get weapon class name
							decl String:sWeapon[32];
							GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
							new bool:bCanHealPaddle = false;
							if (((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1)))
							{
								//PrintToServer("DEBUG 3");
								new iHealth = GetClientHealth(client);
								//new iMaxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
								//new iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
								if (Check_NearbyMedics(client))
								{
									if (iHealth < 100)
									{
										iHealth += g_iHeal_amount_paddles;
										g_healthPack_Amount[entity] -= g_iHeal_amount_paddles;
										if (iHealth >= 100)
										{
											//EmitSoundToAll("Lua_sounds/healthkit_complete.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											iHealth = 100;
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "A medic assisted in healing you (HP: %i)", iHealth);
										}
										else 
										{
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "Self area healing (HP: %i)", iHealth);
										}

										SetEntityHealth(client, iHealth);
									}
								}
								else
								{
									if (iHealth < g_medicHealSelf_max)
									{
										iHealth += g_iHeal_amount_paddles;
										g_healthPack_Amount[entity] -= g_iHeal_amount_paddles;
										if (iHealth >= g_medicHealSelf_max)
										{
											//EmitSoundToAll("Lua_sounds/healthkit_complete.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											iHealth = g_medicHealSelf_max;
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "You area healed yourself (HP: %i) | MAX: %i", iHealth, g_medicHealSelf_max);
										}
										else 
										{
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "Self area healing (HP: %i) | MAX %i", iHealth, g_medicHealSelf_max);
										}
									}
									else 
									{
										PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
										PrintHintText(client, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_medicHealSelf_max);
									}
								}
							}
						}
					}
				}
			}
		}
		else
		{
			//PrintToServer("DEBUG 4");
			RemoveHealthkit(entity);
			KillTimer(timer);
		}
	}
	else if (g_healthPack_Amount[entity] <= 0)
	{
			//PrintToServer("DEBUG 5");
		RemoveHealthkit(entity);
		KillTimer(timer);
	}
}




public bool:Filter_ClientSelf(entity, contentsMask, any:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	new player = ReadPackCell(data);
	if (entity != client && entity != player)
		return true;
	return false;
}

public RemoveHealthkit(entity)
{
	if (entity > MaxClients && IsValidEntity(entity))
	{
		//StopSound(entity, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		//EmitSoundToAll("soundscape/emitters/oneshot/radio_explode.ogg", entity, SNDCHAN_STATIC, _, _, 1.0);
		
		//new dissolver = CreateEntityByName("env_entity_dissolver");
		//if (dissolver != -1)
		//{
			// DispatchKeyValue(dissolver, "dissolvetype", Healthkit_Remove_Type);
			// DispatchKeyValue(dissolver, "magnitude", "1");
			// DispatchKeyValue(dissolver, "target", "!activator");
			// AcceptEntityInput(dissolver, "Dissolve", entity);
			// AcceptEntityInput(dissolver, "Kill");

			AcceptEntityInput(entity, "Kill");
		//}
	}
}

public Check_NearbyMedics(client)
{
	for (new friendlyMedic = 1; friendlyMedic <= MaxClients; friendlyMedic++)
	{
		if (IsClientConnected(friendlyMedic) && IsClientInGame(friendlyMedic) && !IsFakeClient(friendlyMedic))
		{
			//PrintToServer("Medic 1");
			//new team = GetClientTeam(friendlyMedic);
			if (IsPlayerAlive(friendlyMedic) && (StrContains(g_client_last_classstring[friendlyMedic], "medic") > -1) && client != friendlyMedic)
			{
			//PrintToServer("Medic 2");
				//Get position of bot and prop
				new Float:plyrOrigin[3];
				new Float:medicOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(client,plyrOrigin);
				GetClientAbsOrigin(friendlyMedic,medicOrigin);
				//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(medicOrigin,plyrOrigin);
				
				new ActiveWeapon = GetEntPropEnt(friendlyMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;

				// Get weapon class name
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

			//PrintToServer("Medic 3");
				new bool:bCanHealPaddle = false;
				if ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_healthkit") > -1))
				{
			//PrintToServer("Medic 4");
					bCanHealPaddle = true;
				}
				if (fDistance <= Healthkit_Radius && bCanHealPaddle)
				{
			//PrintToServer("Medic 5");
					return true;
				}
			}
		}
	}
	return false;
}

//This is to award nearby medics that participate in reviving a player
public Check_NearbyMedicsRevive(client, iInjured)
{
	for (new friendlyMedic = 1; friendlyMedic <= MaxClients; friendlyMedic++)
	{
		if (IsClientConnected(friendlyMedic) && IsClientInGame(friendlyMedic) && !IsFakeClient(friendlyMedic))
		{
			//PrintToServer("Medic 1");
			//new team = GetClientTeam(friendlyMedic);
			if (IsPlayerAlive(friendlyMedic) && (StrContains(g_client_last_classstring[friendlyMedic], "medic") > -1) && client != friendlyMedic)
			{
				//PrintToServer("Medic 2");
				//Get position of bot and prop
				new Float:medicOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(friendlyMedic,medicOrigin);
				//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(medicOrigin,g_fRagdollPosition[iInjured]);
				
				new ActiveWeapon = GetEntPropEnt(friendlyMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;

				// Get weapon class name
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

				//PrintToServer("Medic 3");
				new bool:bCanHealPaddle = false;
				if ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1))
				{
					//PrintToServer("Medic 4");
					bCanHealPaddle = true;
				}

				new Float:fReviveDistance = 65.0;
				if (fDistance <= fReviveDistance && bCanHealPaddle)
				{
						decl String:woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "critical wound";
						decl String:sBuf[255];
						// Chat to all
						Format(sBuf, 255,"\x05%N\x01 revived(assisted) \x03%N from a %s", friendlyMedic, iInjured, woundType);
						PrintToChatAll("%s", sBuf);
						
						// Hint to friendlyMedic
						Format(sBuf, 255,"You revived(assisted) %N from a %s", iInjured, woundType);
						PrintHintText(friendlyMedic, "%s", sBuf);
						
						// Add kill bonus to friendlyMedic
						new iBonus = GetConVarInt(sm_revive_bonus);
						new iScore = GetClientFrags(friendlyMedic) + iBonus;
						SetEntProp(friendlyMedic, Prop_Data, "m_iFrags", iScore);
						
						/////////////////////////
						// Rank System
						g_iStatRevives[friendlyMedic]++;
						//
						/////////////////////////
						
						// Add score bonus to friendlyMedic (doesn't work)
						iScore = GetPlayerScore(friendlyMedic);
						//PrintToServer("[SCORE] score: %d", iScore + 10);
						SetPlayerScore(friendlyMedic, iScore + 10);

						decl String:sBuf2[255];
						if (iBonus > 1)
							Format(sBuf2, 255,"Awarded %i kills and %i score for assisted revive", iBonus, 10);
						else
							Format(sBuf2, 255,"Awarded %i kill and %i score for assisted revive", iBonus, 10);
						
						PrintToChat(friendlyMedic, "%s", sBuf2);
				}
			}
		}
	}
}
/*
########################LUA HEALING INTEGRATION######################
#	This portion of the script adds in health packs from Lua 		#
##############################END####################################
#####################################################################
*/




stock Effect_SetMarkerAtPos(client,Float:pos[3],Float:intervall,color[4]){

	
	/*static Float:lastMarkerTime[MAXPLAYERS+1] = {0.0,...};
	new Float:gameTime = GetGameTime();
	
	if(lastMarkerTime[client] > gameTime){
		
		//no update cuz its already up2date
		return;
	}
	
	lastMarkerTime[client] = gameTime+intervall;*/
	
	new Float:start[3];
	new Float:end[3];
	//decl Float:worldMaxs[3];
	
	//World_GetMaxs(worldMaxs);
	
	end[0] = start[0] = pos[0];
	end[1] = start[1] = pos[1];
	end[2] = start[2] = pos[2];
	end[2] += 10000.0;
	start[2] += 5.0;
	
	//intervall -= 0.1;
	
	for(new effect=1;effect<=2;effect++){
		
		
		//blue team
		switch(effect){
			
			case 1:{
				TE_SetupBeamPoints(start, end, g_iBeaconBeam, 0, 0, 20, intervall, 1.0, 50.0, 0, 0.0, color, 0);
			}
			case 2:{
				TE_SetupBeamRingPoint(start, 50.0, 50.1, g_iBeaconBeam, g_iBeaconHalo, 0, 10, intervall, 2.0, 0.0, color, 10, 0);
			}
		}
		
		TE_SendToClient(client);
	}
}