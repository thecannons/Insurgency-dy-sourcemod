//Credit to Nick Gaulin
//you can manually hack entities to include the touch event triggers

public Action SDK_MineSpawn(int entity)
{
    SetEntProp(entity, Prop_Send, "m_usSolidFlags", GetEntProp(entity, Prop_Send, "m_usSolidFlags") | 0x0008);

    //SDKHook(entity, SDKHook_OnTakeDamage, SDK_MineTakeDamage);
    SetEntityMoveType(entity, MOVETYPE_NONE);

    int ref = EntIndexToEntRef(entity);

    CreateTimer(0.01, Timer_MineFix,   ref);
    CreateTimer(3.0,  Timer_MineTouch, ref);
}

//that's how i made mines in my socom mod

public OnEntityCreated(int entity, const char[] className)
{
    if(StrEqual(className, "mine_claymore"))
        SDKHook(entity, SDKHook_SpawnPost, SDK_ClaymoreSpawn);
    else if(StrEqual(className, "mine_pmn"))
        SDKHook(entity, SDKHook_SpawnPost, SDK_MineSpawn);
    else if(StrEqual(className, "grenade_m67")
         || StrEqual(className, "grenade_f1")
         || StrEqual(className, "grenade_m18")
         || StrEqual(className, "grenade_m84"))
        SDKHook(entity, SDKHook_SpawnPost, SDK_GrenadeSpawn);
} 

//you can use the global `OnEntityCreated()` forward to create the SDK hooks
//here is the timer delay

public Action Timer_MineTouch(Handle timer, any data)
{
    int entity = EntRefToEntIndex(data);

    if (entity == INVALID_ENT_REFERENCE)
        return;

    SDKHook(entity, SDKHook_Touch, SDK_MineTouch);
}

//and finally the trigger itself

public Action SDK_MineTouch(int entity, int client)
{
    int attacker = GetEntProp(entity, Prop_Send, "m_hOwnerEntity");

    // BOOM!
    SDKHooks_TakeDamage(entity, attacker, attacker, 100.0, 2);
}
/*
yea it was a PITA 
and in this case the explode input didn't work
the only way i could get the mine to properly show who killed the player was when shooting it, so that mine touch trigger actually makes it take damage from the player it manually stores in the owner entity
which then allows it to properly show the attacker, otherwise it never works 
oh and that's a good point, i forgot to include the grenade thrown event which is the only way to actually know who planted the mine, cause in this case they were considered grenades/c4  in how i set them up in the theater files
*/
public Action Event_GrenadeThrown(Handle event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int entity = GetEventInt(event, "entityid");

    char weaponName[32];

    GetEdictClassname(entity, weaponName, sizeof(weaponName));

    if (StrEqual(weaponName, "mine_claymore")
          || StrEqual(weaponName, "mine_pmn"))
    {
        // LOTS OF CODE REMOVED FOR READABILITY
        
        SetEntProp(entity, Prop_Send, "m_hOwnerEntity", client);
    }
}