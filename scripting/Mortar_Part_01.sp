// 1. Count = Num Of strikes
// 2. RadiusX = Choosen Radius
// 3. SavePos = Position where it was called.
// 3.1. I'm using my stock -> GetLookPos(client,Position);
// Pos[2] += 500.0; // Increasing height...

for(new i = 0;i < Count;i++)
{
new Float:SavePos[3];
SavePos[0] = Pos[0]; 
SavePos[0] += GetRandomFloat(-RadiusX,RadiusX);
SavePos[1] = Pos[1]; 
SavePos[1] += GetRandomFloat(-RadiusX,RadiusX);
SavePos[2] = Pos[2]; 
TR_TraceRayFilter(SavePos, Float:{90.0, 0.0, 0.0}, MASK_SOLID, RayType_Infinite, Filter);
TR_GetEndPosition(ShootPos[i]); // capture floor coords
if(SavePos[2] != ShootPos[i][2]) // If It doesnt stuck in textures -> continue.
{
CreateMotarWarning(i);
}
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


//check m_WorldMins & m_WorldMax 3-rd value
