#pragma semicolon 1
#define PLUGIN_VERSION "1.6"
#define PLUGIN_DESCRIPTION "Heeeeeeealing"

#define Healthkit_Timer_Tickrate			0.8		// Basic Sound has 0.8 loop
#define Healthkit_Timer_Timeout				24.0
#define Healthkit_Radius					350.0
#define Healthkit_Remove_Type				"1"
#define Healthkit_Healing_Per_Tick_Min		1
#define Healthkit_Healing_Per_Tick_Max		3

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "竊긌ua Health Kit",
	author = "D.Freddo",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "http://steam.lua.kr"
}

new g_iBeaconBeam;
new g_iBeaconHalo;
new Float:g_fLastHeight[2048] = {0.0, ...};
new Float:g_fTimeCheck[2048] = {0.0, ...};
new g_iTimeCheckHeight[2048] = {0, ...};
public OnPluginStart()
{
	CreateConVar("Lua_Ins_Healthkit", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_DONTRECORD);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("grenade_thrown", Event_GrenadeThrown);
}

public OnPluginEnd()
{
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "healthkit")) > MaxClients && IsValidEntity(ent))
	{
		StopSound(ent, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		AcceptEntityInput(ent, "Kill");
	}
}

public OnMapStart()
{
	g_iBeaconBeam = PrecacheModel("sprites/laserbeam.vmt");
	g_iBeaconHalo = PrecacheModel("sprites/halo01.vmt");
	// Healing sounds
	PrecacheSound("Lua_sounds/healthkit_complete.wav");
	PrecacheSound("Lua_sounds/healthkit_healing.wav");
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

	AddFileToDownloadsTable("materials/models/items/healthkit01.vmt");
	AddFileToDownloadsTable("materials/models/items/healthkit01.vtf");
	AddFileToDownloadsTable("materials/models/items/healthkit01_mask.vtf");
	AddFileToDownloadsTable("models/items/healthkit.dx80.vtx");
	AddFileToDownloadsTable("models/items/healthkit.dx90.vtx");
	AddFileToDownloadsTable("models/items/healthkit.mdl");
	AddFileToDownloadsTable("models/items/healthkit.phy");
	AddFileToDownloadsTable("models/items/healthkit.sw.vtx");
	AddFileToDownloadsTable("models/items/healthkit.vvd");
	AddFileToDownloadsTable("sound/Lua_sounds/healthkit_complete.wav");
	AddFileToDownloadsTable("sound/Lua_sounds/healthkit_healing.wav");
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
/*	for (new i = 1;i <= MaxClients;i++)
	{
		g_bHasInHealing[i] = false;
		StopSound(i, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
	}	*/

	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "healthkit")) > MaxClients && IsValidEntity(ent))
	{
		StopSound(ent, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		AcceptEntityInput(ent, "Kill");
	}
}

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

public OnEntityDestroyed(entity)
{
	if (entity > MaxClients)
	{
		decl String:classname[255];
		GetEntityClassname(entity, classname, 255);
		if (StrEqual(classname, "healthkit"))
		{
			StopSound(entity, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		}
    }
}

public OnEntityCreated(entity, const String:classname[])
{
	if (StrEqual(classname, "healthkit"))
	{
		new Handle:hDatapack;
		CreateDataTimer(Healthkit_Timer_Tickrate, Healthkit, hDatapack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(hDatapack, entity);
		WritePackFloat(hDatapack, GetGameTime()+Healthkit_Timer_Timeout);
		g_fLastHeight[entity] = -9999.0;
		g_iTimeCheckHeight[entity] = -9999;
		SDKHook(entity, SDKHook_VPhysicsUpdate, HealthkitGroundCheck);
		CreateTimer(0.1, HealthkitGroundCheckTimer, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
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
	if (entity > 0 && IsValidEntity(entity) && fGameTime <= fEndTime)
	{
		new Float:fOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
		if (g_fLastHeight[entity] == -9999.0)
		{
			g_fLastHeight[entity] = 0.0;
			EmitSoundToAll("Lua_sounds/healthkit_healing.wav", entity, SNDCHAN_STATIC, _, _, 0.7);
		}
		fOrigin[2] += 16.0;
		TE_SetupBeamRingPoint(fOrigin, 10.0, Healthkit_Radius*1.95, g_iBeaconBeam, g_iBeaconHalo, 0, 30, 0.6, 3.0, 0.0, {0, 204, 102, 255}, 3, 0);
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
		
		for (new iPlayer = 1;iPlayer <= MaxClients;iPlayer++)
		{
			if (IsClientInGame(iPlayer) && IsPlayerAlive(iPlayer) && GetClientTeam(iPlayer) == 2)
			{
				decl Float:fPlayerOrigin[3];
				GetClientEyePosition(iPlayer, fPlayerOrigin);
				if (GetVectorDistance(fPlayerOrigin, fOrigin) <= Healthkit_Radius)
				{
					new Handle:hData = CreateDataPack();
					WritePackCell(hData, entity);
					WritePackCell(hData, iPlayer);
					fOrigin[2] += 32.0;
					new Handle:trace = TR_TraceRayFilterEx(fPlayerOrigin, fOrigin, MASK_SOLID, RayType_EndPoint, Filter_ClientSelf, hData);
					CloseHandle(hData);
					if (!TR_DidHit(trace))
					{
						new iMaxHealth = GetEntProp(iPlayer, Prop_Data, "m_iMaxHealth");
						new iHealth = GetEntProp(iPlayer, Prop_Data, "m_iHealth");
						if (iMaxHealth > iHealth)
						{
							iHealth += GetRandomInt(Healthkit_Healing_Per_Tick_Min, Healthkit_Healing_Per_Tick_Max);
							if (iHealth >= iMaxHealth)
							{
								EmitSoundToAll("Lua_sounds/healthkit_complete.wav", iPlayer, SNDCHAN_STATIC, _, _, 1.0);
								iHealth = iMaxHealth;
								PrintToChat(iPlayer, "\x05竊긌ua \x01@ \x03You are completely healed!");
								PrintCenterText(iPlayer, "Healed !\n\n \n %d %%\n \n \n \n \n \n \n \n", iMaxHealth);
							}
							else PrintCenterText(iPlayer, "Healing...\n\n \n   %d %%\n \n \n \n \n \n \n \n", iHealth);
							SetEntProp(iPlayer, Prop_Data, "m_iHealth", iHealth);
						}
						else PrintCenterText(iPlayer, "Healed !\n\n \n %d %%\n \n \n \n \n \n \n \n", iMaxHealth);
					}
				}
			}
		}
	}
	else
	{
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
		StopSound(entity, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		EmitSoundToAll("soundscape/emitters/oneshot/radio_explode.ogg", entity, SNDCHAN_STATIC, _, _, 1.0);
		new dissolver = CreateEntityByName("env_entity_dissolver");
		if (dissolver != -1)
		{
			DispatchKeyValue(dissolver, "dissolvetype", Healthkit_Remove_Type);
			DispatchKeyValue(dissolver, "magnitude", "1");
			DispatchKeyValue(dissolver, "target", "!activator");
			AcceptEntityInput(dissolver, "Dissolve", entity);
			AcceptEntityInput(dissolver, "Kill");
		}
	}
}