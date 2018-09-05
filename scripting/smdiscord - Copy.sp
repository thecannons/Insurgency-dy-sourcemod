/*
 * SourceMod <-> Discord
 * by: shavit
 *
 * This file is part of SourceMod <-> Discord.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
*/

#include <sourcemod>
#include <dynamic>
#include <SteamWorks>
#include <chat-processor>

#pragma newdecls required
#pragma semicolon 1

#define SMDISCORD_VERSION "1.0"

char gS_WebhookURL[1024];

public Plugin myinfo =
{
	name = "SourceMod <-> Discord",
	author = "shavit",
	description = "Relays in-game chat into a Discord channel.",
	version = SMDISCORD_VERSION,
	url = "https://github.com/shavitush/smdiscord"
}

public void OnPluginStart()
{
	CreateConVar("smdiscord_version", SMDISCORD_VERSION, "Plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	char[] sError = new char[256];

	if(!LoadConfig(sError, 256))
	{
		SetFailState("Couldn't load the configuration file. Error: %s (\"configs/smdiscord.cfg\").");
	}
}

bool LoadConfig(char[] error, int maxlen)
{
	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/smdiscord.cfg");

	Dynamic dConfigFile = Dynamic();

	if(!dConfigFile.ReadKeyValues(sPath))
	{
		dConfigFile.Dispose();

		FormatEx(error, maxlen, "Couldn't access \"%s\". Make sure that the file exists and has correct permissions set.", sPath);

		return false;
	}

	dConfigFile.GetString("WebhookURL", gS_WebhookURL, 1024);

	if(StrContains(gS_WebhookURL, "https://discordapp.com/api/webhooks") == -1)
	{
		FormatEx(error, maxlen, "Please change the value of WebhookURL in the configuration file (\"%s\") to a valid URL. Current value is \"%s\".", sPath, gS_WebhookURL);

		return false;	
	}

	return true;
}
