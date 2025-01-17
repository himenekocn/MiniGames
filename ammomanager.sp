/******************************************************************/
/*                                                                */
/*                     MiniGames - Ammo manager                   */
/*                                                                */
/*                                                                */
/*  File:          ammomanager.sp                                 */
/*  Description:   MiniGames Game Mod.                            */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2021  Kyle                                      */
/*  2018/03/02 04:19:06                                           */
/*                                                                */
/*  This code is licensed under the GPLv3 License.                */
/*                                                                */
/******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <minigames>

#undef REQUIRE_PLUGIN
#include <fys.pupd>
#define REQUIRE_PLUGIN

#define PI_NAME     "Ammo Manager - Lite for MiniGames"
#define PI_AUTHOR   "Kyle 'Kxnrl' Frankiss + PerfectLaugh"
#define PI_DESC     "MiniGames Game Mod"
#define PI_VERSION  "2.2." ... MYBUILD
#define PI_URL      "https://github.com/Kxnrl/MiniGames"

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTHOR,
    description = PI_DESC,
    version     = PI_VERSION,
    url         = PI_URL
};

#define MAX_RESERVE_AMMO_MAX            416

// ENGINE definitions
#define SF_PLAYEREQUIP_USEONLY          0x0001
#define SF_PLAYEREQUIP_STRIPFIRST       0x0002
#define SF_PLAYEREQUIP_ONLYSTRIPSAME    0x0004
#define MAX_EQUIP                       32
#define CS_WEAPON_SLOT_KNIFE            2

Handle SDKCall_GetSlot;
Handle SDKCall_SetReserveAmmoCount;
Handle DHook_GetReserveAmmoMax;
Handle AcceptInput;

ConVar mg_ammo_max_override;

public void OnPluginStart()
{
    GameData config = new GameData("minigames.games");
    if (config == null)
        SetFailState("Gamedata minigames.games not found.");

    int OFFSET_GetReserveAmmoMax = config.GetOffset("CBaseCombatWeapon::GetReserveAmmoMax");
    if (OFFSET_GetReserveAmmoMax == -1)
        SetFailState("Failed to get CBaseCombatWeapon::GetReserveAmmoMax offset");

    DHook_GetReserveAmmoMax = DHookCreate(OFFSET_GetReserveAmmoMax, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity);
    DHookAddParam(DHook_GetReserveAmmoMax, HookParamType_Int);

    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CBaseCombatWeapon::SetReserveAmmoCount"))
        SetFailState("PrepSDKCall_SetSignature(CBaseCombatWeapon::SetReserveAmmoCount) failed!");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    if ((SDKCall_SetReserveAmmoCount = EndPrepSDKCall()) == null)
        SetFailState("Failed to prepare SDKCall SDKCall_SetReserveAmmoCount.");

    int OFFSET_GETSLOT = config.GetOffset("CBaseCombatWeapon::GetSlot");
    if (OFFSET_GETSLOT == -1)
        SetFailState("Failed to get CBaseCombatWeapon::GetSlot offset");

    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetVirtual(OFFSET_GETSLOT))
    {
        SetFailState("PrepSDKCall_SetVirtual(\"GetSlot\" failed!");
        return;
    }
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    if ((SDKCall_GetSlot = EndPrepSDKCall()) == null)
        SetFailState("Failed to prepare SDKCall SDKCall_GetSlot.");

    GameData conf = new GameData("sdktools.games");
    if (conf == null)
        SetFailState("Failed to load gamedata.");

    int offset = conf.GetOffset("AcceptInput"); delete conf;
    if (offset == -1)
        SetFailState("Failed to get offset of \"AcceptInput\".");

    AcceptInput = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity);
    if (AcceptInput == null)
        SetFailState("Failed to DHook \"AcceptInput\".");

    delete conf;

    DHookAddParam(AcceptInput, HookParamType_CharPtr);
    DHookAddParam(AcceptInput, HookParamType_CBaseEntity);
    DHookAddParam(AcceptInput, HookParamType_CBaseEntity);
    DHookAddParam(AcceptInput, HookParamType_Object, 20);
    DHookAddParam(AcceptInput, HookParamType_Int);

    mg_ammo_max_override = CreateConVar("mg_ammo_max_override", "-1", "Override Max Reserve Ammo Value.", _, true, -2.0, true, 416.0);

    HookEvent("round_prestart", Event_Round, EventHookMode_Post);
}

public void Pupd_OnCheckAllPlugins()
{
    Pupd_CheckPlugin(false, "https://build.kxnrl.com/updater/MiniGames/");
}

public void OnConfigsExecuted()
{
    FindConVar("ammo_338mag_max").SetInt(0);
    FindConVar("ammo_357sig_max").SetInt(0);
    FindConVar("ammo_357sig_min_max").SetInt(0);
    FindConVar("ammo_357sig_p250_max").SetInt(0);
    FindConVar("ammo_357sig_small_max").SetInt(0);
    FindConVar("ammo_45acp_max").SetInt(0);
    FindConVar("ammo_50AE_max").SetInt(0);
    FindConVar("ammo_556mm_box_max").SetInt(0);
    FindConVar("ammo_556mm_max").SetInt(0);
    FindConVar("ammo_556mm_small_max").SetInt(0);
    FindConVar("ammo_57mm_max").SetInt(0);
    FindConVar("ammo_762mm_max").SetInt(0);
    FindConVar("ammo_9mm_max").SetInt(0);
    FindConVar("ammo_buckshot_max").SetInt(0);

    // healthshot
    FindConVar("sv_health_approach_enabled").SetBool(true);
    FindConVar("healthshot_health").SetInt(60);
    FindConVar("healthshot_healthboost_time").SetFloat(5.0);
    FindConVar("healthshot_healthboost_damage_multiplier").SetFloat(1.5);
    FindConVar("healthshot_healthboost_speed_multiplier").SetFloat(0.75);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (strncmp(classname, "weapon_", 7) == 0)
    {
        DHookEntity(DHook_GetReserveAmmoMax, false, entity, _, Event_GetReserveAmmoMax);
        SDKHook(entity, SDKHook_SpawnPost, Event_WeaponCreated);
    }

    if (strcmp(classname, "game_player_equip", false) == 0)
    {
        DHookEntity(AcceptInput, false, entity, _, Event_AcceptInput);
        SDKHook(entity, SDKHook_Use, Event_OnUse);
    }
}

public void Event_WeaponCreated(int entity)
{
    SDKUnhook(entity, SDKHook_SpawnPost, Event_WeaponCreated);

    if (!IsValidEdict(entity))
        return;

    SDKCall(SDKCall_SetReserveAmmoCount, entity, 1, MAX_RESERVE_AMMO_MAX, true, -1);
}

public MRESReturn Event_GetReserveAmmoMax(int pThis, Handle hReturn, Handle hParams)
{
    if (!IsValidEdict(pThis))
        return MRES_Ignored;

    // ignore taser
    char classname[32];
    GetEdictClassname(pThis, classname, 32);
    if (strcmp(classname, "weapon_taser") == 0)
        return MRES_Ignored;

    int val = mg_ammo_max_override.IntValue;

    // we are using CS:GO default reserve ammo.
    if (val == -2)
        return MRES_Ignored;

    DHookSetReturn(hReturn, val == -1 ? MAX_RESERVE_AMMO_MAX : val);

    return MRES_Supercede;
}

public MRESReturn Event_AcceptInput(int pThis, Handle hReturn, Handle hParams)
{
    if(!IsValidEntity(pThis))
        return MRES_Ignored;

    char command[128];
    DHookGetParamString(hParams, 1, command, 128);

    if(strcmp(command, "TriggerForAllPlayers", false) == 0)
    {
        DHookSetReturn(hReturn, false);
        RequestFrame(Frame_DelayUse, EntRefToEntIndex(pThis));
        return MRES_Supercede;
    }

    return MRES_Ignored;
}

void Frame_DelayUse(int ref)
{
    int entity = EntRefToEntIndex(ref);
    if (!IsValidEntity(entity))
        return;

    for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsPlayerAlive(i))
    {
        AcceptEntityInput(entity, "Use", i, entity);
    }
}

public Action Event_OnUse(int entity, int client, int caller, UseType type, float value)
{
    if (!(0 < client <= MaxClients) || !IsPlayerAlive(client))
        return Plugin_Continue;

    // we strip knife if has 'Only Strip Same Weapon Type' flag.
    if (!(GetEntProp(entity, Prop_Data, "m_spawnflags") & SF_PLAYEREQUIP_ONLYSTRIPSAME))
        return Plugin_Continue;

    char weapon[32];

    int count = 0;
    bool knife = false;

    for(int index = 0; index < MAX_EQUIP; ++index)
    {
        GetEntPropString(entity, Prop_Data, "m_weaponNames", weapon, 32, index);

        //count += GetEntProp(entity, Prop_Data, "m_weaponCount", 4, index);

        // just counting weapon
        if (strncmp(weapon, "weapon_", 7, false) == 0)
        {
            count++;

            if (strcmp(weapon, "weapon_knife", false) == 0)
            {
                // mark as knife
                knife = true;
            }
        }
    }

    // if player has knife and this entity just for giving knife.
    // we stop that to prevent give twice.
    if (knife)
    {
        // only give knife
        if (count == 1)
        {
            int melee = GetPlayerWeaponSlot(client, CS_WEAPON_SLOT_KNIFE);
            if (melee == -1)
            {
                // we have not knife
                return Plugin_Continue;
            }

            // hold the fists
            if (GetEdictClassname(melee, weapon, 32) && strcmp(weapon, "weapon_fists") == 0)
            {
                RemovePlayerItem(client, melee);
                AcceptEntityInput(melee, "KillHierarchy");
                return Plugin_Continue;
            }

            // we have knife
            return Plugin_Handled;
        }

        HandleKnife(client);
    }

    return Plugin_Continue;
}

void HandleKnife(int client)
{
    int weapon = -1;
    char classname[32];
    int m_hMyWeapons = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
    for(int offset = 0; offset < m_hMyWeapons; offset++)
    {
        weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", offset);
        if(weapon > MaxClients)
        {
            if (SDKCall(SDKCall_GetSlot, weapon) == CS_WEAPON_SLOT_KNIFE)
            {
                // error
                if (!GetEdictClassname(weapon, classname, 32))
                {
                    LogError("Failed to get classname for %d.", weapon);
                    AcceptEntityInput(weapon, "KillHierarchy");
                    continue;
                }

                // if this is fists, just killed...
                if (strcmp(classname, "weapon_fists") == 0)
                {
                    SaveRemove(client, weapon);
                    continue;
                }

                // not the map item
                if (GetEntProp(weapon, Prop_Data, "m_iHammerID") <= 0)
                {
                    SaveRemove(client, weapon);
                    continue;
                }

                // no child
                if (GetEntPropEnt(weapon, Prop_Data, "m_hMoveChild") == -1)
                {
                    SaveRemove(client, weapon);
                    continue;
                }

                // CLagCompensationManager::StartLagCompensation with NULL CUserCmd!!!
                // we need give back again.
                DataPack context = new DataPack();
                context.WriteCell(GetClientUserId(client));
                context.WriteCell(EntIndexToEntRef(weapon));
                context.Reset();
                CreateTimer(0.1, Timer_GiveBack, context);

                RemovePlayerItem(client, weapon);
            }
        }
    }
}

void SaveRemove(int client, int knife)
{
    RemovePlayerItem(client, knife);
    AcceptEntityInput(knife, "KillHierarchy");
}

public Action Timer_GiveBack(Handle timer, DataPack context)
{
    int userid = context.ReadCell();
    int entRef = context.ReadCell();
    int client = GetClientOfUserId(userid);
    int entity = EntRefToEntIndex(entRef);
    delete context;

    if (!client || !IsPlayerAlive(client))
        return Plugin_Stop;

    if (!IsValidEdict(entity))
        return Plugin_Stop;

    // player may has two 
    EquipPlayerWeapon(client, entity);

    return Plugin_Stop;
}

public void Event_Round(Event e, const char[] n, bool b)
{
    mg_ammo_max_override.IntValue = -1;
}