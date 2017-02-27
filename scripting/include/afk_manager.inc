#if defined _afkmanager_included
  #endinput
#endif
#define _afkmanager_included

/**
 * Gets the current AFK status of the client index.
 *
 * @param client	The client index of the player being checked.
 * @return		The clients AFK status.
 * @error		The client index is invalid.
 */
native bool AFKM_IsClientAFK(int client);

/**
 * Gets the current AFK time in seconds of the client index. If the client
 * has an invalid AFK time value -1 will be returned.
 *
 * Examples of clients who would have invalid AFK time values:
 *		Admins with full immunity.
 *		Disconnected clients.
 *		Bots, Fake Clients or Source TV.
 *
 * @param client	The client index of the player being checked.
 * @return		The clients AFK time or -1 if invalid client.
 * @error		The client index is invalid.
 */
native int AFKM_GetClientAFKTime(int client);

/**
 * Called when a client has been set AFK.
 *
 * @param client	The client index of the player being flagged.
 * @noreturn
 */
forward void AFKM_OnClientAFK(int client);

/**
 * Called when a client is back from AFK.
 *
 * @param client	The client index of the player being flagged.
 * @noreturn
 */
forward void AFKM_OnClientBack(int client);

public SharedPlugin:__pl_afkmanager = 
{
	name = "afkmanager",
	file = "afk_manager4.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_afkmanager_SetNTVOptional()
{
	MarkNativeAsOptional("AFKM_IsClientAFK");
	MarkNativeAsOptional("AFKM_GetClientAFKTime");
}
#endif