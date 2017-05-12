new Float:EntityPos[3]; 
GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", EntityPos); 
new target = FindNearestPlayer(entity); 
if(target != -1) 
{ 
    new Float:TargetPos[3]; 
    GetClientAbsOrigin(target, TargetPos); 
    new iClosestAreaIndex = 0; 
    new bool:bBuiltPath = NavMesh_BuildPath(NavMesh_GetNearestArea(EntityPos), NavMesh_GetNearestArea(TargetPos), TargetPos, NavMeshShortestPathCost, _, iClosestAreaIndex, 0.0); 
    if(bBuiltPath) 
    { 
        new iTempAreaIndex = iClosestAreaIndex; 
        new iParentAreaIndex = NavMeshArea_GetParent(iTempAreaIndex); 
        new iNavDirection; 
        new Float:flHalfWidth; 
        new Float:flCenterPortal[3]; 
        new Float:flClosestPoint[3]; 
        hPositions[entity] = CreateArray(3); 
        PushArrayArray(hPositions[entity], TargetPos, 3); 
        while(iParentAreaIndex != -1) 
        { 
            new Float:flTempAreaCenter[3]; 
            new Float:flParentAreaCenter[3]; 
            NavMeshArea_GetCenter(iTempAreaIndex, flTempAreaCenter); 
            NavMeshArea_GetCenter(iParentAreaIndex, flParentAreaCenter); 
            iNavDirection = NavMeshArea_ComputeDirection(iTempAreaIndex, flParentAreaCenter); 
            NavMeshArea_ComputePortal(iTempAreaIndex, iParentAreaIndex, iNavDirection, flCenterPortal, flHalfWidth); 
            NavMeshArea_ComputeClosestPointInPortal(iTempAreaIndex, iParentAreaIndex, iNavDirection, flCenterPortal, flClosestPoint); 
            flClosestPoint[2] = NavMeshArea_GetZ(iTempAreaIndex, flClosestPoint); 
            PushArrayArray(hPositions[entity], flClosestPoint, 3); 
            iTempAreaIndex = iParentAreaIndex; 
            iParentAreaIndex = NavMeshArea_GetParent(iTempAreaIndex); 
        } 
        PushArrayArray(hPositions[entity], EntityPos, 3); 
        new Float:flFromPos[3]; 
        GetArrayArray(hPositions[entity], GetArraySize(hPositions[entity])-2, flFromPos, 3); 
        decl Float:vecDistance[3]; 
        for (new j = 0; j < 3; j++) 
        { 
            vecDistance[j] = flFromPos[j] - EntityPos[j]; 
        } 
        new Float:angles[3]; 
        GetVectorAngles(vecDistance, angles); 
        NormalizeVector(vecDistance, vecDistance); 
        ScaleVector(vecDistance, 1000.0 * GetTickInterval()); 
        AddVectors(vecDistance, EntityPos, vecDistance); 
        angles[0] = 0.0; 
        TeleportEntity(entity, vecDistance, angles, NULL_VECTOR); 
        for(new i = GetArraySize(hPositions[entity]) - 1; i > 0; i--) 
        { 
            decl Float:flFromPos2[3], Float:flToPos[3]; 
            GetArrayArray(hPositions[entity], i, flFromPos2, 3); 
            GetArrayArray(hPositions[entity], i - 1, flToPos, 3); 
            new laser = PrecacheModel("materials/sprites/laserbeam.vmt"); 

            //Maybe get distance flFromPos2 to flToPos then ++ to a max distance to verify distance of path?
            TE_SetupBeamPoints(flFromPos2, flToPos, laser, laser, 0, 30, 0.1, 5.0, 5.0, 5, 0.0, {0, 255, 0, 255}, 30); 
            TE_SendToAll(); 
        } 
    } 
}  