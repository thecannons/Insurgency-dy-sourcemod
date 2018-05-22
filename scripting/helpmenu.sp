/*
 * In-game Help Menu
 * Written by chundo (chundo@mefightclub.com)
 *
 * Licensed under the GPL version 2 or above
 */

#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION "0.3"

enum ChatCommand {
	String:command[32],
	String:description[255]
}

enum HelpMenuType {
	HelpMenuType_List,
	HelpMenuType_Text
}

enum HelpMenu {
	String:name[32],
	String:title[128],
	HelpMenuType:type,
	Handle:items,
	itemct
}

// CVars
new Handle:g_cvarWelcome = INVALID_HANDLE;
new Handle:g_cvarAdmins = INVALID_HANDLE;

// Help menus
new Handle:g_helpMenus = INVALID_HANDLE;

// Map cache
new Handle:g_mapArray = INVALID_HANDLE;
new g_mapSerial = -1;
new g_playerFirstJoin[MAXPLAYERS+1] = 0; 



// Config parsing
new g_configLevel = -1;

public Plugin:myinfo =
{
	name = "In-game Help Menu",
	author = "chundo",
	description = "Display a help menu to users",
	version = PLUGIN_VERSION,
	url = "http://www.mefightclub.com"
};

public OnPluginStart() {
	CreateConVar("sm_helpmenu_version", PLUGIN_VERSION, "Help menu version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_cvarWelcome = CreateConVar("sm_helpmenu_welcome", "1", "Show welcome message to newly connected users.");
	g_cvarAdmins = CreateConVar("sm_helpmenu_admins", "0", "Show a list of online admins in the menu.");
	RegConsoleCmd("sm_info", Command_HelpMenu, "Display the help menu.");
	HookEvent("player_spawn", Event_Spawn);
	new String:hc[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, hc, sizeof(hc), "configs/helpmenu.cfg");
	g_mapArray = CreateArray(32);
	ParseConfigFile(hc);

	AutoExecConfig(false);
}

public OnMapStart() {
	new String:hc[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, hc, sizeof(hc), "configs/helpmenu.cfg");
	ParseConfigFile(hc);
}

public OnClientPutInServer(client) {
	if (GetConVarBool(g_cvarWelcome))
	{
		CreateTimer(30.0, Timer_WelcomeMessage, client);
		CreateTimer(600.0, Timer_WelcomeMessage, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	g_playerFirstJoin[client] = 1;
	Help_ShowMainMenu(client);
}

public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	//For first joining players 
	if (g_playerFirstJoin[client] == 1 && !IsFakeClient(client))
	{
		Help_ShowMainMenu(client);
		g_playerFirstJoin[client] = 0;
	}
	if (!IsClientConnected(client)) {
		return Plugin_Continue;
	}
	if (!IsClientInGame(client)) {
		return Plugin_Continue;
	}
	if (!IsFakeClient(client)) {
		return Plugin_Continue;
	}


	return Plugin_Continue;
}

public Action:Timer_WelcomeMessage(Handle:timer, any:client) {
	if (GetConVarBool(g_cvarWelcome) && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
		PrintToChat(client, "\x01[SRNX] For Sernix Server Specific Info, type \x04!INFO\x01 in chat");
		PrintToChat(client, "\x01[SRNX] Need an ADMIN? type \x04!CALLADMIN <REASON>\x01 in chat to notify admin via discord");
}

bool:ParseConfigFile(const String:file[]) {
	if (g_helpMenus != INVALID_HANDLE) {
		ClearArray(g_helpMenus);
		CloseHandle(g_helpMenus);
		g_helpMenus = INVALID_HANDLE;
	}

	new Handle:parser = SMC_CreateParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMC_SetParseEnd(parser, Config_End);

	new line = 0;
	new col = 0;
	new String:error[128];
	new SMCError:result = SMC_ParseFile(parser, file, line, col);
	CloseHandle(parser);

	if (result != SMCError_Okay) {
		SMC_GetErrorString(result, error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, file);
	}

	return (result == SMCError_Okay);
}

public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes) {
	g_configLevel++;
	if (g_configLevel == 1) {
		new hmenu[HelpMenu];
		strcopy(hmenu[name], sizeof(hmenu[name]), section);
		hmenu[items] = CreateDataPack();
		hmenu[itemct] = 0;
		if (g_helpMenus == INVALID_HANDLE)
			g_helpMenus = CreateArray(sizeof(hmenu));
		PushArrayArray(g_helpMenus, hmenu[0]);
	}
	return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes) {
	new msize = GetArraySize(g_helpMenus);
	new hmenu[HelpMenu];
	GetArrayArray(g_helpMenus, msize-1, hmenu[0]);
	switch (g_configLevel) {
		case 1: {
			if(strcmp(key, "title", false) == 0)
				strcopy(hmenu[title], sizeof(hmenu[title]), value);
			if(strcmp(key, "type", false) == 0) {
				if(strcmp(value, "text", false) == 0)
					hmenu[type] = HelpMenuType_Text;
				else
					hmenu[type] = HelpMenuType_List;
			}
		}
		case 2: {
			WritePackString(hmenu[items], key);
			WritePackString(hmenu[items], value);
			hmenu[itemct]++;
		}
	}
	SetArrayArray(g_helpMenus, msize-1, hmenu[0]);
	return SMCParse_Continue;
}
public SMCResult:Config_EndSection(Handle:parser) {
	g_configLevel--;
	if (g_configLevel == 1) {
		new hmenu[HelpMenu];
		new msize = GetArraySize(g_helpMenus);
		GetArrayArray(g_helpMenus, msize-1, hmenu[0]);
		ResetPack(hmenu[items]);
	}
	return SMCParse_Continue;
}

public Config_End(Handle:parser, bool:halted, bool:failed) {
	if (failed)
		SetFailState("Plugin configuration error");
}

public Action:Command_HelpMenu(client, args) {
	Help_ShowMainMenu(client);
	return Plugin_Handled;
}

Help_ShowMainMenu(client) {
	new Handle:menu = CreateMenu(Help_MainMenuHandler);
	SetMenuExitBackButton(menu, true);
	SetMenuTitle(menu, "Help Menu\n ");
	new msize = GetArraySize(g_helpMenus);
	new hmenu[HelpMenu];
	new String:menuid[10];
	for (new i = 0; i < msize; ++i) {
		Format(menuid, sizeof(menuid), "helpmenu_%d", i);
		GetArrayArray(g_helpMenus, i, hmenu[0]);
		AddMenuItem(menu, menuid, hmenu[name]);
	}
	AddMenuItem(menu, "maplist", "Map Rotation");
	if (GetConVarBool(g_cvarAdmins))
		AddMenuItem(menu, "admins", "List Online Admins");
	DisplayMenu(menu, client, 30);
}

public Help_MainMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_End) {
		CloseHandle(menu);
	} else if (action == MenuAction_Select) {
		new String:buf[64];
		new msize = GetArraySize(g_helpMenus);
		if (param2 == msize) { // Maps
			new Handle:mapMenu = CreateMenu(Help_MenuHandler);
			SetMenuExitBackButton(mapMenu, true);
			ReadMapList(g_mapArray, g_mapSerial, "default");
			Format(buf, sizeof(buf), "Current Rotation (%d maps)\n ", GetArraySize(g_mapArray));
			SetMenuTitle(mapMenu, buf);
			if (g_mapArray != INVALID_HANDLE) {
				new mapct = GetArraySize(g_mapArray);
				new String:mapname[64];
				for (new i = 0; i < mapct; ++i) {
					GetArrayString(g_mapArray, i, mapname, sizeof(mapname));
					AddMenuItem(mapMenu, mapname, mapname, ITEMDRAW_DISABLED);
				}
			}
			DisplayMenu(mapMenu, param1, 30);
		} else if (param2 == msize+1) { // Admins
			new Handle:adminMenu = CreateMenu(Help_MenuHandler);
			SetMenuExitBackButton(adminMenu, true);
			SetMenuTitle(adminMenu, "Online Admins\n ");
			new maxc = GetMaxClients();
			new String:aname[64];
			for (new i = 1; i < maxc; ++i) {
				if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && (GetUserFlagBits(i) & ADMFLAG_GENERIC) == ADMFLAG_GENERIC) {
					GetClientName(i, aname, sizeof(aname));
					AddMenuItem(adminMenu, aname, aname, ITEMDRAW_DISABLED);
				}
			}
			DisplayMenu(adminMenu, param1, 30);
		} else { // Menu from config file
			if (param2 <= msize) {
				new hmenu[HelpMenu];
				GetArrayArray(g_helpMenus, param2, hmenu[0]);
				new String:mtitle[512];
				Format(mtitle, sizeof(mtitle), "%s\n ", hmenu[title]);
				if (hmenu[type] == HelpMenuType_Text) {
					new Handle:cpanel = CreatePanel();
					SetPanelTitle(cpanel, mtitle);
					new String:text[128];
					new String:junk[128];
					for (new i = 0; i < hmenu[itemct]; ++i) {
						ReadPackString(hmenu[items], junk, sizeof(junk));
						ReadPackString(hmenu[items], text, sizeof(text));
						DrawPanelText(cpanel, text);
					}
					for (new j = 0; j < 7; ++j)
						DrawPanelItem(cpanel, " ", ITEMDRAW_NOTEXT);
					DrawPanelText(cpanel, " ");
					DrawPanelItem(cpanel, "Back", ITEMDRAW_CONTROL);
					DrawPanelItem(cpanel, " ", ITEMDRAW_NOTEXT);
					DrawPanelText(cpanel, " ");
					DrawPanelItem(cpanel, "Exit", ITEMDRAW_CONTROL);
					ResetPack(hmenu[items]);
					SendPanelToClient(cpanel, param1, Help_MenuHandler, 30);
					CloseHandle(cpanel);
				} else {
					new Handle:cmenu = CreateMenu(Help_CustomMenuHandler);
					SetMenuExitBackButton(cmenu, true);
					SetMenuTitle(cmenu, mtitle);
					new String:cmd[128];
					new String:desc[128];
					for (new i = 0; i < hmenu[itemct]; ++i) {
						ReadPackString(hmenu[items], cmd, sizeof(cmd));
						ReadPackString(hmenu[items], desc, sizeof(desc));
						new drawstyle = ITEMDRAW_DEFAULT;
						if (strlen(cmd) == 0)
							drawstyle = ITEMDRAW_DISABLED;
						AddMenuItem(cmenu, cmd, desc, drawstyle);
					}
					ResetPack(hmenu[items]);
					DisplayMenu(cmenu, param1, 30);
				}
			}
		}
	}
}

public Help_MenuHandler(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_End) {
		CloseHandle(menu);
	} else if (menu == INVALID_HANDLE && action == MenuAction_Select && param2 == 8) {
		Help_ShowMainMenu(param1);
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack)
			Help_ShowMainMenu(param1);
	}
}

public Help_CustomMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_End) {
		CloseHandle(menu);
	} else if (action == MenuAction_Select) {
		new String:itemval[32];
		GetMenuItem(menu, param2, itemval, sizeof(itemval));
		if (strlen(itemval) > 0)
			FakeClientCommand(param1, itemval);
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack)
			Help_ShowMainMenu(param1);
	}
}
