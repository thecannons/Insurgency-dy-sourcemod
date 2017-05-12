

int m_iTeam = GetClientTeam(client);
int m_iTeamNum;
float vecSpawn[3];
float vecOrigin[3];
new distance;
GetClientAbsOrigin(client,vecOrigin);
new Float:fRandomFloat = GetRandomFloat(0, 1.0);

// Get the number of control points
new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");

// Get active push point
new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
if ((Ins_InCounterAttack())
	m_nActivePushPointIndex--;
new point = FindEntityByClassname(-1, "ins_spawnpoint");
new Float:tObjectiveDistance = 600;
while (point != -1) {
		GetEntPropVector(point, Prop_Send, "m_vecOrigin", vecSpawn);
		Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
		distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
		if (CheckSpawnPoint_PlayerRespawn(vecSpawn,client,tObjectiveDistance,m_nActivePushPointIndex)) {
			vecSpawn = GetInsSpawnGround(point, vecSpawn);
			//PrintToServer("FOUND! m_nActivePushPointIndex: %d %N (%d) spawnpoint %d Distance: %f tObjectiveDistance: %f g_flMaxObjectiveDistance %f RAW ACP: %d",m_nActivePushPointIndex, client, client, point, distance, tObjectiveDistance, g_flMaxObjectiveDistance, acp);
			//return vecSpawn;
		}
		else
		{
			tObjectiveDistance += 4.0;
		}

	point = FindEntityByClassname(point, "ins_spawnpoint");
}













CheckSpawnPoint_PlayerRespawn(Float:vecSpawn[3],client,Float:tObjectiveDistance,Int:m_nActivePushPointIndex) {
//Ins_InCounterAttack
	new m_iTeam = GetClientTeam(client);
	new Float:distance,Float:furthest,Float:closest=-1.0;
	new Float:vecOrigin[3];
	GetClientAbsOrigin(client,vecOrigin);
	new Float:tMinPlayerDistMult = 0;

	//Lets go through checks to find a valid spawn point
	for (new iTarget = 1; iTarget < MaxClients; iTarget++) {
		if (!IsValidClient(iTarget))
			continue;
		if (!IsClientInGame(iTarget))
			continue;
		if (!IsPlayerAlive(iTarget)) 
			continue;
		new tTeam = GetClientTeam(iTarget);
		if (tTeam != TEAM_2)
			continue;

		distance = GetVectorDistance(vecSpawn,g_vecOrigin[iTarget]);
		if (distance > furthest)
			furthest = distance;
		if ((distance < closest) || (closest < 0))
			closest = distance;
		
		if (GetClientTeam(iTarget) != m_iTeam) {
			// If we are too close
			if (distance < (g_flMinPlayerDistance + 400)) {
				 return 0;
			}
			// If the bot can see the spawn point (divided CanSeeVector to slightly reduce strictness)
			if (ClientCanSeeVector(iTarget, vecSpawn, (g_flMinPlayerDistance * g_flCanSeeVectorMultiplier))) {
				return 0; 
			}
		}
	}
	//If any player is too far
	if (closest > g_flMaxPlayerDistance) {
		return 0; 
	}
	
	 	

	Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
	distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
	if (distance > (tObjectiveDistance)) {// && (fRandomFloat <= g_dynamicSpawn_Perc)) {
		 return 0;
	} 
	else if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult)) {
		 return 0;
	}
	PrintToServer("CHECKSPAWN | m_nActivePushPointIndex: %d",m_nActivePushPointIndex);
	return 1;
} 