
#include <insurgencydy>
//#include <sdktools>
//#include <loghelper>
#if defined REQUIRE_PLUGIN
#undef REQUIRE_PLUGIN
#include <updater>
#include <smlib>
#define REQUIRE_PLUGIN
#else
#include <updater>
#include <smlib>
#endif



//Check Min/Max AD
stock AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max)
{
	if (g_AIDir_TeamStatus < g_AIDir_TeamStatus_min)
	g_AIDir_TeamStatus = g_AIDir_TeamStatus_min;
	else if (g_AIDir_TeamStatus > g_AIDir_TeamStatus_max)
	g_AIDir_TeamStatus = g_AIDir_TeamStatus_max;
	return g_AIDir_TeamStatus;
}



