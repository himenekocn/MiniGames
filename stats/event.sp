public void CG_OnClientSpawn(int client)
{
	RequestFrame(RemoveRadar, client);
	CreateTimer(1.0, CheckClientKD, client);
}

public void CG_OnClientDeath(int client, int attacker, int assister, bool headshot, const char[] weapon)
{
	if(g_bWarmup || !g_bEnable)
		return;

	g_eSession[client][Deaths]++;

	if(client == attacker || !IsValidClient(attacker))
		return;
	
	g_iRoundKill[attacker]++;

	g_eSession[attacker][Kills] += 1;
	g_eSession[attacker][Score] += 3;

	if(StrContains(weapon, "negev", false) == -1 && StrContains(weapon, "m249", false) == -1 && StrContains(weapon, "p90", false) == -1 && StrContains(weapon, "hegrenade", false) == -1)
	{
		Store_SetClientCredits(attacker, Store_GetClientCredits(attacker)+1, "MG-击杀玩家");
		PrintToChat(attacker, "%s \x10你击杀\x07 %N \x10获得了\x04 1 信用点", PREFIX_STORE, client);
	}

	if(StrContains(weapon, "knife", false) != -1)
	{
		g_eSession[attacker][Knife] += 1;
		g_eSession[attacker][Score] += 2;
		//Diamonds_KillChecked(attacker, true);
	}
	if(StrContains(weapon, "taser", false) != -1)
	{
		g_eSession[attacker][Taser] += 1;
		g_eSession[attacker][Score] += 2;
		Diamonds_KillChecked(attacker, false);
	}
	
	if(StrContains(weapon, "decoy", false) != -1 || StrContains(weapon, "smoke", false) != -1)
	{
		Diamonds_NadeKill(attacker);
	}
	
	if(headshot)
		Diamonds_HSKill(attacker);
	
	if(g_bRoundEnding)
		return;

	if(!g_bEndGame && !g_bBetting)
	{
		int ct, te;

		for(int i = 1; i <= MaxClients; ++i)
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(GetClientTeam(i) == 2)
					te++;
					
				if(GetClientTeam(i) == 3)
					ct++;
			}

		if(ct == te && (ct == 1 || ct == 2))
		{
			g_bEndGame = true;
			g_bBetting = true;
			g_bBetTimeout = false;
			CreateTimer(15.0, Timer_Timeout);
			SetupBeacon();
			SetupBetting();
		}
	}
	
	if(g_bEndGame)
	{
		int ct, te, lastCT, lastTE;
		for(int i = 1; i <= MaxClients; ++i)
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(GetClientTeam(i) == 2)
				{
					te++;
					lastTE = i;
				}
					
				if(GetClientTeam(i) == 3)
				{	
					ct++;
					lastCT = i;
				}
			}
		if(te == 1 && ct == 0 && IsValidClient(lastTE))
			Diamonds_EndGameWinner(lastTE);
		
		if(te == 0 && ct == 1 && IsValidClient(lastCT))
			Diamonds_EndGameWinner(lastCT);
	}
}

public Action Event_PlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
	SetEventBroadcast(event, true);
	return Plugin_Changed;
}

public void CG_OnRoundStart()
{
	g_bEndGame = false;
	g_bRoundEnding = false;
	ClearTimer(g_tBeacon);

	g_bBetting = false;
	g_bBetTimeout = true;
	g_iTagType = (g_iTagType == 3) ? 0 : g_iTagType+1;
	
	ClearTimer(g_tBurn);
	if(GetConVarBool(CVAR_AUTOBURN))
		g_tBurn = CreateTimer(GetConVarFloat(CVAR_BURNDELAY), Timer_BurnAll);
}

public void CG_OnRoundEnd(int winner)
{
	g_bEndGame = false;
	g_bRoundEnding = true;
	ClearTimer(g_tBeacon);
	
	if(g_tBurn == INVALID_HANDLE)
	{
		for(int client = 1; client <= MaxClients; ++client)
			if(IsClientInGame(client))
				if(IsPlayerAlive(client))
					if(g_iAuthId[client] != 9999)
						ExtinguishEntity(client);
	}
	else
		ClearTimer(g_tBurn);

	if(g_bBetting)
		SettlementBetting(winner);

	if(g_bRandomTeam)
		CreateTimer(2.0, Timer_RoundEndDelay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_WinPanel(Handle event, const char[] name, bool dontBroadcast)
{
	if(g_bEnable)
	{
		LogMessage("Event_WinPanel");

		for(int client = 1; client <= MaxClients; ++client)
		{
			if(IsClientInGame(client) && g_bOnDB[client])
			{
				SavePlayer(client);
				if(g_bMapCredits && (GetTime() - g_eSession[client][Onlines] >= 1500))
					Diamonds_MapScore(client);
			}
		}
	}

	g_bMapCredits = false;
}