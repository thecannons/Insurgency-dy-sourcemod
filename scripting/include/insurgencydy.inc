#if defined _insurgencydy_included
  #endinput
#endif
#define _insurgencydy_included

//#include <sourcemod>
//#include <sdktools>
//#include <loghelper>

#define MAX_DEFINABLE_WEAPONS 100
#define MAX_WEAPON_LEN 32
#define MAX_SQUAD_LEN 32
#define MAX_CLASS_LEN 64
#define MAX_CONTROLPOINTS 32
#define PREFIX_LEN 7
#define MAX_SQUADS 8
#define SQUAD_SIZE 8

//Get and Set Ammo for storing weapons and ammo on death (reference weapon to make sure it exists)
stock GetWeaponAmmo(client, weapon, type)
{
	new PropType:proptype = Prop_Data;
	//new ammoOffset = FindSendPropInfo("CINSPlayer", "m_iAmmo");
	new m_iPrimaryAmmoType, ammo;
				
	
	//return GetEntData(client, ammoOffset+(slot*4));
	if (type == 0) // primary
	{
		m_iPrimaryAmmoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		ammo = GetEntProp(client, proptype, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	else if(type == 1) // secondary
	{
		m_iPrimaryAmmoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		ammo = GetEntProp(client, proptype, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	else if (type == 3) // grenades
	{	
		m_iPrimaryAmmoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		//PrintToServer("m_iPrimaryAmmoType %d", m_iPrimaryAmmoType);
		ammo = GetEntProp(client, proptype, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	//PrintToServer("m_iPrimaryAmmoType: %i, Ammo %i", m_iPrimaryAmmoType, ammo);
	return ammo;
}

stock SetWeaponAmmo(client, weapon, ammo, type)
{
	new PropType:proptype = Prop_Data;
	//new ammoOffset = FindSendPropInfo("CINSPlayer", "m_iAmmo");
	new m_ammoType;
				
	//PrintToServer("m_iPrimaryAmmoType: %i, Ammo %i", m_ammoType, ammo);
	//return GetEntData(client, ammoOffset+(slot*4));
	if (type == 0) // primary
	{
		m_ammoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		SetEntProp(client, proptype, "m_iAmmo", ammo, _, m_ammoType);
	}
	else if(type == 1) // secondary
	{
		m_ammoType = GetEntProp(weapon, proptype, "m_iPrimaryAmmoType");
		SetEntProp(client, proptype, "m_iAmmo", ammo, _, m_ammoType);
	}
	else if (type == 3) // grenades
	{	

	}
}

//Get / Set primary ammo count as it was when died
stock GetPrimaryAmmo(client, weap, type)
{
	//new myweapons = FindSendPropInfo("CCSPlayer", "m_hMyWeapons");
	//new weap = GetEntDataEnt2(client, myweapons+ (slot*4));
	if(IsValidEntity(weap))
	{
		if (type==0)
		{
			return GetEntData(weap, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"));
		}
		else if (type==1)
		{
			return GetEntData(weap, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"));
		}
	}
	return 0;
}

stock SetPrimaryAmmo(client, weap, ammo, type)
{
	//new PropType:proptype = Prop_Data;
	//new myweapons = FindSendPropInfo("CCSPlayer", "m_hMyWeapons");
	//new weap = GetEntDataEnt2(client, myweapons+ (slot*4));
	if(IsValidEntity(weap))
	{
		if (type==0)
		{
			return SetEntData(weap, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), ammo, _, true);
		}
		else if (type==1)
		{
			return SetEntData(weap, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), ammo, _, true);
		}
	}
	
	return 0;
}


stock GetGrenadeAmmo(client, grenadeType)
{
	new PropType:proptype = Prop_Data;
	new ammo;
	////PrintToServer("grenadeType %d", grenadeType);
	ammo = GetEntProp(client, proptype, "m_iAmmo", _, grenadeType);
	return ammo;
}

stock SetGrenadeAmmo(client, grenadeType, grenadeAmount)
{
	new PropType:proptype = Prop_Data;
	//PrintToServer("grenadeType %d, amount to set: %d", grenadeType, grenadeAmount);
	SetEntProp(client, proptype, "m_iAmmo", grenadeAmount, _, grenadeType);
}



/*
#define Gren_M67 68
#define Gren_Incen 73
#define Gren_Molot 74
#define Gren_M18 70
#define Gren_Flash 71
#define Gren_F1 69
#define Gren_IED 72
#define Gren_C4 72
#define Gren_AT4 67
#define Gren_RPG7 61
*/