#include <sourcemod>
#include <clientprefs>

#define PLUGIN_VERSION "1.0.2"

public Plugin:myinfo = 
{
	name = "Show Health",
	author = "exvel",
	description = "Shows your health on the screen",
	version = PLUGIN_VERSION,
	url = "www.sourcemod.net"
}

new Handle:cvar_show_health = INVALID_HANDLE;
new Handle:cvar_show_health_on_hit_only = INVALID_HANDLE;
new Handle:cvar_show_health_text_area = INVALID_HANDLE;
new Handle:cvar_show_health_display_delay = INVALID_HANDLE;

new bool:show_health = true;
new bool:show_health_on_hit_only = true;
new show_health_text_area = 1;
new Float:g_fDisplayDelay;
new bool:g_bIsInit = false;
new bool:g_bIsChangedDelay = false;

new bool:option_show_health[MAXPLAYERS + 1] = {true,...};
new Handle:cookie_show_health = INVALID_HANDLE;

public OnPluginStart()
{
	CreateConVar("sm_show_health_version", PLUGIN_VERSION, "Show Health Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	cvar_show_health = CreateConVar("sm_show_health", "1", "Enabled/Disabled show health functionality, 0 = off/1 = on", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	cvar_show_health_on_hit_only = CreateConVar("sm_show_health_on_hit_only", "0", "Defines the weather when to show a health text:\n0 = show your health on a screen based on delay time.\n1 = show your health only when somebody hit you", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	cvar_show_health_text_area = CreateConVar("sm_show_health_text_area", "1", "Defines the area for health text:\n 1 = in the hint text area\n 2 = in the center of the screen", FCVAR_PLUGIN, true, 1.0, true, 2.0);
	cvar_show_health_display_delay = CreateConVar("sm_show_health_display_delay", "10", "Defines display delay time", FCVAR_PLUGIN);
	
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	
	HookConVarChange(cvar_show_health, OnCVarChange);
	HookConVarChange(cvar_show_health_text_area, OnCVarChange);
	HookConVarChange(cvar_show_health_on_hit_only, OnDisplayDelayChange);
	HookConVarChange(cvar_show_health_display_delay, OnDisplayDelayChange);
	
	AutoExecConfig(true, "plugin.showhealth");
	LoadTranslations("common.phrases");
	LoadTranslations("showhealth.phrases");
	
	cookie_show_health = RegClientCookie("Show Health On/Off", "", CookieAccess_Private);
	SetCookieMenuItem(CookieMenuHandler_ShowHealth, 1, "Show Health");
	
	AutoExecConfig(true,"plugin.showhealth");
	
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_show_health_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshHealthText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnMapStart()
{	
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_show_health_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshHealthText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnMapEnd()
{	
	g_bIsInit = false;
}

public CookieMenuHandler_ShowHealth(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	if (action == CookieMenuAction_DisplayOption)
	{
		decl String:status[10];
		if (option_show_health[client])
		{
			Format(status, sizeof(status), "%T", "On", client);
		}
		else
		{
			Format(status, sizeof(status), "%T", "Off", client);
		}
		
		Format(buffer, maxlen, "%T: %s", "Cookie Show Health", client, status);
	}
	// CookieMenuAction_SelectOption
	else
	{
		option_show_health[client] = !option_show_health[client];
		
		if (option_show_health[client])
		{
			SetClientCookie(client, cookie_show_health, "On");
		}
		else
		{
			SetClientCookie(client, cookie_show_health, "Off");
		}
		
		ShowCookieMenu(client);
	}
}

public OnClientCookiesCached(client)
{
	option_show_health[client] = GetCookieShowHealth(client);
}

bool:GetCookieShowHealth(client)
{
	decl String:buffer[10];
	GetClientCookie(client, cookie_show_health, buffer, sizeof(buffer));
	
	return !StrEqual(buffer, "Off");
}

public OnConfigsExecuted()
{
	GetCVars();
}

public Action:Timer_RefreshHealthText(Handle:timer)
{
	if (g_bIsChangedDelay)
	{
		g_bIsChangedDelay = false;
		g_bIsInit = false;
		CreateTimer(g_fDisplayDelay, Timer_RestartHealthTimer);
		PrintToServer("[Health] Restarting");
		return Plugin_Stop;
	}
	
	if (!show_health || show_health_on_hit_only)
	{
		PrintToServer("[Health] Stoped.(show_health: %d / show_health_on_hit_only: %d)", show_health, show_health_on_hit_only);
		g_bIsInit = false;
		return Plugin_Stop;
	}
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientObserver(client))
		{
			ShowHealth(client, GetClientHealth(client));
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!show_health)
	{
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new health = GetEventInt(event, "health");
	
	if (health > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		ShowHealth(client, health);
	}
	
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!show_health)
	{
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client == 0)
		return Plugin_Continue;
	
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		ShowHealth(client, 0);
	}
	
	return Plugin_Continue;
}

public ShowHealth(client, health)
{
	//if (!option_show_health[client])
	//	return;
	
	switch (show_health_text_area)
	{
		case 1:
		{
			PrintHintText(client, "%t", "HintText Health Text", health);
		}
		
		case 2:
		{
			PrintCenterText(client, "%t", "CenterText Health Text", health);
		}
	}
}

public OnDisplayDelayChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_bIsChangedDelay = true;
	show_health_on_hit_only = GetConVarBool(cvar_show_health_on_hit_only);
	g_fDisplayDelay = GetConVarFloat(cvar_show_health_display_delay)
	CreateTimer(g_fDisplayDelay, Timer_RestartHealthTimer);
	PrintToServer("[Health] Timer cvars changed (g_fDisplayDelay: %f)", g_fDisplayDelay);
}

public Action:Timer_RestartHealthTimer(Handle:timer)
{
	PrintToServer("[Health] Restart Timer (g_bIsInit: %d)", g_bIsInit);
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_show_health_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshHealthText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnCVarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	GetCVars();
	PrintToServer("[Health] Cvars changed");
}

public GetCVars()
{
	show_health = GetConVarBool(cvar_show_health);
	show_health_text_area = GetConVarInt(cvar_show_health_text_area);
	show_health_on_hit_only = GetConVarBool(cvar_show_health_on_hit_only);
	g_fDisplayDelay = GetConVarFloat(cvar_show_health_display_delay);
}