//(C) 2014 Jared Ballou <sourcemod@jballou.com>
//Released under GPLv3

#pragma semicolon 1
#include <sourcemod>
#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS
#define PLUGIN_VERSION "0.0.1"
#define PLUGIN_DESCRIPTION "Basic reserve slot feature for insurgency"

#define INVALID -200
#define UNKICKABLE -100
#define TRANSLATION_FILE "hreservedslots.phrases"

#define DROP_METHOD_NONE 0
#define DROP_METHOD_KICK 1
#define DROP_METHOD_REDIRECT 2

#define DROP_SELECTION_PING 0
#define DROP_SELECTION_CONNECTION_TIME 1
#define DROP_SELECTION_RANDOM 2
#define DROP_SELECTION_SCORE 3

#define ADMIN_PROTECTION_NONE 0
#define ADMIN_PROTECTION_NOT_SPECTATOR 1
#define ADMIN_PROTECTION_ALL 2

#define TEAM_SPECTATOR 1
#define TEAM_TEAMLESS 0

// Credits: Most key code is based off by ins_reserved_slots.sp and reservedslots.sp

#define MAX_BUTTONS 25
new g_LastButtons[MAXPLAYERS+1];

public Plugin:myinfo = {
        name        = "[INS] reserve slot",
        author      = "Daimyo",
        description = PLUGIN_DESCRIPTION,
        version     = PLUGIN_VERSION,
        url         = ""
};


new Handle:s_svVisiblemaxplayers;
new Handle:s_smHreservedSlotsEnable;
new Handle:s_smHreservedSlotsAmount; //not needed atm
new Handle:s_smHreservedAdminProtection;
new Handle:s_smHreservedImmunityDecrement;
new Handle:s_smHreservedUseImmunity;
new Handle:s_smHreservedDropMethod;
new Handle:s_smHreservedDropSelect;
new s_priorityVector[MAXPLAYERS+1]; 



public OnPluginStart()
{
  LoadTranslations(TRANSLATION_FILE);
  CreateConVar("ins_reserved_slots", PLUGIN_VERSION, "Version of [HANSE] Reserved Slots", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_SPONLY);
  
  // register console cvars
  
  s_svVisiblemaxplayers = FindConVar("sv_visiblemaxplayers");
  
  s_smHreservedSlotsEnable = CreateConVar("sm_ins_reserved_slots_enable", "1", "disable/enable reserved slots");
  s_smHreservedSlotsAmount = CreateConVar("sm_ins_reserved_slots_amount", "1", "number of reserved slots (do not specify or set to -1 to automatically use hidden slots as reserved)");
  s_smHreservedAdminProtection = CreateConVar("sm_hreserved_admin_protection", "2", "protect admins from beeing dropped from server by reserved slot access (0: no protection, 1: except spec mode, 2: full protection)");
  s_smHreservedUseImmunity = CreateConVar("sm_hreserved_use_immunity", "1", "use sourcemod immunity level to find a player to be dropped (0: do not use immunity , 1: use immunity level)");
  s_smHreservedImmunityDecrement = CreateConVar("sm_hreserved_immunity_decrement", "1", "value to be subtracted from the immunity level of spectators. The value 0 will make spectators to be treated like players in the game");

  s_smHreservedDropMethod = CreateConVar("sm_hreserved_drop_method", "1", "method for dropping players to free a reserved slot (0: no players are dropped from server, 1: kick, 2: offer to be redirected to the server specified in sm_hreserved_redirect_target)");
  s_smHreservedDropSelect = CreateConVar("sm_hreserved_drop_select", "1", "select how players are chosen to be dropped from server when there are multiple targets with the same priority. (0: highest ping, 1: shortest connection time, 2: random)");

  // new for 1.3
  AutoExecConfig(true, "ins_reserved_slots"); 

}



getVisibleSlots(){
    
  // estimate number of visible slots
  new visibleSlots;
  if (s_svVisiblemaxplayers==INVALID_HANDLE || GetConVarInt(s_svVisiblemaxplayers)==-1)   
    visibleSlots = MaxClients; // if sv_visiblemaxplayers is undefined all slots are visible
  else
    visibleSlots = GetConVarInt(s_svVisiblemaxplayers);

  return visibleSlots;
}


public OnClientPostAdminCheck(clientSlot)
{
    
  if (isPublicSlot()) { return; }
  else 
  {
    // public slots full
    decl String:playername[50];
    GetClientName(clientSlot, playername, 49);
    
    if (hasReservedSlotAccess(playername, GetUserFlagBits(clientSlot)))
    {
      // is admin -> drop other player
      PrintToServer("[ins_reserved_slots] connected to reserved slot, admin rights granted");
      //PrintToConsole(clientSlot,"[ins_reserved_slots] connected to reserved slot, admin rights granted");
      LogMessage("admin %s connected to reserved slot", playername);
      
      if (GetConVarInt(s_smHreservedDropMethod)!=DROP_METHOD_NONE) 
      {
        // calculate list of connected clients with their priority for beeing dropped
        refreshPriorityVector();
        DropPlayerByWeight();
      }
    }
    else
    {
      // not admin -> drop this player
      PrintToServer("[ins_reserved_slots] no free public slots");
      //PrintToConsole(clientSlot,"[ins_reserved_slots] sorry, no free public slots");
      //LogMessage("unpriviledged user %s connected to reserved slot", playername);
        CreateTimer(0.1, OnTimedKickForReject, GetClientUserId(clientSlot));
    }
  }
}

bool:isPublicSlot(bool:isPreconnect=false) {
  // plugin deactivated
  if (GetConVarInt(s_smHreservedSlotsEnable)==0) { return true; }

  new currentClientCount = GetRealClientCount(true) + ((isPreconnect) ? 1 : 0);
  new publicSlots = getPublicSlots();
  
  PrintToServer("[ins_reserved_slots] public slot used (%d/%d)", currentClientCount, publicSlots);
  return (currentClientCount <= publicSlots );
}
getPublicSlots(){
  // number of slots free for everyone
  new cvar;
  cvar = (GetConVarInt(FindConVar("mp_coop_lobbysize")) - 1);
  PrintToServer("getPublicSlots=MP_COOP_LOBBYSIZE: %d", cvar);
  return (cvar);
}

GetRealClientCount( bool:inGameOnly = true ) {
  new clients = 0;
  for( new i = 1; i < MaxClients; i++ ) {
    if( ( ( inGameOnly ) ? IsClientInGame( i ) : IsClientConnected( i ) ) && !IsFakeClient( i ) ) {
      clients++;
    }
  }
  return clients;
 }



/********************************************************************
 * Drop method implementations for delayed execution; called by DropPlayerByWeight()  or OnClientPostAdminCheck(...)
 ********************************************************************/

public Action:OnTimedKickForReject(Handle:timer, any:value)
{
  new clientSlot = GetClientOfUserId(value);
  
  if (!clientSlot || !IsClientInGame(clientSlot) || IsFakeClient(clientSlot))
  {
    return Plugin_Handled;
  }

  decl String:playername[50];
  GetClientName(clientSlot, playername, 49);
  decl String:player_authid[50];
  GetClientAuthId(clientSlot, AuthId_Steam3, player_authid, sizeof(player_authid));
  LogMessage("kicking rejected player %s [%s]", playername, player_authid);
  
  KickClient(clientSlot, "%T", "no free slots", clientSlot);
  return Plugin_Handled;
}

public Action:OnTimedKickToFreeSlot(Handle:timer, any:value)
{
  new clientSlot = GetClientOfUserId(value);
  
  KickToFreeSlotNow(clientSlot);
  return Plugin_Handled;
}
KickToFreeSlotNow(clientSlot) 
{
  if (!clientSlot || !IsClientInGame(clientSlot) || IsFakeClient(clientSlot))
  {
    return;
  } else {
    decl String:playername[50];
    GetClientName(clientSlot, playername, 49);
    decl String:player_authid[50];
    GetClientAuthId(clientSlot, AuthId_Steam3, player_authid, sizeof(player_authid));
    LogMessage("kicking player %s [%s] to free slot", playername, player_authid);
    
    KickClient(clientSlot, "%T", "kicked for free slot", clientSlot);
  }
}

/********************************************************************
 *
 * Custom Functions
 *
 ********************************************************************/

/*
 * evaluate plugin configuration, select corresponding client to be dropped from server and kick it to free a reserved slot 
 * called by OnClientPostAdminCheck if not DROP_METHOD_NONE
 *
 * parameters: -
 * return: -
 */
 
bool:DropPlayerByWeight(bool: enforce=false) {
  decl String:playername[50];

  new lowestImmunity = getLowestImmunity();
  
  if (lowestImmunity>UNKICKABLE)
  {
    LogMessage("selecting player of lowest immunity group (%d)", lowestImmunity);
    new target = findDropTarget(lowestImmunity); // find the target as configured by configuration cvars
    if (target>-1)
    {
      s_priorityVector[target]=UNKICKABLE; // fix to ensure not to select the same player multiple times (marker will be removed with next call to refreshPriorityVector())
      
      GetClientName(target, playername, 49);
      LogMessage("[ins_reserved_slots] dropping %s%s", playername, (enforce) ? "(enforcing method kick when using 'connect' extension)" : "");
      
      if (enforce)
      { 
        KickToFreeSlotNow(target);
      }
      else 
      {
        CreateTimer(0.1, OnTimedKickToFreeSlot, GetClientUserId(target)); 
      }
      return true;
    }
  } else {
    LogMessage("no non-admins available to drop, giving up.");
  }
  
  LogMessage("[ins_reserved_slots] no matching client found to kick");
  return false;
}

/*
* search s_priorityVector for the lowest available immunity group
*
* parameters: -
* return: lowest immunity group available
*/
getLowestImmunity()
{
  new lowestImmunity = INVALID; // is this is still invalid after passing through all clients, no target is found which can be dropped
  
  for (new client = 1; client <= MaxClients; client++)
  {
    // estimate the lowest priority group available
    if (s_priorityVector[client]>UNKICKABLE) {
      // kickable slot
      if (lowestImmunity==INVALID) lowestImmunity=s_priorityVector[client]; // overwrite invalid start entry
      if (s_priorityVector[client]<lowestImmunity) lowestImmunity=s_priorityVector[client];
    }
  }
  
  return lowestImmunity;
}

// return true if this user is allowed to connect to a reserved slot  
bool:hasReservedSlotAccess(const String:playername[], userFlags) {
  
  // admin flag based 
  if (userFlags & ADMFLAG_ROOT || userFlags & ADMFLAG_RESERVATION)
  {
    return true;
  } else {
    return false;
  }
}


/*
 * refresh all entries in static structure s_priorityVector
 * the priority vector assigns all clients a priority for being dropped from server regarding the configuration cvars
 *
 * parameters: -
 * return: -
 */
 
 refreshPriorityVector() {

  new immunity;
  new AdminId:aid;
  new bool:hasReserved;
  
  
  // enumerate all clients
  for (new client = 1; client < MaxClients; client++)
  {
    // check if this player slot is connected and initialized
    if (IsClientInGame(client) && !IsFakeClient(client))
    {
       
      // estimate immunity level and state of reserved slot admin flag
      aid = GetUserAdmin(client);
      if (aid==INVALID_ADMIN_ID && !(GetAdminFlag(aid, Admin_Reservation)))
      {
        // not an admin
        immunity=0;
        hasReserved=false;
      } else {
        immunity = UNKICKABLE;// = GetAdminImmunityLevel(aid);
        hasReserved=GetAdminFlag(aid, Admin_Reservation);
      }
      
      // if set to zero, do not use immunity flag
      if (GetConVarInt(s_smHreservedUseImmunity)==0) {
        immunity=0;
      }
      
      // decrement immunity level for spectators
      if ((( GetClientTeam(client) == TEAM_TEAMLESS) || (GetClientTeam(client) == TEAM_SPECTATOR)) && !hasReserved) {
        // player is spectator
        immunity-=GetConVarInt(s_smHreservedImmunityDecrement); // immunity level is decreased to make this player being kicked before players of same immunity       
      } 
      
      // calculate special permissions for admins
      if (hasReserved) {
        switch (GetConVarInt(s_smHreservedAdminProtection)) {
          case ADMIN_PROTECTION_ALL: {
            immunity = UNKICKABLE; // always denote as an unused/unkickable slot
          }
          case ADMIN_PROTECTION_NOT_SPECTATOR: {
            if (GetClientTeam(client) != TEAM_SPECTATOR) { immunity = UNKICKABLE; } // denote as an unused/unkickable slot if not in spectator mode
          }
          default:  // 0: do not protect admins beside their immunity level
            {}
        }   
      }
      
      
    } else { // if (IsClientInGame(client))
      immunity = UNKICKABLE; // denote as an unused/unkickable slot
    } // if (IsClientInGame(client))
    
    // enter the calculated priority to the priority Vector
    s_priorityVector[client]=immunity;
    
  } // for
  
}

/*
 * estimate the drop target matching the configuration; called by DropPlayerByWeight after the priority vector has been refreshed
 *
 * parameters: -
 * return: client slot selected for dropping client
 */
findDropTarget(lowestImmunity) {
  new targetSlot;
  
  switch (GetConVarInt(s_smHreservedDropSelect)) {
    //case DROP_SELECTION_SCORE:
    //  targetSlot=findHighestScoreTarget(lowestImmunity);
    case DROP_SELECTION_RANDOM: 
      targetSlot=findRandomTarget(lowestImmunity);
    case DROP_SELECTION_CONNECTION_TIME: 
      targetSlot=findShortestConnect(lowestImmunity);
    case DROP_SELECTION_PING: 
      targetSlot=findHighestPing(lowestImmunity);
    default: 
      targetSlot=findHighestPing(lowestImmunity);
  }
  if (targetSlot == -1) targetSlot=selectAnyPlayer(lowestImmunity); // last aid, select anybody
  
  return targetSlot;
}

findShortestConnect(immunity_group)
{
  new Float:ctime = Float:-1.0;
  new target=-1;
  
  for (new client = 1; client <= MaxClients; client++)
  {
    if(!IsClientInGame(client) || IsFakeClient(client))
      continue;
    if ((s_priorityVector[client]==immunity_group)) {
      if ((ctime < Float:0.0) || (GetClientTime(client)<ctime)) {
        ctime = GetClientTime(client);
        target=client;
      }
    }
  }
  if (target!=-1) { LogMessage("selected shortest connected target %d", target); }
  return target;
}

findHighestPing(immunity_group)
{
  new Float:hping = Float:-1.0;
  new target=-1;
  
  for (new client = 1; client <= MaxClients; client++)
  {
    if(!IsClientInGame(client) || IsFakeClient(client))
      continue;
    if ((s_priorityVector[client]==immunity_group) && (GetClientAvgLatency(client, NetFlow_Both) >= hping)) {
      hping=GetClientAvgLatency(client, NetFlow_Both);
      target=client;
    }
  }
  if (target!=-1) { LogMessage("selected highest ping target %d", target); }
  return target;
}

findRandomTarget(immunity_group)
{
  new targetCount = 0;
  new target=-1;
  
  
  
  for (new client = 1; client <= MaxClients; client++)
  {
    if(!IsClientInGame(client) || IsFakeClient(client))
      continue;
    if ((s_priorityVector[client]==immunity_group)) {
      targetCount++;
    }
  }
  if (targetCount>0)
  {
    new targetInGroup = GetRandomInt(1, targetCount);
    for (new jclient = 1; jclient <= MaxClients; jclient++)
    {
      if(!IsClientInGame(jclient))
      continue;
      if ((s_priorityVector[jclient]==immunity_group)) {
        targetInGroup--;
        if (targetInGroup==0) {
          target=jclient;
        }
      }
    }
  }
  if (target!=-1) { LogMessage("selected random target %d", target); }
  return target;
}

selectAnyPlayer(immunity_group)
{
  for (new client = 1; client <= MaxClients; client++)
  {
    if(!IsClientInGame(client) || IsFakeClient(client))
      continue;
    if ((s_priorityVector[client]==immunity_group)) {
      LogMessage("emergency selection of target %d", client); 
      return client;
    }
  }

  return -1;
}