//(C) 2014 Jared Ballou <sourcemod@jballou.com>
//Released under GPLv3

#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <updater>
#include <sdktools> 
#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS
#define PLUGIN_VERSION "0.0.1"
#define PLUGIN_DESCRIPTION "Plugin for Pulling prop_ragdoll bodies"

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
//(button == IN_MOVELEFT || button == IN_MOVERIGHT || button == IN_JUMP) Ones jump
//(button == IN_BACK || button == IN_LEFT || button == IN_RIGHT) one is Z
  //if(button == IN_SPEED || button == IN_USE || button == IN_RUN) v, s and x or reverse s and x
  //if(button == IN_DUCK || button == IN_CANCEL || button == IN_BACK) // ctrl, w and f
#define MAX_BUTTONS 25
new g_LastButtons[MAXPLAYERS+1];
new g_playerCurrentRag[MAXPLAYERS + 1];

public Plugin:myinfo = {
        name        = "[INS] Pull Rag",
        author      = "Daimyo",
        description = PLUGIN_DESCRIPTION,
        version     = PLUGIN_VERSION,
        url         = ""
};

public OnPluginStart()
{

    HookEvent("player_disconnect", Event_PlayerDisconnect_Post, EventHookMode_Post);
}


public Action:Event_PlayerDisconnect_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_LastButtons[client] = 0;
}


public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
  if (!IsFakeClient(client))
  {
    ////PrintToServer("BUTTON PRESS DEBUG RUNCMD");
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


OnButtonPress(client, button, buttons)
{
    new Float:eyepos[3];
    GetClientEyePosition(client, eyepos); // Position of client's eyes.
                      
    //PrintToServer("Client Eye Height %f",eyepos[2]);    
              
    
   if(button == IN_SPRINT && buttons & IN_DUCK && !(buttons & IN_FORWARD) && !(buttons & IN_ATTACK2) && !(buttons & IN_ATTACK))// & !IN_ATTACK2) 
   {
      //PrintToServer("DEBUG 50000000000000");    
    
      new clientTargetRagdoll = GetClientAimTarget(client, false);
      if (clientTargetRagdoll != -1)
      {
        decl String:entClassname[128]; 
        GetEntityClassname(clientTargetRagdoll, entClassname, sizeof(entClassname));
        if (IsValidEdict(clientTargetRagdoll) && IsValidEntity(clientTargetRagdoll) && StrEqual(entClassname, "prop_ragdoll", false))
        {
          
          //Lets verify other players are not dragging body
          for (new tclient = 1; tclient <= MaxClients; tclient++)
          {
              if (client != tclient && tclient > 0 && IsClientInGame(tclient) && !IsFakeClient(tclient))
              {
                  new verifyRagdoll = EntRefToEntIndex(g_playerCurrentRag[tclient]);  
                  if (verifyRagdoll != -1 || verifyRagdoll != INVALID_ENT_REFERENCE)
                  {
                    continue;
                  }
                  else if (verifyRagdoll != -1 && verifyRagdoll != INVALID_ENT_REFERENCE)
                  {
                    if (verifyRagdoll == EntRefToEntIndex(clientTargetRagdoll))
                    {
                      PrintToServer("ANOTHER PLAYER HAS RAGDOLL ALREADY");   
                      return Plugin_Stop;

                    }
                  }
              }
          } 

          new Float:fReviveDistance = 64.0;
          new Float:vecPos[3];
          new Float:ragPos[3];
          new Float:tDistance;
          GetClientAbsOrigin(client, Float:vecPos);
          GetEntPropVector(clientTargetRagdoll, Prop_Send, "m_vecOrigin", ragPos);
          tDistance = GetVectorDistance(ragPos,vecPos);
          //PrintToServer("[PULL_RAG_DEBUG] Distance from ragdoll is %f",tDistance);    
            
          if (tDistance < fReviveDistance)
          {

            // create location based variables
              new Float:origin[3];
              new Float:angles[3];
              new Float:radians[2];
              new Float:destination[3];
              
              // get client position and the direction they are facing
              GetClientEyePosition(client, origin); // Position of client's eyes.
              GetClientAbsAngles(client, angles);   // Direction client is looking.
              

              // convert degrees to radians
              radians[0] = DegToRad(angles[0]);  
              radians[1] = DegToRad(angles[1]);  

              // calculate entity destination after creation (raw number is an offset distance)
              destination[0] = origin[0] + 32 * Cosine(radians[0]) * Cosine(radians[1]);
              destination[1] = origin[1] + 32 * Cosine(radians[0]) * Sine(radians[1]);
              destination[2] = ragPos[2];//origin[2] - 35;// * Sine(radians[0]);
              
              g_playerCurrentRag[client] = EntIndexToEntRef(clientTargetRagdoll);

              
              if (destination[2] < vecPos[2])
                destination[2] = (destination[2] + (vecPos[2] - destination[2]));



              decl Float:_fForce[3];
              _fForce[0] = 1;
              _fForce[1] = 1;
              _fForce[2] = 1;
              //SetEntProp(clientTargetRagdoll, Prop_Data, "m_CollisionGroup", 17);  
              TeleportEntity(clientTargetRagdoll, destination, NULL_VECTOR, _fForce);

              //return Plugin_Stop;
          }
        }
      }
   }
}

OnButtonRelease(client, button)
{



}

RemoveRagdoll(clientRagdoll)
{

  if(clientRagdoll != INVALID_ENT_REFERENCE && IsValidEntity(clientRagdoll))
  {
    AcceptEntityInput(clientRagdoll, "Kill");
    clientRagdoll = INVALID_ENT_REFERENCE;
  } 
}

stock bool:CheckIfBodyIsStuck(ent)
{
  decl Float:flOrigin[3];
  decl Float:flMins[3];
  decl Float:flMaxs[3];
  GetEntPropVector(ent, Prop_Send, "m_vecOrigin", flOrigin);
  GetEntPropVector(ent, Prop_Send, "m_vecMins", flMins);
  GetEntPropVector(ent, Prop_Send, "m_vecMaxs", flMaxs);

  TR_TraceHullFilter(flOrigin, flOrigin, flMins, flMaxs, MASK_SOLID_BRUSHONLY, TraceEntityFilterSolid, ent);
  return TR_DidHit();
}

public bool:TraceEntityFilterSolid(entity, contentsMask) 
{
  return entity > 1;
}


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



public bool:TraceFilterNoPlayers(iEnt, iMask, any:Other)
{
    return (iEnt != Other && iEnt > MaxClients);
}