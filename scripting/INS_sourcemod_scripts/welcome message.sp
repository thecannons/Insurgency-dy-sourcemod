#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
    name = "[INS] Welcome Message",
    description = "Welcome message upon joining",
    author = "Neko-",
    version = "1.0.0",
};

public OnClientPostAdminCheck(client)
{
	PrintToChat(client, "\x0759b0f9[INS] \x01Welcome To The Server! Type 'rules' into the console for our rules!");
	PrintToChat(client, "\x0759b0f9[INS] \x01Our Website: http://insurgency.pro");
	PrintToChat(client, "\x0759b0f9[INS] \x01Discord: http://insurgency.pro/discord");
}