
new iAimTarget = GetClientAimTarget(client, false);
	if (iAimTarget > MaxClients) //Not a client?
	{
		if (iAimTarget > MaxClients && FindDataMapInfo(iAimTarget, "m_ModelName") != -1) //Verify if part of map data?
		{
			decl String:sWeapon[32];
			GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
			new String:sModelPath[128];
			GetEntPropString(iAimTarget, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));
			if (buttons & INS_USE &&  (StrContains(g_client_last_classstring[client], "engineer") > -1) && 
				((StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_wrench") > -1) ||
				(StrContains(sModelPath, "sandbagwall", true) != -1) || (StrContains(sModelPath, "sandbagwall", true) != -1) ))
			{
				new Float:vOrigin[3], Float:vTargetOrigin[3];
				GetEntPropVector(iAimTarget, Prop_Data, "m_vecAbsOrigin", vOrigin);
				GetClientAbsOrigin(client, vTargetOrigin);
				if (GetVectorDistance(vOrigin, vTargetOrigin) <= 80.0)
				{
					new iHp = GetEntProp(iAimTarget, Prop_Data, "m_iHealth");
					new iMaxHp = GetEntProp(iAimTarget, Prop_Data, "m_iMaxHealth");
					iHp += GetRandomInt(1, 5);
					new Float:fDirection[3];
					fDirection[0] = GetRandomFloat(-1.0, 1.0);
					fDirection[1] = GetRandomFloat(-1.0, 1.0);
					fDirection[2] = GetRandomFloat(-1.0, 1.0);
					new Float:vMaxs[3];
					GetEntPropVector(iAimTarget, Prop_Data, "m_vecMaxs", vMaxs);
					vOrigin[2] += vMaxs[2]/2;
					TE_SetupSparks(vOrigin, fDirection, 1, 1);
					TE_SendToAll();
					if (iHp < iMaxHp) PrintCenterText(client, "Repairing... [%d  /  %d]", iHp, iMaxHp);
					else
					{
						if (iHp > iMaxHp)
						{
							//LogToGame("%N is fixed barricade %d", client, iAimTarget);
							//SetEntPropFloat(iAimTarget, Prop_Data, "m_flLocalTime", 0.0);
							FakeClientCommand(client, "say Barricade Repaired!");
							iHp = iMaxHp;
							PrintCenterText(client, " ");
						}
					}
					//new iColor = RoundToNearest((float(iHp) / 2000.0) * 255.0);
					//SetEntityRenderColor(iAimTarget, iColor, iColor, iColor, 255);
					//decl iColors[4] = {255, 255, 255, 255};
					//iColors[1] = iColors[2] = iColor;
					//SetVariantColor(iColors);
					//AcceptEntityInput(iAimTarget, "SetGlowColor");
					SetEntProp(iAimTarget, Prop_Data, "m_iHealth", iHp);
					//DispatchKeyValue(iAimTarget, "targetname", "LuaCustomModel");
				
					//else PrintCenterText(client, "Press \"USE (F) with Knife\" to Repair  Barricade");		
				}
			}
		}
	}

				







//Simulate one second on a button spam command

if (GetClientButtons(client) & INS_USE && GetGameTime()-g_fPlayerLastChat[client] >= 1.0)
{
	CreateTimer(0.1, Timer_PlayerResupply, client, TIMER_FLAG_NO_MAPCHANGE);
	g_fPlayerLastChat[client] = GetGameTime();
}