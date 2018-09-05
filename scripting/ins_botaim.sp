#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Bot Aim",
    description = "Make bot use aimbot",
    author = "Circleus ([INS] Coop Server)",
    version = "1.0.0",
	url = "http://insurgency.pro/"
};

ConVar cvarBotAimPercentage;
ConVar cvarBotFirePercentage;

float fBotAimPercentage;
float fBotFirePercentage;

public OnPluginStart() 
{
	cvarBotAimPercentage = CreateConVar("ins_botaim", "0.01", "The amount of percentage bot will use aimbot at players. Bot will try to land headshot on every shot. Bot will trigger surpression. They will fire at players until they run out of ammo. When they reload, they will continue shooting at players. As long as they see just a bit of player model, it will trigger this aimbot.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvarBotFirePercentage = CreateConVar("ins_botweaponfire", "0.1", "The amount of percentage bot will trigger weapon fire with the current weapon/grenade in their hand while looking at player. (This do not affect the botaim suppression.)", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	cvarBotAimPercentage.AddChangeHook(OnCvarChange);
	cvarBotFirePercentage.AddChangeHook(OnCvarChange);
	
	AutoExecConfig(true,"ins.botaim");
}

public void OnCvarChange(ConVar convar, char[] oldValue, char[] newValue) 
{
	if(convar == cvarBotAimPercentage)
	{
		fBotAimPercentage = GetConVarFloat(cvarBotAimPercentage);
	}
	else if(convar == cvarBotFirePercentage)
	{
		fBotFirePercentage = GetConVarFloat(cvarBotFirePercentage);
	}
}

public OnMapStart()
{
	fBotAimPercentage = GetConVarFloat(cvarBotAimPercentage);
	fBotFirePercentage = GetConVarFloat(cvarBotFirePercentage);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &nSubType, &nCmdNum, &nTickCount, &nSeed)  
{
	if(IsFakeClient(client) && IsPlayerAlive(client))
	{
		//Get where target view
		int nTargetView = GetClientViewClient(client);
		//Get where target aim
		int nTargetAim = GetClientAimTarget(client, true);
		
		//Get RNG float
		float fBotAimRandom = GetRandomFloat(0.0, 1.0);
		float fBotFireRandom = GetRandomFloat(0.0, 1.0);
		//PrintToChatAll("fBotAimRandom %f, fBotFireRandom %f", fBotAimRandom, fBotFireRandom);
		//Trigger aimbot base on percentage of float
		//if((fBotAimRandom < fBotAimPercentage))
		//{
		//	//Get the current weapon in hand
		//	int nActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		//	//Get the current weapon in hand ammo amount
		//	int nClipAmmo = GetEntProp(nActiveWeapon, Prop_Send, "m_iClip1");
			
		//	//Get the closest target
		//	int nTarget = GetClosestClient(client);
			
		//	//If ammo is more than 0 and target is found
		//	if((nClipAmmo > 0) && (nTarget > 0))
		//	{
		//		//Force bot to look at target
		//		LookAtClient(client, nTarget);
		//		//Trigger fire
		//		buttons |= IN_ATTACK;
		//		return Plugin_Changed;  
		//	}
		//}
		//Get the current weapon in hand
		int nActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		//Get the current weapon in hand ammo amount
		int nClipAmmo = GetEntProp(nActiveWeapon, Prop_Send, "m_iClip1");
		
		//Get the closest target
		int nTarget = GetClosestClient(client);
		
		//Bot trigger fire if target is in bot crosshair
		if((nClipAmmo > 0) && (nTarget > 0) && (nTargetView == nTargetAim) && (GetClientTeam(client) != GetClientTeam(nTargetAim)) && (fBotFireRandom < fBotFirePercentage))
		{
			//Force bot to look at target
			LookAtClient(client, nTarget);
			//Trigger fire
			buttons |= IN_ATTACK; 
			return Plugin_Changed;  
		}
	}
	
	return Plugin_Continue;
}

stock void LookAtClient(int iClient, int iTarget)
{
	float fTargetPos[3]; float fTargetAngles[3]; float fClientPos[3]; float fFinalPos[3];
	
	//Calculate if bot gets near perfect shot.
	float fBotPerfectShot = GetRandomFloat(0.0, 1.0);

	//Get client eye position
	GetClientEyePosition(iClient, fClientPos);
	//Get target eye position
	GetClientEyePosition(iTarget, fTargetPos);
	//Get target eye angles
	GetClientEyeAngles(iTarget, fTargetAngles);
	
	float fVecFinal[3];
	AddInFrontOf(fTargetPos, fTargetAngles, 0.0, fVecFinal);
	MakeVectorFromPoints(fClientPos, fVecFinal, fFinalPos);
	
	float fbotOffsetX = GetRandomFloat(-20.0, 20.0);
	float fbotOffsetY = GetRandomFloat(-20.0, 20.0);
	float fbotOffsetZ = GetRandomFloat(-20.0, 20.0);
	fFinalPos[0] = fFinalPos[0] + fbotOffsetX;
	fFinalPos[1] = fFinalPos[1] + fbotOffsetY;
	fFinalPos[2] = fFinalPos[2] + fbotOffsetZ;
	GetVectorAngles(fFinalPos, fFinalPos);
	//Teleport the entity to make them look at the target
	TeleportEntity(iClient, NULL_VECTOR, fFinalPos, NULL_VECTOR);
}

stock void AddInFrontOf(float fVecOrigin[3], float fVecAngle[3], float fUnits, float fOutPut[3])
{
	float fVecView[3];
	
	//Get the headshot vector
	GetHeadshotViewVector(fVecAngle, fVecView);
	
	fOutPut[0] = fVecView[0] * fUnits + fVecOrigin[0];
	fOutPut[1] = fVecView[1] * fUnits + fVecOrigin[1];
	fOutPut[2] = fVecView[2] * fUnits + fVecOrigin[2];
}

stock void GetHeadshotViewVector(float fVecAngle[3], float fOutPut[3])
{
	//Change the vector angles to make them look at the target head regardless the distance
	fOutPut[0] = Cosine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[1] = Sine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[2] = -Sine(fVecAngle[0] / (180 / FLOAT_PI));
}

stock int GetClosestClient(int iClient)
{
	float fClientOrigin[3], fTargetOrigin[3];
	
	//Get client position
	GetClientAbsOrigin(iClient, fClientOrigin);
	
	int iClientTeam = GetClientTeam(iClient);
	int iClosestTarget = -1;
	
	float fClosestDistance = -1.0;
	float fTargetDistance;
	
	//Loop all client to get the target
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			//If client is not alive or it on the same team then skip this target
			if (iClient == i || GetClientTeam(i) == iClientTeam || !IsPlayerAlive(i))
			{
				continue;
			}
			
			//Get target position
			GetClientAbsOrigin(i, fTargetOrigin);
			//Get the distance between client and the target
			fTargetDistance = GetVectorDistance(fClientOrigin, fTargetOrigin);

			//Skip the target if the target distance is more far than the closest distance
			if (fTargetDistance > fClosestDistance && fClosestDistance > -1.0)
			{
				continue;
			}

			//If client can't see this target then skip this target
			if (!ClientCanSeeTarget(iClient, i))
			{
				continue;
			}
			
			//If target distance is less than 70 then skip this target
			if (fTargetDistance < 70)
			{
				continue;
			}
			
			//Set the closest distance
			fClosestDistance = fTargetDistance;
			//Set the clostest target
			iClosestTarget = i;
		}
	}
	
	return iClosestTarget;
}

stock bool ClientCanSeeTarget(int iClient, int iTarget, float fDistance = 0.0, float fHeight = 50.0)
{
	float fClientPosition[3]; float fTargetPosition[3];
	
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", fClientPosition);
	//Increase the height slightly
	fClientPosition[2] += fHeight;

	GetClientEyePosition(iTarget, fTargetPosition);
	
	if (fDistance == 0.0 || GetVectorDistance(fClientPosition, fTargetPosition, false) < fDistance)
	{
		Handle hTrace = TR_TraceRayFilterEx(fClientPosition, fTargetPosition, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter);
		
		if (TR_DidHit(hTrace))
		{
			delete hTrace;
			return false;
		}
		
		delete hTrace;
		return true;
	}
	
	return false;
}

public bool Base_TraceFilter(int iEntity, int iContentsMask, int iData)
{
	return iEntity == iData;
}

stock int GetClientViewClient(int client) {
	float m_vecOrigin[3];
	float m_angRotation[3];
	
	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);
	
	Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TraceEntityFilter:FilterOutPlayer, client);
	int pEntity = -1;
	
	if (TR_DidHit(tr))
	{
		//Use TraceRay to get the entity(target) where client looking at
		pEntity = TR_GetEntityIndex(tr);
		delete tr;
		
		if (!IsValidClient(client))
			return -1;
		
		if (!IsValidEntity(pEntity))
			return -1;
		
		return pEntity;
	}
	delete tr;
	return -1;
}

public bool:FilterOutPlayer(entity, contentsMask, any:data)
{
    if (entity == data)
    {
        return false;
    }
    
    return true;
}

bool:IsValidClient(client) 
{
	if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
		return false; 
	
	return true; 
}  