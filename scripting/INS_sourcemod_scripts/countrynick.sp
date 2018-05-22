/*
SourceMod Country Nick Plugin
Add country of the player near his nick
 
Country Nick Plugin (C)2009-2010 A-L. All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

$Id: countrynick.sp 29 2009-02-23 23:45:22Z aen0 $
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <geoip>
 
#define VERSION "1.0.0"

new Handle:hTagSize, iTagSize,
	Handle:hMsg, bool:bMsg;

public Plugin:myinfo =
{
	name = "[INS] Country Nick Plugin",
	author = "Neko- (Antoine LIBERT aka AeN0, Grey83)",
	description = "Add country of the player near his nick",
	version = VERSION
};

public OnPluginStart()
{
	LoadTranslations("countrynick.phrases");

	CreateConVar("countrynick_version", VERSION, "Country Nick Version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_DONTRECORD);
	hTagSize = CreateConVar("sm_countrynick_tagsize", "3", "Size of the country tag (2 or 3 letters)", FCVAR_NONE, true, 2.0, true, 3.0);
	hMsg = CreateConVar("sm_countrynick_msg", "0", "1/0 - Switch On/Off announcement connecting of a players (and error logging)", FCVAR_NONE, true, 0.0, true, 1.0);

	iTagSize = GetConVarInt(hTagSize);
	bMsg = GetConVarBool(hMsg);

	HookConVarChange(hTagSize, OnConVarChange);
	HookConVarChange(hMsg, OnConVarChange);
	
	HookEvent("player_changename", Event_PlayerChangename, EventHookMode_Pre);

	AutoExecConfig(true, "countrynick");
}

public OnConVarChange(Handle:hCVar, const String:oldValue[], const String:newValue[])
{
	if (hCVar == hTagSize) iTagSize = StringToInt(newValue);
	else if (hCVar == hMsg) bMsg = bool:StringToInt(newValue);
}

public OnClientPostAdminCheck(client)
{
	decl String:ip[16];
	decl String:country[46];
	decl String:sName[65];
	
	if(1 <= client <= MaxClients && !IsFakeClient(client))
	{
		GetClientName(client, sName, sizeof(sName));
		SetNewName(client, sName);
		
		if(bMsg) 
		{
			GetClientIP(client, ip, 16); 
			if(GeoipCountry(ip, country, 45))
				PrintToChatAll("\x03%T", "Announcer country found", LANG_SERVER, client, country);
			else
			{
				PrintToChatAll("\x03%T", "Announcer country not found", LANG_SERVER, client);
				LogError("[Country Nick] Warning : %N uses %s that is not listed in GEOIP database", client, ip);
			}
		}
	}
}

public Action:Event_PlayerChangename(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:sName[65];
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsFakeClient(client))
	{
		GetEventString(event, "newname", sName, 65);
		SetNewName(client, sName);
		return Plugin_Handled; // avoid printing the change to the chat
	}
	return Plugin_Continue;
}

SetNewName(client, String:sName[])
{
	decl String:ip[16];
	decl String:code[3];
	new bool:found;
	decl String:flag[6];
	
	GetClientIP(client, ip, 16);
	new AdminId:admin = GetUserAdmin(client);
	if(iTagSize == 2)
	{
		found = GeoipCode2(ip, code);
		if(found) Format(flag, 5, "[%2s]", code);
		else Format(flag, 5, "[--]");
		
		if((admin != INVALID_ADMIN_ID) && (GetAdminFlag(admin, Admin_Root, Access_Effective)))
		{
			Format(flag, 5, "[IQ]");
		}
	}
	else
	{
		found = GeoipCode3(ip, code);
		if(found) Format(flag, 6, "[%3s]", code);
		else Format(flag, 6, "[-?-]");
		
		if((admin != INVALID_ADMIN_ID) && (GetAdminFlag(admin, Admin_Root, Access_Effective)))
		{
			Format(flag, 6, "[IRQ]");
		}
	}

	if(!(StrContains(sName, flag, false) == 0))
	{
		Format(sName, 69, "%s %s", flag, sName);
		//SetClientInfo(client, "name", sName);
		SetClientName(client, sName);
	}
}