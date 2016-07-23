#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>
#include <smjansson>

enum Numeros
{
	String:ModelName[STORE_MAX_NAME_LENGTH],
	String:Modelo[PLATFORM_MAX_PATH],
	zpropColor[4],
	Vida
}

new Handle:cvar_max = INVALID_HANDLE;

new g_zprop[1024][Numeros];
new g_zpropCount;

new g_iprops[MAXPLAYERS+1] = 0;

new Handle:g_zpropNameIndex = INVALID_HANDLE;

public Plugin:myinfo =
{
	name        = "[Store] Zprops",
	author      = "Franc1sco steam: franug",
	description = "Zprops component for [Store]",
	version     = "1.0.0",
	url         = "http://servers-cfg.foroactivo.com/"
};

/**
 * Plugin is loading.
 */
public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");

	cvar_max = CreateConVar("sm_zprops_max", "4", "Props max per client");
	Store_RegisterItemType("zprops", OnEquip, LoadItem);
	
	HookEvent("round_start", Event_RoundStart);
}


public OnConfigsExecuted()
{
	PrecacheSound("physics/metal/metal_box_break1.wav");
	PrecacheSound("physics/metal/metal_box_break2.wav");
}

/** 
 * Called when a new API library is loaded.
 */
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("zprops", OnEquip, LoadItem);
	}	
}


public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
		g_iprops[i] = 0;
	
}


public Store_OnReloadItems() 
{
	if (g_zpropNameIndex != INVALID_HANDLE)
		CloseHandle(g_zpropNameIndex);
		
	g_zpropNameIndex = CreateTrie();
	g_zpropCount = 0;
}

public LoadItem(const String:itemName[], const String:attrs[])
{
	strcopy(g_zprop[g_zpropCount][ModelName], STORE_MAX_NAME_LENGTH, itemName);
		
	SetTrieValue(g_zpropNameIndex, g_zprop[g_zpropCount][ModelName], g_zpropCount);
	
	new Handle:json = json_load(attrs);
	json_object_get_string(json, "model", g_zprop[g_zpropCount][Modelo], PLATFORM_MAX_PATH);

	g_zprop[g_zpropCount][Vida] = json_object_get_int(json, "health"); 
	if (g_zprop[g_zpropCount][Vida] == 0)
		g_zprop[g_zpropCount][Vida] = 0;


	new Handle:color = json_object_get(json, "color");

	if (color == INVALID_HANDLE)
	{
		g_zprop[g_zpropCount][zpropColor] = { 255, 255, 255, 255 };
	}
	else
	{
		for (new i = 0; i < 4; i++)
			g_zprop[g_zpropCount][zpropColor][i] = json_array_get_int(color, i);

		CloseHandle(color);
	}

	CloseHandle(json);

	
	g_zpropCount++;
}

public Store_ItemUseAction:OnEquip(client, itemId, bool:equipped)
{
	if (!IsClientInGame(client))
	{
		return Store_DoNothing;
	}
	
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "Must be alive to use");
		return Store_DoNothing;
	}
	
	new max_props = GetConVarInt(cvar_max);
	if (max_props < g_iprops[client])
	{
		PrintToChat(client, "%s Props limit exceeded (max: %i)",STORE_PREFIX, max_props);
		return Store_DoNothing;
	}
	
	decl String:name[STORE_MAX_NAME_LENGTH];
	Store_GetItemName(itemId, name, sizeof(name));

		
	new zprop = -1;
	if (!GetTrieValue(g_zpropNameIndex, name, zprop))
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
		return Store_DoNothing;
	}

	decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
	Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
	
	
	decl Ent;  
	PrecacheModel(g_zprop[zprop][Modelo],true);
	Ent = CreateEntityByName("prop_physics"); 
	
	
	DispatchKeyValue(Ent, "model", g_zprop[zprop][Modelo]);
	DispatchKeyValue(Ent, "classname", "barricada_prop");
	DispatchSpawn(Ent);
	
	decl Float:FurnitureOrigin[3];
	decl Float:ClientOrigin[3];
	decl Float:EyeAngles[3];
	GetClientEyeAngles(client, EyeAngles);
	GetClientAbsOrigin(client, ClientOrigin);
	
	FurnitureOrigin[0] = (ClientOrigin[0] + (50 * Cosine(DegToRad(EyeAngles[1]))));
	FurnitureOrigin[1] = (ClientOrigin[1] + (50 * Sine(DegToRad(EyeAngles[1]))));
	FurnitureOrigin[2] = (ClientOrigin[2] + 50);
	
	TeleportEntity(Ent, FurnitureOrigin, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(Ent, MOVETYPE_VPHYSICS);  


	new vida13 = g_zprop[zprop][Vida];
	if(vida13 > 0)
	{
		SDKHook(Ent, SDKHook_OnTakeDamage, OnTakeDamage2); 
		SetEntProp(Ent, Prop_Data, "m_takedamage", 2, 1);
		SetEntProp(Ent, Prop_Data, "m_iHealth", vida13);
	}
	
	new color[4];
	for (new i = 0; i < 4; i++)
		color[i] = g_zprop[zprop][zpropColor][i];
		
	SetEntityRenderColor(Ent, color[0], color[1], color[2], color[3]);


	PrintToChat(client, "%s Prop: %s Health: %i", STORE_PREFIX,displayName, vida13);
	
	g_iprops[client]++;
	
	return Store_DeleteItem;
}

public IsValidClient( client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}

public Action:OnTakeDamage2(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (IsValidEdict(victim))
	{
		if (IsValidClient(attacker))
		{
			decl String:szWeapon[32];
			GetClientWeapon(attacker, szWeapon, 32);
			if (StrContains(szWeapon, "knife", true) == -1)
			{
				Move(victim, attacker,Float:damage);
				return Plugin_Handled;
			}
		}
		new mullado = GetRandomInt(1, 2);
		switch (mullado)
		{
			case 1:
			{
				new Float:pos[3];
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
				EmitSoundToAll("physics/metal/metal_box_break1.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
			}
			case 2:
			{
				new Float:pos[3];
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
				EmitSoundToAll("physics/metal/metal_box_break2.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
			}
		}
	}
	return Plugin_Continue;
}

Move(client, attacker,Float:damage)
{
	new Float:knockback = 3.0; // knockback amount

 	new Float:clientloc[3];
   	new Float:attackerloc[3];
    
    	//GetClientAbsOrigin(client, clientloc);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientloc);
    
        // Get attackers eye position.
        GetClientEyePosition(attacker, attackerloc);
        
        // Get attackers eye angles.
        new Float:attackerang[3];
        GetClientEyeAngles(attacker, attackerang);
        
        // Calculate knockback end-vector.
        TR_TraceRayFilter(attackerloc, attackerang, MASK_ALL, RayType_Infinite, KnockbackTRFilter);
        TR_GetEndPosition(clientloc);
    
    
    	// Apply damage knockback multiplier.
    	knockback *= damage;
    
    	// Apply knockback.
    	KnockbackSetVelocity(client, attackerloc, clientloc, knockback);
}

KnockbackSetVelocity(client, const Float:startpoint[3], const Float:endpoint[3], Float:magnitude)
{
    // Create vector from the given starting and ending points.
    new Float:vector[3];
    MakeVectorFromPoints(startpoint, endpoint, vector);
    
    // Normalize the vector (equal magnitude at varying distances).
    NormalizeVector(vector, vector);
    
    // Apply the magnitude by scaling the vector (multiplying each of its components).
    ScaleVector(vector, magnitude);
    

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vector);
}

public bool:KnockbackTRFilter(entity, contentsMask)
{
    // If entity is a player, continue tracing.
    if (entity > 0 && entity < MAXPLAYERS)
    {
        return false;
    }
    
    // Allow hit.
    return true;
}