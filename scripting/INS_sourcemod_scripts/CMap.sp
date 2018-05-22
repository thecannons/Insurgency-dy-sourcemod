#include <sourcemod>
#include <sdktools>

#define PLUGIN_DESCRIPTION "Change insurgency map"
#define PLUGIN_NAME "[INS] CMap"
#define PLUGIN_VERSION "1.0.2"
#define PLUGIN_AUTHOR "Neko-"
#define PLUGIN_PREFIX "[CMap]"

public Plugin:myinfo = {
        name            = PLUGIN_NAME,
        author          = PLUGIN_AUTHOR,
        description     = PLUGIN_DESCRIPTION,
        version         = PLUGIN_VERSION,
};

public OnPluginStart() 
{
    //Admin with flag 'b' will able to use this command
    RegAdminCmd("sm_cmap", ChangeMap, ADMFLAG_GENERIC, "Change map");
    RegAdminCmd("sm_changemap", ChangeMap, ADMFLAG_GENERIC, "Change map");
}

public Action:ChangeMap(client, args) 
{
    decl String:strMapName[64];
    decl String:strMapType[16];
    decl String:szServerRet[1024];

    if(args != 2)
    {
        PrintToChat(client, "%s cmap <map name> <gamemode>", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    GetCmdArg(1, strMapName, sizeof(strMapName));
    GetCmdArg(2, strMapType, sizeof(strMapType));

    ServerCommandEx(szServerRet, sizeof(szServerRet), "map %s %s", strMapName, strMapType);
    PrintToConsole(client, "%s", szServerRet);
    
    if((szServerRet[0] != EOS) && StrContains(szServerRet, "failed", true))
    {
        PrintToChat(client, "%s Invalid Map!", PLUGIN_PREFIX);
    }
    else
    {
        PrintToChat(client, "%s Changing map...", PLUGIN_PREFIX);
    }

    return Plugin_Handled;
}