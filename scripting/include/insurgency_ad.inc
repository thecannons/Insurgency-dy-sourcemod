
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
stock AI_Director_SetMinMax(t_AIDir_TeamStatus, t_AIDir_TeamStatus_min, t_AIDir_TeamStatus_max)
{
	if (t_AIDir_TeamStatus < t_AIDir_TeamStatus_min)
	t_AIDir_TeamStatus = t_AIDir_TeamStatus_min;
	else if (t_AIDir_TeamStatus > t_AIDir_TeamStatus_max)
	t_AIDir_TeamStatus = t_AIDir_TeamStatus_max;
	return t_AIDir_TeamStatus;
}



