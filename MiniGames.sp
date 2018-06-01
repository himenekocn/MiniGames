/******************************************************************/
/*                                                                */
/*                         MiniGames Core                         */
/*                                                                */
/*                                                                */
/*  File:          MiniGames.sp                                   */
/*  Description:   MiniGames Game Mod.                            */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2018/03/02 04:19:06                                           */
/*                                                                */
/*  This code is licensed under the GPLv3 License.                */
/*                                                                */
/******************************************************************/


#pragma semicolon 1
#pragma newdecls required

// libraries
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

// header
#include "minigames/global.h"

// module
#include "minigames/teams.sp"
#include "minigames/stats.sp"
#include "minigames/ranks.sp"
#include "minigames/cvars.sp"
#include "minigames/games.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    if(GetEngineVersion() != Engine_CSGO)
        SetFailState("This plugin only for CSGO!");

    // Database
    ConnectToDatabase(0);
    
    // fire to module
    Cvars_OnPluginStart();
    Ranks_OnPluginStart();
    Stats_OnPluginStart();

    // block radio
    for(int x; x < 27; ++x)
    AddCommandListener(Command_BlockRadio, g_szBlockRadio[x]);

    // team controller
    AddCommandListener(Command_Jointeam, "jointeam");

    // game events
    HookEventEx("round_freeze_end",     Event_RoundStart,       EventHookMode_Post);
    HookEventEx("round_end",            Event_RoundEnd,         EventHookMode_Post);
    HookEventEx("player_spawn",         Event_PlayerSpawn,      EventHookMode_Post);
    HookEventEx("player_death",         Event_PlayerDeath,      EventHookMode_Post);
    HookEventEx("player_hurt",          Event_PlayerHurts,      EventHookMode_Post);
    HookEventEx("player_team",          Event_PlayerTeams,      EventHookMode_Pre);
    HookEventEx("player_disconnect",    Event_PlayerDisconnect, EventHookMode_Pre);
    HookEventEx("weapon_fire",          Event_WeaponFire,       EventHookMode_Post);
    HookEventEx("cs_win_panel_match",   Event_WinPanel,         EventHookMode_Post);
    HookEventEx("announce_phase_end",   Event_AnnouncePhaseEnd, EventHookMode_Post);
    
    // for noblock
    g_offsetNoBlock = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
    if(g_offsetNoBlock == -1)
        SetFailState("NoBlock offset -> not found.");
}

public void OnPluginEnd()
{
    // save all when unload plugin
    Stats_OnPluginEnd();
}

static void ConnectToDatabase(int retry)
{
    if(g_hMySQL != null)
        return;

    // connect to database
    Database.Connect(Database_OnConnected, "default", retry);
}

public void Database_OnConnected(Database db, const char[] error, int retry)
{
    // Exception
    if(db == null)
    {
        LogError("Database_OnConnected -> Connect failed -> %s", error);
        if(++retry <= 10)
            CreateTimer(3.0, Timer_ReconnectDB, retry);
        else
            SetFailState("connect to database failed! -> %s", error);
        return;
    }

    g_hMySQL = db;
    g_hMySQL.SetCharset("utf8mb4");

    char m_szQuery[2048];
    FormatEx(m_szQuery, 2048, "CREATE TABLE IF NOT EXISTS `k_minigames` (               \
                              `uid` int(11) unsigned NOT NULL AUTO_INCREMENT,           \
                              `steamid` varchar(32) NOT NULL DEFAULT 'INVALID_STEAMID', \
                              `username` varchar(32) DEFAULT NULL,                      \
                              `kills` int(11) unsigned NOT NULL DEFAULT '0',            \
                              `deaths` int(11) unsigned NOT NULL DEFAULT '0',           \
                              `assists` int(11) unsigned NOT NULL DEFAULT '0',          \
                              `hits` int(11) unsigned NOT NULL DEFAULT '0',             \
                              `shots` int(11) unsigned NOT NULL DEFAULT '0',            \
                              `headshots` int(11) unsigned NOT NULL DEFAULT '0',        \
                              `knife` int(11) unsigned NOT NULL DEFAULT '0',            \
                              `taser` int(11) unsigned NOT NULL DEFAULT '0',            \
                              `grenade` int(11) unsigned NOT NULL DEFAULT '0',          \
                              `molotov` int(11) unsigned NOT NULL DEFAULT '0',          \
                              `damage` int(11) unsigned NOT NULL DEFAULT '0',           \
                              `survivals` int(11) unsigned NOT NULL DEFAULT '0',        \
                              `rounds` int(11) unsigned NOT NULL DEFAULT '0',           \
                              `score` int(11) unsigned NOT NULL DEFAULT '0',            \
                              `online` int(11) unsigned NOT NULL DEFAULT '0',           \
                              PRIMARY KEY (`uid`),                                      \
                              UNIQUE KEY `uk_steamid` (`steamid`)                       \
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;                    \
                            ");
    g_hMySQL.Query(Database_CreateTable, m_szQuery, _, DBPrio_High);
}

public void Database_CreateTable(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    if(results == null || error[0])
        SetFailState("Database_CreateTable -> %s", error);
    
    // fire to module
    Ranks_OnDBConnected();
}

public Action Timer_ReconnectDB(Handle timer, int retry)
{
    // retry
    LogError("Timer_ReconnectDB -> Reconnect -> %d", retry);
    ConnectToDatabase(retry);
    return Plugin_Stop;
}

public void OnMapStart()
{
    // we only work on mg_ maps
    char map[128];
    GetCurrentMap(map, 128);
    if(StrContains(map, "mg_", false) != 0)
        SetFailState("This plugin only for mg_ (MiniGames/MultiGames) map!");

    // fire to module
    Stats_OnMapStart();
    Games_OnMapStart();
    Ranks_OnMapStart();
}

public void OnAutoConfigsBuffered()
{
    // fire to module
    Cvars_OnAutoConfigsBuffered();
}

public void OnConfigsExecuted()
{
    // set up warmup timer
    if(g_tWarmup != null)
        KillTimer(g_tWarmup);
    g_tWarmup = CreateTimer(mp_warmuptime.FloatValue + 0.5, Timer_WarmupEnd);
}

public void OnMapEnd()
{
    // fire to module
    Games_OnMapEnd();
    Ranks_OnMapEnd();
    
    // clear timer
    if(g_tWarmup != null)
        KillTimer(g_tWarmup);
    g_tWarmup = null;
}

public void OnClientConnected(int client)
{
    // reset client vars
    g_iUId [client] = 0;
    g_iTeam[client] = 0;
    
    // fire to module
    Stats_OnClientConnected(client);
    Teams_OnClientConnected(client);
}

public void OnClientPutInServer(int client)
{
    // fire to module
    Ranks_OnClientPutInServer(client);
    Stats_OnClientPutInServer(client);
    
    // hook this to check weapon
    SDKHookEx(client, SDKHook_WeaponEquipPost, Hook_OnPostWeaponEquip);
}

public void OnClientDisconnect(int client)
{
    // if client is not fully in-game
    if(!IsClientInGame(client))
        return;
    
    // fire to module
    Ranks_OnClientDisconnect(client);
    Stats_OnClientDisconnect(client);

    // unhook
    SDKUnhook(client, SDKHook_WeaponEquipPost, Hook_OnPostWeaponEquip);
}

public void Hook_OnPostWeaponEquip(int client, int weapon)
{
    if(!IsValidEdict(weapon))
        return;

    // we need check weapon when client fully equipped. 1 frame delay.
    DataPack pack = new DataPack();
    pack.WriteCell(client);
    pack.WriteCell(EntIndexToEntRef(weapon));
    RequestFrame(Games_OnEquipPost, pack);
}

public Action Timer_WarmupEnd(Handle timer)
{
    g_tWarmup = null;
    Stats_OnWarmupEnd();
    
    // custom gamemode maybe cause WARMUPTIME 0:01
    CreateTimer(5.0, Timer_CheckWarmupEnd, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Stop;
}

public Action Timer_CheckWarmupEnd(Handle timer)
{
    if(GameRules_GetProp("m_bWarmupPeriod") != 1)
        return Plugin_Stop;

    // force end warmup
    ServerCommand("mp_warmup_end");

    return Plugin_Stop;
}

public Action Command_BlockRadio(int client, const char[] command, int args)
{
    // block radio command
    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    // fire to module
    Games_OnPlayerRunCmd(client);
    Ranks_OnPlayerRunCmd(client, buttons);
    
    return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    
    Stats_OnClientSpawn(client);

    CreateTimer(0.1, Games_OnClientSpawn, userid);

    // for no block
    SetEntData(client, g_offsetNoBlock, 2, 4, true);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if(g_tWarmup != null)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int assister = GetClientOfUserId(event.GetInt("assister"));
    bool headshot = event.GetBool("headshot");
    char weapon[32];
    event.GetString("weapon", weapon, 32, "");

    Stats_OnClientDeath(client, attacker, assister, headshot, weapon);
}

public void Event_PlayerHurts(Event event, const char[] name, bool dontBroadcast)
{
    if(g_tWarmup != null)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int damage = event.GetInt("dmg_health");
    //int hitgroup = event.GetInt("hitgroup");
    char weapon[32];
    event.GetString("weapon", weapon, 32, "");

    Stats_PlayerHurts(client, attacker, damage, weapon);
}

public Action Event_PlayerTeams(Event event, const char[] name, bool dontBroadcast)
{
    g_iTeam[GetClientOfUserId(event.GetInt("userid"))] = event.GetInt("team");

    SetEventBroadcast(event, true);
    return Plugin_Changed;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    SetEventBroadcast(event, true);
    return Plugin_Changed;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    Cvars_OnRoundStart();
    Games_OnRoundStart();
    Teams_OnRoundStart();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    //int winner = event.GetInt("winner");
    
    Stats_OnRoundEnd();
    Games_OnRoundEnd();
    Teams_OnRoundEnd();
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    char weapon[32];
    event.GetString("weapon", weapon, 32, "");
    
    Stats_OnWeaponFire(client, weapon);
}

public void Event_WinPanel(Event event, const char[] name, bool dontBroadcast)
{
    // save all ...
    Stats_OnWinPanel();
}

public void Event_AnnouncePhaseEnd(Event event, const char[] name, bool dontBroadcast)
{
    // scoreboard ranking
    if(StartMessageAll("ServerRankRevealAll") != null)
        EndMessage();
}