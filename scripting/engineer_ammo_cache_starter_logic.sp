

int m_iTeam = GetClientTeam(client); //Or set this to TEAM_1
int m_iTeamNum;
new zone = FindEntityByClassname(-1, "ins_spawnzone");
while (zone != -1) {
	// Check to make sure it is the same team else no point
	m_iTeamNum = GetEntProp(zone, Prop_Send, "m_iTeamNum");
	if (m_iTeamNum == m_iTeam) {
		//This would determine our current attack point (a, b, c, d, e) as an integer and hopefully we can match this integer with current ins_spawnzone
		new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex"); 

		//Else we can try to grab the active spawn zone.. though I dont know if this is doing that and have never tested, I literally just found CINSSpawnZone in Netprops dump
		new m_ActiveSpawnZone = Ins_ObjectiveResource_GetProp("CINSSpawnZone"); 
		
		//Theres other GHETTO ways to determine spawn zone, such an objective is captured and players spawn, get nearest spawnzone where players spawn (unless players dont spawn)

		//Assuming we have spawnzone
		//Get entity Name, and TeamNumber
	}
}

//We have zone info!
zoneName;
zoneTeam;
//Create Brush entity ins_spawnzone with
//Teleport zone to newly created ammo bag and add further conditional code.