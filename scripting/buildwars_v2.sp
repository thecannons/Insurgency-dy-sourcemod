/*
	==================================================================================================================================================
	Revision: v2.0.8
	==================================================================================================================================================
	Plugin has been re-written with the basics of BuildWars v3, albeit an older version.
	- Configuration files are now updated each map if they've been modified.
	- Modified the method used to load chat commands to be slightly more efficient, not that it matters.
	==================================================================================================================================================

	==================================================================================================================================================
	Version 2.1.0
	==================================================================================================================================================
	- Important Changes!
	--- Now compatible with SM ~1.7. Apparently older verions would cause crashes/issues/voodoo.
	--- Now utilizes GetClientAuthId over GetClientAuthString as the latter has been depreciated.
	------ Important! Data saved with old method (STEAM:x:x:xxxxxxx) will no longer load!
	------ Data is now saved as a SteamID64 (uint64), ex: 76561197968573709. Screw your data! Or convert it yourself!
	--- Now optionally compiles with morecolors.inc; defaults to basic SM if include doesn't exist.
	--- Basic CS:GO Support! It launches, that's enough for me, as this isn't the current plugin branch.
	--- The "Back" option has been added back to all menus. Sorry CS:GO users!

	- Convar Changes!
	--- sm_buildwars_version has been replaced with buildwars_version, to match the other versions of the plugin.

	- Configuration Changes!
	--- Now requires AutoExecConfig during compile time, allowing the .cfg file to update when/if necessary.
	--- Now consists of buildwars_v2.css.cfg and buildwars_v2.csgo.cfg, instead of the original sm_buildwars_v2.cfg.
	--- sm_buildwars_cmds.ini has been replaced with sm_buildwars_cmds.css.ini and sm_buildwars_cmds.csgo.ini.
	--- sm_buildwars_props.ini has been replaced with sm_buildwars_props.css.ini and sm_buildwars_props.csgo.ini.

	- Translation Changes!
	--- Now consists of buildwars_v2.css.phrases.txt and buildwars_v2.csgo.phrases.txt instead of the original sm_buildwars_v2.phrases.txt.
	==================================================================================================================================================
*/

/*
	Overrides:
	--------------------
	- bw_access_admin - required to access the "admin" benefits provided by Build Wars. ("Default: 'e')
	- bw_access_supporter - required to access the "supporter" benefits provided of Build Wars. ("Default: 'r')
	- bw_access_base - required to access the base feature provided by Build Wars. ("Default: 'r')

	Restrictions:
	--------------------
	- bw_admin_delete - Allows the user to delete props belonging to other individuals. ("Default: 'b')
	- bw_admin_teleport - Allows the user to teleport other individuals. ("Default: 'b')
	- bw_admin_color - Allows the user to color props belonging to other individuals. ("Default: 'b')
	- bw_admin_target - Allows the user to target @t/@ct/@all with delete/teleport/color. ("Default: 'e')
*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <autoexecconfig>
#undef REQUIRE_EXTENSIONS
#tryinclude <morecolors>
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION "2.1.0"

//Hardcoded limit to the number of props available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_PROPS 128

//Hardcoded limit to the number of colors available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_COLORS 64

//Hardcoded limit to the number of degrees available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_ROTATIONS 16

//Hardcoded limit to the number of positions available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_POSITIONS 16

//Hardcoded limit to the number of commands available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_COMMANDS 32

//Hardcoded limit to the number of teleport destinations available for maps in build wars (saves memory, increase to allow more).
#define MAX_TELEPORT_ENDS 64

//The maximum amount of entities the current Source Engine will support, used for global iEntity arrays.
#define MaxEntities 2048

//Cvars
#define CVAR_COUNT 50
#define CVAR_ENABLED 0
#define CVAR_DISSOLVE 1
#define CVAR_HELP 2
#define CVAR_ADVERT 3
#define CVAR_DEFAULT_COLOR 4
#define CVAR_DEFAULT_ROTATION 5
#define CVAR_DEFAULT_POSITION 6
#define CVAR_DEFAULT_CONTROL 7
#define CVAR_DISABLE 8
#define CVAR_QUICK 9
#define CVAR_PUBLIC_PROPS 10
#define CVAR_SUPPORTER_PROPS 11
#define CVAR_ADMIN_PROPS 12
#define CVAR_PUBLIC_DELETES 13
#define CVAR_SUPPORTER_DELETES 14
#define CVAR_ADMIN_DELETES 15
#define CVAR_PUBLIC_TELES 16
#define CVAR_SUPPORTER_TELES 17
#define CVAR_ADMIN_TELES 18
#define CVAR_PUBLIC_DELAY 19
#define CVAR_SUPPORTER_DELAY 20
#define CVAR_ADMIN_DELAY 21
#define CVAR_PUBLIC_COLORING 22
#define CVAR_SUPPORTER_COLORING 23
#define CVAR_ADMIN_COLORING 24
#define CVAR_PUBLIC_COLOR 25
#define CVAR_SUPPORTER_COLOR 26
#define CVAR_ADMIN_COLOR 27
#define CVAR_COLOR_RED 28
#define CVAR_COLOR_BLUE 29
#define CVAR_ACCESS_SPEC 30
#define CVAR_ACCESS_RED 31
#define CVAR_ACCESS_BLUE 32
#define CVAR_ACCESS_CHECK 33
#define CVAR_ACCESS_GRAB 34
#define CVAR_DISABLE_DELAY 35
#define CVAR_ACCESS_SETTINGS 36
#define CVAR_ACCESS_ADMIN 37
#define CVAR_GRAB_DISTANCE 38
#define CVAR_GRAB_REFRESH 39
#define CVAR_GRAB_MINIMUM 40
#define CVAR_GRAB_MAXIMUM 41
#define CVAR_GRAB_INTERVAL 42
#define CVAR_ACCESS_BASE 43
#define CVAR_BASE_DATABASE 44
#define CVAR_BASE_DISTANCE 45
#define CVAR_BASE_GROUPS 46
#define CVAR_BASE_ENABLED 47
#define CVAR_BASE_NAMES 48
#define CVAR_BASE_LIMIT 49

//Teams...
#define TEAM_NONE 0
#define TEAM_SPEC 1
#define TEAM_RED 2
#define TEAM_BLUE 3

//Command Indexes...
#define COMMAND_MENU 0
#define COMMAND_ROTATION 1
#define COMMAND_POSITION 2
#define COMMAND_DELETE 3
#define COMMAND_CONTROL 4
#define COMMAND_CHECK 5
#define COMMAND_TELE 6
#define COMMAND_HELP 7
#define COMMAND_CLEAR 8

//Phase Disable Flags...
#define DISABLE_SPAWN 1
#define DISABLE_DELETE 2
#define DISABLE_ROTATE 4
#define DISABLE_MOVE 8
#define DISABLE_CONTROL 16
#define DISABLE_CHECK 32
#define DISABLE_TELE 64
#define DISABLE_COLOR 128
#define DISABLE_CLEAR 256

//Auth Flags...
#define ACCESS_PUBLIC 1
#define ACCESS_SUPPORTER 2
#define ACCESS_ADMIN 4
#define ACCESS_BASE 8

//Admin Flags...
#define ADMIN_NONE 0
#define ADMIN_DELETE 1
#define ADMIN_TELEPORT 2
#define ADMIN_COLOR 4
#define ADMIN_TARGET 8

//Admin Targeting...
#define TARGET_SINGLE 0
#define TARGET_RED 1
#define TARGET_BLUE 2
#define TARGET_ALL 3

//Modifcation Axis...
#define ROTATION_AXIS_X 0
#define ROTATION_AXIS_Y 1
#define POSITION_AXIS_X 2
#define POSITION_AXIS_Y 3
#define POSITION_AXIS_Z 4
#define AXIS_TOTAL 5

//Menu Indexes
#define MENU_MAIN 0
#define MENU_CREATE 1
#define MENU_ROTATE 2
#define MENU_MOVE 3
#define MENU_CONTROL 4
#define MENU_COLOR 5
#define MENU_ACTION 6
#define MENU_ADMIN 7

//Base Menu Indexes
#define MENU_BASE_NULL -1
#define MENU_BASE_MAIN 8
#define MENU_BASE_CURRENT 9
#define MENU_BASE_MOVE 10

//Auth Defaults
#define AUTH_SUPPORTER ADMFLAG_CUSTOM4
#define AUTH_ADMIN ADMFLAG_UNBAN
#define AUTH_BASE ADMFLAG_CUSTOM4
#define AUTH_DELETE ADMFLAG_GENERIC
#define AUTH_TELEPORT ADMFLAG_GENERIC
#define AUTH_COLOR ADMFLAG_GENERIC
#define AUTH_TARGET ADMFLAG_UNBAN

//Sprites...
#define BEAM_SPRITE 0
#define GLOW_SPRITE 1
#define FLASH_SPRITE 2

//Axis Characters
new String:g_sAxisDisplay[][] = {"X", "Y", "X", "Y", "Z"};

//Prop Types
new String:g_sPropTypes[][] = { "prop_dynamic", "prop_dynamic_override", "prop_physics_multiplayer", "prop_physics_override", "prop_physics" };

//Sprites
new String:g_sSpritesCSS[][] = { "materials/sprites/laser.vmt", "sprites/strider_blackball.vmt", "materials/sprites/muzzleflash4.vmt" };
new String:g_sSpritesCSGO[][] = { "materials/sprites/laserbeam.vmt", "sprites/xfireball3.vmt", "materials/sprites/smoke.vmt" };

//Queries
new String:g_sSQL_CreateBaseTable[] = { "CREATE TABLE IF NOT EXISTS buildwars_bases (base_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL default 1, base_count int(6) NOT NULL default 0, steamid varchar(32) NOT NULL default '')" };
new String:g_sSQL_CreatePropTable[] = { "CREATE TABLE IF NOT EXISTS buildwars_props (prop_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL default 1, prop_base int(6) NOT NULL default 0, prop_type int(6) NOT NULL default 0, pos_x float(6) NOT NULL default 0.0, pos_y float(6) NOT NULL default 0.0, pos_z float(6) NOT NULL default 0.0, ang_x float(6) NOT NULL default 0.0, ang_y float(6) NOT NULL default 0.0, ang_z float(6) NOT NULL default 0.0, steamid varchar(32) NOT NULL default '')" } ;
new String:g_sSQL_BaseLoad[] = { "SELECT base_index, base_count FROM buildwars_bases WHERE steamid = '%s'" };
new String:g_sSQL_BaseCreate[] = { "INSERT INTO buildwars_bases (steamid, base_index) VALUES ('%s', NULL)" };
new String:g_sSQL_BaseUpdate[] = { "UPDATE buildwars_bases SET base_count = %d WHERE base_index = '%d'" };
new String:g_sSQL_PropLoad[] = { "SELECT prop_index, prop_type, pos_x, pos_y, pos_z, ang_x, ang_y, ang_z FROM buildwars_props WHERE prop_base = %d" };
new String:g_sSQL_PropSaveIndex[] = { "REPLACE INTO buildwars_props (prop_index, prop_base, prop_type, pos_x, pos_y, pos_z, ang_x, ang_y, ang_z, steamid) VALUES (%d, %d, %d, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, '%s')" };
new String:g_sSQL_PropSaveNull[] = { "REPLACE INTO buildwars_props (prop_index, prop_base, prop_type, pos_x, pos_y, pos_z, ang_x, ang_y, ang_z, steamid) VALUES (NULL, %d, %d, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, '%s')" };
new String:g_sSQL_PropDelete[] = { "DELETE FROM buildwars_props WHERE prop_index = %d" };
new String:g_sSQL_PropEmpty[] = { "DELETE FROM buildwars_props WHERE prop_base = %d AND steamid = '%s'" };
new String:g_sSQL_PropCheck[] = { "SELECT prop_index FROM buildwars_props WHERE prop_base = %d" };

new g_iNumProps, g_iNumColors, g_iNumRotations, g_iNumPositions;
new String:g_sDefinedPropNames[MAX_CONFIG_PROPS][64];
new String:g_sDefinedPropPaths[MAX_CONFIG_PROPS][256];
new g_iDefinedPropTypes[MAX_CONFIG_PROPS];
new g_iDefinedPropAccess[MAX_CONFIG_PROPS];
new String:g_sDefinedColorNames[MAX_CONFIG_COLORS][64];
new g_iDefinedColorArrays[MAX_CONFIG_COLORS][4];
new Float:g_fDefinedRotations[MAX_CONFIG_ROTATIONS];
new Float:g_fDefinedPositions[MAX_CONFIG_POSITIONS];

new bool:g_bValidProp[MaxEntities + 1];
new bool:g_bValidGrab[MaxEntities + 1];
new bool:g_bValidBase[MaxEntities + 1];
new g_iPropUser[MaxEntities + 1];
new g_iPropType[MaxEntities + 1];
new g_iBaseIndex[MaxEntities + 1];
new String:g_sPropOwner[MaxEntities + 1][32];

//Data for the clients
new g_iTeam[MAXPLAYERS + 1];
new g_iPlayerAccess[MAXPLAYERS + 1];
new g_iAdminAccess[MAXPLAYERS + 1];
new g_iPlayerTeleports[MAXPLAYERS + 1];
new g_iPlayerDeletes[MAXPLAYERS + 1];
new g_iPlayerProps[MAXPLAYERS + 1];
new g_iPlayerColors[MAXPLAYERS + 1];
new g_iPlayerControl[MAXPLAYERS + 1];
new Float:g_fConfigDistance[MAXPLAYERS + 1];
new g_iConfigRotation[MAXPLAYERS + 1];
new g_iConfigPosition[MAXPLAYERS + 1];
new g_iConfigColor[MAXPLAYERS + 1];
new bool:g_bTeleporting[MAXPLAYERS + 1];
new bool:g_bTeleported[MAXPLAYERS + 1];
new bool:g_bLoaded[MAXPLAYERS + 1];
new bool:g_bAlive[MAXPLAYERS + 1];
new bool:g_bQuickToggle[MAXPLAYERS + 1];
new bool:g_bConfigAxis[MAXPLAYERS + 1][AXIS_TOTAL];
new Float:g_fTeleRemaining[MAXPLAYERS + 1];
new String:g_sSteam[MAXPLAYERS + 1][32];
new String:g_sName[MAXPLAYERS + 1][32];
new Handle:g_hArray_PlayerProps[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_TeleportPlayer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_UpdateControl[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };

new bool:g_bSaveLocation[MAXPLAYERS + 1];			//The client's save location state
new Handle:g_hSaveLocation[MAXPLAYERS + 1];		//The client's handle to repeating timer
new Float:g_fSaveLocation[MAXPLAYERS + 1][3];		//The client's save location origin
new g_iPlayerBaseMenu[MAXPLAYERS + 1] = { -1, ... };
new g_iPlayerBaseQuery[MAXPLAYERS + 1];
new g_iPlayerBaseLoading[MAXPLAYERS + 1];
new g_iPlayerBase[MAXPLAYERS + 1][7];	//The client's base index
new g_iPlayerBaseCount[MAXPLAYERS + 1][7];	//The client's base prop count
new bool:g_bPlayerBaseSpawned[MAXPLAYERS + 1] = { false, ... };	//True if the client currently has a base spawned.
new g_iPlayerBaseCurrent[MAXPLAYERS + 1] = { -1, ... };		//The client's current base
new Float:g_fPlayerBaseLocation[MAXPLAYERS + 1][3];	//The client's intended spawn location.

new Handle:g_hCvar[CVAR_COUNT] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_Update = INVALID_HANDLE;
new Handle:g_hTrieCommands = INVALID_HANDLE;
new Handle:g_hSql_Database = INVALID_HANDLE;
new Handle:g_cConfigVersion = INVALID_HANDLE;
new Handle:g_cConfigRotation = INVALID_HANDLE;
new Handle:g_cConfigPosition = INVALID_HANDLE;
new Handle:g_cConfigColor = INVALID_HANDLE;
new Handle:g_cConfigLocks = INVALID_HANDLE;
new Handle:g_cConfigDistance = INVALID_HANDLE;
new Handle:g_hServerTags = INVALID_HANDLE;
new Handle:g_hTrieCommandConfig = INVALID_HANDLE;

new bool:g_bHelp, g_iEnabled, bool:g_bLateLoad, bool:g_bEnding, bool:g_bDissolve, bool:g_bRotationAllowed, bool:g_bPositionAllowed, bool:g_bColorAllowed, bool:g_bControlAllowed,
	bool:g_bAccessAdmin, bool:g_bAccessSettings, bool:g_bHasAccess[4] = { false, false, false, false }, bool:g_bQuickMenu, bool:g_bDisableFeatures, bool:g_bBaseEnabled, bool:g_bLateBase,
	bool:g_bGlobalOffensive;
new g_iCurEntities, g_iColorRed[4], g_iColorBlue[4], g_iPropPublic, g_iPropSupporter, g_iPropAdmin, g_iDeletePublic, g_iDeleteSupporter, g_iDeleteAdmin, g_iTeleportPublic, g_iTeleportSupporter,
	g_iTeleportAdmin, g_iDefaultColor, g_iDefaultRotation, g_iDefaultPosition, g_iColoringPublic, g_iColoringSupporter, g_iColoringAdmin, g_iColorPublic, g_iColorSupporter, g_iColorAdmin,
	g_iControlAccess, g_iCheckAccess, g_iCurrentDisable, g_iUniqueProp, g_iNumRedSpawns, g_iNumBlueSpawns, g_iDisableDelay, g_iNumSeconds, g_iBaseGroups, g_iGlowSprite, g_iFlashSprite,
	g_iBaseLimit, g_iBaseAccess, g_iBeamSprite, g_iLoadProps, g_iLoadColors, g_iLoadRotations, g_iLoadPositions, g_iLoadCommands;
new Float:g_fDefaultControl, Float:g_fGrabMinimum, Float:g_fGrabMaximum, Float:g_fGrabInterval, Float:g_fAdvert, Float:g_fTeleportPublicDelay, Float:g_fTeleportSupporterDelay, Float:g_fTeleportAdminDelay,
	Float:g_fGrabDistance, Float:g_fGrabUpdate, Float:g_fRedTeleports[32][3], Float:g_fBlueTeleports[32][3], Float:g_fBaseDistance;
new String:g_sPrefixSelect[128], String:g_sPrefixEmpty[128], String:g_sDissolve[8], String:g_sTitle[128], String:g_sHelp[128], String:g_sPrefixChat[128], String:g_sPrefixHint[128],
	String:g_sPrefixConsole[128], String:g_sPrefixCenter[128], String:g_sBaseDatabase[32], String:g_sBaseNames[7][32];

public Plugin:myinfo =
{
	name = "BuildWars (v2)",
	author = "Panduh (AlliedMods: thetwistedpanda)",
	description = "Gameplay modification where teams must build their own defenses then attack the opposing team.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = g_bLateBase = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	decl String:sBuffer[32];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	g_bGlobalOffensive = StrEqual(sBuffer, "csgo", false);

	LoadTranslations("common.phrases");
	if(g_bGlobalOffensive)
	{
		LoadTranslations("buildwars_v2.csgo.phrases");
		AutoExecConfig_SetFile("buildwars_v2.csgo");
	}
	else
	{
		LoadTranslations("buildwars_v2.css.phrases");
		AutoExecConfig_SetFile("buildwars_v2.css");
	}

	CreateConVar("buildwars_version", PLUGIN_VERSION, "BuildWars: Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_CHEAT|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvar[CVAR_ENABLED] = AutoExecConfig_CreateConVar("sm_buildwars_enable", "1", "Enables/disables all features of the plugin. (0 = Disabled, 1 = Enabled)", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ENABLED], OnCVarChange);
	g_hCvar[CVAR_DISSOLVE] = AutoExecConfig_CreateConVar("sm_buildwars_dissolve", "3", "The dissolve effect to be used for removing props. (-1 = Disabled, 0 = Energy, 1 = Light, 2 = Heavy, 3 = Core)", FCVAR_NONE, true, -1.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_DISSOLVE], OnCVarChange);
	g_hCvar[CVAR_HELP] = AutoExecConfig_CreateConVar("sm_buildwars_help", "", "The page that appears when a user types the help command into chat (\"\" = Disabled)", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_HELP], OnCVarChange);
	g_hCvar[CVAR_ADVERT] = AutoExecConfig_CreateConVar("sm_buildwars_advert", "5.0", "The number of seconds after a player joins an initial team for sm_buildwars_advert to be sent to the player. (-1 = Disabled)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADVERT], OnCVarChange);
	g_hCvar[CVAR_QUICK] = AutoExecConfig_CreateConVar("sm_buildwars_quick_menu", "1.0", "If enabled, clients will be able to open the Build Wars menu by pressing their USE key.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_QUICK], OnCVarChange);
	g_hCvar[CVAR_DEFAULT_COLOR] = AutoExecConfig_CreateConVar("sm_buildwars_default_color", "0", "The default prop color that players will spawn with. (# = Index, -1 = No Color Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_COLOR], OnCVarChange);
	g_hCvar[CVAR_DEFAULT_ROTATION] = AutoExecConfig_CreateConVar("sm_buildwars_default_rotation", "3", "The default degree value that players will spawn with. (# = Index, -1 = No Rotation Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_ROTATION], OnCVarChange);
	g_hCvar[CVAR_DEFAULT_POSITION] = AutoExecConfig_CreateConVar("sm_buildwars_default_position", "4", "The default position value that players will spawn with. (# = Index, -1 = No Position Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_POSITION], OnCVarChange);
	g_hCvar[CVAR_DEFAULT_CONTROL] = AutoExecConfig_CreateConVar("sm_buildwars_default_distance", "150", "The default control distance that players will spawn with. (#.# = Interval, -1 = No Control Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_CONTROL], OnCVarChange);
	g_hCvar[CVAR_DISABLE] = AutoExecConfig_CreateConVar("sm_buildwars_disable", "0", "Add values together for multiple feature disable. (0 = Disabled, 1 = Building, 2 = Deleting, 4 = Rotating, 8 = Moving, 16 = Grabbing, 32 = Checking, 64 = Teleporting, 128 = Coloring, 256 = Clearing)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE], OnCVarChange);
	g_hCvar[CVAR_DISABLE_DELAY] = AutoExecConfig_CreateConVar("sm_buildwars_disable_delay", "0", "The number of seconds after the start of the round for sm_buildwars_disable to be executed, restricting the defined features.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE_DELAY], OnCVarChange);
	g_hCvar[CVAR_PUBLIC_PROPS] = AutoExecConfig_CreateConVar("sm_buildwars_prop_public", "85", "The maximum amount of props public players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_PROPS], OnCVarChange);
	g_hCvar[CVAR_SUPPORTER_PROPS] = AutoExecConfig_CreateConVar("sm_buildwars_prop_supporter", "100", "The maximum amount of props administrative players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_PROPS], OnCVarChange);
	g_hCvar[CVAR_ADMIN_PROPS] = AutoExecConfig_CreateConVar("sm_buildwars_prop_admin", "100", "The maximum amount of props supporter players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_PROPS], OnCVarChange);
	g_hCvar[CVAR_PUBLIC_DELETES] = AutoExecConfig_CreateConVar("sm_buildwars_delete_public", "0", "The maximum amount of props public players are allowed to delete. (0 = Infinite, -1 = No Deleting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_DELETES], OnCVarChange);
	g_hCvar[CVAR_SUPPORTER_DELETES] = AutoExecConfig_CreateConVar("sm_buildwars_delete_supporter", "0", "The maximum amount of props supporter players are allowed to delete. (0 = Infinite, -1 = No Deleting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_DELETES], OnCVarChange);
	g_hCvar[CVAR_ADMIN_DELETES] = AutoExecConfig_CreateConVar("sm_buildwars_delete_admin", "0", "The maximum amount of props administrative players are allowed to delete. (0 = Infinite, -1 = No Deleting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_DELETES], OnCVarChange);
	g_hCvar[CVAR_PUBLIC_TELES] = AutoExecConfig_CreateConVar("sm_buildwars_tele_public", "0", "The maximum amount of teleports public players are allowed to use. (0 = Infinite, -1 = No Teleporting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_TELES], OnCVarChange);
	g_hCvar[CVAR_SUPPORTER_TELES] = AutoExecConfig_CreateConVar("sm_buildwars_tele_supporter", "0", "The maximum amount of teleports supporter players are allowed to use. (0 = Infinite, -1 = No Teleporting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_TELES], OnCVarChange);
	g_hCvar[CVAR_ADMIN_TELES] = AutoExecConfig_CreateConVar("sm_buildwars_tele_admin", "0", "The maximum amount of teleports administrative players are allowed to use. (0 = Infinite, -1 = No Teleporting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_TELES], OnCVarChange);
	g_hCvar[CVAR_PUBLIC_DELAY] = AutoExecConfig_CreateConVar("sm_buildwars_tele_public_delay", "10", "The number of seconds public players must wait before their teleport is processed. (0 = Instant)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_DELAY], OnCVarChange);
	g_hCvar[CVAR_SUPPORTER_DELAY] = AutoExecConfig_CreateConVar("sm_buildwars_tele_supporter_delay", "5", "The number of seconds supporters must wait before their teleport is processed. (0 = Instant)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_DELAY], OnCVarChange);
	g_hCvar[CVAR_ADMIN_DELAY] = AutoExecConfig_CreateConVar("sm_buildwars_tele_admin_delay", "0", "The number of seconds admins must wait before their teleport is processed. (0 = Instant)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_DELAY], OnCVarChange);
	g_hCvar[CVAR_PUBLIC_COLOR] = AutoExecConfig_CreateConVar("sm_buildwars_color_public", "15", "If the player's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_COLOR], OnCVarChange);
	g_hCvar[CVAR_SUPPORTER_COLOR] = AutoExecConfig_CreateConVar("sm_buildwars_color_supporter", "30", "If the supporter's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_COLOR], OnCVarChange);
	g_hCvar[CVAR_ADMIN_COLOR] = AutoExecConfig_CreateConVar("sm_buildwars_color_admin", "0", "If the admin's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_COLOR], OnCVarChange);
	g_hCvar[CVAR_PUBLIC_COLORING] = AutoExecConfig_CreateConVar("sm_buildwars_coloring_mode_public", "0", "Determines how props will be colored for public players. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_COLORING], OnCVarChange);
	g_hCvar[CVAR_SUPPORTER_COLORING] = AutoExecConfig_CreateConVar("sm_buildwars_coloring_mode_supporter", "0", "Determines how props will be colored for supporters. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_COLORING], OnCVarChange);
	g_hCvar[CVAR_ADMIN_COLORING] = AutoExecConfig_CreateConVar("sm_buildwars_coloring_mode_admin", "0", "Determines how props will be colored for admins. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_COLORING], OnCVarChange);
	g_hCvar[CVAR_COLOR_RED] = AutoExecConfig_CreateConVar("sm_buildwars_coloring_red", "255 0 0 255", "The defined color for players on the Terrorist team when colors are forced.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_COLOR_RED], OnCVarChange);
	g_hCvar[CVAR_COLOR_BLUE] = AutoExecConfig_CreateConVar("sm_buildwars_coloring_blue", "0 0 255 255", "The defined color for players on the Terrorist team when colors are forced.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_COLOR_BLUE], OnCVarChange);
	g_hCvar[CVAR_ACCESS_SPEC] = AutoExecConfig_CreateConVar("sm_buildwars_access_team_spec", "1", "Controls whether or not Spectators have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_SPEC], OnCVarChange);
	g_hCvar[CVAR_ACCESS_RED] = AutoExecConfig_CreateConVar("sm_buildwars_access_team_red", "1", "Controls whether or not Terrorists have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_RED], OnCVarChange);
	g_hCvar[CVAR_ACCESS_BLUE] = AutoExecConfig_CreateConVar("sm_buildwars_access_team_blue", "1", "Controls whether or not Counter-Terrorists have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_BLUE], OnCVarChange);
	g_hCvar[CVAR_ACCESS_SETTINGS] = AutoExecConfig_CreateConVar("sm_buildwars_access_settings", "1", "If enabled, players will be able to access the Actions / Settings menu in Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_SETTINGS], OnCVarChange);
	g_hCvar[CVAR_ACCESS_ADMIN]  = AutoExecConfig_CreateConVar("sm_buildwars_access_admin", "1", "If enabled, admins will be able to access the Admin Actions menu in Build Wars", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_ADMIN], OnCVarChange);
	g_hCvar[CVAR_ACCESS_CHECK] = AutoExecConfig_CreateConVar("sm_buildwars_access_check", "7", "Controls access to the check prop feature.  Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_CHECK], OnCVarChange);
	g_hCvar[CVAR_ACCESS_GRAB] = AutoExecConfig_CreateConVar("sm_buildwars_access_grab", "7", "Controls access to the grab feature. Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_GRAB], OnCVarChange);
	g_hCvar[CVAR_ACCESS_BASE] = AutoExecConfig_CreateConVar("sm_buildwars_access_base", "6", "Controls access to the base feature, if it is enabled. Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_BASE], OnCVarChange);
	g_hCvar[CVAR_GRAB_DISTANCE] = AutoExecConfig_CreateConVar("sm_buildwars_grab_distance", "768", "The maximum distance at which props can be grabbed from. (0 = No Maximum)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_DISTANCE], OnCVarChange);
	g_hCvar[CVAR_GRAB_REFRESH] = AutoExecConfig_CreateConVar("sm_buildwars_grab_update", "0.1", "The frequency at which grabbed objects will update.", FCVAR_NONE, true, 0.1);
	HookConVarChange(g_hCvar[CVAR_GRAB_REFRESH], OnCVarChange);
	g_hCvar[CVAR_GRAB_MINIMUM] = AutoExecConfig_CreateConVar("sm_buildwars_grab_minimum", "50", "The distance players can decrease their grab distance to.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_MINIMUM], OnCVarChange);
	g_hCvar[CVAR_GRAB_MAXIMUM] = AutoExecConfig_CreateConVar("sm_buildwars_grab_maximum", "300", "The distance players can increase their grab distance to.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_MAXIMUM], OnCVarChange);
	g_hCvar[CVAR_GRAB_INTERVAL] = AutoExecConfig_CreateConVar("sm_buildwars_grab_interval", "10", "The interval at which a players grab distance will increase/decrease.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_INTERVAL], OnCVarChange);
	g_hCvar[CVAR_BASE_ENABLED] = AutoExecConfig_CreateConVar("sm_buildwars_base_enabled", "1", "If enabled, players with appropriate access will be able to access the Base feature, which allows saving/spawning multiple props.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_BASE_ENABLED], OnCVarChange);
	g_hCvar[CVAR_BASE_DATABASE] = AutoExecConfig_CreateConVar("sm_buildwars_base_database", "", "The sqlite database located within databases.cfg. (\"\" = sourcemod-local.sql)", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_BASE_DATABASE], OnCVarChange);
	g_hCvar[CVAR_BASE_DISTANCE] = AutoExecConfig_CreateConVar("sm_buildwars_base_distance", "1000", "Props greater than this distance from the origin of the base location will not be saved, to prevent corruption. (0.0 = Disabled)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_BASE_DISTANCE], OnCVarChange);
	g_hCvar[CVAR_BASE_GROUPS] = AutoExecConfig_CreateConVar("sm_buildwars_base_groups", "3", "The number of bases available to clients with appropriate access. Limit of 7 bases per client.", FCVAR_NONE, true, 1.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_BASE_GROUPS], OnCVarChange);
	g_hCvar[CVAR_BASE_NAMES] = AutoExecConfig_CreateConVar("sm_buildwars_base_names", "Alpha, Beta, Gamma, Delta, Epsilon, Zeta, Eta", "The names to be assigned to the client bases. Separate values with \", \".", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_BASE_NAMES], OnCVarChange);
	g_hCvar[CVAR_BASE_LIMIT] = AutoExecConfig_CreateConVar("sm_buildwars_base_limit", "0", "The maximum limit of props each base can hold. Use 0 to limit the number of props to the client's maximum, otherwise use -1 to disable this feature.", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_BASE_LIMIT], OnCVarChange);

	if(g_bGlobalOffensive)
	{
		AutoExecConfig(true, "buildwars_v2.csgo");
	}
	else
	{
		AutoExecConfig(true, "buildwars_v2.css");
	}

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_hServerTags = FindConVar("sv_tags");
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	HookEvent("round_end", Event_OnRoundEnd);
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_changename", Event_OnPlayerName, EventHookMode_Pre);

	RegAdminCmd("sm_showhelp", Command_Help, ADMFLAG_GENERIC, "Build Wars: Forces the client to type !help");
	RegConsoleCmd("sm_buildwars_reset", Command_Reset, "Provides the ability to delete all props at once from outside the Build Wars script. <Target> parameter optional.");
	g_cConfigVersion = RegClientCookie("BuildWars_ClientVersion", "The version string from which the client was authenticated.", CookieAccess_Private);
	g_cConfigRotation = RegClientCookie("BuildWars_ConfigRotation", "The client's configuration value for rotation intervals.", CookieAccess_Private);
	g_cConfigPosition = RegClientCookie("BuildWars_ConfigPosition", "The client's configuration value for position intervals.", CookieAccess_Private);
	g_cConfigColor = RegClientCookie("BuildWars_ConfigColor", "The client's configuration value for prop colors.", CookieAccess_Private);
	g_cConfigLocks = RegClientCookie("BuildWars_ConfigLocks", "The client's configuration value for positional and rotational locking.", CookieAccess_Private);
	g_cConfigDistance = RegClientCookie("BuildWars_ConfigGrab", "The client's configuration value for grab distance.", CookieAccess_Private);

	Define_Defaults();
	AddCustomTag();
}

public OnPluginEnd()
{
	if(g_iEnabled)
	{
		RemCustomTag();
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				Bool_ClearClientProps(i, _, _);
				ClearClientControl(i);
				ClearClientTeleport(i);
			}
		}
	}
}

public OnMapStart()
{
	g_iCurEntities = 0;
	for(new i = 1; i <= MaxEntities; i++)
		if(IsValidEntity(i))
			g_iCurEntities++;

	if(g_iEnabled)
	{
		if(g_hTrieCommands == INVALID_HANDLE)
			g_hTrieCommands = CreateTrie();

		for(new i = 1; i <= MaxClients; i++)
			if(g_hArray_PlayerProps[i] == INVALID_HANDLE)
				g_hArray_PlayerProps[i] = CreateArray();

		Define_Props();
		Define_Rotations();
		Define_Positions();
		Define_Colors();
		Define_Commands();

		SetSpawns();

		for(new i = 0; i < g_iNumProps; i++)
			PrecacheModel(g_sDefinedPropPaths[i]);

		if(g_bGlobalOffensive)
		{
			g_iBeamSprite = PrecacheModel(g_sSpritesCSGO[BEAM_SPRITE]);
			g_iGlowSprite = PrecacheModel(g_sSpritesCSGO[GLOW_SPRITE]);
			g_iFlashSprite = PrecacheModel(g_sSpritesCSGO[FLASH_SPRITE]);
		}
		else
		{
			g_iBeamSprite = PrecacheModel(g_sSpritesCSS[BEAM_SPRITE]);
			g_iGlowSprite = PrecacheModel(g_sSpritesCSS[GLOW_SPRITE]);
			g_iFlashSprite = PrecacheModel(g_sSpritesCSS[FLASH_SPRITE]);
		}
	}
}

public OnMapEnd()
{
	g_bEnding = true;
	if(g_iEnabled)
	{
		if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
			g_hTimer_Update = INVALID_HANDLE;

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				Bool_ClearClientProps(i, _, _);
				ClearClientControl(i);
				ClearClientTeleport(i);
			}
		}
	}
}

public OnConfigsExecuted()
{
	if(g_iEnabled)
	{
		if(g_hSql_Database == INVALID_HANDLE)
			SQL_TConnect(SQL_ConnectCall, StrEqual(g_sBaseDatabase, "") ? "storage-local" : g_sBaseDatabase);

		Format(g_sTitle, 128, "%T", "Main_Menu_Title", LANG_SERVER);
		Format(g_sPrefixChat, 128, "%T", "Prefix_Chat", LANG_SERVER);
		Format(g_sPrefixHint, 128, "%T", "Prefix_Hint", LANG_SERVER);
		Format(g_sPrefixCenter, 128, "%T", "Prefix_Center", LANG_SERVER);
		Format(g_sPrefixConsole, 128, "%T", "Prefix_Console", LANG_SERVER);
		Format(g_sPrefixSelect, 128, "%T", "Menu_Option_Selected", LANG_SERVER);
		Format(g_sPrefixEmpty, 128, "%T", "Menu_Option_Empty", LANG_SERVER);

		if(g_bLateLoad)
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				g_iPlayerAccess[i] = ACCESS_PUBLIC;

				if(IsClientInGame(i))
				{
					g_iTeam[i] = GetClientTeam(i);
					g_bAlive[i] = IsPlayerAlive(i);
					GetClientAuthId(i, AuthId_SteamID64, g_sSteam[i], sizeof(g_sSteam[]), true);
					GetClientName(i, g_sName[i], 32);

					g_iPlayerProps[i] = 0;
					g_iPlayerDeletes[i] = 0;
					g_iPlayerColors[i] = 0;
					g_iPlayerTeleports[i] = 0;
					g_iPlayerControl[i] = -1;

					AuthClient(i);
					if(AreClientCookiesCached(i))
						LoadCookies(i);
				}
			}

			g_bLateLoad = false;
		}
	}
}

public OnClientPutInServer(client)
{
	if(g_iEnabled)
	{
		g_iPlayerProps[client] = 0;
		g_iPlayerColors[client] = 0;
		g_iPlayerDeletes[client] = 0;
		g_iPlayerTeleports[client] = 0;
	}
}

public OnClientPostAdminCheck(client)
{
	if(g_iEnabled)
	{
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerAccess[client] = ACCESS_PUBLIC;
			GetClientAuthId(client, AuthId_SteamID64, g_sSteam[client], sizeof(g_sSteam[]), true);
			GetClientName(client, g_sName[client], 32);

			AuthClient(client);

			if(!g_bLoaded[client] && AreClientCookiesCached(client))
				LoadCookies(client);

			if(g_bBaseEnabled && (g_iPlayerAccess[client] & g_iBaseAccess || g_iPlayerAccess[client] & ACCESS_BASE))
				LoadClientBase(client);
		}
	}
}

public OnClientDisconnect(client)
{
	if(g_iEnabled)
	{
		Bool_ClearClientProps(client, _, _);
		ClearClientControl(client);
		ClearClientTeleport(client);

		if(g_hSql_Database != INVALID_HANDLE)
		{
			if(g_bBaseEnabled && (g_iPlayerAccess[client] & g_iBaseAccess || g_iPlayerAccess[client] & ACCESS_BASE))
			{
				decl String:_sQuery[256];
				for(new i = 0; i < g_iBaseGroups; i++)
				{
					Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseUpdate, g_iPlayerBaseCount[client][i], g_iPlayerBase[client][i]);
					SQL_TQuery(g_hSql_Database, SQL_QueryBaseUpdatePost, _sQuery, GetClientUserId(client));
				}

				if(g_bSaveLocation[client])
				{
					g_bSaveLocation[client] = false;
					if(g_hSaveLocation[client] != INVALID_HANDLE && CloseHandle(g_hSaveLocation[client]))
						g_hSaveLocation[client] = INVALID_HANDLE;
				}

				g_iPlayerBaseCurrent[client] = -1;
			}
		}

		g_iTeam[client] = 0;
		g_bAlive[client] = false;
		g_bLoaded[client] = false;
		g_bQuickToggle[client] = false;
		g_bTeleported[client] = false;
	}
}

public OnClientCookiesCached(client)
{
	if(g_iEnabled)
	{
		if(!g_bLoaded[client])
			LoadCookies(client);
	}
}

public Action:OnLevelInit(const String:mapName[], String:mapEntities[2097152])
{
	if(g_iEnabled)
	{
		g_iCurEntities = 0;
	}

	return Plugin_Continue;
}

public OnEntityCreated(iEnt, const String:classname[])
{
	if(iEnt >= 0)
	{
		if(g_iEnabled)
		{
			g_bValidProp[iEnt] = false;
			g_bValidGrab[iEnt] = false;
			g_iPropUser[iEnt] = 0;
		}

		g_iCurEntities++;
	}
}

public OnEntityDestroyed(iEnt)
{
	if(iEnt >= 0)
	{
		if(g_iEnabled)
		{
			if(g_bValidProp[iEnt])
			{
				g_bValidProp[iEnt] = false;
				if(!g_bEnding)
				{
					new client = GetClientOfUserId(g_iPropUser[iEnt]);
					if(client > 0)
					{
						g_iPlayerProps[client]--;
						new iIndex = GetEntityIndex(client, iEnt);
						if(iIndex >= 0)
							RemoveFromArray(g_hArray_PlayerProps[client], iIndex);
					}
				}
			}

			g_bValidGrab[iEnt] = false;
			g_iPropUser[iEnt] = 0;
		}

		g_iCurEntities--;
	}
}

public OnGameFrame()
{
	if(g_iEnabled && !g_bEnding && g_bQuickMenu)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(GetClientButtons(i) & IN_USE)
				{
					if(!g_bQuickToggle[i])
					{
						g_bQuickToggle[i] = true;
						Menu_Main(i);
					}
				}
				else if(g_bQuickToggle[i])
					g_bQuickToggle[i] = false;
			}
		}
	}
}

public Action:Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_iEnabled)
	{
		g_bEnding = true;
		if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
			g_hTimer_Update = INVALID_HANDLE;

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				ClearClientControl(i);
				ClearClientTeleport(i);
				Bool_ClearClientProps(i, false, _);

				if(g_hSql_Database != INVALID_HANDLE)
				{
					if(g_bBaseEnabled && (g_iPlayerAccess[i] & g_iBaseAccess || g_iPlayerAccess[i] & ACCESS_BASE))
					{
						g_iPlayerBaseQuery[i] = 0;
						if(g_bPlayerBaseSpawned[i])
							g_bPlayerBaseSpawned[i] = false;

						if(g_bSaveLocation[i])
						{
							g_bSaveLocation[i] = false;
							if(g_hSaveLocation[i] != INVALID_HANDLE && CloseHandle(g_hSaveLocation[i]))
								g_hSaveLocation[i] = INVALID_HANDLE;
						}
					}
				}

				g_iPlayerProps[i] = 0;
				g_iPlayerDeletes[i] = 0;
				g_iPlayerColors[i] = 0;
				g_iPlayerTeleports[i] = 0;
				g_bTeleported[i] = false;
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_iEnabled)
	{
		g_bEnding = false;
		g_bDisableFeatures = false;
		g_iUniqueProp = 0;
		g_iNumSeconds = 0;

		g_hTimer_Update = CreateTimer(1.0, Timer_Update, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action:Timer_Update(Handle:timer)
{
	if(GetClientCount() >= 2)
		g_iNumSeconds++;
	else
	{
		g_iNumSeconds = 0;
		g_bDisableFeatures = false;
	}

	if(g_iDisableDelay && g_iCurrentDisable)
	{
		if(g_iNumSeconds >= g_iDisableDelay)
		{
			if(!g_bDisableFeatures)
				g_bDisableFeatures = true;
		}
		else if(g_bDisableFeatures)
			g_bDisableFeatures = false;
	}
}

public Action:Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_iEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		g_iTeam[client] = GetEventInt(event, "team");
		if(g_iTeam[client] == TEAM_SPEC)
			g_bAlive[client] = false;

		if(g_bHasAccess[g_iTeam[client]])
		{
			if(GetEventInt(event, "oldteam") == TEAM_NONE)
			{
				if(g_fAdvert >= 0.0)
					CreateTimer(g_fAdvert, Timer_Announce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				ClearClientControl(client);
				ClearClientTeleport(client);

				if(g_iTeam[client] != TEAM_SPEC)
					Bool_ClearClientProps(client, _, _);
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_iEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client <= 0 || !IsClientInGame(client) || g_iTeam[client] < TEAM_RED)
			return Plugin_Continue;

		g_bAlive[client] = true;
	}

	return Plugin_Continue;
}

public Action:Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_iEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		g_bAlive[client] = false;
		if(!g_bEnding && g_bHasAccess[g_iTeam[client]])
		{
			ClearClientControl(client);
			ClearClientTeleport(client);
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnPlayerName(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_iEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client > 0 && IsClientInGame(client) && g_bHasAccess[g_iTeam[client]])
		{
			GetEventString(event, "newname", g_sName[client], 32);
			new _iSize = GetArraySize(g_hArray_PlayerProps[client]);
			for(new i = 0; i < _iSize; i++)
			{
				new iEntity = GetArrayCell(g_hArray_PlayerProps[client], i);
				if(IsValidEntity(iEntity))
					Format(g_sPropOwner[iEntity], 32, "%s", g_sName[client]);
			}
		}
	}
}

public Action:Command_Say(client, const String:command[], argc)
{
	if(g_iEnabled)
	{
		if(g_bEnding || client <= 0 || !IsClientInGame(client) || !g_bHasAccess[g_iTeam[client]])
			return Plugin_Continue;
		else
		{
			new String:_sTrigger[2][32];
			decl iIndex, String:_sText[192];
			GetCmdArgString(_sText, 192);
			StripQuotes(_sText);
			TrimString(_sText);

			ExplodeString(_sText, " ", _sTrigger, sizeof(_sTrigger), sizeof(_sTrigger[]));
			new _iSize = strlen(_sTrigger[0]);
			for (new i = 0; i < _iSize; i++)
				if(IsCharAlpha(_sTrigger[0][i]) && IsCharUpper(_sTrigger[0][i]))
					_sTrigger[0][i] = CharToLower(_sTrigger[0][i]);

			if(GetTrieValue(g_hTrieCommands, _sTrigger[0], iIndex))
			{
				switch(iIndex)
				{
					case COMMAND_MENU:
					{
						if(StrEqual(_sTrigger[1], ""))
							Menu_Main(client);
						else
						{
							if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true))
							{
								new _iProp = StringToInt(_sTrigger[1]);
								if((_iProp >= 0 || _iProp < g_iNumProps) && g_iDefinedPropAccess[_iProp] & g_iPlayerAccess[client])
									SpawnChat(client, _iProp);
							}
						}
					}
					case COMMAND_ROTATION:
					{
						if(Bool_RotateValid(client, true))
							Menu_ModifyRotation(client);
					}
					case COMMAND_POSITION:
					{
						if(Bool_MoveValid(client, true))
							Menu_ModifyPosition(client);
					}
					case COMMAND_DELETE:
					{
						if(!StrEqual(_sTrigger[1], "") && g_iAdminAccess[client] & ADMIN_DELETE)
						{
							new _iEntity = (StringToInt(_sTrigger[1]) > 0) ? StringToInt(_sTrigger[1]) : Trace_GetEntity(client);
							if(_iEntity && Entity_Valid(_iEntity))
							{
								PrintCenterText(client, "%s%t", g_sPrefixCenter, "Notify_Succeed_Delete");
								DeleteProp(client, _iEntity);
							}

							return Plugin_Handled;
						}
						else if(Bool_DeleteAllowed(client, true) && Bool_DeleteValid(client, true))
							DeleteProp(client);
					}
					case COMMAND_CONTROL:
					{
						if(g_iPlayerControl[client] > 0)
							ClearClientControl(client);
						else if(Bool_ControlValid(client, true))
						{
							new iEntity = Trace_GetEntity(client, g_fGrabDistance);
							if(Entity_Valid(iEntity))
								IssueGrab(client, iEntity);

							Menu_Control(client);
						}
					}
					case COMMAND_CHECK:
					{
						if(Bool_CheckValid(client, true))
							CheckProp(client);
					}
					case COMMAND_TELE:
					{
						if(!StrEqual(_sTrigger[1], "") && g_iAdminAccess[client] & ADMIN_TELEPORT)
						{
							new _iTarget = FindTarget(client, _sTrigger[1], true, true);
							if(!_iTarget || !IsClientInGame(_iTarget))
							{
#if defined _colors_included
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#else
								PrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#endif
							}
							else if(!CanUserTarget(client, _iTarget))
							{
#if defined _colors_included
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
#else
								PrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
#endif
							}
							else
							{
								Menu_AdminConfirmTeleport(client, TARGET_SINGLE, GetClientUserId(_iTarget));
							}

							return Plugin_Handled;
						}
						else if(Bool_TeleportAllowed(client, true) && Bool_TeleportValid(client, true))
							PerformTeleport(client);
					}
					case COMMAND_HELP:
					{
						if(g_bHelp)
						{
							decl String:sBuffer[192];
							Format(sBuffer, 192, "%T", "Command_Help_Url_Title", client);
							ShowMOTDPanel(client, sBuffer, g_sHelp, MOTDPANEL_TYPE_URL);
						}
					}
					case COMMAND_CLEAR:
					{
						if(!StrEqual(_sTrigger[1], "") && g_iAdminAccess[client] & ADMIN_DELETE)
						{
							new _iTarget = FindTarget(client, _sTrigger[1], true, true);
							if(!_iTarget || !IsClientInGame(_iTarget))
							{
#if defined _colors_included
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#else
								PrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#endif
							}
							else if(!CanUserTarget(client, _iTarget))
							{
#if defined _colors_included
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
#else
								PrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
#endif
							}
							else
							{
								Menu_AdminConfirmDelete(client, TARGET_SINGLE, GetClientUserId(_iTarget));
							}

							return Plugin_Handled;
						}
						else if(Bool_DeleteAllowed(client, true, true) && Bool_ClearValid(client, true))
							Menu_ConfirmDelete(client);
					}
				}

				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

IssueGrab(client, iEntity)
{
	new _iOwner = GetClientOfUserId(g_iPropUser[iEntity]);
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(_iOwner && _iOwner == client)
		{
			for(new target = 1; target <= MaxClients; target++)
			{
				if(target != client && g_iPlayerControl[target] > 0 && g_iPlayerControl[target] == iEntity)
				{
#if defined _colors_included
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken", g_sDefinedPropNames[g_iPropType[iEntity]]);
#else
					PrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken", g_sDefinedPropNames[g_iPropType[iEntity]]);
#endif
					return;
				}
			}
		}
		else
		{
			PrintHintText(client, "%s%t", g_sPrefixHint, "Control_Prop_Failure", g_sDefinedPropNames[g_iPropType[iEntity]], g_sPropOwner[iEntity]);
			return;
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		for(new target = 1; target <= MaxClients; target++)
		{
			if(target != client && g_iPlayerControl[target] > 0 && g_iPlayerControl[target] == iEntity)
			{
				if(g_iPlayerAccess[target] & ACCESS_ADMIN)
				{
#if defined _colors_included
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken_Already", g_sDefinedPropNames[g_iPropType[iEntity]]);
#else
					PrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken_Already", g_sDefinedPropNames[g_iPropType[iEntity]]);
#endif
					return;
				}
				else
				{
#if defined _colors_included
					CPrintToChat(target, "%s%t", g_sPrefixChat, "Control_Prop_Take_Away", g_sDefinedPropNames[g_iPropType[iEntity]]);
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken_Away", g_sDefinedPropNames[g_iPropType[iEntity]], g_sName[target]);
#else
					PrintToChat(target, "%s%t", g_sPrefixChat, "Control_Prop_Take_Away", g_sDefinedPropNames[g_iPropType[iEntity]]);
					PrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken_Away", g_sDefinedPropNames[g_iPropType[iEntity]], g_sName[target]);
#endif
					ClearClientControl(target);
				}
			}
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(_iOwner && _iOwner == client)
		{
			for(new target = 1; target <= MaxClients; target++)
			{
				if(target != client && g_iPlayerControl[target] > 0 && g_iPlayerControl[target] == iEntity)
				{
#if defined _colors_included
					CPrintToChat(target, "%s%t", g_sPrefixChat, "Control_Prop_Taken", g_sDefinedPropNames[g_iPropType[iEntity]]);
#else
					PrintToChat(target, "%s%t", g_sPrefixChat, "Control_Prop_Taken", g_sDefinedPropNames[g_iPropType[iEntity]]);
#endif
					return;
				}
			}
		}
		else
		{
			PrintHintText(client, "%s%t", g_sPrefixHint, "Control_Prop_Failure", g_sDefinedPropNames[g_iPropType[iEntity]], g_sPropOwner[iEntity]);
			return;
		}
	}

	g_hTimer_UpdateControl[client] = CreateTimer(g_fGrabUpdate, Timer_UpdateControl, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerControl[client] = iEntity;

	g_bValidGrab[g_iPlayerControl[client]] = true;
}

ClearClientControl(client)
{
	if(g_iPlayerControl[client] != -1)
	{
		g_bValidGrab[g_iPlayerControl[client]] = false;
		g_iPlayerControl[client] = -1;
	}

	if(g_hTimer_UpdateControl[client] != INVALID_HANDLE && CloseHandle(g_hTimer_UpdateControl[client]))
		g_hTimer_UpdateControl[client] = INVALID_HANDLE;
}

ClearClientTeleport(client)
{
	g_bTeleporting[client] = false;
	if(g_hTimer_TeleportPlayer[client] != INVALID_HANDLE && CloseHandle(g_hTimer_TeleportPlayer[client]))
		g_hTimer_TeleportPlayer[client] = INVALID_HANDLE;
}

public Action:Timer_UpdateControl(Handle:timer, any:client)
{
	if(!IsClientInGame(client) || g_iPlayerControl[client] <= 0 || !g_bValidProp[g_iPlayerControl[client]])
	{
		g_hTimer_UpdateControl[client] = INVALID_HANDLE;
		ClearClientControl(client);

		return Plugin_Stop;
	}

	decl Float:g_fDirection[3], Float:_fPosition[3], Float:_fAngles[3], Float:_fOriginal[3];
	GetClientEyeAngles(client, _fAngles);
	GetClientEyePosition(client, _fPosition);
	GetAngleVectors(_fAngles, g_fDirection, NULL_VECTOR, NULL_VECTOR);

	_fPosition[0] += g_fDirection[0] * g_fConfigDistance[client];
	_fPosition[1] += g_fDirection[1] * g_fConfigDistance[client];
	_fPosition[2] += g_fDirection[2] * g_fConfigDistance[client];

	GetEntPropVector(g_iPlayerControl[client], Prop_Send, "m_vecOrigin", _fOriginal);
	_fPosition[0] = g_bConfigAxis[client][POSITION_AXIS_X] ? _fOriginal[0] : float(RoundToNearest(_fPosition[0] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
	_fPosition[1] = g_bConfigAxis[client][POSITION_AXIS_Y] ? _fOriginal[1] : float(RoundToNearest(_fPosition[1] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
	_fPosition[2] = g_bConfigAxis[client][POSITION_AXIS_Z] ? _fOriginal[2] : float(RoundToNearest(_fPosition[2] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];

	GetEntPropVector(g_iPlayerControl[client], Prop_Data, "m_angRotation", _fOriginal);
	_fAngles[0] = g_bConfigAxis[client][ROTATION_AXIS_X] ? _fOriginal[0] : float(RoundToNearest(_fAngles[0] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
	_fAngles[1] = g_bConfigAxis[client][ROTATION_AXIS_Y] ? _fOriginal[1] : float(RoundToNearest(_fAngles[1] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
	_fAngles[2] = _fOriginal[2];

	TeleportEntity(g_iPlayerControl[client], _fPosition, _fAngles, NULL_VECTOR);
	return Plugin_Continue;
}

public Action:Timer_Announce(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(client > 0 && IsClientInGame(client))
	{
#if defined _colors_included
		CPrintToChat(client, "%s%t", g_sPrefixChat, "Welcome_Advert", g_sName[client]);
#else
		PrintToChat(client, "%s%t", g_sPrefixChat, "Welcome_Advert", g_sName[client]);
#endif
	}

	return Plugin_Handled;
}

public Action:Timer_Teleport(Handle:timer, any:client)
{
	g_fTeleRemaining[client] -= 1.0;
	if(g_fTeleRemaining[client] <= 0.0)
	{
		g_bTeleporting[client] = false;
		g_hTimer_TeleportPlayer[client] = INVALID_HANDLE;

		PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Notify");
		TeleportPlayer(client);
		return Plugin_Stop;
	}

	PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Delay_Notify", g_fTeleRemaining[client]);
	return Plugin_Continue;
}

TeleportPlayer(client)
{
	switch(g_iTeam[client])
	{
		case 2:
			TeleportEntity(client, g_fRedTeleports[GetRandomInt(0, g_iNumRedSpawns)], NULL_VECTOR, NULL_VECTOR);
		case 3:
			TeleportEntity(client, g_fBlueTeleports[GetRandomInt(0, g_iNumBlueSpawns)], NULL_VECTOR, NULL_VECTOR);
	}
}

public Action:Timer_KillEntity(Handle:timer, any:ref)
{
	new iEntity = EntRefToEntIndex(ref);
	if(iEntity != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iEntity, "Kill");
}

Trace_GetEntity(client, Float:_fDistance = 0.0)
{
	new Handle:_hTemp, iIndex = -1;
	decl Float:_fOrigin[3], Float:_fAngles[3];
	GetClientEyePosition(client, _fOrigin);
	GetClientEyeAngles(client, _fAngles);

	_hTemp = TR_TraceRayFilterEx(_fOrigin, _fAngles, MASK_OPAQUE, RayType_Infinite, Tracer_FilterPlayers, client);
	if(TR_DidHit(_hTemp))
	{
		iIndex = TR_GetEntityIndex(_hTemp);
		if(_fDistance)
		{
			GetEntPropVector(iIndex, Prop_Send, "m_vecOrigin", _fAngles);
			if(GetVectorDistance(_fAngles, _fOrigin) > _fDistance)
			{
				if(IsValidEntity(iIndex) && g_bValidProp[iIndex])
					PrintHintText(client, "%s%t", g_sPrefixHint, "Control_Prop_Distance", g_sDefinedPropNames[g_iPropType[iIndex]]);
				CloseHandle(_hTemp);
				return -1;
			}
		}
	}

	if(_hTemp != INVALID_HANDLE)
		CloseHandle(_hTemp);

	return (iIndex > 0) ? iIndex : -1;
}

public bool:Tracer_FilterPlayers(iEntity, contentsMask, any:data)
{
	if(iEntity > MaxClients)
		return true;

	return false;
}

public bool:Tracer_FilterBlocks(iEntity, contentsMask, any:data)
{
	if(iEntity > MaxClients && !g_bValidGrab[iEntity])
		return true;

	return false;
}

GetEntityIndex(client, iEntity)
{
	return FindValueInArray(g_hArray_PlayerProps[client], iEntity);
}

PerformTeleport(client)
{
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		g_iPlayerTeleports[client]++;
		if(!g_fTeleportPublicDelay)
		{
			if(g_iTeleportPublic)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Limited", (g_iTeleportPublic - g_iPlayerTeleports[client]), g_iTeleportPublic);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Infinite");

			TeleportPlayer(client);
		}
		else
		{
			if(g_iTeleportPublic)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Limited", g_fTeleportPublicDelay, g_iPlayerTeleports[client], g_iTeleportPublic);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Infinite", g_fTeleportPublicDelay);

			g_bTeleporting[client] = true;
			g_fTeleRemaining[client] = g_fTeleportPublicDelay;
			PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Delay_Notify", g_fTeleRemaining[client]);
			g_hTimer_TeleportPlayer[client] = CreateTimer(1.0, Timer_Teleport, client, TIMER_REPEAT);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		g_iPlayerTeleports[client]++;
		if(!g_fTeleportAdminDelay)
		{
			if(g_iTeleportAdmin)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Limited", (g_iTeleportAdmin - g_iPlayerTeleports[client]), g_iTeleportAdmin);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Infinite");

			TeleportPlayer(client);
		}
		else
		{
			if(g_iTeleportAdmin)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Limited", g_fTeleportAdminDelay, (g_iTeleportAdmin - g_iPlayerTeleports[client]), g_iTeleportAdmin);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Infinite", g_fTeleportAdminDelay);

			g_bTeleporting[client] = true;
			g_fTeleRemaining[client] = g_fTeleportAdminDelay;
			PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Delay_Notify", g_fTeleRemaining[client]);
			g_hTimer_TeleportPlayer[client] = CreateTimer(1.0, Timer_Teleport, client, TIMER_REPEAT);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		g_iPlayerTeleports[client]++;
		if(!g_fTeleportSupporterDelay)
		{
			if(g_iTeleportSupporter)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Limited", (g_iTeleportSupporter - g_iPlayerTeleports[client]), g_iTeleportSupporter);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Infinite");

			TeleportPlayer(client);
		}
		else
		{
			if(g_iTeleportSupporter)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Limited", g_fTeleportSupporterDelay, g_iPlayerTeleports[client], g_iTeleportSupporter);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Infinite", g_fTeleportSupporterDelay);

			g_bTeleporting[client] = true;
			g_fTeleRemaining[client] = g_fTeleportSupporterDelay;
			PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Delay_Notify", g_fTeleRemaining[client]);
			g_hTimer_TeleportPlayer[client] = CreateTimer(1.0, Timer_Teleport, client, TIMER_REPEAT);
		}
	}
}

ColorClientProps(client, index)
{
	new _iSize = GetArraySize(g_hArray_PlayerProps[client]);
	for(new i = 0; i < _iSize; i++)
	{
		new iEntity = GetArrayCell(g_hArray_PlayerProps[client], i);
		if(IsValidEdict(iEntity) && IsValidEntity(iEntity))
		{
			if(g_iDefinedColorArrays[index][3] == -1)
				SetEntityRenderColor(iEntity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
			else
				SetEntityRenderColor(iEntity, g_iDefinedColorArrays[index][0], g_iDefinedColorArrays[index][1], g_iDefinedColorArrays[index][2], g_iDefinedColorArrays[index][3]);
		}
	}
}

Bool_ClearClientProps(client, bool:bDelete = true, bool:bClear = false)
{
	new iDeleted;
	if(bDelete)
	{
		new _iSize = GetArraySize(g_hArray_PlayerProps[client]);
		for(new i = 0; i < _iSize; i++)
		{
			new iEntity = GetArrayCell(g_hArray_PlayerProps[client], i);
			if(IsValidEntity(iEntity))
			{
				Entity_DeleteProp(iEntity);
				iDeleted++;
			}
		}
	}

	g_iPlayerProps[client] = 0;
	if(bClear)
		g_iPlayerDeletes[client] += iDeleted;
	else
		g_iPlayerDeletes[client] = 0;

	ClearArray(g_hArray_PlayerProps[client]);

	if(g_bBaseEnabled)
		if(g_bPlayerBaseSpawned[client])
			g_bPlayerBaseSpawned[client] = false;

	return iDeleted ? true : false;
}

bool:Entity_Valid(iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && g_bValidProp[iEntity])
		return true;

	return false;
}

Entity_SpawnProp(client, _iType, Float:_fPosition[3], Float:_fAngles[3])
{
	new iEntity = CreateEntityByName(g_sPropTypes[g_iDefinedPropTypes[_iType]]);
	if(iEntity > 0)
	{
		g_bValidProp[iEntity] = true;
		g_bValidBase[iEntity] = false;
		g_iBaseIndex[iEntity] = -1;
		g_iPropUser[iEntity] = GetClientUserId(client);
		g_iPropType[iEntity] = _iType;
		Format(g_sPropOwner[iEntity], 32, "%s", g_sName[client]);

		g_iUniqueProp++;
		decl String:sBuffer[24];
		Format(sBuffer, 24, "BuildWars:%d", g_iUniqueProp);
		DispatchKeyValue(iEntity, "targetname", sBuffer);
		DispatchKeyValue(iEntity, "model", g_sDefinedPropPaths[_iType]);
		DispatchKeyValue(iEntity, "disablereceiveshadows", "1");
		DispatchKeyValue(iEntity, "disableshadows", "1");
		DispatchKeyValue(iEntity, "Solid", "6");
		DispatchSpawn(iEntity);
		if(g_bColorAllowed)
		{
			new _iTemp;
			if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
				_iTemp = g_iColoringPublic;
			else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
				_iTemp = g_iColoringAdmin;
			else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
				_iTemp = g_iColoringSupporter;

			switch(_iTemp)
			{
				case 0:
				{
					if(g_iDefinedColorArrays[g_iConfigColor[client]][3] == -1)
						SetEntityRenderColor(iEntity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 255);
					else
						SetEntityRenderColor(iEntity, g_iDefinedColorArrays[g_iConfigColor[client]][0], g_iDefinedColorArrays[g_iConfigColor[client]][1], g_iDefinedColorArrays[g_iConfigColor[client]][2], g_iDefinedColorArrays[g_iConfigColor[client]][3]);
				}
				case 1:
				{
					SetEntityRenderColor(iEntity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 255);
				}
				case 2:
				{
					switch(g_iTeam[client])
					{
						case TEAM_RED:
							SetEntityRenderColor(iEntity, g_iColorRed[0], g_iColorRed[1], g_iColorRed[2], g_iColorRed[3]);
						case TEAM_BLUE:
							SetEntityRenderColor(iEntity, g_iColorBlue[0], g_iColorBlue[1], g_iColorBlue[2], g_iColorBlue[3]);
						default:
							SetEntityRenderColor(iEntity, 255, 255, 255, 255);
					}
				}
				case 3:
				{
					SetEntityRenderColor(iEntity, 255, 255, 255, 255);
				}
			}
		}
		else
			SetEntityRenderColor(iEntity, 255, 255, 255, 255);

		TeleportEntity(iEntity, _fPosition, _fAngles, NULL_VECTOR);
		return iEntity;
	}

	return 0;
}

Entity_SpawnBase(client, _iType, Float:_fPosition[3], Float:_fAngles[3], iIndex)
{
	new iEntity = CreateEntityByName(g_sPropTypes[g_iDefinedPropTypes[_iType]]);
	if(iEntity > 0)
	{
		g_bValidProp[iEntity] = true;
		g_bValidBase[iEntity] = true;
		g_iBaseIndex[iEntity] = iIndex;
		g_iPropUser[iEntity] = GetClientUserId(client);
		g_iPropType[iEntity] = _iType;
		Format(g_sPropOwner[iEntity], 32, "%s", g_sName[client]);

		g_iUniqueProp++;
		decl String:sBuffer[24];
		Format(sBuffer, 24, "BuildWars:%d", g_iUniqueProp);
		DispatchKeyValue(iEntity, "targetname", sBuffer);
		DispatchKeyValue(iEntity, "model", g_sDefinedPropPaths[_iType]);
		DispatchKeyValue(iEntity, "disablereceiveshadows", "1");
		DispatchKeyValue(iEntity, "disableshadows", "1");
		DispatchKeyValue(iEntity, "Solid", "6");
		DispatchSpawn(iEntity);
		if(g_bColorAllowed)
		{
			new _iTemp;
			if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
				_iTemp = g_iColoringPublic;
			else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
				_iTemp = g_iColoringAdmin;
			else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
				_iTemp = g_iColoringSupporter;

			switch(_iTemp)
			{
				case 0:
				{
					if(g_iDefinedColorArrays[g_iConfigColor[client]][3] == -1)
						SetEntityRenderColor(iEntity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 255);
					else
						SetEntityRenderColor(iEntity, g_iDefinedColorArrays[g_iConfigColor[client]][0], g_iDefinedColorArrays[g_iConfigColor[client]][1], g_iDefinedColorArrays[g_iConfigColor[client]][2], g_iDefinedColorArrays[g_iConfigColor[client]][3]);
				}
				case 1:
				{
					SetEntityRenderColor(iEntity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 255);
				}
				case 2:
				{
					switch(g_iTeam[client])
					{
						case TEAM_RED:
							SetEntityRenderColor(iEntity, g_iColorRed[0], g_iColorRed[1], g_iColorRed[2], g_iColorRed[3]);
						case TEAM_BLUE:
							SetEntityRenderColor(iEntity, g_iColorBlue[0], g_iColorBlue[1], g_iColorBlue[2], g_iColorBlue[3]);
						default:
							SetEntityRenderColor(iEntity, 255, 255, 255, 255);
					}
				}
				case 3:
				{
					SetEntityRenderColor(iEntity, 255, 255, 255, 255);
				}
			}
		}
		else
			SetEntityRenderColor(iEntity, 255, 255, 255, 255);

		TeleportEntity(iEntity, _fPosition, _fAngles, NULL_VECTOR);
		return iEntity;
	}

	return 0;
}

Entity_RotateProp(iEntity, Float:_fValue[3], bool:_bReset)
{
	new Float:_fAngles[3];
	if(!_bReset)
	{
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", _fAngles);
		AddVectors(_fAngles, _fValue, _fAngles);
		for(new i = 0; i <= 2; i++)
		{
			while(_fAngles[i] < 0.0)
				_fAngles[i] += 360.0;

			while(_fAngles[i] > 360.0)
				_fAngles[i] -= 360.0;
		}
		TeleportEntity(iEntity, NULL_VECTOR, _fAngles, NULL_VECTOR);
	}
	else
		TeleportEntity(iEntity, NULL_VECTOR, _fAngles, NULL_VECTOR);
}

Entity_PositionProp(iEntity, Float:_fValue[3])
{
	decl Float:_fOrigin[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", _fOrigin);

	AddVectors(_fOrigin, _fValue, _fOrigin);
	TeleportEntity(iEntity, _fOrigin, NULL_VECTOR, NULL_VECTOR);
}

Entity_DeleteProp(iEntity, bool:dissolve = true)
{
	if(g_bDissolve && dissolve)
	{
		new _iDissolve = CreateEntityByName("env_entity_dissolver");
		if(_iDissolve > 0)
		{
			g_bValidProp[iEntity] = false;

			decl String:_sName[64];
			GetEntPropString(iEntity, Prop_Data, "m_iName", _sName, 64);
			DispatchKeyValue(_iDissolve, "dissolvetype", g_sDissolve);
			DispatchKeyValue(_iDissolve, "target", _sName);
			AcceptEntityInput(_iDissolve, "Dissolve");

			CreateTimer(1.0, Timer_KillEntity, EntIndexToEntRef(iEntity));
			CreateTimer(0.1, Timer_KillEntity, EntIndexToEntRef(_iDissolve));
			return;
		}
	}

	g_bValidProp[iEntity] = false;
	AcceptEntityInput(iEntity, "Kill");
}

DeleteClientProp(client, iEntity)
{
	new iIndex = GetEntityIndex(client, iEntity);
	if(iIndex >= 0)
		RemoveFromArray(g_hArray_PlayerProps[client], iIndex);

	if(Entity_Valid(iEntity))
	{
		g_iPlayerProps[client]--;
		g_iPlayerDeletes[client]++;
		Entity_DeleteProp(iEntity);
	}
}

SetSpawns()
{
	new iEntity = -1;
	g_iNumRedSpawns = 0;
	while((iEntity = FindEntityByClassname(iEntity, "info_player_terrorist")) != -1)
	{
		if(g_iNumRedSpawns >= 32)
			break;

		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", g_fRedTeleports[g_iNumRedSpawns]);
		g_iNumRedSpawns++;
	}

	if(g_iNumRedSpawns)
		g_iNumRedSpawns--;

	iEntity = -1;
	g_iNumBlueSpawns = 0;
	while((iEntity = FindEntityByClassname(iEntity, "info_player_counterterrorist")) != -1)
	{
		if(g_iNumBlueSpawns >= 32)
			break;

		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", g_fBlueTeleports[g_iNumBlueSpawns]);
		g_iNumBlueSpawns++;
	}

	if(g_iNumBlueSpawns)
		g_iNumBlueSpawns--;
}

Define_Defaults()
{
	g_hTrieCommandConfig = CreateTrie();
	SetTrieValue(g_hTrieCommandConfig, "Commands_Menu", COMMAND_MENU);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Rotate", COMMAND_ROTATION);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Position", COMMAND_POSITION);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Delete", COMMAND_DELETE);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Grab", COMMAND_CONTROL);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Check", COMMAND_CHECK);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Tele", COMMAND_TELE);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Help", COMMAND_HELP);
	SetTrieValue(g_hTrieCommandConfig, "Commands_DeleteAll", COMMAND_CLEAR);

	decl String:_sTemp[32], String:_sColors[4][4];

	g_iEnabled = GetConVarInt(g_hCvar[CVAR_ENABLED]) ? true : false;
	GetConVarString(g_hCvar[CVAR_DISSOLVE], g_sDissolve, 8);
	g_bDissolve = GetConVarInt(g_hCvar[CVAR_DISSOLVE]) >= 0 ? true : false;
	GetConVarString(g_hCvar[CVAR_HELP], g_sHelp, 128);
	g_bHelp = StrEqual(g_sHelp, "") ? false : true;
	g_fAdvert = GetConVarFloat(g_hCvar[CVAR_ADVERT]);
	g_bQuickMenu = GetConVarInt(g_hCvar[CVAR_QUICK]) ? true : false;

	g_iDefaultColor = GetConVarInt(g_hCvar[CVAR_DEFAULT_COLOR]);
	g_bColorAllowed = g_iDefaultColor != -1 ? true : false;
	g_iDefaultRotation = GetConVarInt(g_hCvar[CVAR_DEFAULT_ROTATION]);
	g_bRotationAllowed = g_iDefaultRotation != -1 ? true : false;
	g_iDefaultPosition = GetConVarInt(g_hCvar[CVAR_DEFAULT_POSITION]);
	g_bPositionAllowed = g_iDefaultPosition != -1 ? true : false;
	g_fDefaultControl = GetConVarFloat(g_hCvar[CVAR_DEFAULT_CONTROL]);
	g_bControlAllowed = g_fDefaultControl != -1.0 ? true : false;

	g_iCurrentDisable = GetConVarInt(g_hCvar[CVAR_DISABLE]);
	g_iDisableDelay = GetConVarInt(g_hCvar[CVAR_DISABLE_DELAY]);

	g_iPropPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_PROPS]);
	g_iPropSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_PROPS]);
	g_iPropAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_PROPS]);

	g_iDeletePublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_DELETES]);
	g_iDeleteSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_DELETES]);
	g_iDeleteAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_DELETES]);

	g_iTeleportPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_TELES]);
	g_iTeleportSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_TELES]);
	g_iTeleportAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_TELES]);
	g_fTeleportPublicDelay = GetConVarFloat(g_hCvar[CVAR_PUBLIC_DELAY]);
	g_fTeleportSupporterDelay = GetConVarFloat(g_hCvar[CVAR_SUPPORTER_DELAY]);
	g_fTeleportAdminDelay = GetConVarFloat(g_hCvar[CVAR_ADMIN_DELAY]);

	g_iColoringPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_COLORING]);
	g_iColoringSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_COLORING]);
	g_iColoringAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_COLORING]);
	g_iColorPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_COLOR]);
	g_iColorSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_COLOR]);
	g_iColorAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_COLOR]);
	GetConVarString(g_hCvar[CVAR_COLOR_RED], _sTemp, 32);
	ExplodeString(_sTemp, " ", _sColors, 4, 4);
	for(new i = 0; i <= 3; i++)
		g_iColorRed[i] = StringToInt(_sColors[i]);
	GetConVarString(g_hCvar[CVAR_COLOR_BLUE], _sTemp, 32);
	ExplodeString(_sTemp, " ", _sColors, 4, 4);
	for(new i = 0; i <= 3; i++)
		g_iColorBlue[i] = StringToInt(_sColors[i]);

	g_bHasAccess[TEAM_SPEC] = GetConVarInt(g_hCvar[CVAR_ACCESS_SPEC]) ? true : false;
	g_bHasAccess[TEAM_RED] = GetConVarInt(g_hCvar[CVAR_ACCESS_RED]) ? true : false;
	g_bHasAccess[TEAM_BLUE] = GetConVarInt(g_hCvar[CVAR_ACCESS_BLUE]) ? true : false;
	g_iCheckAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_CHECK]);
	g_iControlAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_GRAB]);
	g_bAccessSettings = GetConVarInt(g_hCvar[CVAR_ACCESS_SETTINGS]) ? true : false;
	g_bAccessAdmin = GetConVarInt(g_hCvar[CVAR_ACCESS_ADMIN]) ? true : false;
	g_iBaseAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_BASE]);

	g_fGrabDistance = GetConVarFloat(g_hCvar[CVAR_GRAB_DISTANCE]);
	g_fGrabUpdate = GetConVarFloat(g_hCvar[CVAR_GRAB_REFRESH]);
	g_fGrabMinimum = GetConVarFloat(g_hCvar[CVAR_GRAB_MINIMUM]);
	g_fGrabMaximum = GetConVarFloat(g_hCvar[CVAR_GRAB_MAXIMUM]);
	g_fGrabInterval = GetConVarFloat(g_hCvar[CVAR_GRAB_INTERVAL]);

	decl String:sBuffer[256];
	g_bBaseEnabled = GetConVarInt(g_hCvar[CVAR_BASE_ENABLED]) ? true : false;
	GetConVarString(g_hCvar[CVAR_BASE_DATABASE], g_sBaseDatabase, sizeof(g_sBaseDatabase));
	g_fBaseDistance = GetConVarFloat(g_hCvar[CVAR_BASE_DISTANCE]);
	g_iBaseGroups = GetConVarInt(g_hCvar[CVAR_BASE_GROUPS]);
	GetConVarString(g_hCvar[CVAR_BASE_NAMES], sBuffer, sizeof(sBuffer));
	ExplodeString(sBuffer, ", ", g_sBaseNames, 7, 32);
	g_iBaseLimit = GetConVarInt(g_hCvar[CVAR_BASE_LIMIT]);
}

public OnCVarChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if(cvar == g_hCvar[CVAR_ENABLED])
	{
		g_iEnabled = bool:StringToInt(newvalue);
		if(g_iEnabled)
		{
			if(!StringToInt(oldvalue))
			{
				AddCustomTag();
				Define_Props();
				Define_Rotations();
				Define_Positions();
				Define_Colors();
				Define_Commands();
			}
		}
		else
		{
			if(StringToInt(oldvalue))
			{
				RemCustomTag();
			}
		}
	}
	else if(cvar == g_hCvar[CVAR_DISSOLVE])
	{
		g_bDissolve = StringToInt(newvalue) >= 0 ? true : false;
		Format(g_sDissolve, 8, "%s", newvalue);
	}
	else if(cvar == g_hCvar[CVAR_HELP])
	{
		g_bHelp = StrEqual(newvalue, "") ? false : true;
		Format(g_sHelp, 128, "%s", newvalue);
	}
	else if(cvar == g_hCvar[CVAR_ADVERT])
		g_fAdvert = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_QUICK])
		g_bQuickMenu = StringToInt(newvalue) >= 0 ? true : false;
	else if(cvar == g_hCvar[CVAR_DISABLE])
	{
		g_iCurrentDisable = StringToInt(newvalue);
		if(g_iDisableDelay && g_iDisableDelay > g_iNumSeconds)
			g_bDisableFeatures = true;
		else
			g_bDisableFeatures = false;
	}
	else if(cvar == g_hCvar[CVAR_DISABLE_DELAY])
		g_iDisableDelay = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DEFAULT_COLOR])
	{
		g_iDefaultColor = StringToInt(newvalue);
		g_bColorAllowed = g_iDefaultColor != -1 ? true : false;
		Define_Colors();
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_ROTATION])
	{
		g_iDefaultRotation = StringToInt(newvalue);
		g_bRotationAllowed = g_iDefaultRotation != -1 ? true : false;
		Define_Rotations();
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_POSITION])
	{
		g_iDefaultPosition = StringToInt(newvalue);
		g_bPositionAllowed = g_iDefaultPosition != -1 ? true : false;
		Define_Positions();
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_CONTROL])
	{
		g_fDefaultControl = StringToFloat(newvalue);
		g_bControlAllowed = g_fDefaultControl != -1 ? true : false;
	}

	else if(cvar == g_hCvar[CVAR_PUBLIC_PROPS])
		g_iPropPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_PROPS])
		g_iPropSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_PROPS])
		g_iPropAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PUBLIC_DELETES])
		g_iDeletePublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_DELETES])
		g_iDeleteSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_DELETES])
		g_iDeleteAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PUBLIC_TELES])
		g_iTeleportPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_TELES])
		g_iTeleportSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_TELES])
		g_iTeleportAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PUBLIC_DELAY])
		g_fTeleportPublicDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_DELAY])
		g_fTeleportSupporterDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_DELAY])
		g_fTeleportAdminDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_PUBLIC_COLORING])
		g_iColoringPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_COLORING])
		g_iColoringSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_COLORING])
		g_iColoringAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PUBLIC_COLOR])
		g_iColorPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_COLOR])
		g_iColorSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_COLOR])
		g_iColorAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_COLOR_RED])
	{
		decl String:_sColors1[4][4];
		ExplodeString(newvalue, " ", _sColors1, 4, 4);
		for(new i = 0; i <= 3; i++)
			g_iColorRed[i] = StringToInt(_sColors1[i]);
	}
	else if(cvar == g_hCvar[CVAR_COLOR_BLUE])
	{
		decl String:_sColors2[4][4];
		ExplodeString(newvalue, " ", _sColors2, 4, 4);
		for(new i = 0; i <= 3; i++)
			g_iColorBlue[i] = StringToInt(_sColors2[i]);
	}
	else if(cvar == g_hCvar[CVAR_ACCESS_SPEC])
		g_bHasAccess[TEAM_SPEC] = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_RED])
		g_bHasAccess[TEAM_RED] = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_BLUE])
		g_bHasAccess[TEAM_BLUE] = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_CHECK])
		g_iCheckAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_GRAB])
		g_iControlAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_SETTINGS])
		g_bAccessSettings = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_ADMIN])
		g_bAccessAdmin = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_BASE])
		g_iBaseAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_DISTANCE])
		g_fGrabDistance = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_REFRESH])
		g_fGrabUpdate = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_MINIMUM])
		g_fGrabMinimum = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_MAXIMUM])
		g_fGrabMaximum = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_INTERVAL])
		g_fGrabInterval = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_BASE_ENABLED])
		g_bBaseEnabled = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_BASE_DATABASE])
	{
		if(g_hSql_Database != INVALID_HANDLE && CloseHandle(g_hSql_Database))
			g_hSql_Database = INVALID_HANDLE;

		Format(g_sBaseDatabase, sizeof(g_sBaseDatabase), "%s", newvalue);
		SQL_TConnect(SQL_ConnectCall, StrEqual(g_sBaseDatabase, "") ? "storage-local" : g_sBaseDatabase);
	}
	else if(cvar == g_hCvar[CVAR_BASE_DISTANCE])
		g_fBaseDistance = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_BASE_GROUPS])
		g_iBaseGroups = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_BASE_NAMES])
		ExplodeString(newvalue, ", ", g_sBaseNames, 7, 32);
	else if(cvar == g_hCvar[CVAR_BASE_LIMIT])
		g_iBaseLimit = StringToInt(newvalue);
}

AddCustomTag()
{
	decl String:sBuffer[128];
	GetConVarString(g_hServerTags, sBuffer, sizeof(sBuffer));
	if(StrContains(sBuffer, "buildwars", false) == -1)
	{
		Format(sBuffer, sizeof(sBuffer), "%s,buildwars", sBuffer);
		SetConVarString(g_hServerTags, sBuffer, true);
	}
}

RemCustomTag()
{
	decl String:sBuffer[128];
	GetConVarString(g_hServerTags, sBuffer, sizeof(sBuffer));
	if(StrContains(sBuffer, "buildwars") != -1)
	{
		ReplaceString(sBuffer, sizeof(sBuffer), "buildwars", "", false);
		ReplaceString(sBuffer, sizeof(sBuffer), ",,", ",", false);
		SetConVarString(g_hServerTags, sBuffer, true);
	}
}

Menu_Main(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_Main);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);

	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iPropPublic != -1)
		{
			if(!g_iPropPublic)
				Format(sBuffer, 192, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropPublic);

			AddMenuItem(hMenuHandle, "0", sBuffer, Bool_SpawnValid(client, false) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bRotationAllowed)
		{
			Format(sBuffer, 192, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(hMenuHandle, "1", sBuffer, Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bPositionAllowed)
		{
			Format(sBuffer, 192, "%T", "Menu_Position_Prop", client);
			AddMenuItem(hMenuHandle, "2", sBuffer, Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iDeletePublic != -1)
		{
			if(!g_iDeletePublic)
				Format(sBuffer, 192, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeletePublic);

			AddMenuItem(hMenuHandle, "3", sBuffer, Bool_DeleteValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bControlAllowed && g_iControlAccess & ACCESS_PUBLIC)
		{
			Format(sBuffer, 192, "%T", "Menu_Control_Prop", client);
			AddMenuItem(hMenuHandle, "4", sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iCheckAccess & ACCESS_PUBLIC)
		{
			Format(sBuffer, 192, "%T", "Menu_Check_Prop", client);
			AddMenuItem(hMenuHandle, "7", sBuffer, Bool_CheckValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iPropAdmin != -1)
		{
			if(!g_iPropAdmin)
				Format(sBuffer, 192, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropAdmin);

			AddMenuItem(hMenuHandle, "0", sBuffer, Bool_SpawnValid(client, false) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bRotationAllowed)
		{
			Format(sBuffer, 192, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(hMenuHandle, "1", sBuffer);
		}

		if(g_bPositionAllowed)
		{
			Format(sBuffer, 192, "%T", "Menu_Position_Prop", client);
			AddMenuItem(hMenuHandle, "2", sBuffer);
		}

		if(g_iDeleteAdmin != -1)
		{
			if(!g_iDeleteAdmin)
				Format(sBuffer, 192, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeleteAdmin);

			AddMenuItem(hMenuHandle, "3", sBuffer);
		}

		if(g_bControlAllowed && g_iControlAccess & ACCESS_ADMIN)
		{
			Format(sBuffer, 192, "%T", "Menu_Control_Prop", client);
			AddMenuItem(hMenuHandle, "4", sBuffer);
		}

		if(g_iCheckAccess & ACCESS_ADMIN)
		{
			Format(sBuffer, 192, "%T", "Menu_Check_Prop", client);
			AddMenuItem(hMenuHandle, "7", sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iPropSupporter != -1)
		{
			if(!g_iPropSupporter)
				Format(sBuffer, 192, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropSupporter);

			AddMenuItem(hMenuHandle, "0", sBuffer, Bool_SpawnValid(client, false) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bRotationAllowed)
		{
			Format(sBuffer, 192, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(hMenuHandle, "1", sBuffer, Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bPositionAllowed)
		{
			Format(sBuffer, 192, "%T", "Menu_Position_Prop", client);
			AddMenuItem(hMenuHandle, "2", sBuffer, Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iDeleteSupporter != -1)
		{
			if(!g_iDeleteSupporter)
				Format(sBuffer, 192, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeleteSupporter);

			AddMenuItem(hMenuHandle, "3", sBuffer, Bool_DeleteValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bControlAllowed && g_iControlAccess & ACCESS_SUPPORTER)
		{
			Format(sBuffer, 192, "%T", "Menu_Control_Prop", client);
			AddMenuItem(hMenuHandle, "4", sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iCheckAccess & ACCESS_SUPPORTER)
		{
			Format(sBuffer, 192, "%T", "Menu_Check_Prop", client);
			AddMenuItem(hMenuHandle, "7", sBuffer, Bool_CheckValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}

	if(g_bBaseEnabled && (g_iPlayerAccess[client] & g_iBaseAccess || g_iPlayerAccess[client] & ACCESS_BASE))
	{
		if(g_hSql_Database != INVALID_HANDLE)
		{
			Format(sBuffer, 192, "%T", "Menu_Base_Actions", client);
			AddMenuItem(hMenuHandle, "8", sBuffer);
		}
	}

	if(g_bAccessSettings)
	{
		Format(sBuffer, 192, "%T", "Menu_Player_Actions", client);
		AddMenuItem(hMenuHandle, "5", sBuffer);
	}

	if(g_bAccessAdmin && (g_iAdminAccess[client] & ADMIN_DELETE || g_iAdminAccess[client] & ADMIN_TELEPORT || g_iAdminAccess[client] & ADMIN_COLOR))
	{
		Format(sBuffer, 192, "%T", "Menu_Admin_Actions", client);
		AddMenuItem(hMenuHandle, "6", sBuffer);
	}

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_Main(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			switch(StringToInt(_sOption))
			{
				case 0:
				{
					if(Bool_SpawnValid(param1, true, MENU_MAIN))
						Menu_Create(param1);
				}
				case 1:
				{
					if(Bool_RotateValid(param1, true, MENU_MAIN))
						Menu_ModifyRotation(param1);
				}
				case 2:
				{
					if(Bool_MoveValid(param1, true, MENU_MAIN))
						Menu_ModifyPosition(param1);
				}
				case 3:
				{
					if(Bool_DeleteValid(param1, true, MENU_MAIN))
					{
						DeleteProp(param1);
						Menu_Main(param1);
					}
				}
				case 4:
				{
					if(Bool_MoveValid(param1, true, MENU_MAIN))
						Menu_Control(param1);
				}
				case 5:
				{
					Menu_PlayerActions(param1);
					return;
				}
				case 6:
				{
					if(!Menu_Admin(param1))
						Menu_Main(param1);

					return;
				}
				case 7:
				{
					if(Bool_CheckValid(param1, true, MENU_MAIN))
					{
						CheckProp(param1);
						Menu_Main(param1);
					}
				}
				case 8:
				{
					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
			}
		}
	}
}

Menu_Create(client, index = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sTemp[4];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_CreateMenu);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	for(new i = 0; i < g_iNumProps; i++)
	{
		if(g_iDefinedPropAccess[i] & g_iPlayerAccess[client])
		{
			Format(_sTemp, 4, "%d", i);
			AddMenuItem(hMenuHandle, _sTemp, g_sDefinedPropNames[i]);
		}
	}

	DisplayMenuAtItem(hMenuHandle, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_CreateMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			SpawnProp(param1, StringToInt(_sOption), GetMenuSelectionPosition());
		}
	}
}

SpawnProp(client, type, slot)
{
	if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true, MENU_MAIN))
	{
		decl Float:_fOrigin[3], Float:_fAngles[3], Float:_fNormal[3];
		GetClientEyePosition(client, _fOrigin);
		GetClientEyeAngles(client, _fAngles);
		TR_TraceRayFilter(_fOrigin, _fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterBlocks, client);
		if(TR_DidHit(INVALID_HANDLE))
		{
			_fAngles[0] = 0.0;
			_fAngles[1] += 90.0;
			TR_GetEndPosition(_fOrigin, INVALID_HANDLE);
			TR_GetPlaneNormal(INVALID_HANDLE, _fNormal);
			decl Float:_fVectorAngles[3];
			GetVectorAngles(_fNormal, _fVectorAngles);
			_fVectorAngles[0] += 90.0;
			decl Float:_fCross[3], Float:_fTempAngles[3], Float:_fTempAngles2[3];
			GetAngleVectors(_fAngles, _fTempAngles, NULL_VECTOR, NULL_VECTOR);
			_fTempAngles[2] = 0.0;
			GetAngleVectors(_fVectorAngles, _fTempAngles2, NULL_VECTOR, NULL_VECTOR);
			GetVectorCrossProduct( _fTempAngles, _fNormal, _fCross );
			new Float:_fYaw = GetAngleBetweenVectors(_fTempAngles2, _fCross, _fNormal);
			RotateYaw(_fVectorAngles, _fYaw);
			for(new i = 0; i <= 2; i++)
				_fVectorAngles[i] = float(RoundToNearest(_fVectorAngles[i] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];

			new iEntity = Entity_SpawnProp(client, type, _fOrigin, _fVectorAngles);
			PushArrayCell(g_hArray_PlayerProps[client], iEntity);
			g_iPlayerProps[client]++;

			new _iMax = Int_SpawnMaximum(client);
			if(g_iPlayerAccess[client] & ACCESS_ADMIN)
			{
				if(_iMax)
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited_Admin", g_sDefinedPropNames[type], (_iMax - g_iPlayerProps[client]), _iMax, iEntity, g_iCurEntities);
				else
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite_Admin", g_sDefinedPropNames[type], iEntity, g_iCurEntities);
			}
			else
			{
				if(_iMax)
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited", g_sDefinedPropNames[type], (_iMax - g_iPlayerProps[client]), _iMax);
				else
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite", g_sDefinedPropNames[type]);
			}
		}

		Menu_Create(client, slot);
		return;
	}
}

SpawnClone(client, iEntity)
{
	if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true))
	{
		decl Float:_fOrigin[3], Float:_fRotation[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", _fOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", _fRotation);
		new _iType = g_iPropType[iEntity];
		new _iEnt = Entity_SpawnProp(client, _iType, _fOrigin, _fRotation);
		PushArrayCell(g_hArray_PlayerProps[client], _iEnt);
		g_iPlayerProps[client]++;

		new _iMax = Int_SpawnMaximum(client);
		if(g_iPlayerAccess[client] & ACCESS_ADMIN)
		{
			if(_iMax)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited_Admin", g_sDefinedPropNames[_iType], (_iMax - g_iPlayerProps[client]), _iMax, _iEnt, g_iCurEntities);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite_Admin", g_sDefinedPropNames[_iType], _iEnt, g_iCurEntities);
		}
		else
		{
			if(_iMax)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited", g_sDefinedPropNames[_iType], (_iMax - g_iPlayerProps[client]), _iMax);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite", g_sDefinedPropNames[_iType]);
		}
	}
}

SpawnChat(client, type)
{
	decl Float:_fOrigin[3], Float:_fAngles[3], Float:_fNormal[3];
	GetClientEyePosition(client, _fOrigin);
	GetClientEyeAngles(client, _fAngles);
	TR_TraceRayFilter(_fOrigin, _fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterBlocks, client);
	if(TR_DidHit(INVALID_HANDLE))
	{
		_fAngles[0] = 0.0;
		_fAngles[1] += 90.0;
		TR_GetEndPosition(_fOrigin, INVALID_HANDLE);
		TR_GetPlaneNormal(INVALID_HANDLE, _fNormal);
		decl Float:_fVectorAngles[3];
		GetVectorAngles(_fNormal, _fVectorAngles);
		_fVectorAngles[0] += 90.0;
		decl Float:_fCross[3], Float:_fTempAngles[3], Float:_fTempAngles2[3];
		GetAngleVectors(_fAngles, _fTempAngles, NULL_VECTOR, NULL_VECTOR);
		_fTempAngles[2] = 0.0;
		GetAngleVectors(_fVectorAngles, _fTempAngles2, NULL_VECTOR, NULL_VECTOR);
		GetVectorCrossProduct( _fTempAngles, _fNormal, _fCross );
		new Float:_fYaw = GetAngleBetweenVectors(_fTempAngles2, _fCross, _fNormal);
		RotateYaw(_fVectorAngles, _fYaw);
		for(new i = 0; i <= 2; i++)
			_fVectorAngles[i] = float(RoundToNearest(_fVectorAngles[i] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];

		new iEntity = Entity_SpawnProp(client, type, _fOrigin, _fVectorAngles);
		PushArrayCell(g_hArray_PlayerProps[client], iEntity);
		g_iPlayerProps[client]++;

		new _iMax = Int_SpawnMaximum(client);
		if(g_iPlayerAccess[client] & ACCESS_ADMIN)
		{
			if(_iMax)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited_Admin", g_sDefinedPropNames[type], (_iMax - g_iPlayerProps[client]), _iMax, iEntity, g_iCurEntities);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite_Admin", g_sDefinedPropNames[type], iEntity, g_iCurEntities);
		}
		else
		{
			if(_iMax)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited", g_sDefinedPropNames[type], (_iMax - g_iPlayerProps[client]), _iMax);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite", g_sDefinedPropNames[type]);
		}
	}
}

DeleteProp(client, iEntity = 0)
{
	new _iEnt = (iEntity > 0) ? iEntity : Trace_GetEntity(client);
	if(Entity_Valid(_iEnt))
	{
		new _iOwner = GetClientOfUserId(g_iPropUser[_iEnt]);
		if(!_iOwner)
		{
			if(g_iAdminAccess[client] & ADMIN_DELETE)
				Entity_DeleteProp(_iEnt);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Failure", g_sDefinedPropNames[g_iPropType[_iEnt]], g_sPropOwner[_iEnt]);
		}
		else
		{
			new _iDelete;
			if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
				_iDelete = g_iDeletePublic;
			else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
				_iDelete = g_iDeleteAdmin;
			else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
				_iDelete = g_iDeleteSupporter;

			if(_iDelete && g_iPlayerDeletes[client] >= _iDelete)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
#endif
			}
			else
			{
				if(_iOwner == client)
				{
					if(_iDelete)
						PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Limited", g_sDefinedPropNames[g_iPropType[_iEnt]], (_iDelete - (g_iPlayerDeletes[client] + 1)), _iDelete);
					else
						PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Infinite", g_sDefinedPropNames[g_iPropType[_iEnt]]);

					DeleteClientProp(client, _iEnt);
				}
				else
				{
					if(g_iPlayerAccess[client] & ACCESS_ADMIN)
					{
						PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Admin", g_sDefinedPropNames[g_iPropType[_iEnt]], g_sName[_iOwner]);
						DeleteClientProp(_iOwner, _iEnt);
					}
					else
						PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Failure", g_sDefinedPropNames[g_iPropType[_iEnt]], g_sPropOwner[_iEnt]);
				}
			}
		}
	}
}

Menu_ModifyRotation(client, iEntity = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_ModifyRotation);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	if(iEntity)
	{
		decl Float:_fAngles[3];
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", _fAngles);

		Format(sBuffer, 192, "%T", "Menu_Rotation_Info", client, _fAngles[0], _fAngles[1], _fAngles[2]);
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(sBuffer, 192, "%T", "Menu_Rotation_Info_Missing", client);
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
	}

	new _iState = Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(sBuffer, 192, "%T", "Menu_Rotation_X_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(hMenuHandle, "1", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Rotation_X_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(hMenuHandle, "2", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Rotation_Y_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(hMenuHandle, "3", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Rotation_Y_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(hMenuHandle, "4", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Rotation_Z_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(hMenuHandle, "5", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Rotation_Z_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(hMenuHandle, "6", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Rotation_Reset", client);
	AddMenuItem(hMenuHandle, "7", sBuffer);
	Format(sBuffer, 192, "%T", "Menu_Rotation_Default", client);
	AddMenuItem(hMenuHandle, "0", sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_ModifyRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			new _iTemp = StringToInt(_sOption);

			if(!_iTemp)
				Menu_DefaultRotation(param1);
			else
			{
				if(Bool_RotateValid(param1, true, MENU_ROTATE))
				{
					new iEntity = (g_iPlayerControl[param1] > 0) ? g_iPlayerControl[param1] : Trace_GetEntity(param1);
					if(Entity_Valid(iEntity))
					{
						new _iOwner = GetClientOfUserId(g_iPropUser[iEntity]);
						if(_iOwner == param1 || g_iPlayerAccess[param1] & ACCESS_ADMIN)
						{
							new bool:_bTemp, Float:_fTemp[3];
							switch(_iTemp)
							{
								case 1:
									_fTemp[0] = g_fDefinedRotations[g_iConfigRotation[param1]];
								case 2:
									_fTemp[0] = (g_fDefinedRotations[g_iConfigRotation[param1]] * -1);
								case 3:
									_fTemp[1] = g_fDefinedRotations[g_iConfigRotation[param1]];
								case 4:
									_fTemp[1] = (g_fDefinedRotations[g_iConfigRotation[param1]] * -1);
								case 5:
									_fTemp[2] = g_fDefinedRotations[g_iConfigRotation[param1]];
								case 6:
									_fTemp[2] = (g_fDefinedRotations[g_iConfigRotation[param1]] * -1);
								case 7:
									_bTemp = true;
							}

							if(g_iPlayerAccess[param1] & ACCESS_ADMIN)
							{
								if(_bTemp)
								{
									if(!_iOwner || _iOwner == param1)
										PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Reset_Admin", g_sDefinedPropNames[g_iPropType[iEntity]], iEntity, g_iCurEntities);
									else
										PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Reset_Client_Admin", g_sDefinedPropNames[g_iPropType[iEntity]], g_sName[_iOwner], iEntity, g_iCurEntities);
								}
								else
								{
									if(!_iOwner || _iOwner == param1)
										PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Admin", g_sDefinedPropNames[g_iPropType[iEntity]], g_fDefinedRotations[g_iConfigRotation[param1]], iEntity, g_iCurEntities);
									else
										PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Client_Admin", g_sDefinedPropNames[g_iPropType[iEntity]], g_sName[_iOwner], g_fDefinedRotations[g_iConfigRotation[param1]], iEntity, g_iCurEntities);
								}
							}
							else
							{
								if(_bTemp)
									PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Reset_Client", g_sDefinedPropNames[g_iPropType[iEntity]]);
								else
									PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Client", g_sDefinedPropNames[g_iPropType[iEntity]], g_fDefinedRotations[g_iConfigRotation[param1]]);
							}

							Entity_RotateProp(iEntity, _fTemp, _bTemp);
							Menu_ModifyRotation(param1, iEntity);
							return;
						}
						else
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Failure", g_sDefinedPropNames[g_iPropType[iEntity]], g_sPropOwner[iEntity]);
					}

					Menu_ModifyRotation(param1, 0);
				}
			}
		}
	}
}

Menu_DefaultRotation(client, index = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192], String:_sTemp[4];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_DefaultRotation);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	for(new i = 0; i < g_iNumRotations; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(sBuffer, 192, "%s%T", (g_iConfigRotation[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Rotation_Option", client, g_fDefinedRotations[i]);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer);
	}

	DisplayMenuAtItem(hMenuHandle, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_ModifyRotation(param1, 0);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigRotation[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigRotation, _sOption);

#if defined _colors_included
			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Rotation", g_fDefinedRotations[g_iConfigRotation[param1]]);
#else
			PrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Rotation", g_fDefinedRotations[g_iConfigRotation[param1]]);
#endif
			Menu_DefaultRotation(param1, GetMenuSelectionPosition());
		}
	}
}

Menu_ModifyPosition(client, iEntity = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_ModifyPosition);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	if(iEntity)
	{
		decl Float:_fOrigin[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", _fOrigin);

		Format(sBuffer, 192, "%T", "Menu_Position_Info", client, _fOrigin[0], _fOrigin[1], _fOrigin[2]);
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(sBuffer, 192, "%T", "Menu_Position_Info_Missing", client);
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
	}

	new _iState = Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(sBuffer, 192, "%T", "Menu_Position_X_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "1", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Position_X_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "2", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Position_Y_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "3", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Position_Y_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "4", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Position_Z_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "5", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Position_Z_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "6", sBuffer, _iState);
	Format(sBuffer, 192, "%T", "Menu_Position_Default", client);
	AddMenuItem(hMenuHandle, "0", sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_ModifyPosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			new _iTemp = StringToInt(_sOption);

			if(!_iTemp)
				Menu_DefaultPosition(param1);
			else
			{
				if(Bool_MoveValid(param1, true, MENU_MOVE))
				{
					new iEntity = (g_iPlayerControl[param1] > 0) ? g_iPlayerControl[param1] : Trace_GetEntity(param1);
					if(Entity_Valid(iEntity))
					{
						new _iOwner = GetClientOfUserId(g_iPropUser[iEntity]);
						if(_iOwner == param1 || g_iPlayerAccess[param1] & ACCESS_ADMIN)
						{
							new Float:_fTemp[3];
							switch(_iTemp)
							{
								case 1:
									_fTemp[0] = g_fDefinedPositions[g_iConfigPosition[param1]];
								case 2:
									_fTemp[0] = (g_fDefinedPositions[g_iConfigPosition[param1]] * -1);
								case 3:
									_fTemp[1] = g_fDefinedPositions[g_iConfigPosition[param1]];
								case 4:
									_fTemp[1] = (g_fDefinedPositions[g_iConfigPosition[param1]] * -1);
								case 5:
									_fTemp[2] = g_fDefinedPositions[g_iConfigPosition[param1]];
								case 6:
									_fTemp[2] = (g_fDefinedPositions[g_iConfigPosition[param1]] * -1);
							}

							if(g_iPlayerAccess[param1] & ACCESS_ADMIN)
							{
								if(!_iOwner || _iOwner == param1)
									PrintHintText(param1, "%s%t", g_sPrefixHint, "Position_Own_Prop_Admin", g_sDefinedPropNames[g_iPropType[iEntity]], g_fDefinedPositions[g_iConfigPosition[param1]], iEntity, g_iCurEntities);
								else
									PrintHintText(param1, "%s%t", g_sPrefixHint, "Position_Other_Prop_Admin", g_sDefinedPropNames[g_iPropType[iEntity]], g_sName[_iOwner], g_fDefinedPositions[g_iConfigPosition[param1]], iEntity, g_iCurEntities);
							}
							else
								PrintHintText(param1, "%s%t", g_sPrefixHint, "Position_Own_Prop", g_sDefinedPropNames[g_iPropType[iEntity]], g_fDefinedPositions[g_iConfigPosition[param1]]);

							Entity_PositionProp(iEntity, _fTemp);
							Menu_ModifyPosition(param1, iEntity);
							return;
						}
						else
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Position_Prop_Failure", g_sDefinedPropNames[g_iPropType[iEntity]], g_sPropOwner[iEntity]);
					}

					Menu_ModifyPosition(param1, 0);
				}
			}
		}
	}

	return;
}

Menu_DefaultPosition(client, index = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192], String:_sTemp[4];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_DefaultPosition);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	for(new i = 0; i < g_iNumPositions; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(sBuffer, 192, "%s%T", (g_iConfigPosition[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Position_Option", client, g_fDefinedPositions[i]);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer);
	}

	DisplayMenuAtItem(hMenuHandle, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultPosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_ModifyPosition(param1, 0);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigPosition[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigPosition, _sOption);

#if defined _colors_included
			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Position", g_fDefinedPositions[g_iConfigPosition[param1]]);
#else
			PrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Position", g_fDefinedPositions[g_iConfigPosition[param1]]);
#endif
			Menu_DefaultPosition(param1, GetMenuSelectionPosition());
		}
	}
}

CheckProp(client, iEntity = 0)
{
	new _iEnt = (iEntity > 0) ? iEntity : Trace_GetEntity(client);
	if(Entity_Valid(_iEnt))
	{
		new _iOwner = GetClientOfUserId(g_iPropUser[_iEnt]);
		if(g_iPlayerAccess[client] & ACCESS_ADMIN)
			PrintHintText(client, "%s%t", g_sPrefixHint, "Check_Prop_Admin", g_sDefinedPropNames[g_iPropType[_iEnt]], _iOwner ? g_sName[_iOwner] : g_sPropOwner[_iEnt], _iEnt, g_iCurEntities);
		else
			PrintHintText(client, "%s%t", g_sPrefixHint, "Check_Prop", g_sDefinedPropNames[g_iPropType[_iEnt]], _iOwner ? g_sName[_iOwner] : g_sPropOwner[_iEnt]);
	}
}

Menu_Control(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_Grab);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	if(g_iPlayerControl[client] > 0)
		Format(sBuffer, 192, "%T", "Menu_Control_Release", client);
	else
		Format(sBuffer, 192, "%T", "Menu_Control_Issue", client);
	AddMenuItem(hMenuHandle, "0", sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	Format(sBuffer, 192, "%T", "Menu_Control_Increase", client);
	AddMenuItem(hMenuHandle, "1", sBuffer);

	Format(sBuffer, 192, "%T", "Menu_Control_Decrease", client);
	AddMenuItem(hMenuHandle, "2", sBuffer);

	if(g_iPlayerControl[client] > 0)
		Format(sBuffer, 192, "%T", "Menu_Control_Clone", client, g_sDefinedPropNames[g_iPropType[g_iPlayerControl[client]]]);
	else
		Format(sBuffer, 192, "%T", "Menu_Control_Empty", client);
	AddMenuItem(hMenuHandle, "3", sBuffer, (g_iPlayerControl[client] > 0 && Bool_SpawnValid(client, false)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	if(g_bRotationAllowed)
	{
		Format(sBuffer, 192, "%s%T", (g_bConfigAxis[client][ROTATION_AXIS_X]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Rotation_Lock_X", client);
		AddMenuItem(hMenuHandle, "4", sBuffer);

		Format(sBuffer, 192, "%s%T", (g_bConfigAxis[client][ROTATION_AXIS_Y]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Rotation_Lock_Y", client);
		AddMenuItem(hMenuHandle, "5", sBuffer);
	}

	if(g_bPositionAllowed)
	{
		Format(sBuffer, 192, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_X]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_X", client);
		AddMenuItem(hMenuHandle, "6", sBuffer);

		Format(sBuffer, 192, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_Y]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_Y", client);
		AddMenuItem(hMenuHandle, "7", sBuffer);

		Format(sBuffer, 192, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_Z]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_Z", client);
		AddMenuItem(hMenuHandle, "8", sBuffer);
	}

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_Grab(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl _iOption, String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			_iOption = StringToInt(_sOption);

			switch(_iOption)
			{
				case 0:
				{
					if(g_iPlayerControl[param1] > 0)
						ClearClientControl(param1);
					else
					{
						new iEntity = Trace_GetEntity(param1, g_fGrabDistance);
						if(Entity_Valid(iEntity))
							IssueGrab(param1, iEntity);
					}
				}
				case 1:
				{
					if(g_fConfigDistance[param1] < g_fGrabMaximum)
						g_fConfigDistance[param1] += g_fGrabInterval;
					else
						g_fConfigDistance[param1] = g_fGrabMinimum;

					PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Cycle_Change", g_fConfigDistance[param1]);
				}
				case 2:
				{
					if(g_fConfigDistance[param1] > g_fGrabMinimum)
						g_fConfigDistance[param1] -= g_fGrabInterval;
					else
						g_fConfigDistance[param1] = g_fGrabMaximum;

					PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Cycle_Change", g_fConfigDistance[param1]);
				}
				case 3:
				{
					if(g_iPlayerControl[param1] > 0)
						SpawnClone(param1, g_iPlayerControl[param1]);
				}
				default:
				{
					_iOption -= 4;
					g_bConfigAxis[param1][_iOption] = !g_bConfigAxis[param1][_iOption];

					decl String:_sAxis[16] = "";
					for(new i = 0; i < AXIS_TOTAL; i++)
						Format(_sAxis, 16, "%s%s ", _sAxis, g_bConfigAxis[param1][i] ? "1" : "0");
					SetClientCookie(param1, g_cConfigLocks, _sAxis);

					if(_iOption >= ROTATION_AXIS_X && _iOption <= ROTATION_AXIS_Y)
					{
						if(g_bConfigAxis[param1][_iOption])
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Rotation_Lock", g_sAxisDisplay[_iOption]);
						else
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Rotation_Unlock", g_sAxisDisplay[_iOption]);
					}
					else if(_iOption >= POSITION_AXIS_X && _iOption <= POSITION_AXIS_Z)
					{
						if(g_bConfigAxis[param1][_iOption])
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Position_Lock", g_sAxisDisplay[_iOption]);
						else
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Position_Unlock", g_sAxisDisplay[_iOption]);
					}
				}
			}

			Menu_Control(param1);
		}
	}
}

Menu_PlayerActions(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_PlayerActions);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iColorPublic != -1 && !g_iColoringPublic && g_bColorAllowed)
		{
			if(!g_iColorPublic)
				Format(sBuffer, 192, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorPublic);
			AddMenuItem(hMenuHandle, "1", sBuffer, Bool_ColorValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iTeleportPublic != -1)
		{
			if(!g_iTeleportPublic)
				Format(sBuffer, 192, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportPublic);
			AddMenuItem(hMenuHandle, "2", sBuffer, Bool_TeleportValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iDeletePublic != -1)
		{
			Format(sBuffer, 192, "%T", "Menu_Action_Delete", client);
			AddMenuItem(hMenuHandle, "3", sBuffer, Bool_ClearValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iColorAdmin != -1 && !g_iColoringAdmin && g_bColorAllowed)
		{
			if(!g_iColorAdmin)
				Format(sBuffer, 192, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorAdmin);
			AddMenuItem(hMenuHandle, "1", sBuffer);
		}

		if(g_iTeleportAdmin != -1)
		{
			if(!g_iTeleportAdmin)
				Format(sBuffer, 192, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportAdmin);
			AddMenuItem(hMenuHandle, "2", sBuffer);
		}

		if(g_iDeleteAdmin != -1)
		{
			Format(sBuffer, 192, "%T", "Menu_Action_Delete", client);
			AddMenuItem(hMenuHandle, "3", sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iColorSupporter != -1 && !g_iColoringSupporter && g_bColorAllowed)
		{
			if(!g_iColorSupporter)
				Format(sBuffer, 192, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorSupporter);
			AddMenuItem(hMenuHandle, "1", sBuffer, Bool_ColorValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iTeleportSupporter != -1)
		{
			if(!g_iTeleportSupporter)
				Format(sBuffer, 192, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(sBuffer, 192, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportSupporter);
			AddMenuItem(hMenuHandle, "2", sBuffer, Bool_TeleportValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iDeleteSupporter != -1)
		{
			Format(sBuffer, 192, "%T", "Menu_Action_Delete", client);
			AddMenuItem(hMenuHandle, "3", sBuffer, Bool_ClearValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}

	Format(sBuffer, 192, "%T", "Menu_Rotation_Default", client);
	AddMenuItem(hMenuHandle, "4", sBuffer);

	Format(sBuffer, 192, "%T", "Menu_Position_Default", client);
	AddMenuItem(hMenuHandle, "5", sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_PlayerActions(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			switch(StringToInt(_sOption))
			{
				case 1:
				{
					Menu_DefaultColors(param1);
				}
				case 2:
				{
					if(Bool_TeleportValid(param1, true, MENU_ACTION))
						Menu_ConfirmTeleport(param1);
				}
				case 3:
				{
					if(Bool_ClearValid(param1, true, MENU_ACTION))
						Menu_ConfirmDelete(param1);
				}
				case 4:
				{
					Menu_DefaultRotation(param1);
				}
				case 5:
				{
					Menu_DefaultPosition(param1);
				}
			}
		}
	}
}

Menu_DefaultColors(client, index = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sTemp[4], String:sBuffer[192];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_DefaultColors);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	for(new i = 0; i < g_iNumColors; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(sBuffer, 192, "%s%s", (g_iConfigColor[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, g_sDefinedColorNames[i]);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer);
	}

	DisplayMenuAtItem(hMenuHandle, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultColors(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigColor[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigColor, _sOption);

#if defined _colors_included
			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Color", g_sDefinedColorNames[g_iConfigColor[param1]]);
#else
			PrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Color", g_sDefinedColorNames[g_iConfigColor[param1]]);
#endif
			if(!g_bEnding)
			{
				if((g_iPlayerAccess[param1] & ACCESS_ADMIN) || !(g_bDisableFeatures && g_iCurrentDisable & DISABLE_COLOR))
				{
					if(g_iPlayerProps[param1] > 0)
					{
						new _iMax;
						if(g_iPlayerAccess[param1] == ACCESS_PUBLIC)
							_iMax = g_iColorPublic;
						else if(g_iPlayerAccess[param1] & ACCESS_ADMIN)
							_iMax = g_iColorAdmin;
						else if(g_iPlayerAccess[param1] & ACCESS_SUPPORTER)
							_iMax = g_iColorSupporter;

						if(_iMax && g_iPlayerColors[param1] >= _iMax)
						{
#if defined _colors_included
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Color_Prop_Limit_Reached");
#else
							PrintToChat(param1, "%s%t", g_sPrefixChat, "Color_Prop_Limit_Reached");
#endif
							Menu_PlayerActions(param1);
							return;
						}
						else
						{
							g_iPlayerColors[param1]++;
							ColorClientProps(param1, g_iConfigColor[param1]);
						}
					}
				}
			}

			Menu_DefaultColors(param1, GetMenuSelectionPosition());
		}
	}
}

Menu_ConfirmTeleport(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_ConfirmTeleport);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	Format(sBuffer, 192, "%T", "Menu_Action_Confirm_Teleport_Ask", client);
	AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
	Format(sBuffer, 192, "%T", "Menu_Action_Confirm_Teleport_Yes", client);
	AddMenuItem(hMenuHandle, "1", sBuffer);
	Format(sBuffer, 192, "%T", "Menu_Action_Confirm_Teleport_No", client);
	AddMenuItem(hMenuHandle, "0", sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_ConfirmTeleport(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			if(Bool_TeleportValid(param1, true, MENU_ACTION))
			{
				if(StringToInt(_sOption))
					PerformTeleport(param1);
				else
					Menu_PlayerActions(param1);
			}
		}
	}
}

Menu_ConfirmDelete(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_ConfirmDelete);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	Format(sBuffer, 192, "%T", "Menu_Action_Confirm_Delete_Ask", client);
	AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
	Format(sBuffer, 192, "%T", "Menu_Action_Confirm_Delete_Yes", client);
	AddMenuItem(hMenuHandle, "1", sBuffer);
	Format(sBuffer, 192, "%T", "Menu_Action_Confirm_Delete_No", client);
	AddMenuItem(hMenuHandle, "0", sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_ConfirmDelete(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			if(StringToInt(_sOption) && Bool_ClearValid(param1, true, MENU_ACTION))
				Bool_ClearClientProps(param1, true, true);
			else
				Menu_PlayerActions(param1);
		}
	}
}

Menu_Admin(client)
{
	decl String:sBuffer[192];
	new _iOptions, Handle:hMenuHandle = CreateMenu(MenuHandler_Admin);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	if(g_iAdminAccess[client] & ADMIN_DELETE)
	{
		_iOptions++;
		Format(sBuffer, 192, "%T", "Menu_Admin_Delete", client);
		AddMenuItem(hMenuHandle, "0", sBuffer);
	}

	if(g_iAdminAccess[client] & ADMIN_TELEPORT)
	{
		_iOptions++;
		Format(sBuffer, 192, "%T", "Menu_Admin_Teleport", client);
		AddMenuItem(hMenuHandle, "1", sBuffer);
	}

	if(g_iAdminAccess[client] & ADMIN_COLOR)
	{
		_iOptions++;
		Format(sBuffer, 192, "%T", "Menu_Admin_Color", client);
		AddMenuItem(hMenuHandle, "2", sBuffer);
	}

	if(_iOptions)
		DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);

	return _iOptions;
}

public MenuHandler_Admin(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			Menu_AdminSelect(param1, StringToInt(_sOption));
		}
	}
}

Menu_AdminSelect(client, action)
{
	decl String:sBuffer[192], String:_sTemp[16];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_AdminSelect);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	Format(sBuffer, 192, "%T", "Menu_Admin_Select_Single", client);
	Format(_sTemp, 16, "%d %d", action, TARGET_SINGLE);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer);

	if(g_iAdminAccess[client] & ADMIN_TARGET)
	{
		Format(sBuffer, 192, "%T", "Menu_Admin_Select_Red", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_RED);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer);

		Format(sBuffer, 192, "%T", "Menu_Admin_Select_Blue", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_BLUE);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer);

		Format(sBuffer, 192, "%T", "Menu_Admin_Select_Mass", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_ALL);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer);
	}

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelect(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:sBuffer[16], String:_sOption[2][8];
			GetMenuItem(menu, param2, sBuffer, 16);
			ExplodeString(sBuffer, " ", _sOption, 2, 8);

			new _iGroup = StringToInt(_sOption[1]);
			switch(StringToInt(_sOption[0]))
			{
				case 0:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, 0);
					else
						Menu_AdminConfirmDelete(param1, _iGroup);
				}
				case 1:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, 1);
					else
						Menu_AdminConfirmTeleport(param1, _iGroup);
				}
				case 2:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, 2);
					else
						Menu_AdminSelectColor(param1, _iGroup);
				}
			}
		}
	}
}

Menu_AdminSelectSingle(client, action)
{
	decl String:_sTemp[16];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_AdminSelectSingle);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	switch(action)
	{
		case 0:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_bHasAccess[g_iTeam[i]])
				{
					Format(_sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(hMenuHandle, _sTemp, g_sName[i]);
				}
			}
		}
		case 1:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_bAlive[i])
				{
					Format(_sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(hMenuHandle, _sTemp, g_sName[i]);
				}
			}
		}
		case 2:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_bHasAccess[g_iTeam[i]])
				{
					Format(_sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(hMenuHandle, _sTemp, g_sName[i]);
				}
			}
		}
	}

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelectSingle(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:sBuffer[16], String:_sOption[2][8];
			GetMenuItem(menu, param2, sBuffer, 16);
			ExplodeString(sBuffer, " ", _sOption, 2, 8);

			new _iTarget = GetClientOfUserId(StringToInt(_sOption[1]));
			if(!_iTarget || !IsClientInGame(_iTarget))
			{
#if defined _colors_included
				CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#else
				PrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#endif
			}
			else if(!CanUserTarget(param1, _iTarget))
			{
#if defined _colors_included
				CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
#else
				PrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
#endif
			}
			else
			{
				switch(StringToInt(_sOption[0]))
				{
					case 0:
						Menu_AdminConfirmDelete(param1, TARGET_SINGLE, StringToInt(_sOption[1]));
					case 1:
						Menu_AdminConfirmTeleport(param1, TARGET_SINGLE, StringToInt(_sOption[1]));
					case 2:
						Menu_AdminSelectColor(param1, TARGET_SINGLE, StringToInt(_sOption[1]));
				}

				return;
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminConfirmDelete(client, group, target = 0)
{
	decl String:sBuffer[192], String:_sTemp[36];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_AdminConfirmDelete);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Red", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_BLUE:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Blue", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_ALL:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Mass", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
	}

	Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_No", client);
	Format(_sTemp, 36, "0 %d %d", group, target);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer);

	Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Yes", client);
	Format(_sTemp, 36, "1 %d %d",  group, target);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmDelete(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[36], String:sBuffer[3][12], String:_sTemp[192];
			GetMenuItem(menu, param2, _sOption, 36);
			ExplodeString(_sOption, " ", sBuffer, 3, 12);

			if(StringToInt(sBuffer[0]))
			{
				switch(StringToInt(sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new _iTarget = GetClientOfUserId(StringToInt(sBuffer[2]));
						if(!_iTarget || !IsClientInGame(_iTarget))
						{
#if defined _colors_included
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#else
							PrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#endif
						}
						else
						{
							if(Bool_ClearClientProps(_iTarget, true, true))
							{
								PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Clear");
								Format(_sTemp, 192, "%T", "Notify_Activity_Clear", LANG_SERVER, _iTarget);
								ShowActivity2(param1, "[SM] ", _sTemp);

								Format(_sTemp, 192, "%T", "Log_Action_Clear", LANG_SERVER, param1, _iTarget);
								LogAction(param1, _iTarget, _sTemp);
							}
						}
					}
					case TARGET_RED:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iTeam[i] == TEAM_RED)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(_sTemp, 192, "%T", "Notify_Activity_Clear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", _sTemp);

										Format(_sTemp, 192, "%T", "Log_Action_Clear", LANG_SERVER, param1, i);
										LogAction(param1, i, _sTemp);
									}
								}
							}
						}

						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Clear_Multiple", _iSucceed);
					}
					case TARGET_BLUE:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iTeam[i] == TEAM_BLUE)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(_sTemp, 192, "%T", "Notify_Activity_Clear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", _sTemp);

										Format(_sTemp, 192, "%T", "Log_Action_Clear", LANG_SERVER, param1, i);
										LogAction(param1, i, _sTemp);
									}
								}
							}
						}

						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Clear_Multiple", _iSucceed);
					}
					case TARGET_ALL:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(_sTemp, 192, "%T", "Notify_Activity_Clear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", _sTemp);

										Format(_sTemp, 192, "%T", "Log_Action_Clear", LANG_SERVER, param1, i);
										LogAction(param1, i, _sTemp);
									}
								}
							}
						}

						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Clear_Multiple", _iSucceed);
					}
				}
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminConfirmTeleport(client, group, target = 0)
{
	decl String:sBuffer[192], String:_sTemp[36];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_AdminConfirmTele);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Red", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_BLUE:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Blue", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_ALL:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Mass", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
	}

	Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_No", client);
	Format(_sTemp, 36, "0 %d %d", group, target);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer);

	Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Yes", client);
	Format(_sTemp, 36, "1 %d %d",  group, target);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmTele(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[36], String:sBuffer[3][12], String:_sTemp[192];
			GetMenuItem(menu, param2, _sOption, 36);
			ExplodeString(_sOption, " ", sBuffer, 3, 12);

			if(StringToInt(sBuffer[0]))
			{
				switch(StringToInt(sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new _iTarget = GetClientOfUserId(StringToInt(sBuffer[2]));
						if(!_iTarget || !IsClientInGame(_iTarget))
						{
#if defined _colors_included
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#else
							PrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#endif
						}
						else if(g_bAlive[_iTarget])
						{
							TeleportPlayer(_iTarget);
							ClearClientTeleport(_iTarget);

							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Tele");
							Format(_sTemp, 192, "%T", "Notify_Activity_Tele", LANG_SERVER, _iTarget);
							ShowActivity2(param1, "[SM] ", _sTemp);

							Format(_sTemp, 192, "%T", "Log_Action_Tele", LANG_SERVER, param1, _iTarget);
							LogAction(param1, _iTarget, _sTemp);
						}
					}
					case TARGET_RED:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i) && g_iTeam[i] == TEAM_RED)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									TeleportPlayer(i);
									ClearClientTeleport(i);

									_iSucceed++;
									Format(_sTemp, 192, "%T", "Notify_Activity_Tele", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", _sTemp);

									Format(_sTemp, 192, "%T", "Log_Action_Tele", LANG_SERVER, param1, i);
									LogAction(param1, i, _sTemp);
								}
							}
						}

						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Tele", _iSucceed);
					}
					case TARGET_BLUE:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i) && g_iTeam[i] == TEAM_BLUE)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									TeleportPlayer(i);
									ClearClientTeleport(i);

									_iSucceed++;
									Format(_sTemp, 192, "%T", "Notify_Activity_Tele", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", _sTemp);

									Format(_sTemp, 192, "%T", "Log_Action_Tele", LANG_SERVER, param1, i);
									LogAction(param1, i, _sTemp);
								}
							}
						}

						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Tele", _iSucceed);
					}
					case TARGET_ALL:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i))
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									TeleportPlayer(i);
									ClearClientTeleport(i);

									_iSucceed++;
									Format(_sTemp, 192, "%T", "Notify_Activity_Tele", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", _sTemp);

									Format(_sTemp, 192, "%T", "Log_Action_Tele", LANG_SERVER, param1, i);
									LogAction(param1, i, _sTemp);
								}
							}
						}

						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Tele", _iSucceed);
					}
				}
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminSelectColor(client, group, target = 0)
{
	decl String:_sTemp[36];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_AdminSelectColor);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	for(new i = 0; i < g_iNumColors; i++)
	{
		Format(_sTemp, 36, "%d %d %d", group, i, target);
		AddMenuItem(hMenuHandle, _sTemp, g_sDefinedColorNames[i]);
	}

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelectColor(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[36], String:sBuffer[3][12];
			GetMenuItem(menu, param2, _sOption, 36);
			ExplodeString(_sOption, " ", sBuffer, 3, 12);

			Menu_AdminConfirmColor(param1, StringToInt(sBuffer[0]), StringToInt(sBuffer[1]), StringToInt(sBuffer[2]));
		}
	}
}

Menu_AdminConfirmColor(client, group, color, target = 0)
{
	decl String:sBuffer[192], String:_sTemp[40];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_AdminConfirmColor);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Red", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_BLUE:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Blue", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_ALL:
		{
			Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Mass", client);
			AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
		}
	}

	Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_No", client);
	Format(_sTemp, 40, "0 %d %d %d", group, color, target);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer);

	Format(sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Yes", client);
	Format(_sTemp, 40, "1 %d %d %d",  group, color, target);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmColor(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[40], String:sBuffer[4][10];
			GetMenuItem(menu, param2, _sOption, 40);
			ExplodeString(_sOption, " ", sBuffer, 4, 10);

			if(StringToInt(sBuffer[0]))
			{
				new iIndex = StringToInt(sBuffer[2]);
				switch(StringToInt(sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new _iTarget = GetClientOfUserId(StringToInt(sBuffer[3]));
						if(!_iTarget || !IsClientInGame(_iTarget))
						{
#if defined _colors_included
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#else
							PrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
#endif
						}
						else
						{
							ColorClientProps(_iTarget, iIndex);
						}
					}
					case TARGET_RED:
					{
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iTeam[i] == TEAM_RED)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
									ColorClientProps(i, iIndex);
							}
						}
					}
					case TARGET_BLUE:
					{
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iTeam[i] == TEAM_BLUE)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
									ColorClientProps(i, iIndex);
							}
						}
					}
					case TARGET_ALL:
					{
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
									ColorClientProps(i, iIndex);
							}
						}
					}
				}
			}

			PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Admin_Color_Succeed");
			Menu_Admin(param1);
		}
	}
}

LoadCookies(client)
{
	decl String:_sTemp[32], String:_sCookie[4] = "";
	GetClientCookie(client, g_cConfigVersion, _sTemp, 32);

	if(StrEqual(_sTemp, "", false))
	{
		SetClientCookie(client, g_cConfigVersion, PLUGIN_VERSION);

		g_iConfigRotation[client] = g_iDefaultRotation;
		IntToString(g_iConfigRotation[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigRotation, _sCookie);

		g_iConfigPosition[client] = g_iDefaultPosition;
		IntToString(g_iConfigPosition[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigPosition, _sCookie);

		g_iConfigColor[client] = g_iDefaultColor;
		IntToString(g_iConfigColor[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigColor, _sCookie);

		for(new i = 0; i < AXIS_TOTAL; i++)
			g_bConfigAxis[client][i]  = false;
		SetClientCookie(client, g_cConfigLocks, "0 0 0 0 0");

		g_fConfigDistance[client] = g_fDefaultControl;
		FloatToString(g_fConfigDistance[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigDistance, _sCookie);
	}
	else
	{
		if(g_bRotationAllowed)
		{
			GetClientCookie(client, g_cConfigRotation, _sCookie, 4);
			g_iConfigRotation[client] = StringToInt(_sCookie);

			if(g_iConfigRotation[client] >= g_iNumRotations)
			{
				g_iConfigRotation[client] = g_iDefaultRotation;
				IntToString(g_iConfigRotation[client], _sCookie, 4);
				SetClientCookie(client, g_cConfigRotation, _sCookie);
			}
		}

		if(g_bPositionAllowed)
		{
			GetClientCookie(client, g_cConfigPosition, _sCookie, 4);
			g_iConfigPosition[client] = StringToInt(_sCookie);

			if(g_iConfigPosition[client] >= g_iNumPositions)
			{
				g_iConfigPosition[client] = g_iDefaultPosition;
				IntToString(g_iConfigPosition[client], _sCookie, 4);
				SetClientCookie(client, g_cConfigPosition, _sCookie);
			}
		}

		if(g_bColorAllowed)
		{
			GetClientCookie(client, g_cConfigColor, _sCookie, 4);
			g_iConfigColor[client] = StringToInt(_sCookie);

			if(g_iConfigColor[client] >= g_iNumColors)
			{
				g_iConfigColor[client] = g_iDefaultColor;
				IntToString(g_iConfigColor[client], _sCookie, 4);
				SetClientCookie(client, g_cConfigColor, _sCookie);
			}
		}

		if(g_bControlAllowed)
		{
			GetClientCookie(client, g_cConfigDistance, _sCookie, 4);
			g_fConfigDistance[client] = StringToFloat(_sCookie);

			if(g_fConfigDistance[client] < g_fGrabMinimum || g_fConfigDistance[client] > g_fGrabMaximum)
			{
				g_fConfigDistance[client] = g_fDefaultControl;
				FloatToString(g_fConfigDistance[client], _sCookie, 4);
				SetClientCookie(client, g_cConfigDistance, _sCookie);
			}

			decl String:sBuffer[AXIS_TOTAL][4];
			GetClientCookie(client, g_cConfigLocks, _sTemp, 32);

			ExplodeString(_sTemp, " ", sBuffer, AXIS_TOTAL, 4);
			for(new i = 0; i < AXIS_TOTAL; i++)
				g_bConfigAxis[client][i] = StrEqual(sBuffer[i], "0", false) ? false : true;
		}
	}

	g_bLoaded[client] = true;
}

public Action:Command_Help(client, args)
{
	if(g_iEnabled && g_bHelp)
	{
		if(args < 1)
		{
			ReplyToCommand(client, "%t", "Command_Show_Help_Failure");
			return Plugin_Handled;
		}

		new _iTargets[MAXPLAYERS + 1], bool:_bTemp;
		decl String:_sPattern[64], String:sBuffer[192];
		GetCmdArg(1, _sPattern, 64);
		new _iCount = ProcessTargetString(_sPattern, client, _iTargets, sizeof(_iTargets), COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED, sBuffer, sizeof(sBuffer), _bTemp);
		if(_iCount)
		{
			for(new i = 0; i < _iCount; i++)
			{
				if(IsClientInGame(_iTargets[i]))
				{
					Format(sBuffer, 192, "%T", "Command_Show_Help_Show_Activity", LANG_SERVER, _iTargets[i]);
					ShowActivity2(client, "[SM] ", sBuffer);

					Format(sBuffer, 192, "%T", "Command_Show_Help_Log_Message", LANG_SERVER, client, _iTargets[i]);
					LogAction(client, _iTargets[i], sBuffer);

					Format(sBuffer, 192, "%T", "Command_Help_Url_Title", LANG_SERVER);
					ShowMOTDPanel(_iTargets[i], sBuffer, g_sHelp, MOTDPANEL_TYPE_URL);
				}
			}
		}
	}

	return Plugin_Handled;
}


public Action:Command_Reset(client, args)
{
	if(g_iEnabled)
	{
		if(!g_bEnding && (!client || (IsClientInGame(client) && !(g_iAdminAccess[client] & ADMIN_DELETE))))
		{
			if(args)
			{
				decl String:sBuffer[64];
				GetCmdArg(1, sBuffer, sizeof(sBuffer));
				new _iTarget = FindTarget(client, sBuffer, false, true);

				if(_iTarget > 0)
					Bool_ClearClientProps(_iTarget, false, _);
			}
			else
			{
				for(new i = 1; i <= MaxClients; i++)
					if(IsClientInGame(i))
						Bool_ClearClientProps(i, false, _);
			}
		}
	}

	return Plugin_Handled;
}

AuthClient(client)
{
	g_iPlayerAccess[client] = ACCESS_PUBLIC;
	if(CheckCommandAccess(client, "bw_access_supporter", AUTH_SUPPORTER))
		g_iPlayerAccess[client] += ACCESS_SUPPORTER;

	if(CheckCommandAccess(client, "bw_access_admin", AUTH_ADMIN))
		g_iPlayerAccess[client] += ACCESS_ADMIN;

	if(CheckCommandAccess(client, "bw_access_base", AUTH_BASE))
		g_iPlayerAccess[client] += ACCESS_BASE;

	g_iAdminAccess[client] = ADMIN_NONE;
	if(CheckCommandAccess(client, "bw_admin_delete", AUTH_DELETE))
		g_iAdminAccess[client] += ADMIN_DELETE;

	if(CheckCommandAccess(client, "bw_admin_teleport", AUTH_TELEPORT))
		g_iAdminAccess[client] += ADMIN_TELEPORT;

	if(CheckCommandAccess(client, "bw_admin_color", AUTH_COLOR))
		g_iAdminAccess[client] += ADMIN_COLOR;

	if(CheckCommandAccess(client, "bw_admin_target", AUTH_TARGET))
		g_iAdminAccess[client] += ADMIN_TARGET;
}

ReturnToMenu(client, _iMenu, _iSlot = 0)
{
	switch(_iMenu)
	{
		case MENU_MAIN:
		{
			Menu_Main(client);
		}
		case MENU_CREATE:
		{
			Menu_Create(client, _iSlot);
		}
		case MENU_ROTATE:
		{
			Menu_ModifyRotation(client);
		}
		case MENU_MOVE:
		{
			Menu_ModifyPosition(client);
		}
		case MENU_CONTROL:
		{
			Menu_Control(client);
		}
		case MENU_COLOR:
		{
			Menu_DefaultColors(client);
		}
		case MENU_ACTION:
		{
			Menu_PlayerActions(client);
		}
		case MENU_ADMIN:
		{
			if(!Menu_Admin(client))
				Menu_Main(client);
		}
		case MENU_BASE_MAIN:
		{
			Menu_BaseActions(client);
		}
		case MENU_BASE_CURRENT:
		{
			if(_iSlot == -1)
				_iSlot = g_iPlayerBaseCurrent[client];

			Menu_BaseCurrent(client, _iSlot);
		}
		case MENU_BASE_MOVE:
		{
			Menu_BaseMove(client);
		}
	}
}

bool:Bool_DeleteAllowed(client, bool:_bMessage = false, bool:_bClear = false)
{
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iDeletePublic != -1)
		{
			if(!g_iDeletePublic)
				return true;
			else
			{
				if(_bClear)
				{
					if((g_iPlayerDeletes[client] + g_iPlayerProps[client]) < g_iDeletePublic)
						return true;
					else if(_bMessage)
					{
#if defined _colors_included
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
#else
						PrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
#endif
					}
				}
				else
				{
					if(g_iPlayerDeletes[client] < g_iDeletePublic)
						return true;
					else if(_bMessage)
					{
#if defined _colors_included
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
#else
						PrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
#endif
					}
				}
			}
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iDeleteAdmin != -1)
		{
			if(!g_iDeleteAdmin)
				return true;
			else
			{
				if(_bClear)
				{
					if((g_iPlayerDeletes[client] + g_iPlayerProps[client]) < g_iDeleteAdmin)
						return true;
					else if(_bMessage)
					{
#if defined _colors_included
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
#else
						PrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
#endif
					}
				}
				else
				{
					if(g_iPlayerDeletes[client] < g_iDeleteAdmin)
						return true;
					else if(_bMessage)
					{
#if defined _colors_included
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
#else
						PrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
#endif
					}
				}
			}
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iDeleteSupporter != -1)
		{
			if(!g_iDeleteSupporter)
				return true;
			else
			{
				if(_bClear)
				{
					if((g_iPlayerDeletes[client] + g_iPlayerProps[client]) < g_iDeleteSupporter)
						return true;
					else if(_bMessage)
					{
#if defined _colors_included
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
#else
						PrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
#endif
					}
				}
				else
				{
					if(g_iPlayerDeletes[client] < g_iDeleteSupporter)
						return true;
					else if(_bMessage)
					{
#if defined _colors_included
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
#else
						PrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
#endif
					}
				}
			}
		}

		return false;
	}

	return false;
}

bool:Bool_DeleteValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_DELETE)
		{
			if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Restricted");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Restricted");
#endif
			}

			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
	}

	return true;
}

bool:Bool_ClearValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_CLEAR)
		{
			if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Clear_Prop_Restricted");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Clear_Prop_Restricted");
#endif
			}

			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
	}

	return true;
}

bool:Bool_SpawnAllowed(client, bool:_bMessage = false)
{
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iPropPublic != -1)
		{
			if(!g_iPropPublic)
				return true;
			else if(g_iPlayerProps[client] < g_iPropPublic)
				return true;
			else if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
#endif
			}
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iPropAdmin != -1)
		{
			if(!g_iPropAdmin)
				return true;
			else if(g_iPlayerProps[client] < g_iPropAdmin)
				return true;
			else if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
#endif
			}
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iPropSupporter != -1)
		{
			if(!g_iPropSupporter)
				return true;
			else if(g_iPlayerProps[client] < g_iPropSupporter)
				return true;
			else if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
#endif
			}
		}

		return false;
	}

	return false;
}

bool:Bool_SpawnValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_SPAWN)
		{
			if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Restricted");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Restricted");
#endif
			}

			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
	}

	return true;
}

Int_SpawnMaximum(client)
{
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
		return g_iPropPublic;
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
		return g_iPropAdmin;
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
		return g_iPropSupporter;

	return 0;
}

bool:Bool_RotateValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!g_bRotationAllowed)
		return false;
	else if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_ROTATE)
		{
			if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Rotate_Prop_Restricted");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Rotate_Prop_Restricted");
#endif
			}

			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
	}

	return true;
}

bool:Bool_MoveValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!g_bPositionAllowed)
		return false;
	else if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_MOVE)
		{
			if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Position_Prop_Restricted");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Position_Prop_Restricted");
#endif
			}

			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
	}

	return true;
}

bool:Bool_ControlValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!g_bControlAllowed)
		return false;
	else if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_CONTROL)
		{
			if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Restricted");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Restricted");
#endif
			}

			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
	}

	return true;
}

bool:Bool_CheckValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!g_bControlAllowed)
		return false;
	else if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_CHECK)
		{
			if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Check_Prop_Restricted");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Check_Prop_Restricted");
#endif
			}

			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
	}

	return true;
}

bool:Bool_TeleportAllowed(client, bool:_bMessage = false)
{
	if(g_bTeleporting[client])
	{
		if(_bMessage)
		{
#if defined _colors_included
			CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_In_Progress");
#else
			PrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_In_Progress");
#endif
		}

		return false;
	}

	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iTeleportPublic != -1)
		{
			if(!g_iTeleportPublic)
				return true;
			else if(g_iPlayerTeleports[client] < g_iTeleportPublic)
				return true;
			else if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
#endif
			}
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iTeleportAdmin != -1)
		{
			if(!g_iTeleportAdmin)
				return true;
			else if(g_iPlayerTeleports[client] < g_iTeleportAdmin)
				return true;
			else if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
#endif
			}
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iTeleportSupporter != -1)
		{
			if(!g_iTeleportSupporter)
				return true;
			else if(g_iPlayerTeleports[client] < g_iTeleportSupporter)
				return true;
			else if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
#endif
			}
		}

		return false;
	}

	return false;
}

bool:Bool_TeleportValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_TELE)
		{
			if(_bMessage)
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Restricted");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Restricted");
#endif
			}

			if(_iReturn)
				ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
	}

	return true;
}

bool:Bool_ColorValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(g_bEnding || !g_bAlive[client])
	{
		if(_iReturn)
			ReturnToMenu(client, _iReturn, _iSlot);

		return false;
	}
	else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_COLOR)
	{
		if(_bMessage)
		{
#if defined _colors_included
			CPrintToChat(client, "%s%t", g_sPrefixChat, "Color_Prop_Restricted");
#else
			PrintToChat(client, "%s%t", g_sPrefixChat, "Color_Prop_Restricted");
#endif
		}

		if(_iReturn)
			ReturnToMenu(client, _iReturn, _iSlot);

		return false;
	}

	return true;
}

Define_Props()
{
	decl String:sTempPath[PLATFORM_MAX_PATH];
	if(g_bGlobalOffensive)
		BuildPath(Path_SM, sTempPath, PLATFORM_MAX_PATH, "configs/buildwars_v2/sm_buildwars_props.csgo.ini");
	else
		BuildPath(Path_SM, sTempPath, PLATFORM_MAX_PATH, "configs/buildwars_v2/sm_buildwars_props.css.ini");

	new iCurrent = GetFileTime(sTempPath, FileTime_LastChange);
	if(iCurrent < g_iLoadProps)
		return;
	else
		g_iLoadProps = iCurrent;

	g_iNumProps = 0;
	new Handle:hKeyValue = CreateKeyValues("BuildWars_Props");
	if(FileToKeyValues(hKeyValue, sTempPath))
	{
		KvGotoFirstSubKey(hKeyValue);
		do
		{
			KvGetSectionName(hKeyValue, g_sDefinedPropNames[g_iNumProps], 64);
			KvGetString(hKeyValue, "path", g_sDefinedPropPaths[g_iNumProps], PLATFORM_MAX_PATH);
			PrecacheModel(g_sDefinedPropPaths[g_iNumProps]);

			g_iDefinedPropTypes[g_iNumProps] = KvGetNum(hKeyValue, "type");
			g_iDefinedPropAccess[g_iNumProps] = KvGetNum(hKeyValue, "access");
			g_iNumProps++;
		}
		while (KvGotoNextKey(hKeyValue));
		CloseHandle(hKeyValue);
	}
	else
	{
		CloseHandle(hKeyValue);
		if(g_bGlobalOffensive)
			SetFailState("BuildWars: Could not locate \"configs/buildwars_v2/sm_buildwars_props.csgo.ini\"");
		else
			SetFailState("BuildWars: Could not locate \"configs/buildwars_v2/sm_buildwars_props.css.ini\"");
	}
}

Define_Colors()
{
	decl String:sTempPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sTempPath, PLATFORM_MAX_PATH, "configs/buildwars_v2/sm_buildwars_colors.ini");

	new iCurrent = GetFileTime(sTempPath, FileTime_LastChange);
	if(iCurrent < g_iLoadColors)
		return;
	else
		g_iLoadColors = iCurrent;

	g_iNumColors = 0;
	new Handle:hKeyValue = CreateKeyValues("BuildWars_Colors");
	if(FileToKeyValues(hKeyValue, sTempPath))
	{
		decl String:_sTemp[64], String:_sValues[][] = { "Red", "Green", "Blue", "Alpha" };
		KvGotoFirstSubKey(hKeyValue);
		do
		{
			KvGetSectionName(hKeyValue, g_sDefinedColorNames[g_iNumColors], 64);

			for(new i = 0; i <= 3; i++)
			{
				KvGetString(hKeyValue, _sValues[i], _sTemp, 64);
				g_iDefinedColorArrays[g_iNumColors][i] = StringToInt(_sTemp);
			}

			g_iNumColors++;
		}
		while (KvGotoNextKey(hKeyValue));
		CloseHandle(hKeyValue);
	}
	else
	{
		CloseHandle(hKeyValue);
		SetFailState("BuildWars: Could not locate \"configs/buildwars_v2/sm_buildwars_colors.ini\"");
	}
}

Define_Rotations()
{
	decl String:sTempPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sTempPath, PLATFORM_MAX_PATH, "configs/buildwars_v2/sm_buildwars_rotations.ini");

	new iCurrent = GetFileTime(sTempPath, FileTime_LastChange);
	if(iCurrent < g_iLoadRotations)
		return;
	else
		g_iLoadRotations = iCurrent;

	g_iNumRotations = 0;
	new Handle:hKeyValue = CreateKeyValues("BuildWars_Rotations");
	if(FileToKeyValues(hKeyValue, sTempPath))
	{
		decl String:_sTemp[64];
		KvGotoFirstSubKey(hKeyValue);
		do
		{
			KvGetString(hKeyValue, "value", _sTemp, 64);
			g_fDefinedRotations[g_iNumRotations] = StringToFloat(_sTemp);

			g_iNumRotations++;
		}
		while (KvGotoNextKey(hKeyValue));
		CloseHandle(hKeyValue);
	}
	else
	{
		CloseHandle(hKeyValue);
		SetFailState("BuildWars: Could not locate \"configs/buildwars_v2/sm_buildwars_rotations.ini\"");
	}
}

Define_Positions()
{	decl String:sTempPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sTempPath, PLATFORM_MAX_PATH, "configs/buildwars_v2/sm_buildwars_positions.ini");

	new iCurrent = GetFileTime(sTempPath, FileTime_LastChange);
	if(iCurrent < g_iLoadPositions)
		return;
	else
		g_iLoadPositions = iCurrent;

	g_iNumPositions = 0;
	new Handle:hKeyValue = CreateKeyValues("BuildWars_Positions");
	if(FileToKeyValues(hKeyValue, sTempPath))
	{
		decl String:_sTemp[64];
		KvGotoFirstSubKey(hKeyValue);
		do
		{
			KvGetString(hKeyValue, "value", _sTemp, 64);
			g_fDefinedPositions[g_iNumPositions] = StringToFloat(_sTemp);

			g_iNumPositions++;
		}
		while (KvGotoNextKey(hKeyValue));
		CloseHandle(hKeyValue);
	}
	else
	{
		CloseHandle(hKeyValue);
		SetFailState("BuildWars: Could not locate \"configs/buildwars_v2/sm_buildwars_positions.ini\"");
	}
}

Define_Commands()
{
	decl String:sTempPath[PLATFORM_MAX_PATH];
	if(g_bGlobalOffensive)
		BuildPath(Path_SM, sTempPath, PLATFORM_MAX_PATH, "configs/buildwars_v2/sm_buildwars_cmds.csgo.ini");
	else
		BuildPath(Path_SM, sTempPath, PLATFORM_MAX_PATH, "configs/buildwars_v2/sm_buildwars_cmds.css.ini");

	new iCurrent = GetFileTime(sTempPath, FileTime_LastChange);
	if(iCurrent < g_iLoadCommands)
		return;
	else
		g_iLoadCommands = iCurrent;

	ClearTrie(g_hTrieCommands);
	new Handle:hKeyValue = CreateKeyValues("BuildWars_Commands");
	if(FileToKeyValues(hKeyValue, sTempPath))
	{
		decl iIndex, String:_sTemp[4], String:sBuffer[32];
		KvGotoFirstSubKey(hKeyValue);
		do
		{
			KvGetSectionName(hKeyValue, sBuffer, sizeof(sBuffer));
			GetTrieValue(g_hTrieCommandConfig, sBuffer, iIndex);
			for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
			{
				IntToString(i, _sTemp, sizeof(_sTemp));
				KvGetString(hKeyValue, _sTemp, sBuffer, sizeof(sBuffer));
				if(!StrEqual(sBuffer, ""))
					SetTrieValue(g_hTrieCommands, sBuffer, iIndex);
			}
		}
		while (KvGotoNextKey(hKeyValue));
		CloseHandle(hKeyValue);
	}
	else
	{
		CloseHandle(hKeyValue);
		if(g_bGlobalOffensive)
			SetFailState("BuildWars: Could not locate \"configs/buildwars_v2/sm_buildwars_cmds.csgo.ini\"");
		else
			SetFailState("BuildWars: Could not locate \"configs/buildwars_v2/sm_buildwars_cmds.css.ini\"");
	}
}


public SQL_ConnectCall(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_ConnectCall Error: %s", error);
	else
	{
		SQL_LockDatabase(hndl);
		if(!SQL_FastQuery(hndl, g_sSQL_CreateBaseTable))
		{
			decl String:_sError[512];
			SQL_GetError(hndl, _sError, 512);
			LogError("SQL_ConnectCall: Unable to create buildwars_bases!");
			LogError("SQL_ConnectCall: Error: %s", _sError);
			CloseHandle(hndl);
			return;
		}

		if(!SQL_FastQuery(hndl, g_sSQL_CreatePropTable))
		{
			decl String:_sError[512];
			SQL_GetError(hndl, _sError, 512);
			LogError("SQL_ConnectCall: Unable to create buildwars_props!");
			LogError("SQL_ConnectCall: Error: %s", _sError);
			CloseHandle(hndl);
			return;
		}
		SQL_UnlockDatabase(hndl);

		g_hSql_Database = hndl;
		if(g_bLateBase)
		{
			if(g_bBaseEnabled)
				for(new i = 1; i <= MaxClients; i++)
					if(IsClientInGame(i))
						if((g_iPlayerAccess[i] & g_iBaseAccess || g_iPlayerAccess[i] & ACCESS_BASE))
							LoadClientBase(i);

			g_bLateBase = false;
		}
	}
}

public SQL_QueryBaseLoad(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseLoad Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			decl String:_sQuery[256];
			new _iRows = SQL_GetRowCount(hndl);
			if(_iRows < g_iBaseGroups)
			{
				Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseCreate, g_sSteam[client]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseCreate, _sQuery, userid);
			}
			else
			{
				for(new i = 0; i < g_iBaseGroups; i++)
				{
					SQL_FetchRow(hndl);
					g_iPlayerBase[client][i] = SQL_FetchInt(hndl, 0);
					g_iPlayerBaseCount[client][i] = SQL_FetchInt(hndl, 1);

					Format(_sQuery, sizeof(_sQuery), g_sSQL_PropCheck, g_iPlayerBase[client][i]);
					SQL_TQuery(g_hSql_Database, SQL_QueryPropCheck, _sQuery, userid);
				}
			}
		}
	}
}

public SQL_QueryPropCheck(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropCheck Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			decl String:_sQuery[256];
			new _iCount = SQL_GetRowCount(hndl);
			if(_iCount != g_iPlayerBaseCount[client][g_iPlayerBaseLoading[client]])
			{
				g_iPlayerBaseQuery[client] += 1;
				g_iPlayerBaseCount[client][g_iPlayerBaseLoading[client]] = _iCount;

				Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseUpdate, _iCount, g_iPlayerBase[client][g_iPlayerBaseLoading[client]]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseUpdate, _sQuery, userid);
			}

			g_iPlayerBaseLoading[client]++;
			if(g_iPlayerBaseLoading[client] == g_iBaseGroups && g_iPlayerBaseMenu[client] != -1)
			{
				QueryBuildMenu(client, MENU_BASE_CURRENT);
				g_iPlayerBaseMenu[client] = -1;
			}
		}
	}
}

public SQL_QueryBaseCreate(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseCreate Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			decl String:_sQuery[256];
			Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseLoad, g_sSteam[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryBaseLoad, _sQuery, userid);
		}
	}
}

public SQL_QueryPropSaveMass(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropSave Error: %s", error);
	else
	{
		new iEntity = EntRefToEntIndex(ref);
		if(iEntity != INVALID_ENT_REFERENCE)
		{
			g_bValidBase[iEntity] = true;
			g_iBaseIndex[iEntity] = SQL_GetInsertId(owner);

			new client = GetClientOfUserId(g_iPropUser[iEntity]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				if(!g_iPlayerBaseQuery[client])
				{
#if defined _colors_included
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#else
					PrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#endif

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_CURRENT);
						g_iPlayerBaseMenu[client] = -1;
					}
				}

				g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]++;
			}
		}
	}
}

public SQL_QueryPropSaveSingle(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropSave Error: %s", error);
	else
	{
		new iEntity = EntRefToEntIndex(ref);
		if(iEntity != INVALID_ENT_REFERENCE)
		{
			new _iTemp = g_iBaseIndex[iEntity];
			g_bValidBase[iEntity] = true;
			g_iBaseIndex[iEntity] = SQL_GetInsertId(owner);

			new client = GetClientOfUserId(g_iPropUser[iEntity]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				if(!g_iPlayerBaseQuery[client])
				{
#if defined _colors_included
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props", g_sDefinedPropNames[g_iPropType[iEntity]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#else
					PrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props", g_sDefinedPropNames[g_iPropType[iEntity]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#endif

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_CURRENT);
						g_iPlayerBaseMenu[client] = -1;
					}
				}

				if(g_iBaseIndex[iEntity] != _iTemp)
					g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]++;
			}
		}
	}
}

public SQL_QueryPropDelete(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropDelete Error: %s", error);
	else
	{
		new iEntity = EntRefToEntIndex(ref);
		if(iEntity != INVALID_ENT_REFERENCE)
		{
			g_bValidBase[iEntity] = false;
			g_iBaseIndex[iEntity] = -1;

			new client = GetClientOfUserId(g_iPropUser[iEntity]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]--;
				if(!g_iPlayerBaseQuery[client])
				{
#if defined _colors_included
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props", g_sDefinedPropNames[g_iPropType[iEntity]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#else
					PrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props", g_sDefinedPropNames[g_iPropType[iEntity]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#endif

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_CURRENT);
						g_iPlayerBaseMenu[client] = -1;
					}
				}
			}
		}
	}
}

public SQL_QueryBaseEmpty(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseEmpty Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerBaseQuery[client] -= 1;
			g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]] = 0;
			if(!g_iPlayerBaseQuery[client])
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props_All", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props_All", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#endif

				if(g_iPlayerBaseMenu[client] != -1)
				{
					QueryBuildMenu(client, MENU_BASE_CURRENT);
					g_iPlayerBaseMenu[client] = -1;
				}
			}
		}
	}
}

public SQL_QueryBaseReadySave(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseReadySave Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]] = 0;

			new _iSize = (GetArraySize(g_hArray_PlayerProps[client]) - 1);
			new Float:_fSaveDelay = 0.1;
			g_iPlayerBaseQuery[client] -= 1;
			g_bPlayerBaseSpawned[client] = true;

			for(new i = _iSize; i >= 0; i--)
			{
				new iEntity = GetArrayCell(g_hArray_PlayerProps[client], i);
				if(IsValidEntity(iEntity))
				{
					g_iPlayerBaseQuery[client] += 1;

					new Handle:_hPack = INVALID_HANDLE;
					CreateDataTimer(_fSaveDelay, Timer_SaveBaseProps, _hPack);
					WritePackCell(_hPack, client);
					WritePackCell(_hPack, iEntity);
					_fSaveDelay += 0.01;
				}
			}
		}
	}
}

public SQL_QueryBaseUpdate(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseUpdate Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerBaseQuery[client] -= 1;
			if(!g_iPlayerBaseQuery[client] && g_iPlayerBaseMenu[client] != -1)
			{
				QueryBuildMenu(client, MENU_BASE_CURRENT);
				g_iPlayerBaseMenu[client] = -1;
			}
		}
	}
}

public SQL_QueryBaseUpdatePost(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseUpdate Error: %s", error);
}

public SQL_QueryPropLoad(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropLoad Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			new Float:_fSpawnDelay = 0.1;
			decl Float:_fOrigin[3];
			while (SQL_FetchRow(hndl))
			{
				new Handle:_hPack = INVALID_HANDLE;
				CreateDataTimer(_fSpawnDelay, Timer_SpawnBaseProps, _hPack);
				WritePackCell(_hPack, client);

				WritePackCell(_hPack, SQL_FetchInt(hndl, 0));
				WritePackCell(_hPack, SQL_FetchInt(hndl, 1));

				_fOrigin[0] = SQL_FetchFloat(hndl, 2);
				_fOrigin[1] = SQL_FetchFloat(hndl, 3);
				_fOrigin[2] = SQL_FetchFloat(hndl, 4);
				AddVectors(_fOrigin, g_fPlayerBaseLocation[client], _fOrigin);
				WritePackFloat(_hPack, _fOrigin[0]);
				WritePackFloat(_hPack, _fOrigin[1]);
				WritePackFloat(_hPack, _fOrigin[2]);

				WritePackFloat(_hPack, SQL_FetchFloat(hndl, 5));
				WritePackFloat(_hPack, (SQL_FetchFloat(hndl, 6) + 180.0));
				WritePackFloat(_hPack, SQL_FetchFloat(hndl, 7));
				_fSpawnDelay += 0.025;
			}
		}
	}
}

public Action:Timer_SpawnBaseProps(Handle:timer, Handle:pack)
{
	decl Float:_fOrigin[3], Float:_fAngles[3];

	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iIndex = ReadPackCell(pack);
	new _iType = ReadPackCell(pack);
	for(new i = 0; i <= 2; i++)
		_fOrigin[i] = ReadPackFloat(pack);
	for(new i = 0; i <= 2; i++)
		_fAngles[i] = ReadPackFloat(pack);

	new iEntity = Entity_SpawnBase(client, _iType, _fOrigin, _fAngles, iIndex);
	PushArrayCell(g_hArray_PlayerProps[client], iEntity);
	g_iPlayerProps[client]++;

	g_iPlayerBaseQuery[client] -= 1;
	if(!g_iPlayerBaseQuery[client])
	{
#if defined _colors_included
		CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#else
		PrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#endif

		if(g_iPlayerBaseMenu[client] != -1)
		{
			QueryBuildMenu(client, MENU_BASE_CURRENT);
			g_iPlayerBaseMenu[client] = -1;
		}
	}
}

QueryBuildMenu(client, menu, group = -1)
{
	if(g_iPlayerBaseLoading[client] < g_iBaseGroups)
	{
		decl String:sBuffer[192];
		new Handle:hMenuHandle = CreateMenu(MenuHandler_BaseLoading);
		SetMenuTitle(hMenuHandle, g_sTitle);
		SetMenuExitButton(hMenuHandle, true);
		SetMenuExitBackButton(hMenuHandle, true);

		Format(sBuffer, 192, "%T", "Menu_Base_Loading", client);
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

		Format(sBuffer, 192, "%T", "Menu_Base_Loading_Wait", client);
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

		DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
	}
	else if(g_iPlayerBaseQuery[client] > 0)
	{
		decl String:sBuffer[192];
		new Handle:hMenuHandle = CreateMenu(MenuHandler_BaseQuery);
		SetMenuTitle(hMenuHandle, g_sTitle);
		SetMenuExitButton(hMenuHandle, true);
		SetMenuExitBackButton(hMenuHandle, true);

		Format(sBuffer, 192, "%T", "Menu_Base_Query", client);
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

		Format(sBuffer, 192, "%T", "Menu_Base_Query_Wait", client);
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

		DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
	}
	else
	{
		switch(menu)
		{
			case MENU_BASE_NULL:
			{
#if defined _colors_included
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Query_Completed");
#else
				PrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Query_Completed");
#endif
			}
			case MENU_BASE_MAIN:
			{
				Menu_BaseActions(client);
			}
			case MENU_BASE_CURRENT:
			{
				if(group == -1)
					group = g_iPlayerBaseCurrent[client];

				Menu_BaseCurrent(client, group);
			}
			case MENU_BASE_MOVE:
			{
				Menu_BaseMove(client);
			}
		}
	}
}

Menu_BaseActions(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192], String:_sIndex[4];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_BaseActions);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	for(new i = 0; i < g_iBaseGroups; i++)
	{
		IntToString(i, _sIndex, 4);
		Format(sBuffer, 192, "%T", "Menu_Base_Option", client, g_sBaseNames[i]);
		Format(sBuffer, 192, "%s%T", sBuffer, "Menu_Base_Option_Props", client, g_iPlayerBaseCount[client][i]);
		if(g_iBaseGroups > 1 && g_iPlayerBaseCurrent[client] == i)
			Format(sBuffer, 192, "%s%T", sBuffer, "Menu_Base_Current", client);

		AddMenuItem(hMenuHandle, _sIndex, sBuffer);
	}

	Format(sBuffer, 192, "%T", "Menu_Base_Spacer", client);
	if(!StrEqual(sBuffer, ""))
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

	if(g_bSaveLocation[client])
	{
		Format(sBuffer, 192, "%T", "Menu_Base_Update_Location", client);
		AddMenuItem(hMenuHandle, "7", sBuffer);

		Format(sBuffer, 192, "%T", "Menu_Base_Clear_Location", client);
		AddMenuItem(hMenuHandle, "8", sBuffer);
	}
	else
	{
		Format(sBuffer, 192, "%T", "Menu_Base_Set_Location", client);
		AddMenuItem(hMenuHandle, "7", sBuffer);

		Format(sBuffer, 192, "%T", "Menu_Base_Clear_Location", client);
		AddMenuItem(hMenuHandle, "8", sBuffer, ITEMDRAW_DISABLED);
	}

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseActions(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			new _iOption = StringToInt(_sOption);

			if(_iOption >= 0 && _iOption <= 6)
				QueryBuildMenu(param1, MENU_BASE_CURRENT, _iOption);
			else if(_iOption == 7)
			{
				if(!g_bEnding)
				{
					decl Float:_fDestination[3], Float:_fOrigin[3], Float:_fAngles[3];
					GetClientAbsOrigin(param1, _fOrigin);
					GetClientEyePosition(param1, _fDestination);
					GetClientEyeAngles(param1, _fAngles);

					TR_TraceRayFilter(_fDestination, _fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterPlayers, param1);
					if(TR_DidHit(INVALID_HANDLE))
					{
						TR_GetEndPosition(g_fSaveLocation[param1], INVALID_HANDLE);
						if(g_bSaveLocation[param1])
						{
#if defined _colors_included
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Update");
#else
							PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Update");
#endif
							CloseHandle(g_hSaveLocation[param1]);
						}
						else
						{
#if defined _colors_included
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Issue");
#else
							PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Issue");
#endif
							g_bSaveLocation[param1] = true;
						}

						DisplaySaveLocation(param1);
						g_hSaveLocation[param1] = CreateTimer(1.0, Timer_DisplaySaveLocation, param1, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}

				QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
			else if(_iOption == 8)
			{
				if(!g_bEnding)
				{
					g_bSaveLocation[param1] = false;
					if(g_hSaveLocation[param1] != INVALID_HANDLE && CloseHandle(g_hSaveLocation[param1]))
						g_hSaveLocation[param1] = INVALID_HANDLE;

#if defined _colors_included
					CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Cancel");
#else
					PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Cancel");
#endif
				}

				QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
		}
	}
}

public MenuHandler_BaseLoading(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
			{
				g_iPlayerBaseMenu[param1] = -1;
				Menu_Main(param1);
			}
		}
	}
}

public MenuHandler_BaseQuery(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
			{
				g_iPlayerBaseMenu[param1] = -1;
				Menu_Main(param1);
			}
		}
	}
}

Menu_BaseCurrent(client, group)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192], String:_sTemp[32];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_BaseCurrent);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	if(g_iBaseGroups > 1)
	{
		if(g_iPlayerBaseCurrent[client] != -1)
		{
			Format(sBuffer, 192, "%T", "Menu_Base_Current_Base", client, g_sBaseNames[g_iPlayerBaseCurrent[client]]);
			AddMenuItem(hMenuHandle, "0", sBuffer, ITEMDRAW_DISABLED);
		}

		if(g_iPlayerBaseCurrent[client] != group)
		{
			Format(_sTemp, 32, "%d 1", group);
			Format(sBuffer, 192, "%T", "Menu_Base_Current_Select", client, g_sBaseNames[group]);
			AddMenuItem(hMenuHandle, _sTemp, sBuffer, ITEMDRAW_DEFAULT);
		}
		else
		{
			if(g_iPlayerBaseCurrent[client] != -1)
			{
				Format(sBuffer, 192, "%T", "Menu_Base_Spacer", client);
				if(!StrEqual(sBuffer, ""))
					AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);
			}
		}
	}

	new _iState = g_iPlayerBaseCurrent[client] != group ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
	if(!g_bPlayerBaseSpawned[client] || g_iPlayerBaseCurrent[client] != group)
	{
		Format(_sTemp, 32, "%d 2", group);
		Format(sBuffer, 192, "%T", "Menu_Base_Current_Spawn", client);
		AddMenuItem(hMenuHandle,_sTemp, sBuffer, _iState);
	}
	else
	{
		Format(_sTemp, 32, "%d 3", group);
		Format(sBuffer, 192, "%T", "Menu_Base_Current_Delete", client);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer, _iState);
	}

	Format(_sTemp, 32, "%d 4", group);
	Format(sBuffer, 192, "%T", "Menu_Base_Current_Save_Target", client);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer, _iState);

	Format(_sTemp, 32, "%d 5", group);
	Format(sBuffer, 192, "%T", "Menu_Base_Current_Clear_Target", client);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer, _iState);

	Format(_sTemp, 32, "%d 6", group);
	Format(sBuffer, 192, "%T", "Menu_Base_Current_Save_All", client);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer, _iState);

	Format(_sTemp, 32, "%d 7", group);
	Format(sBuffer, 192, "%T", "Menu_Base_Current_Clear_All", client);
	AddMenuItem(hMenuHandle, _sTemp, sBuffer, _iState);

	if(g_bPositionAllowed)
	{
		Format(_sTemp, 32, "%d 8", group);
		Format(sBuffer, 192, "%T", "Menu_Base_Current_Move_All", client);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer, _iState);
	}

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseCurrent(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				QueryBuildMenu(param1, MENU_BASE_MAIN);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			g_iPlayerBaseMenu[param1] = MENU_BASE_CURRENT;

			decl String:_sOption[8], String:sBuffer[2][4];
			GetMenuItem(menu, param2, _sOption, 8);
			ExplodeString(_sOption, " ", sBuffer, 2, 4);

			new _iGroup = StringToInt(sBuffer[0]);
			switch(StringToInt(sBuffer[1]))
			{
				case 1:
				{
					if(g_iPlayerBaseCurrent[param1] != _iGroup)
					{
						g_iPlayerBaseCurrent[param1] = _iGroup;

						if(g_bPlayerBaseSpawned[param1])
							g_bPlayerBaseSpawned[param1] = false;

						if(!g_bEnding && Bool_DeleteValid(param1, false))
							Bool_ClearClientBase(param1, false);
					}

					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 2:
				{
					if(!g_bEnding)
					{
						new iCurrent = g_iPlayerProps[param1];
						if(!g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]])
						{
#if defined _colors_included
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props_Empty", g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
#else
							PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props_Empty", g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
#endif

							QueryBuildMenu(param1, MENU_BASE_CURRENT);
							return;
						}

						new _iMax = Int_SpawnMaximum(param1);
						if(g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] <= _iMax)
						{
							if((g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] + iCurrent) > _iMax)
							{
								new _iTemp = (g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] + iCurrent) - _iMax;
#if defined _colors_included
								CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props_Insufficient", g_sBaseNames[g_iPlayerBaseCurrent[param1]], _iTemp);
#else
								PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props_Insufficient", g_sBaseNames[g_iPlayerBaseCurrent[param1]], _iTemp);
#endif

								QueryBuildMenu(param1, MENU_BASE_CURRENT);
								return;
							}
						}

						if(Bool_SpawnAllowed(param1, true) && Bool_SpawnValid(param1, true, MENU_BASE_CURRENT))
						{
							decl Float:_fDestination[3], Float:_fOrigin[3], Float:_fAngles[3];
							GetClientAbsOrigin(param1, _fOrigin);
							GetClientEyePosition(param1, _fDestination);
							GetClientEyeAngles(param1, _fAngles);
							TR_TraceRayFilter(_fDestination, _fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterPlayers, param1);
							if(TR_DidHit(INVALID_HANDLE))
							{
								TR_GetEndPosition(g_fPlayerBaseLocation[param1], INVALID_HANDLE);

								g_fSaveLocation[param1] = g_fPlayerBaseLocation[param1];
								if(!g_bSaveLocation[param1])
									g_bSaveLocation[param1] = true;
								else
									CloseHandle(g_hSaveLocation[param1]);

								DisplaySaveLocation(param1);
								g_hSaveLocation[param1] = CreateTimer(1.0, Timer_DisplaySaveLocation, param1, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

								g_bPlayerBaseSpawned[param1] = true;
								g_iPlayerBaseQuery[param1] += g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];

								decl String:_sQuery[256];
								Format(_sQuery, sizeof(_sQuery), g_sSQL_PropLoad, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]]);
								SQL_TQuery(g_hSql_Database, SQL_QueryPropLoad, _sQuery, GetClientUserId(param1));
							}

							QueryBuildMenu(param1, MENU_BASE_CURRENT);
						}
					}
				}
				case 3:
				{
					if(!g_bEnding && Bool_DeleteValid(param1, true, MENU_BASE_CURRENT))
					{
						if(g_bPlayerBaseSpawned[param1])
						{
							g_bPlayerBaseSpawned[param1] = false;
							new Float:_fWriteDelay = 0.1;
							new _iDeleted, _iArraySize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
							for(new i = _iArraySize; i >= 0; i--)
							{
								new iEntity = GetArrayCell(g_hArray_PlayerProps[param1], i);
								if(IsValidEntity(iEntity) && g_bValidBase[iEntity])
								{
									_iDeleted++;
									g_bValidProp[iEntity] = false;
									g_bValidBase[iEntity] = false;
									g_iPlayerBaseQuery[param1] += 1;

									new Handle:_hPack = INVALID_HANDLE;
									CreateDataTimer(_fWriteDelay, Timer_DeleteBaseProps, _hPack);
									WritePackCell(_hPack, param1);
									WritePackCell(_hPack, iEntity);
									_fWriteDelay += 0.01;

									RemoveFromArray(g_hArray_PlayerProps[param1], i);
								}
							}

							g_iPlayerProps[param1] -= _iDeleted;
						}
					}

					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 4:
				{
					if(!g_bSaveLocation[param1])
					{
#if defined _colors_included
						CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location_Missing");
#else
						PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location_Missing");
#endif
						QueryBuildMenu(param1, MENU_BASE_MAIN);
						return;
					}
					else
					{
						new iEntity = Trace_GetEntity(param1);
						if(Entity_Valid(iEntity))
						{
							new _iOwner = GetClientOfUserId(g_iPropUser[iEntity]);
							if(_iOwner == param1)
							{
								if(g_iBaseLimit != -1 && g_iBaseIndex[iEntity] == -1)
								{
									new _iSize = g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];
									new _iAllowed = (!g_iBaseLimit) ? Int_SpawnMaximum(param1) : g_iBaseLimit;
									if((_iSize + 1) > _iAllowed)
									{
#if defined _colors_included
										CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Size", _iAllowed, g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
#else
										PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Size", _iAllowed, g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
#endif
										QueryBuildMenu(param1, MENU_BASE_CURRENT);
										return;
									}
								}

								decl Float:_fOrigin[3];
								GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", _fOrigin);

								if(Bool_CheckProximity(g_fSaveLocation[param1], _fOrigin, g_fBaseDistance, false))
								{
#if defined _colors_included
									CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location", g_sDefinedPropNames[g_iPropType[iEntity]]);
#else
									PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location", g_sDefinedPropNames[g_iPropType[iEntity]]);
#endif
								}
								else
								{
									decl String:_sQuery[512], Float:_fAngles[3], Float:_fTemp;
									GetEntPropVector(iEntity, Prop_Send, "m_angRotation", _fAngles);
									_fTemp = _fOrigin[2];

									SubtractVectors(g_fSaveLocation[param1], _fOrigin, _fOrigin);
									if(g_fSaveLocation[param1][2] >= 0 && _fTemp >= 2 && _fOrigin[2] < 0)
										_fOrigin[2] *= -1;

									if(!g_bPlayerBaseSpawned[param1])
										g_bPlayerBaseSpawned[param1] = true;

									g_iPlayerBaseQuery[param1] += 1;
									if(g_iBaseIndex[iEntity] != -1)
									{
										Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveIndex, g_iBaseIndex[iEntity], g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_iPropType[iEntity], _fOrigin[0], _fOrigin[1], _fOrigin[2], _fAngles[0], _fAngles[1], _fAngles[2], g_sSteam[param1]);
										SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveSingle, _sQuery, EntIndexToEntRef(iEntity));
									}
									else
									{
										Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveNull, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_iPropType[iEntity], _fOrigin[0], _fOrigin[1], _fOrigin[2], _fAngles[0], _fAngles[1], _fAngles[2], g_sSteam[param1]);
										SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveSingle, _sQuery, EntIndexToEntRef(iEntity));
									}
								}
							}
							else
							{
#if defined _colors_included
								CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Ownership", g_sDefinedPropNames[g_iPropType[iEntity]], g_sPropOwner[iEntity]);
#else
								PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Ownership", g_sDefinedPropNames[g_iPropType[iEntity]], g_sPropOwner[iEntity]);
#endif
							}
						}
					}

					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 5:
				{
					if(!g_bEnding)
					{
						new iEntity = Trace_GetEntity(param1);
						if(Entity_Valid(iEntity))
						{
							new _iOwner = GetClientOfUserId(g_iPropUser[iEntity]);
							if(_iOwner == param1)
							{
								if(g_iBaseIndex[iEntity] != -1)
								{
									g_iPlayerBaseQuery[param1] += 1;

									decl String:_sQuery[256];
									Format(_sQuery, sizeof(_sQuery), g_sSQL_PropDelete, g_iBaseIndex[iEntity]);
									SQL_TQuery(g_hSql_Database, SQL_QueryPropDelete, _sQuery, EntIndexToEntRef(iEntity));
								}
								else
								{
#if defined _colors_included
									CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props_Missing", g_sDefinedPropNames[g_iPropType[iEntity]], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
#else
									PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props_Missing", g_sDefinedPropNames[g_iPropType[iEntity]], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
#endif
								}
							}
							else
							{
#if defined _colors_included
								CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Ownership", g_sDefinedPropNames[g_iPropType[iEntity]], g_sPropOwner[iEntity]);
#else
								PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Ownership", g_sDefinedPropNames[g_iPropType[iEntity]], g_sPropOwner[iEntity]);
#endif
							}
						}
					}

					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 6:
				{
					if(!g_bSaveLocation[param1])
					{
#if defined _colors_included
						CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location_Missing");
#else
						PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location_Missing");
#endif
						QueryBuildMenu(param1, MENU_BASE_MAIN);
						return;
					}
					else
					{
						if(g_iBaseLimit != -1)
						{
							new _iSize = GetArraySize(g_hArray_PlayerProps[param1]);

							if(_iSize < 0)
							{
#if defined _colors_included
								CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Empty");
#else
								PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Empty");
#endif
								QueryBuildMenu(param1, MENU_BASE_CURRENT);
								return;
							}
							else
							{
								new _iAllowed = (!g_iBaseLimit) ? Int_SpawnMaximum(param1) : g_iBaseLimit;
								if(_iSize > _iAllowed)
								{
#if defined _colors_included
									CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Size", _iAllowed, g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
#else
									PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Size", _iAllowed, g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
#endif
									QueryBuildMenu(param1, MENU_BASE_CURRENT);
									return;
								}
							}
						}

						Menu_BaseConfirmSave(param1);
						return;
					}
				}
				case 7:
				{
					if(!g_bEnding)
					{
						new _iSize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
						for(new i = _iSize; i >= 0; i--)
						{
							new iEntity = GetArrayCell(g_hArray_PlayerProps[param1], i);
							if(IsValidEntity(iEntity) && g_bValidBase[iEntity])
							{
								g_bValidBase[iEntity] = false;
								g_iBaseIndex[iEntity] = -1;
							}
						}

						Menu_BaseConfirmEmpty(param1);
						return;
					}

					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 8:
				{
					QueryBuildMenu(param1, MENU_BASE_MOVE);
				}
			}
		}
	}
}

Menu_BaseConfirmSave(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_BaseConfirmSave);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	Format(sBuffer, 192, "%T", "Menu_Base_Confirm_Save_Ask", client);
	AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

	Format(sBuffer, 192, "%T", "Menu_Base_Spacer", client);
	if(!StrEqual(sBuffer, ""))
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

	Format(sBuffer, 192, "%T", "Menu_Base_Confirm_Save_Yes", client);
	AddMenuItem(hMenuHandle, "1", sBuffer);
	Format(sBuffer, 192, "%T", "Menu_Base_Confirm_Save_No", client);
	AddMenuItem(hMenuHandle, "0", sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseConfirmSave(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			if(StringToInt(_sOption))
			{
				g_iPlayerBaseQuery[param1] += 1;

				decl String:_sQuery[256];
				Format(_sQuery, sizeof(_sQuery), g_sSQL_PropEmpty, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_sSteam[param1]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseReadySave, _sQuery, GetClientUserId(param1));
			}

			QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
	}
}

Menu_BaseConfirmEmpty(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];
	new Handle:hMenuHandle = CreateMenu(MenuHandler_BaseConfirmEmpty);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	Format(sBuffer, 192, "%T", "Menu_Base_Confirm_Empty_Ask", client, g_sBaseNames[g_iPlayerBaseCurrent[client]]);
	AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

	Format(sBuffer, 192, "%T", "Menu_Base_Spacer", client);
	if(!StrEqual(sBuffer, ""))
		AddMenuItem(hMenuHandle, "", sBuffer, ITEMDRAW_DISABLED);

	Format(sBuffer, 192, "%T", "Menu_Base_Confirm_Empty_Yes", client);
	AddMenuItem(hMenuHandle, "1", sBuffer);
	Format(sBuffer, 192, "%T", "Menu_Base_Confirm_Empty_No", client);
	AddMenuItem(hMenuHandle, "0", sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseConfirmEmpty(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			if(StringToInt(_sOption))
			{
				g_iPlayerBaseQuery[param1] += 1;

				decl String:_sQuery[256];
				Format(_sQuery, sizeof(_sQuery), g_sSQL_PropEmpty, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_sSteam[param1]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseEmpty, _sQuery, GetClientUserId(param1));
			}

			QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
	}
}

Menu_BaseMove(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_BaseMove);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	new _iState = Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(sBuffer, 192, "%T", "Menu_Position_X_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "1", sBuffer, _iState);

	Format(sBuffer, 192, "%T", "Menu_Position_X_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "2", sBuffer, _iState);

	Format(sBuffer, 192, "%T", "Menu_Position_Y_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "3", sBuffer, _iState);

	Format(sBuffer, 192, "%T", "Menu_Position_Y_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "4", sBuffer, _iState);

	Format(sBuffer, 192, "%T", "Menu_Position_Z_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "5", sBuffer, _iState);

	Format(sBuffer, 192, "%T", "Menu_Position_Z_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(hMenuHandle, "6", sBuffer, _iState);

	Format(sBuffer, 192, "%T", "Menu_Position_Default", client);
	AddMenuItem(hMenuHandle, "0", sBuffer);

	DisplayMenu(hMenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseMove(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			new _iOption = StringToInt(_sOption);
			if(!_iOption)
				Menu_DefaultBasePosition(param1);
			else
			{
				g_iPlayerBaseMenu[param1] = MENU_BASE_MOVE;

				new _iSize = g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];
				if(!_iSize)
				{
#if defined _colors_included
					CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Move_All_Empty");
#else
					PrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Move_All_Empty");
#endif
					QueryBuildMenu(param1, MENU_BASE_CURRENT);
					return;
				}

				new Float:_fWriteDelay = 0.1;
				new _iArraySize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
				for(new i = _iArraySize; i >= 0; i--)
				{
					new iEntity = GetArrayCell(g_hArray_PlayerProps[param1], i);
					if(IsValidEntity(iEntity) && g_bValidBase[iEntity])
					{
						g_iPlayerBaseQuery[param1] += 1;

						new Handle:_hPack = INVALID_HANDLE;
						CreateDataTimer(_fWriteDelay, Timer_MoveBaseProps, _hPack);
						WritePackCell(_hPack, param1);
						WritePackCell(_hPack, iEntity);
						WritePackCell(_hPack, _iOption);
						_fWriteDelay += 0.01;
					}
				}

				QueryBuildMenu(param1, MENU_BASE_MOVE);
			}
		}
	}
}

Menu_DefaultBasePosition(client, index = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:sBuffer[192], String:_sTemp[4];

	new Handle:hMenuHandle = CreateMenu(MenuHandler_DefaultBasePosition);
	SetMenuTitle(hMenuHandle, g_sTitle);
	SetMenuExitButton(hMenuHandle, true);
	SetMenuExitBackButton(hMenuHandle, true);

	for(new i = 0; i < g_iNumPositions; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(sBuffer, 192, "%s%T", (g_iConfigPosition[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Position_Option", client, g_fDefinedPositions[i]);
		AddMenuItem(hMenuHandle, _sTemp, sBuffer);
	}

	DisplayMenuAtItem(hMenuHandle, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultBasePosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_BaseMove(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigPosition[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigPosition, _sOption);

#if defined _colors_included
			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Position", g_fDefinedPositions[g_iConfigPosition[param1]]);
#else
			PrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Position", g_fDefinedPositions[g_iConfigPosition[param1]]);
#endif
			Menu_DefaultBasePosition(param1, GetMenuSelectionPosition());
		}
	}
}

Bool_ClearClientBase(client, bool:message = true)
{
	new _iDeleted, _iSize = (GetArraySize(g_hArray_PlayerProps[client]) - 1);
	for(new i = _iSize; i >= 0; i--)
	{
		new iEntity = GetArrayCell(g_hArray_PlayerProps[client], i);
		if(IsValidEntity(iEntity) && g_bValidBase[iEntity])
		{
			Entity_DeleteProp(iEntity);
			RemoveFromArray(g_hArray_PlayerProps[client], i);
			_iDeleted++;
		}
	}

	g_iPlayerProps[client] -= _iDeleted;
	g_iPlayerDeletes[client] += _iDeleted;

	if(message)
	{
#if defined _colors_included
		CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Clear_Props", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#else
		PrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Clear_Props", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
#endif
	}

	return _iDeleted ? true : false;
}

LoadClientBase(client)
{
	if(g_hSql_Database != INVALID_HANDLE)
	{
		g_iPlayerBaseCurrent[client] = (g_iBaseGroups == 1) ? 0 : -1;
		g_iPlayerBaseMenu[client] = -1;
		g_iPlayerBaseQuery[client] = 0;
		g_iPlayerBaseLoading[client] = 0;
		for(new i = 0; i < g_iBaseGroups; i++)
		{
			g_iPlayerBase[client][i] = 0;
			g_iPlayerBaseCount[client][i] = 0;
		}

		decl String:_sQuery[256];
		Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseLoad, g_sSteam[client]);
		SQL_TQuery(g_hSql_Database, SQL_QueryBaseLoad, _sQuery, GetClientUserId(client));
	}
}

public Action:Timer_SaveBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iEntity = ReadPackCell(pack);

	decl Float:_fOrigin[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", _fOrigin);
	if(Bool_CheckProximity(g_fSaveLocation[client], _fOrigin, g_fBaseDistance, true))
	{
		decl String:_sQuery[512], Float:_fAngles[3], Float:_fTemp;
		GetEntPropVector(iEntity, Prop_Send, "m_angRotation", _fAngles);
		_fTemp = _fOrigin[2];

		SubtractVectors(g_fSaveLocation[client], _fOrigin, _fOrigin);
		if(g_fSaveLocation[client][2] >= 0 && _fTemp >= 2 && _fOrigin[2] < 0)
			_fOrigin[2] *= -1;

		if(g_iBaseIndex[iEntity] != -1)
		{
			Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveIndex, g_iBaseIndex[iEntity], g_iPlayerBase[client][g_iPlayerBaseCurrent[client]], g_iPropType[iEntity],	_fOrigin[0], _fOrigin[1], _fOrigin[2], _fAngles[0], _fAngles[1], _fAngles[2], g_sSteam[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveMass, _sQuery, EntIndexToEntRef(iEntity));
		}
		else
		{
			Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveNull, g_iPlayerBase[client][g_iPlayerBaseCurrent[client]], g_iPropType[iEntity], _fOrigin[0], _fOrigin[1], _fOrigin[2], _fAngles[0], _fAngles[1], _fAngles[2], g_sSteam[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveMass, _sQuery, EntIndexToEntRef(iEntity));
		}
	}
	else
	{
		g_iPlayerBaseQuery[client] -= 1;
		if(!g_iPlayerBaseQuery[client] && g_iPlayerBaseMenu[client] != -1)
		{
			QueryBuildMenu(client, MENU_BASE_CURRENT);
			g_iPlayerBaseMenu[client] = -1;
		}
	}
}

public Action:Timer_MoveBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iEntity = ReadPackCell(pack);
	new option = ReadPackCell(pack);

	new Float:_fTemp[3];
	switch(option)
	{
		case 1:
			_fTemp[0] = g_fDefinedPositions[g_iConfigPosition[client]];
		case 2:
			_fTemp[0] = (g_fDefinedPositions[g_iConfigPosition[client]] * -1);
		case 3:
			_fTemp[1] = g_fDefinedPositions[g_iConfigPosition[client]];
		case 4:
			_fTemp[1] = (g_fDefinedPositions[g_iConfigPosition[client]] * -1);
		case 5:
			_fTemp[2] = g_fDefinedPositions[g_iConfigPosition[client]];
		case 6:
			_fTemp[2] = (g_fDefinedPositions[g_iConfigPosition[client]] * -1);
	}

	g_iPlayerBaseQuery[client] -= 1;
	Entity_PositionProp(iEntity, _fTemp);

	if(!g_iPlayerBaseQuery[client] && g_iPlayerBaseMenu[client] != -1)
	{
		QueryBuildMenu(client, MENU_BASE_MOVE);
		g_iPlayerBaseMenu[client] = -1;
	}
}

public Action:Timer_DeleteBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iEntity = ReadPackCell(pack);

	if(IsValidEntity(iEntity))
		Entity_DeleteProp(iEntity);

	g_iPlayerBaseQuery[client] -= 1;
	if(!g_iPlayerBaseQuery[client] && g_iPlayerBaseMenu[client] != -1)
	{
		QueryBuildMenu(client, MENU_BASE_CURRENT);
		g_iPlayerBaseMenu[client] = -1;
	}
}

public Action:Timer_DisplaySaveLocation(Handle:timer, any:client)
{
	if(!IsClientInGame(client))
		g_hSaveLocation[client] = INVALID_HANDLE;
	else
	{
		DisplaySaveLocation(client);
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

DisplaySaveLocation(client)
{
	decl Float:_fTemp[3];
	_fTemp = g_fSaveLocation[client];
	_fTemp[2] += 1.5;

	TE_SetupGlowSprite(_fTemp, g_iGlowSprite, 1.0, 0.5, 255);
	TE_SendToClient(client);

	TE_SetupBeamRingPoint(_fTemp, 8.0, 40.0, g_iBeamSprite, g_iFlashSprite, 0, 10, 1.0, 16.0, 1.0, {200, 255, 200, 150}, 15, 0);
	TE_SendToClient(client);
}


Float:GetAngleBetweenVectors( const Float:vector1[3], const Float:vector2[3], const Float:direction[3] )
{
	decl Float:vector1_n[3], Float:vector2_n[3], Float:direction_n[3], Float:cross[3];
	NormalizeVector( direction, direction_n );
	NormalizeVector( vector1, vector1_n );
	NormalizeVector( vector2, vector2_n );
	new Float:degree = ArcCosine( GetVectorDotProduct( vector1_n, vector2_n ) ) * 57.29577951;
	GetVectorCrossProduct( vector1_n, vector2_n, cross );

	if( GetVectorDotProduct( cross, direction_n ) < 0.0 )
	{
		degree *= -1.0;
	}

	return degree;
}

RotateYaw( Float:angles[3], Float:degree )
{
	decl Float:direction[3], Float:normal[3];
	GetAngleVectors( angles, direction, NULL_VECTOR, normal );

	new Float:sin = Sine( degree * 0.01745328 );
	new Float:cos = Cosine( degree * 0.01745328 );
	new Float:a = normal[0] * sin;
	new Float:b = normal[1] * sin;
	new Float:c = normal[2] * sin;
	new Float:x = direction[2] * b + direction[0] * cos - direction[1] * c;
	new Float:y = direction[0] * c + direction[1] * cos - direction[2] * a;
	new Float:z = direction[1] * a + direction[2] * cos - direction[0] * b;
	direction[0] = x;
	direction[1] = y;
	direction[2] = z;

	GetVectorAngles( direction, angles );

	decl Float:up[3];
	GetVectorVectors( direction, NULL_VECTOR, up );

	new Float:roll = GetAngleBetweenVectors( up, normal, direction );
	angles[2] += roll;
}

bool:Bool_CheckProximity(Float:_fOrigin[3], Float:_fLocation[3], Float:_fLimit, bool:_bWithin)
{
	if(_fLimit <= 0)
		return false;
	else
	{
		if(_bWithin)
		{
			if(GetVectorDistance(_fOrigin, _fLocation) <= _fLimit)
				return true;
			else
				return false;
		}
		else
		{
			if(GetVectorDistance(_fOrigin, _fLocation) > _fLimit)
				return true;
			else
				return false;
		}
	}
}