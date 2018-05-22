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
 To do different servers, rename plugin and build to different configs\configname.cfg file with different webhook URL
*/

#include <sourcemod>
#include <dynamic>
#include <SteamWorks>

#pragma semicolon 1

ConVar hostname = null;
char gS_WebhookURL[1024];
new String:g_szMessage[1024];
new String:g_szMessageTime[1024];

public Plugin myinfo =
{
	name = "[INS] Discord",
	author = "Neko- (shavit)",
	description = "Relays in-game chat into a Discord channel.",
	version = "1.0.1",
	url = "https://github.com/shavitush/smdiscord"
}

public void OnPluginStart()
{
	RegConsoleCmd("calladmin", Cmd_CallAdmin, "Call admin from discord");
	
	hostname = FindConVar("hostname");

	char[] sError = new char[256];

	if(!LoadConfig(sError, 256))
	{
		SetFailState("Couldn't load the configuration file. Error: %s", sError);
	}
	
	AddCommandListener(Say_Event, "say");
	AddCommandListener(SayTeam_Event, "say_team");
}

bool LoadConfig(char[] error, int maxlen)
{
	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/discord.cfg");

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

void EscapeString(char[] string, int maxlen)
{
	ReplaceString(string, maxlen, "@", "＠");
	ReplaceString(string, maxlen, "'", "\'");
	ReplaceString(string, maxlen, "\"", "＂");
}

void EscapeStringAllowAt(char[] string, int maxlen)
{
	ReplaceString(string, maxlen, "'", "\'");
	ReplaceString(string, maxlen, "\"", "＂");
}

public Action:Say_Event(client, const String:cmd[], argc)
{
	decl String:strMsg[255];
	GetCmdArgString(strMsg, 255);
	StripQuotes(strMsg);
	
	decl String:sAuthID[64];
	//GetClientAuthString(client, sAuthID, 64);
	GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID));
	
	decl String:strName[64];
	GetClientName(client, strName, sizeof(strName));
	
	DiscordMessage(sAuthID, strName, strMsg);
	
	return Plugin_Continue;
}

public Action:SayTeam_Event(client, const String:cmd[], argc)
{
	decl String:strMsg[255];
	GetCmdArgString(strMsg, 255);
	StripQuotes(strMsg);
	
	decl String:sAuthID[64];
	GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID));
	//GetClientAuthString(client, sAuthID, 64);
	
	decl String:strName[64];
	GetClientName(client, strName, sizeof(strName));
	
	DiscordMessage(sAuthID, strName, strMsg, true);
	
	return Plugin_Continue;
}

DiscordMessage(const String:strAuthID[], const String:strName[], const String:strMessage[], bool bTeamChat = false)
{
	char[] sHostname = new char[32];
	hostname.GetString(sHostname, 32);
	EscapeString(sHostname, 32);
	
	char[] sFormat = new char[1024];
	FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game Chat");

	char[] sTime = new char[10];
	FormatTime(sTime, 10, "%H:%I:%S");

	char[] sNewMessage = new char[1024];
	
	if(bTeamChat)
	{
		FormatEx(sNewMessage, 1024, "**[%s] (TEAM) %s :** %s", strAuthID, strName, strMessage);
	}
	else
	{
		FormatEx(sNewMessage, 1024, "**[%s] %s :** %s", strAuthID, strName, strMessage);
	}
	
	EscapeString(sNewMessage, 1024);
	ReplaceString(sFormat, 1024, "{msg}", sNewMessage);
	
	if((!StrEqual(g_szMessageTime, sTime, false)) || (!StrEqual(g_szMessage, sNewMessage, false)))
	{
		Format(g_szMessageTime, sizeof(g_szMessageTime), "%s", sTime);
		Format(g_szMessage, sizeof(g_szMessage), "%s", sNewMessage);
		
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
		SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
		SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
		SteamWorks_SendHTTPRequest(hRequest);
	}
}

public void OnRequestComplete(Handle hRequest, bool bFailed, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	delete hRequest;
}

public Action:Cmd_CallAdmin(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: calladmin <reason>");
		return Plugin_Handled;
	}
	
	char szReason[500];
	GetCmdArgString(szReason, sizeof(szReason));
	
	decl String:sAuthID[64];
	//GetClientAuthString(client, sAuthID, 64);
	GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID));
	
	decl String:strName[64];
	GetClientName(client, strName, sizeof(strName));
	EscapeString(strName, 64);

	char[] sFormat = new char[1024];
	FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game Admin Notification");
	
	char[] sNewMessage = new char[1024];
	FormatEx(sNewMessage, 1024, "**[%s] %s** is calling for <@&241224989662117889>```%s```", sAuthID, strName, szReason);
	EscapeStringAllowAt(sNewMessage, 1024);
	ReplaceString(sFormat, 1024, "{msg}", sNewMessage);
	
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
	SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
	SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
	SteamWorks_SendHTTPRequest(hRequest);
	
	PrintToChat(client, "\x0759b0f9[INS] \x01Please wait for the next available admin to reach you...");
	return Plugin_Handled;
}