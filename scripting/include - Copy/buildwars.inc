/*
	Round Phases
*/
#define PHASE_DISABLED 0
#define PHASE_LEGACY 1
#define PHASE_BUILD 2
#define PHASE_WAR 4
#define PHASE_SUDDEN 8

/*
	Entity States
*/
#define STATE_VALID 1
#define STATE_BASE 2
#define STATE_GRABBED 4
#define STATE_SAVED 8
#define STATE_DELETED 16
#define STATE_BREAKABLE 32
#define STATE_PHASE 64

#if defined _buildwars_included
	#endinput
#endif
#define _buildwars_included

/**
 * Gets the current state of an entity
 *
 * @param iEntity		The specific entity.
 * @return			 	A bitvalue containing the entity's state.
 *					 0: Entity is not a valid prop.
 *					 1: Entity is a valid prop for BuildWars.
 *					 2: Entity also belongs to a player's base.
 *					 4: Entity is being grabbed by a player.
 *					 8: Entity is currently being saved.
 *					16: Entity is currently being deleted. 
 *					32: Entity may not be a prop, but can be broken via gunfire.
 *					64: Entity is currently phased. 
**/
native BuildWars_GetEntityState(iEntity);

/**
 * Gets the current state of a valid prop.
 *
 * @param iEntity		The specific entity.
 * @return				The team the entity belongs to.
**/
native BuildWars_GetPropTeam(iEntity);

/**
 * Gets the owner of a valid prop.
 *
 * @param iEntity		The specific entity.
 * @param sName			Reference for the name of owner.
 * @return				The userid for the owner.
**/
native BuildWars_GetPropOwner(iEntity, String:sName[]);

/**
 * Forwards when the phase for BuildWars is changed.
 * @param iPhase		The current phase of BuildWars.
 *					 0: The phase is currently disabled... Not running perhaps?
 *					 1: The phase is currently Legacy.
 *					 2: The phase is currently Build.
 *					 4: The phase is currently War.
 *					 8: The phase is currently Sudden Death. 
**/
forward BuildWars_OnPhaseChange(_iPhase);

/**
 * Checks currently defined Zones and determines if the build position provided is blocked.
 *
 * @param fOrigin[3]	The position to check.
 * @return			 	-1: Not in a zone
 *						 #: Index of current zone that has building blocked.
**/
native bool:BuildWars_GetBlockedZone(Float:fOrigin[3]);

/**
 * Checks the client's current position to determine what zone they're currently within.
 *
 * @param iClient		The client index to check.
 * @return			 	-1: Not in a zone
 *						 0: Terrorist Zone
 *						 1: Counter- Terrorist Zone
 *						 2: Neutral Zone
 *						 3: Building Restricted
**/
native bool:BuildWars_GetCurrentZone(Float:fOrigin[3]);

/**
 * Grabs the current team that should be advancing. (The opposing team, of course, defending).
 *
 * @return			 	The advancing team. (2 = Terrorist, 3 = Counter-Terrorist);
**/
native bool:BuildWars_GetAdvanceTeam();