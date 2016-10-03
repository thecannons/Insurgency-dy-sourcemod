#include <sourcemod>
#include <sdktools>
//#include <>

public OnPluginStart()
{
	RegAdminCmd("sm_pt",parttest,ADMFLAG_ROOT);
}
public OnMapStart()
{
	AddFileToDownloadsTable("particles/iextest.pcf"); // Download to client,or it will not work
	PrecacheGeneric("particles/iextest.pcf",true); //Precache Any pcf(particle file)
}

public Action:parttest(client, args)
{
//decl String:info[100];
//GetCmdArg(1, info, 100);
PrintToChatAll("Run");
new iExp = CreateEntityByName("info_particle_system");//Call custom particle
DispatchKeyValue(iExp, "start_active", "1");
DispatchKeyValue(iExp, "effect_name", "iEx_Test"); //info = String of name of an effect.
DispatchSpawn(iExp);
PrintToChatAll("Spawn:%d",iExp);
new Float:Pos[3];
GetLookPos(client,Pos);
PrintToChatAll("Pos:%f %f %f",Pos[0],Pos[1],Pos[2]);
TeleportEntity(iExp, Pos, NULL_VECTOR,NULL_VECTOR);
ActivateEntity(iExp);
return Plugin_Handled;
}

public bool:GetLookPos_Filter(ent, mask, any:client) return client != ent;
GetLookPos(client, Float:pos[3])
{ 
decl Float:EyePosition[3], Float:EyeAngles[3], Handle:h_trace; 
GetClientEyePosition(client, EyePosition); 
GetClientEyeAngles(client, EyeAngles); 
h_trace = TR_TraceRayFilterEx(EyePosition, EyeAngles, MASK_SOLID, RayType_Infinite, GetLookPos_Filter, client); 
TR_GetEndPosition(pos, h_trace); 
CloseHandle(h_trace); 
}