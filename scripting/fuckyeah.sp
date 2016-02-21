#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"
#define PLUGIN_DESCRIPTION "Fucking fuck yeah"

public Plugin:info = {
	name = "Fuck Yeah",
	author = "Casey Weed (Battleroid)",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION
};

new Handle:g_CvarEnabled;
new Handle:g_CvarDebugEnabled
new Handle:g_CvarYellChance;

// list of specific files that are decent
new String:FuckingSounds[][] = {
	/*
	"player/voice/radial/security/leader/suppressed/go3.ogg",
	"player/voice/radial/security/leader/suppressed/target10.ogg",
	"player/voice/radial/security/leader/suppressed/target5.ogg",
	"player/voice/radial/security/leader/suppressed/target8.ogg",
	"player/voice/radial/security/subordinate/suppressed/target10.ogg",
	"player/voice/radial/security/subordinate/suppressed/target2.ogg",
	"player/voice/radial/security/subordinate/suppressed/target3.ogg",
	"player/voice/radial/security/subordinate/suppressed/target4.ogg",
	"player/voice/radial/security/subordinate/unsuppressed/enemydown_knifekill3.ogg",
	"player/voice/radial/security/subordinate/unsuppressed/enemydown_knifekill1.ogg",
	"player/voice/responses/security/subordinate/suppressed/frag6.ogg",
	"player/voice/responses/security/subordinate/suppressed/frag7.ogg",
	"player/voice/responses/security/subordinate/suppressed/target12.ogg",
	"player/voice/responses/security/subordinate/suppressed/target2.ogg",
	"player/voice/responses/security/subordinate/suppressed/target3.ogg",
	"player/voice/responses/security/subordinate/suppressed/target7.ogg",
	"player/voice/responses/security/subordinate/suppressed/target9.ogg"
	*/
	"player/voice/responses/security/subordinate/suppressed/target1.ogg",
	"player/voice/responses/security/subordinate/suppressed/target2.ogg",
	"player/voice/responses/security/subordinate/suppressed/target3.ogg",
	"player/voice/responses/security/subordinate/suppressed/target4.ogg",
	"player/voice/responses/security/subordinate/suppressed/target5.ogg",
	"player/voice/responses/security/subordinate/suppressed/target6.ogg",
	"player/voice/responses/security/subordinate/suppressed/target7.ogg",
	"player/voice/responses/security/subordinate/suppressed/target8.ogg",
	"player/voice/responses/security/subordinate/suppressed/target9.ogg",
	"player/voice/responses/security/subordinate/suppressed/target10.ogg",
	"player/voice/responses/security/subordinate/suppressed/target11.ogg",
	"player/voice/responses/security/subordinate/suppressed/target12.ogg",
	"player/voice/responses/security/subordinate/suppressed/target13.ogg"
};

// few voices that are typically good
// TODO: non-functional for now, EmitGameSoundToAll is not working properly, figure out why
// new String:FuckingVoices[][] = {
// 	"ins_sounds_radial_security.Radial_Security.Leader_UnSupp_EnemyDownKnife",
// 	"ins_sounds_radial_security.Radial_Security.Subordinate_UnSupp_EnemyDownKnife",
// 	"ins_sounds_radial_security.Radial_Security.Subordinate_Supp_TargetDown"
// };

// whether or not the player has an active cooldown, end time for cooldown
new bool:PlayerCooldown[MAXPLAYERS + 1] = {true, ...};
new Float:PlayerTimedone[MAXPLAYERS + 1];

// length of time to wait before yelling can occur again (in seconds)
new Handle:CooldownPeriod;

public void OnPluginStart() {
	// cvars
	CreateConVar("fy_enabled", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_DONTRECORD);
	g_CvarEnabled = CreateConVar("fy_enabled", "1", "Fuck Yeah Enabled [0/1]", FCVAR_NOTIFY | FCVAR_PLUGIN);
	g_CvarDebugEnabled = CreateConVar("fy_debug", "0", "Fuck Yeah Debugging Enabled [0/1]", FCVAR_NOTIFY | FCVAR_PLUGIN);
	g_CvarYellChance = CreateConVar("fy_chance", "0.5", "Chance of Yelling [0-1]", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, true, 1.0);
	CooldownPeriod = CreateConVar("fy_cooldown", "1.0", "Cooldown period between yells [>0.0]", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, false);

	// commands (debug)
	RegConsoleCmd("fuckyeah", Command_FuckTest, "Test Fuck Yeah plugin.");

	// events
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	// notify
	if (GetConVarBool(g_CvarEnabled)) {
		new Float:percentage = GetConVarFloat(g_CvarYellChance) * 100;
		PrintToServer("[FY] Started with %0.2f% yell chance!", percentage);
		PrintToServer("[FY] CooldownPeriod is %0.2f", GetConVarFloat(CooldownPeriod));
	}
}

public OnMapStart() {
	new noncached = 0;
	// cache sounds in string array to be used
	for (new i = 0; i < sizeof(FuckingSounds); i++) {
		if (!IsSoundPrecached(FuckingSounds[i])) {
			PrecacheSound(FuckingSounds[i]);
			noncached++;
			if (GetConVarBool(g_CvarDebugEnabled)) {
				PrintToServer("[FY] Cached: %s", FuckingSounds[i]);
			}
		}
	}
	PrintToServer("[FY] Done caching %d sounds (total %d)", noncached, sizeof(FuckingSounds));
}

public OnClientDisconnected(client) {
	RemoveCooldown(client);
}

public Action:Command_FuckTest(client, args) {
	Fuck(client);
	return Plugin_Handled;
}

public Action:Fuck(client) {
	if (!GetConVarBool(g_CvarEnabled)) {
		return Plugin_Stop;
	}

	// statics
	static idx_Sound = -1;
	// static voice = false;

	// decide on voice or sound
	new idx_Old = idx_Sound;
	idx_Sound = GetRandomInt(0, sizeof(FuckingSounds) - 1);
	// TODO: Need voices to work before this can be implemented.
	// if (0.5 > GetRandomFloat(0.0, 1.0)) {
	// 	idx_Sound = GetRandomInt(0, sizeof(FuckingSounds) - 1);
	// 	voice = false;
	// } else {
	// 	idx_Sound = GetRandomInt(0, sizeof(FuckingVoices) - 1);
	// 	voice = true;
	// }

	if (GetConVarBool(g_CvarDebugEnabled)) {
		PrintToServer("[FY] Sound ID: Old %d, New %d", idx_Old, idx_Sound);
	}

	// prevent playing the same sound in a row
	if (idx_Old == idx_Sound) {
		return Fuck(client);
	} else {
		// TODO: Need voices to work before this can be implemented.
		// if (voice) {
		// 	if (GetConVarBool(g_CvarDebugEnabled)) {
		// 		PrintToServer("[FY] Using Voice %s", FuckingVoices[idx_Sound]);
		// 	}
		// 	EmitGameSoundToAll(FuckingVoices[idx_Sound], client);
		// } else {
		// 	if (GetConVarBool(g_CvarDebugEnabled)) {
		// 		PrintToServer("[FY] Using Sound %s", FuckingSounds[idx_Sound]);
		// 	}
		// 	EmitSoundToAll(FuckingSounds[idx_Sound], client);
		// }
		EmitSoundToAll(FuckingSounds[idx_Sound], client);
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

	if (GetConVarBool(g_CvarDebugEnabled)) {
		PrintToServer("[FY] Client %d timedone is %0.2f, it is %0.2f now", client, timedone, GetGameTime());
	}
}

public Action:RemoveCooldown(client) {
	PlayerCooldown[client] = false;
	PlayerTimedone[client] = 0.0;

	if (GetConVarBool(g_CvarDebugEnabled)) {
		PrintToServer("[FY] Removing cooldown for %d", client);
	}
}

public Action:Event_PlayerDeath(Handle:event, String:name[], bool:broadcast) {
	// get killer of victim
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));

	// if victim was a player, remove his timer
	if (victim > 0 && !IsFakeClient(victim) && IsClientInGame(victim)) {
		RemoveCooldown(victim);
	}

	// if the killer is a bot stop here
	if (killer == 0 || !IsClientInGame(killer) || IsFakeClient(killer) ) {
		if (GetConVarBool(g_CvarDebugEnabled)) {
			PrintToServer("[FY] Did not yell, client was not valid (client %d)", killer);
		}
		return Plugin_Continue;
	}

	// get killer timedone and check if we have passed it
	new Float:CurrentTime = GetGameTime();
	if (PlayerCooldown[killer]) {
		if (CurrentTime < PlayerTimedone[killer]) {
			if (GetConVarBool(g_CvarDebugEnabled)) {
				PrintToServer("[FY] Time check: %f < %f", CurrentTime, PlayerTimedone[killer]);
			}
			return Plugin_Continue;
		} else {
			if (GetConVarBool(g_CvarDebugEnabled)) {
				PrintToServer("[FY] Removed cooldown for %d", killer);
			}
			RemoveCooldown(killer);
		}
	}

	// play sound at the player if RNG passes
	new Float:rn = GetRandomFloat(0.0, 1.0);
	if (rn <= GetConVarFloat(g_CvarYellChance)) {
		Fuck(killer);
		SetCooldown(killer);
	} else {
		if (GetConVarBool(g_CvarDebugEnabled)) {
			PrintToServer("[FY] Did not yell (client %d) chance was %0.2f", killer, rn * 100);
		}
	}

	return Plugin_Continue;
}
