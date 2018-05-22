#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = 
{
	name = "[INS] Drop Items",
	author = "Neko-",
	description = "Drop the weapon or item you are holding",
	version = "1.0.0",
}

new const String:BlacklistWeaponNames[][] =
{
	"weapon_kabar",
	"weapon_gurkha",
	"weapon_knife",
	"weapon_kukri",
	"weapon_katana"
}

public OnPluginStart()
{
	RegConsoleCmd("drop", Drop_Stuff, "Drop the item in your hand");
}

public Action:Drop_Stuff(client,args)
{
	new health = GetClientHealth(client);
	
	if (health > 0)
	{
		new CurrentUserWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (CurrentUserWeapon < 0) {
			return Plugin_Continue;
		}
		
		decl String:User_Weapon[32];
		GetEdictClassname(CurrentUserWeapon, User_Weapon, sizeof(User_Weapon));
		
		new AdminId:admin = GetUserAdmin(client);
		for (new count=0; count<5; count++)
		{
			//If player not admin, prevent user from dropping knife
			if (StrEqual(User_Weapon, BlacklistWeaponNames[count]) && (admin == INVALID_ADMIN_ID) && (GetAdminFlag(admin, Admin_Generic, Access_Effective) == false))
			{
				return Plugin_Continue;
			}
		}
		SDKHooks_DropWeapon(client, CurrentUserWeapon, NULL_VECTOR, NULL_VECTOR);
	}
	
	return Plugin_Handled;
}