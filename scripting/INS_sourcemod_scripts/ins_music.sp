#include <sourcemod>
#include <sdktools>

#define MAX_FILE_LEN 80

new bool:g_nPlayer[MAXPLAYERS+1] = {false, ...};

public Plugin:myinfo = {
    name = "[INS] Music",
    description = "Play music for player",
    author = "Neko-",
    version = "1.0.2",
};

new String:MusicSounds[][] = {
	"music/uav.ogg",
	"music/baby.ogg",
	"music/what_is_love.ogg",
	"music/down_in_flames.ogg",
	"music/ohno.ogg"
};

public OnPluginStart() 
{
	RegConsoleCmd("uav", PlayUAV, "Play UAV Online");
	RegConsoleCmd("baby", PlayBaby, "Play baby");
	RegConsoleCmd("whatislove", PlayWhatIsLove, "Play what is love");
	RegConsoleCmd("downinflames", PlayDownInFlames, "Play down in flames");
	RegConsoleCmd("ohno", PlayOhNo, "Play Oh No from planet of ape");
	RegAdminCmd("babyall", PlayBabyAll, ADMFLAG_KICK, "Play baby for all players");
	RegAdminCmd("whatisloveall", PlayWhatIsLoveAll, ADMFLAG_KICK, "Play what is love for all players");
	RegAdminCmd("downinflamesall", PlayDownInFlamesAll, ADMFLAG_KICK, "Play down in flames for all players");
	RegAdminCmd("ohnoall", PlayOhNoAll, ADMFLAG_KICK, "Play Oh No from planet of ape for all players");
}

public OnConfigsExecuted()
{
	decl String:buffer[MAX_FILE_LEN];
	for (new i = 0; i < sizeof(MusicSounds); i++) {
		Format(buffer, sizeof(buffer), "sound/%s", MusicSounds[i]);
		AddFileToDownloadsTable(buffer);
	}
}

public OnMapStart()
{
	for (new i = 0; i < sizeof(MusicSounds); i++) {
		PrecacheSound(MusicSounds[i]);
	}
}  

public OnClientPostAdminCheck(client)
{
	g_nPlayer[client] = false;
}

public OnClientDisconnect(client)
{
	g_nPlayer[client] = false;
}

public Action:Timer_ResetPlayerMusicCooldown(Handle:Timer, any:client)
{
	g_nPlayer[client] = false;
}

public Action:PlayUAV(client, args)
{
	new health = GetClientHealth(client);
	
	if((health > 0) && (g_nPlayer[client] == false))
	{
		EmitSoundToAll(MusicSounds[0], client);
		g_nPlayer[client] = true;
		CreateTimer(10.0, Timer_ResetPlayerMusicCooldown, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Handled;
}

public Action:PlayBaby(client, args)
{
	new health = GetClientHealth(client);
	
	if((health > 0) && (g_nPlayer[client] == false))
	{
		EmitSoundToAll(MusicSounds[1], client);
		g_nPlayer[client] = true;
		CreateTimer(10.0, Timer_ResetPlayerMusicCooldown, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Handled;
}

public Action:PlayBabyAll(client, args)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			new health = GetClientHealth(i);
			if(health > 0)
			{
				EmitSoundToAll(MusicSounds[1], i);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:PlayWhatIsLove(client, args)
{
	new health = GetClientHealth(client);
	
	if((health > 0) && (g_nPlayer[client] == false))
	{
		EmitSoundToAll(MusicSounds[2], client);
		g_nPlayer[client] = true;
		CreateTimer(12.0, Timer_ResetPlayerMusicCooldown, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Handled;
}

public Action:PlayWhatIsLoveAll(client, args)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			new health = GetClientHealth(i);
			if(health > 0)
			{
				EmitSoundToAll(MusicSounds[2], i);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:PlayDownInFlames(client, args)
{
	new health = GetClientHealth(client);
	
	if((health > 0) && (g_nPlayer[client] == false))
	{
		EmitSoundToAll(MusicSounds[3], client);
		g_nPlayer[client] = true;
		CreateTimer(15.0, Timer_ResetPlayerMusicCooldown, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Handled;
}

public Action:PlayDownInFlamesAll(client, args)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			new health = GetClientHealth(i);
			if(health > 0)
			{
				EmitSoundToAll(MusicSounds[3], i);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:PlayOhNo(client, args)
{
	new health = GetClientHealth(client);
	
	if((health > 0) && (g_nPlayer[client] == false))
	{
		EmitSoundToAll(MusicSounds[4], client);
		g_nPlayer[client] = true;
		CreateTimer(8.0, Timer_ResetPlayerMusicCooldown, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Handled;
}

public Action:PlayOhNoAll(client, args)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			new health = GetClientHealth(i);
			if(health > 0)
			{
				EmitSoundToAll(MusicSounds[4], i);
			}
		}
	}
	
	return Plugin_Handled;
}


stock FakePrecacheSound( const String:szPath[] )
{
	AddToStringTable(FindStringTable("soundprecache"), szPath);
}

bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}