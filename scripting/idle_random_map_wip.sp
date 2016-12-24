#pragma semicolon 1
#include <sourcemod>

new bool:g_LoggedFileName = false;		/* Whether or not the file name has been logged */
new g_ErrorCount = 0;				/* Current error count */
new g_CurrentLine = 0;				/* Current line we're on */
new String:g_Filename[PLATFORM_MAX_PATH];	/* Used for error messages */
new String:g_map[255];
new Handle:g_map_idle_time;
new Handle:g_players_change;
new Handle:g_log_map_change;
new Handle:g_MapsArray;
new Handle:g_timer; 
bool g_changeMap;

public Plugin:myinfo =
{
	name = "Idle Random Map",
	author = "Gdk",
	description = "Change to a random map for a defined player count after a defined time",
	version = "1.2.0",
	url = "https://github.com/RavageCS/Idle-Change-Random-Map"
}

public OnPluginStart()
{
     	g_map_idle_time = CreateConVar("sm_irm_idle_time","5","Time limit to change map", FCVAR_PLUGIN);
      	g_players_change = CreateConVar("sm_irm_players_change","0","How many players on server to start map change timer", FCVAR_PLUGIN);
	g_log_map_change = CreateConVar("sm_irm_log_map_change","0","Log map selection", FCVAR_PLUGIN);
	AutoExecConfig(true, "idle_random_map");
}

public OnMapStart()
{
	ServerCommand("sv_hibernate_when_empty 0");
	g_timer = INVALID_HANDLE;
}

public OnConfigsExecuted()
{
	g_MapsArray = CreateArray(255);
	ReadMaps();
	SetNextmap();
	
	PrintToServer("Idle Random Map: %s.", g_map);

	if(GetConVarInt(g_log_map_change))
		LogMessage("Idle Random Map: %s.", g_map);
	if(g_timer == INVALID_HANDLE)
	{
		g_timer = CreateTimer(GetConVarFloat(g_map_idle_time)*60, mapChange); //Start checking
		g_changeMap = true;
	}
}

public OnClientPutInServer(client)
{
	if(GetRealClientCount(true) > GetConVarInt(g_players_change))
	{
		if(g_timer != INVALID_HANDLE)
		{
			KillTimer(g_timer); 
      			g_timer = INVALID_HANDLE; //Stop checking
			g_changeMap = false;
		}
	}
}

public OnClientDisconnect_Post(client)
{
	if(GetRealClientCount(true) <= GetConVarInt(g_players_change))
	{
		if(g_timer == INVALID_HANDLE)
		{
			g_timer = CreateTimer(GetConVarFloat(g_map_idle_time)*60, mapChange); //Start checking
			g_changeMap = true;
		}
	}
}

public OnMapEnd()
{
	g_timer = INVALID_HANDLE;
}

public Action:mapChange(Handle:Timer)
{
	if(IsMapValid(g_map) && g_changeMap) 
	{
		ServerCommand("changelevel %s", g_map);
	}
	if(!IsMapValid(g_map))
	{
		ParseError("Invalid map: %s", g_map);
	}
        
	return Plugin_Handled;
}

// Load maps from ini file
public ReadMaps()
{
	BuildPath(Path_SM, g_Filename, sizeof(g_Filename), "configs/idle_random_map.ini");
	
	File file = OpenFile(g_Filename, "rt");
	if (!file)
	{
		ParseError("Could not open file!");
		return;
	}
	
	while (!file.EndOfFile())
	{
		char line[255];
		if (!file.ReadLine(line, sizeof(line)))
			break;
		
		/* Trim comments */
		int len = strlen(line);
		bool ignoring = false;
		for (int i=0; i<len; i++)
		{
			if (ignoring)
			{
				if (line[i] == '"')
					ignoring = false;
			} 
			else 
			{
				if (line[i] == '"')
				{
					ignoring = true;
				} 
				else if (line[i] == ';') 
				{
					line[i] = '\0';
					break;
				} 
				else if (line[i] == '/' && i != len - 1 && line[i+1] == '/')
				{
					line[i] = '\0';
					break;
				}
			}
		}
		
		TrimString(line);
		
		if ((line[0] == '/' && line[1] == '/') || (line[0] == ';' || line[0] == '\0'))
		{
			continue;
		}

		PushArrayString(g_MapsArray, line); //Add maps to the array
	}
	
	file.Close();
}

// Pick the next map
public SetNextmap()
{
	int numberOfMaps = GetArraySize(g_MapsArray);
	int rand = GetRandomInt(0,numberOfMaps-1);

    	for(int i=0; i < numberOfMaps; i++)
    	{
		if(i == rand)
		{
        		GetArrayString(g_MapsArray, i, g_map, 255); //Set the map
		}
   	}

}
	
stock GetRealClientCount( bool:inGameOnly = true ) 
{
	new clients = 0;
	for( new i = 1; i <= GetMaxClients(); i++ ) 
	{
		if( ( ( inGameOnly ) ? IsClientInGame( i ) : IsClientConnected( i ) ) && !IsFakeClient( i ) ) 
		{
			clients++;
		}
	}
	return clients;
}

ParseError(const String:format[], any:...)
{
	decl String:buffer[512];
	
	if (!g_LoggedFileName)
	{
		LogError("Error(s) detected parsing %s", g_Filename);
		g_LoggedFileName = true;
	}
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
	LogError(" (line %d) %s", g_CurrentLine, buffer);
	
	g_ErrorCount++;
}
