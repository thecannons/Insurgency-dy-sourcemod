public PlVers:__version =
{
	version = 5,
	filevers = "1.10.0.6270",
	date = "07/23/2018",
	time = "14:18:27"
};
new Float:NULL_VECTOR[3];
new String:NULL_STRING[4];
public Extension:__ext_core =
{
	name = "Core",
	file = "core",
	autoload = 0,
	required = 0,
};
new MaxClients;
public Extension:__ext_sdktools =
{
	name = "SDKTools",
	file = "sdktools.ext",
	autoload = 1,
	required = 1,
};
public Extension:__ext_sdkhooks =
{
	name = "SDKHooks",
	file = "sdkhooks.ext",
	autoload = 1,
	required = 1,
};
public Plugin:myinfo =
{
	name = "[INS] Bot Aim",
	description = "Make bot use aimbot",
	author = "Circleus ([INS] Coop Server)",
	version = "1.0.0",
	url = "http://insurgency.pro/"
};
new Handle:cvarBotAimPercentage;
new Handle:cvarBotFirePercentage;
new Float:fBotAimPercentage;
new Float:fBotFirePercentage;
public void:__ext_core_SetNTVOptional()
{
	MarkNativeAsOptional("GetFeatureStatus");
	MarkNativeAsOptional("RequireFeature");
	MarkNativeAsOptional("AddCommandListener");
	MarkNativeAsOptional("RemoveCommandListener");
	MarkNativeAsOptional("BfWriteBool");
	MarkNativeAsOptional("BfWriteByte");
	MarkNativeAsOptional("BfWriteChar");
	MarkNativeAsOptional("BfWriteShort");
	MarkNativeAsOptional("BfWriteWord");
	MarkNativeAsOptional("BfWriteNum");
	MarkNativeAsOptional("BfWriteFloat");
	MarkNativeAsOptional("BfWriteString");
	MarkNativeAsOptional("BfWriteEntity");
	MarkNativeAsOptional("BfWriteAngle");
	MarkNativeAsOptional("BfWriteCoord");
	MarkNativeAsOptional("BfWriteVecCoord");
	MarkNativeAsOptional("BfWriteVecNormal");
	MarkNativeAsOptional("BfWriteAngles");
	MarkNativeAsOptional("BfReadBool");
	MarkNativeAsOptional("BfReadByte");
	MarkNativeAsOptional("BfReadChar");
	MarkNativeAsOptional("BfReadShort");
	MarkNativeAsOptional("BfReadWord");
	MarkNativeAsOptional("BfReadNum");
	MarkNativeAsOptional("BfReadFloat");
	MarkNativeAsOptional("BfReadString");
	MarkNativeAsOptional("BfReadEntity");
	MarkNativeAsOptional("BfReadAngle");
	MarkNativeAsOptional("BfReadCoord");
	MarkNativeAsOptional("BfReadVecCoord");
	MarkNativeAsOptional("BfReadVecNormal");
	MarkNativeAsOptional("BfReadAngles");
	MarkNativeAsOptional("BfGetNumBytesLeft");
	MarkNativeAsOptional("BfWrite.WriteBool");
	MarkNativeAsOptional("BfWrite.WriteByte");
	MarkNativeAsOptional("BfWrite.WriteChar");
	MarkNativeAsOptional("BfWrite.WriteShort");
	MarkNativeAsOptional("BfWrite.WriteWord");
	MarkNativeAsOptional("BfWrite.WriteNum");
	MarkNativeAsOptional("BfWrite.WriteFloat");
	MarkNativeAsOptional("BfWrite.WriteString");
	MarkNativeAsOptional("BfWrite.WriteEntity");
	MarkNativeAsOptional("BfWrite.WriteAngle");
	MarkNativeAsOptional("BfWrite.WriteCoord");
	MarkNativeAsOptional("BfWrite.WriteVecCoord");
	MarkNativeAsOptional("BfWrite.WriteVecNormal");
	MarkNativeAsOptional("BfWrite.WriteAngles");
	MarkNativeAsOptional("BfRead.ReadBool");
	MarkNativeAsOptional("BfRead.ReadByte");
	MarkNativeAsOptional("BfRead.ReadChar");
	MarkNativeAsOptional("BfRead.ReadShort");
	MarkNativeAsOptional("BfRead.ReadWord");
	MarkNativeAsOptional("BfRead.ReadNum");
	MarkNativeAsOptional("BfRead.ReadFloat");
	MarkNativeAsOptional("BfRead.ReadString");
	MarkNativeAsOptional("BfRead.ReadEntity");
	MarkNativeAsOptional("BfRead.ReadAngle");
	MarkNativeAsOptional("BfRead.ReadCoord");
	MarkNativeAsOptional("BfRead.ReadVecCoord");
	MarkNativeAsOptional("BfRead.ReadVecNormal");
	MarkNativeAsOptional("BfRead.ReadAngles");
	MarkNativeAsOptional("BfRead.GetNumBytesLeft");
	MarkNativeAsOptional("PbReadInt");
	MarkNativeAsOptional("PbReadFloat");
	MarkNativeAsOptional("PbReadBool");
	MarkNativeAsOptional("PbReadString");
	MarkNativeAsOptional("PbReadColor");
	MarkNativeAsOptional("PbReadAngle");
	MarkNativeAsOptional("PbReadVector");
	MarkNativeAsOptional("PbReadVector2D");
	MarkNativeAsOptional("PbGetRepeatedFieldCount");
	MarkNativeAsOptional("PbSetInt");
	MarkNativeAsOptional("PbSetFloat");
	MarkNativeAsOptional("PbSetBool");
	MarkNativeAsOptional("PbSetString");
	MarkNativeAsOptional("PbSetColor");
	MarkNativeAsOptional("PbSetAngle");
	MarkNativeAsOptional("PbSetVector");
	MarkNativeAsOptional("PbSetVector2D");
	MarkNativeAsOptional("PbAddInt");
	MarkNativeAsOptional("PbAddFloat");
	MarkNativeAsOptional("PbAddBool");
	MarkNativeAsOptional("PbAddString");
	MarkNativeAsOptional("PbAddColor");
	MarkNativeAsOptional("PbAddAngle");
	MarkNativeAsOptional("PbAddVector");
	MarkNativeAsOptional("PbAddVector2D");
	MarkNativeAsOptional("PbRemoveRepeatedFieldValue");
	MarkNativeAsOptional("PbReadMessage");
	MarkNativeAsOptional("PbReadRepeatedMessage");
	MarkNativeAsOptional("PbAddMessage");
	MarkNativeAsOptional("Protobuf.ReadInt");
	MarkNativeAsOptional("Protobuf.ReadFloat");
	MarkNativeAsOptional("Protobuf.ReadBool");
	MarkNativeAsOptional("Protobuf.ReadString");
	MarkNativeAsOptional("Protobuf.ReadColor");
	MarkNativeAsOptional("Protobuf.ReadAngle");
	MarkNativeAsOptional("Protobuf.ReadVector");
	MarkNativeAsOptional("Protobuf.ReadVector2D");
	MarkNativeAsOptional("Protobuf.GetRepeatedFieldCount");
	MarkNativeAsOptional("Protobuf.SetInt");
	MarkNativeAsOptional("Protobuf.SetFloat");
	MarkNativeAsOptional("Protobuf.SetBool");
	MarkNativeAsOptional("Protobuf.SetString");
	MarkNativeAsOptional("Protobuf.SetColor");
	MarkNativeAsOptional("Protobuf.SetAngle");
	MarkNativeAsOptional("Protobuf.SetVector");
	MarkNativeAsOptional("Protobuf.SetVector2D");
	MarkNativeAsOptional("Protobuf.AddInt");
	MarkNativeAsOptional("Protobuf.AddFloat");
	MarkNativeAsOptional("Protobuf.AddBool");
	MarkNativeAsOptional("Protobuf.AddString");
	MarkNativeAsOptional("Protobuf.AddColor");
	MarkNativeAsOptional("Protobuf.AddAngle");
	MarkNativeAsOptional("Protobuf.AddVector");
	MarkNativeAsOptional("Protobuf.AddVector2D");
	MarkNativeAsOptional("Protobuf.RemoveRepeatedFieldValue");
	MarkNativeAsOptional("Protobuf.ReadMessage");
	MarkNativeAsOptional("Protobuf.ReadRepeatedMessage");
	MarkNativeAsOptional("Protobuf.AddMessage");
	VerifyCoreVersion();
	return void:0;
}

.2920.-40000005(Float:oper)
{
	return oper ^ -2147483648;
}

.2920.-40000005(Float:oper)
{
	return oper ^ -2147483648;
}

.2956.0/40000005(oper1, Float:oper2)
{
	return float(oper1) / oper2;
}

.2956.0/40000005(oper1, Float:oper2)
{
	return float(oper1) / oper2;
}

.3012.40000005<0(Float:oper1, oper2)
{
	return oper1 < float(oper2);
}

.3012.40000005<0(Float:oper1, oper2)
{
	return oper1 < float(oper2);
}

void:MakeVectorFromPoints(Float:pt1[3], Float:pt2[3], Float:output[3])
{
	output[0] = pt2[0] - pt1[0];
	output[1] = pt2[1] - pt1[1];
	output[2] = pt2[2] - pt1[2];
	return void:0;
}

public void:OnPluginStart()
{
	cvarBotAimPercentage = CreateConVar("ins_botaim", "1.0", "The amount of percentage bot will use aimbot at players. Bot will try to land headshot on every shot. Bot will trigger surpression. They will fire at players until they run out of ammo. When they reload, they will continue shooting at players. As long as they see just a bit of player model, it will trigger this aimbot.", 32, true, 0.0, true, 1.0);
	cvarBotFirePercentage = CreateConVar("ins_botweaponfire", "1.0", "The amount of percentage bot will trigger weapon fire with the current weapon/grenade in their hand while looking at player. (This do not affect the botaim suppression.)", 32, true, 0.0, true, 1.0);
	AutoExecConfig(true, "ins.botaim", "sourcemod");
	return void:0;
}

public void:OnMapStart()
{
	fBotAimPercentage = GetConVarFloat(cvarBotAimPercentage);
	fBotFirePercentage = GetConVarFloat(cvarBotFirePercentage);
	return void:0;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &nSubType, &nCmdNum, &nTickCount, &nSeed)
{
	new var1;
	if (IsFakeClient(client) && IsPlayerAlive(client))
	{
		new nTargetView = getClientViewClient(client);
		new nTargetAim = GetClientAimTarget(client, true);
		new Float:fBotAimRandom = GetRandomFloat(0.0, 1.0);
		new Float:fBotFireRandom = GetRandomFloat(0.0, 1.0);
		new bool:bAllowAim = 1;
		new var2;
		if (bAllowAim && fBotAimRandom <= fBotAimPercentage)
		{
			new nActiveWeapon = GetEntPropEnt(client, PropType:0, "m_hActiveWeapon", 0);
			new nClipAmmo = GetEntProp(nActiveWeapon, PropType:0, "m_iClip1", 4, 0);
			new nTarget = GetClosestClient(client);
			new var3;
			if (nClipAmmo > 0 && nTarget > 0)
			{
				LookAtClient(client, nTarget);
				buttons = buttons | 1;
				return Action:1;
			}
		}
		new var4;
		if (nTargetAim == nTargetView && GetClientTeam(nTargetAim) != GetClientTeam(client) && fBotFireRandom <= fBotFirePercentage)
		{
			buttons = buttons | 1;
			return Action:1;
		}
	}
	return Action:0;
}

void:LookAtClient(iClient, iTarget)
{
	new Float:fTargetPos[3] = 0.0;
	new Float:fTargetAngles[3] = 0.0;
	new Float:fClientPos[3] = 0.0;
	new Float:fFinalPos[3] = 0.0;
	GetClientEyePosition(iClient, fClientPos);
	GetClientEyePosition(iTarget, fTargetPos);
	GetClientEyeAngles(iTarget, fTargetAngles);
	new Float:fVecFinal[3] = 0.0;
	AddInFrontOf(fTargetPos, fTargetAngles, 0.0, fVecFinal);
	MakeVectorFromPoints(fClientPos, fVecFinal, fFinalPos);
	GetVectorAngles(fFinalPos, fFinalPos);
	TeleportEntity(iClient, NULL_VECTOR, fFinalPos, NULL_VECTOR);
	return void:0;
}

void:AddInFrontOf(Float:fVecOrigin[3], Float:fVecAngle[3], Float:fUnits, Float:fOutPut[3])
{
	new Float:fVecView[3] = 0.0;
	GetViewVector(fVecAngle, fVecView);
	fOutPut[0] = fVecView[0] * fUnits + fVecOrigin[0];
	fOutPut[1] = fVecView[1] * fUnits + fVecOrigin[1];
	fOutPut[2] = fVecView[2] * fUnits + fVecOrigin[2];
	return void:0;
}

void:GetViewVector(Float:fVecAngle[3], Float:fOutPut[3])
{
	fOutPut[0] = Cosine(fVecAngle[1] / .2956.0/40000005(180, 3.1415927));
	fOutPut[1] = Sine(fVecAngle[1] / .2956.0/40000005(180, 3.1415927));
	fOutPut[2] = .2920.-40000005(Sine(fVecAngle[0] / .2956.0/40000005(180, 3.1415927)));
	return void:0;
}

GetClosestClient(iClient)
{
	new Float:fClientOrigin[3] = 0.0;
	new Float:fTargetOrigin[3] = 0.0;
	GetClientAbsOrigin(iClient, fClientOrigin);
	new iClientTeam = GetClientTeam(iClient);
	new iClosestTarget = -1;
	new Float:fClosestDistance = -1.0;
	new Float:fTargetDistance = 0.0;
	new i = 1;
	while (i <= MaxClients)
	{
		if (IsValidClient(i))
		{
			new var1;
			if (!(i != iClient && iClientTeam != GetClientTeam(i) && !IsPlayerAlive(i)))
			{
				GetClientAbsOrigin(i, fTargetOrigin);
				fTargetDistance = GetVectorDistance(fClientOrigin, fTargetOrigin, false);
				new var2;
				if (!(fTargetDistance > fClosestDistance && fClosestDistance > -1.0))
				{
					if (ClientCanSeeTarget(iClient, i, 0.0, 50.0))
					{
						if (!(.3012.40000005<0(fTargetDistance, 70)))
						{
							fClosestDistance = fTargetDistance;
							iClosestTarget = i;
						}
						i++;
					}
					i++;
				}
				i++;
			}
			i++;
		}
		i++;
	}
	return iClosestTarget;
}

bool:ClientCanSeeTarget(iClient, iTarget, Float:fDistance, Float:fHeight)
{
	new Float:fClientPosition[3] = 0.0;
	new Float:fTargetPosition[3] = 0.0;
	GetEntPropVector(iClient, PropType:0, "m_vecOrigin", fClientPosition, 0);
	fClientPosition[2] += fHeight;
	GetClientEyePosition(iTarget, fTargetPosition);
	new var1;
	if (0.0 == fDistance || GetVectorDistance(fClientPosition, fTargetPosition, false) < fDistance)
	{
		new Handle:hTrace = TR_TraceRayFilterEx(fClientPosition, fTargetPosition, 16395, RayType:0, Base_TraceFilter, any:0);
		if (TR_DidHit(hTrace))
		{
			CloseHandle(hTrace);
			hTrace = MissingTAG:0;
			return false;
		}
		CloseHandle(hTrace);
		hTrace = MissingTAG:0;
		return true;
	}
	return false;
}

public bool:Base_TraceFilter(iEntity, iContentsMask, iData)
{
	return iData == iEntity;
}

getClientViewClient(client)
{
	new Float:m_vecOrigin[3] = 0.0;
	new Float:m_angRotation[3] = 0.0;
	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);
	new Handle:tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, 24705, RayType:1, FilterOutPlayer, client);
	new pEntity = -1;
	if (TR_DidHit(tr))
	{
		pEntity = TR_GetEntityIndex(tr);
		CloseHandle(tr);
		tr = MissingTAG:0;
		if (!IsValidClient(client))
		{
			return -1;
		}
		if (!IsValidEntity(pEntity))
		{
			return -1;
		}
		new Float:playerPos[3] = 0.0;
		new Float:entPos[3] = 0.0;
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(pEntity, PropType:1, "m_vecOrigin", entPos, 0);
		return pEntity;
	}
	CloseHandle(tr);
	tr = MissingTAG:0;
	return -1;
}

public bool:FilterOutPlayer(entity, contentsMask, any:data)
{
	if (data == entity)
	{
		return false;
	}
	return true;
}

bool:IsValidClient(client)
{
	new var1;
	if (!1 <= MaxClients >= client || !IsClientInGame(client))
	{
		return false;
	}
	return true;
}

