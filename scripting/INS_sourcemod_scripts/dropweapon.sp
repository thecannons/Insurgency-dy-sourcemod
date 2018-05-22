#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define PLUGIN_VERSION "1.0.4"

new const String:WeaponNames[][] =
{
	"weapon_ak74",    
	"weapon_akm",      
	"weapon_aks74u",  
	"weapon_fal",  
	"weapon_m14",
	"weapon_m16a4",
	"weapon_m18",
	"weapon_m1a1",
	"weapon_m249",
	"weapon_m40a1",
	"weapon_m4a1",
	"weapon_m590",
	"weapon_mini14",
	"weapon_mk18",
	"weapon_mosin",
	"weapon_mp40",
	"weapon_mp5",
	"weapon_rpk", 
	"weapon_sks",
	"weapon_toz",
	"weapon_l1a1",
	"weapon_sterling",
	"weapon_galil",
	"weapon_galil_sar",
	"weapon_ump45",
	"weapon_ae_mg42",
	"weapon_ae_dragunov",
	"weapon_ae_m1garand",
	"weapon_ae_pecheneg",
	"weapon_ae_m240",
	"weapon_ae_l118a1",
	"weapon_ae_m16a1",
	"weapon_ae_steyraug",
	"weapon_ae_scarl",
	"weapon_ae_type95",
	"weapon_ae_coltcommando",
	"weapon_ae_cm901",
	"weapon_ae_ak47",
	"weapon_ae_ak12u",
	"weapon_ae_acr",
	"weapon_ae_scar",
	"weapon_ae_g36c",
	"weapon_ae_famas",
	"weapon_ae_ks23",
	"weapon_ae_spas12",
	"weapon_ae_saiga12",
	"weapon_ae_pm9",
	"weapon_ae_mp5a4",
	"weapon_ae_krissvector",
	"weapon_ae_thompson",
	"weapon_ae_colt9mm", //0-50
	"weapon_m1911",  
	"weapon_m9",
	"weapon_m45",   
	"weapon_makarov",
	"weapon_model10",
	"weapon_riotshield",
	"weapon_ae_waltherp99",
	"weapon_ae_beretta93r",
	"weapon_ae_usp",
	"weapon_ae_deagle",
	"weapon_ae_glock18",
	"weapon_ae_glock19",
	"weapon_ae_uzi", //51-63
};

new const String:BlacklistWeaponNames[][] =
{
	"weapon_kabar",
	"weapon_gurkha",
	"weapon_knife",
	"weapon_kukri",
	"weapon_katana",
	"grenade_gas"
};

new g_iPlayerEquipGear;

public Plugin:myinfo = 
{
	name = "[INS] Wound Arm",
	author = "Neko-",
	description = "Drop Weapon on arm wounded",
	version = PLUGIN_VERSION,
}

public OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	
	g_iPlayerEquipGear = FindSendPropInfo("CINSPlayer", "m_EquippedGear");
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client     = GetClientOfUserId(GetEventInt(event, "userid"))
	new attacker   = GetClientOfUserId(GetEventInt(event, "attacker"))
	new hitgroup = GetEventInt(event, "hitgroup")
	new damage   = GetEventInt(event, "dmg_health")
	new health = GetClientHealth(client)
	
	if(attacker == 0)
	{
		return Plugin_Continue;
	}
	
	//new slot
	decl String:weapon[32]
	GetClientWeapon(attacker, weapon, sizeof(weapon))
	//GetClientWeapon(client, weapon, sizeof(weapon))
	
	new CurrentUserWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	new nTakeDamage = GetEntProp(client, Prop_Data, "m_takedamage");
	if ((CurrentUserWeapon < 0) || (nTakeDamage == 1)) {
		return Plugin_Continue;
	}
		
	decl String:User_Weapon[32];
	GetEdictClassname(CurrentUserWeapon, User_Weapon, sizeof(User_Weapon));
	
	//Get client accessories
	new nAccessoryItemID = GetEntData(client, g_iPlayerEquipGear + (4 * 3));
	
	if (((((hitgroup == 0) && (damage > 70)) && (health >0)) || (((hitgroup == 4) || (hitgroup == 5)) && (health >0))) && (nAccessoryItemID != 31))
	{
		/*
		for (new count=0; count<=63; count++)
		{
			switch(count)
			{
			case 51: slot = 1
			case 64: break
			}
			if (StrEqual(weapon, WeaponNames[count]))
			{
				if (GetPlayerWeaponSlot(client, slot) > 0)
				{
					PrintToServer("Player %N lost gun %s", client, weapon)
					new weapon_id = GetPlayerWeaponSlot(client, slot)
					SDKHooks_DropWeapon(client, weapon_id, NULL_VECTOR, NULL_VECTOR)
					PrintHintText(client, "Wounded to the arm! You lost your weapon!")
				}
			}
		}
		*/
		
		//Blacklist gas grenade		
		for (new count=0; count<6; count++)
		{
			if (StrEqual(User_Weapon, BlacklistWeaponNames[count]))
			{
				return Plugin_Continue;
			}
		}
		
		PrintToServer("Player %N lost gun %s", client, weapon)
		SDKHooks_DropWeapon(client, CurrentUserWeapon, NULL_VECTOR, NULL_VECTOR);
		PrintHintText(client, "Wounded to the arm! You lost your weapon!")
	}
	
	return Plugin_Continue;
}

