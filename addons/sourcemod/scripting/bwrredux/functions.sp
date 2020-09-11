// functions that can be removed from the main file

// Globals
ArrayList g_aSpyTeleport;
ArrayList g_aEngyTeleport;

char g_strHatchTrigger[64];
char g_strExploTrigger[64];
char g_strNormalSpawns[512];
char g_strGiantSpawns[512];
char g_strSniperSpawns[512];
char g_strSpySpawns[512];
char g_strNormalSplit[16][64];
char g_strGiantSplit[16][64];
char g_strSniperSplit[16][64];
char g_strSpySplit[16][64];
int g_iSplitSize[4];

/**
 * Checks if the given client index is valid.
 *
 * @param client         The client index.  
 * @return              True if the client is valid
 *                      False if the client is invalid.
 */
stock bool IsValidClient(int client)
{
	if( client < 1 || client > MaxClients ) return false;
	if( !IsValidEntity(client) ) return false;
	if( !IsClientConnected(client) ) return false;
	return IsClientInGame(client);
}

/**
 * Gets a random player in game from a specific team.
 * Do not call this if the server is empty.
 *
 * @param iTeam         Team Index
 * @param bBots         Include bots?
 * @return              The client index
 */
stock int GetRandomClientFromTeam(const int iTeam, bool bBots = false)
{
	int players_available[MAXPLAYERS+1];
	int counter = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if( bBots )
		{
			if ( IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iTeam )
			{
				players_available[counter] = i;
				counter++;
			}			
		}
		else
		{
			if ( IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam )
			{
				players_available[counter] = i;
				counter++;
			}						
		}
	}
	
	return players_available[GetRandomInt(0,(counter-1))];
}

// selects a random player from a team
int GetRandomPlayer(TFTeam Team, bool bIncludeBots = false)
{
	int players_available[MAXPLAYERS+1];
	int counter = 0; // counts how many valid players we have
	for (int i = 1; i <= MaxClients; i++)
	{
		if(bIncludeBots)
		{
			if(IsClientInGame(i) && TF2_GetClientTeam(i) == Team)
			{
				players_available[counter] = i; // stores the client userid
				counter++;
			}			
		}
		else
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == Team)
			{
				players_available[counter] = i; // stores the client userid
				counter++;
			}				
		}

	}
	
	// now we should have an array filled with user ids and exactly how many players we have in game.
	int iRandomMax = counter - 1;
	int iRandom = GetRandomInt(0,iRandomMax); // get a random number between 0 and counted players
	// now we get the user id from the array cell selected via iRandom
	return players_available[iRandom];
}

// IsMvM code by FlaminSarge
bool IsMvM(bool forceRecalc = false)
{
	static bool found = false;
	static bool ismvm = false;
	if (forceRecalc)
	{
		found = false;
		ismvm = false;
	}
	if (!found)
	{
		int i = FindEntityByClassname(-1, "tf_logic_mann_vs_machine");
		if (i > MaxClients && IsValidEntity(i)) ismvm = true;
		found = true;
	}
	return ismvm;
}

// Teleports a spy near a RED player
void TeleportSpyRobot(int client)
{
	int target = GetRandomClientFromTeam( view_as<int>(TFTeam_Red), false);
	int oldtarget = target;
	
	if( TF2Spawn_IsClientInSpawn2(target) )
	{
		int i = 0;
		while( i < 20)
		{
			target = GetRandomClientFromTeam( view_as<int>(TFTeam_Red), false);
			if( target != oldtarget )
				break;
				
			i++;
		}
	}
	
	float TargetPos[3];
	
	if(!IsValidClient(target))
	{
		if( GetSpyTeleportFromConfig(TargetPos) )
		{
			p_bInSpawn[client] = false;
			TF2_RemoveCondition(client, TFCond_UberchargedHidden);
			TeleportEntity(client, TargetPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
	else
	{
		if( GetSpyTeleportFromConfig(TargetPos, target) )
		{
			p_bInSpawn[client] = false;
			TF2_RemoveCondition(client, TFCond_UberchargedHidden);
			TeleportEntity(client, TargetPos, NULL_VECTOR, NULL_VECTOR);
			char name[MAX_NAME_LENGTH];
			GetClientName(target, name, sizeof(name));
			CPrintToChat(client, "%t", "Spy_Teleported", name);
		}
	}
}

// searches for an engineer nest close to the bomb
void FindEngineerNestNearBomb(int client)
{
	float nVec[3], bVec[3], tVec[3]; // nest pos, bomb pos, tele pos
	float current_dist, min_dist = 750.0;
	float smallest_dist = 15000.0;
	int iTargetNest = -1; // the closest nest found.
	int i = -1;
	int iBomb = -1; // the bomb we're going to use to check distance.
	int iBombOwner = -1; // bomb carrier
	
	// find the bomb current position
	while( (i = FindEntityByClassname(i, "item_teamflag" )) != -1 )
	{
		if( IsValidEntity(i) && GetEntProp( i, Prop_Send, "m_bDisabled" ) == 0 ) // ignore disabled bombs
		{
			iBomb = i; // use the first bomb found.
			iBombOwner = GetEntPropEnt( i, Prop_Send, "m_hOwnerEntity" );
			break;
		}
	}
	
	if( iBomb == -1 )
		return; // no bomb found
	
	// search for bot hints
	i = -1;
	while( (i = FindEntityByClassname(i, "bot_hint_engineer_nest" )) != -1 )
	{
		if( IsValidEntity(i) )
		{
			if( iBombOwner == -1 || iBombOwner > MaxClients)
			{
				GetEntPropVector(iBomb, Prop_Send, "m_vecOrigin", bVec); // bomb
			}
			else // if the bomb is carried by a player, use the eye position of the carrier instead
			{
				GetClientEyePosition(iBombOwner, bVec);
			}
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", nVec); // nest
			
			current_dist = GetVectorDistance(bVec, nVec);
			
			if( current_dist < smallest_dist && current_dist > min_dist )
			{
				iTargetNest = i;
				smallest_dist = current_dist;
			}
		}
	}
	
	if( iTargetNest == -1 ) // no bot_hint_engineer_nest found
	{
		if( iBombOwner == -1 || iBombOwner > MaxClients)
		{
			GetEntPropVector(iBomb, Prop_Send, "m_vecOrigin", bVec); // bomb
		}
		else // if the bomb is carried by a player, use the eye position of the carrier instead
		{
			GetClientEyePosition(iBombOwner, bVec);
		}
		if( GetEngyTeleportFromConfig(tVec, bVec) )
		{
			TeleportEngineerToPosition(tVec, client);
		}
	}
	else
	{
		GetEntPropVector(iTargetNest, Prop_Send, "m_vecOrigin", tVec);
		TeleportEngineerToPosition(tVec, client);
	}
}

// teleports a client to the entity origin.
// also adds engineer spawn particle
void TeleportEngineerToPosition(float origin[3], int client, float OffsetVec[3] = {0.0,0.0,0.0})
{
	float FinalVec[3];
	
	p_bInSpawn[client] = false;
	TF2_RemoveCondition(client, TFCond_UberchargedHidden);
	AddVectors(origin, OffsetVec, FinalVec);
	TeleportEntity(client, FinalVec, NULL_VECTOR, NULL_VECTOR);
	CreateTEParticle("teleported_blue",FinalVec, _, _,3.0,-1,-1,-1);
	CreateTEParticle("teleported_mvm_bot",FinalVec, _, _,3.0,-1,-1,-1);
}

// searches for a teleporter exit 
int FindBestBluTeleporter()
{
	float nVec[3]; // nest pos
	float bVec[3]; // bomb pos
	float current_dist;
	float smallest_dist = 15000.0;
	int iTargetTele = -1; // the closest nest found.
	int i = -1;
	int iBomb = -1; // the bomb we're going to use to check distance.
	int iBombOwner = -1;
	
	while( (i = FindEntityByClassname(i, "item_teamflag" )) != -1 )
	{
		if( IsValidEntity(i) && GetEntProp( i, Prop_Send, "m_bDisabled" ) == 0 ) // ignore disabled bombs
		{
			iBomb = i; // use the first bomb found.
			iBombOwner = GetEntPropEnt( i, Prop_Send, "m_hOwnerEntity" );
			break;
		}
	}
	
	if( iBomb == -1 )
		return -1; // no bomb found
	
	i = -1;
	while( (i = FindEntityByClassname(i, "obj_teleporter" )) != -1 )
	{
		if( IsValidEntity(i) )
		{
			if( GetEntProp( i, Prop_Send, "m_bHasSapper" ) == 0 && GetEntProp( i, Prop_Send, "m_iTeamNum" ) != view_as<int>(TFTeam_Red) && GetEntPropFloat(i, Prop_Send, "m_flPercentageConstructed") >= 0.99 )
			{ // teleporters from spectator are also valid since we started moving dead blu players to spec
				if( iBombOwner == -1 || iBombOwner > MaxClients)
				{
					GetEntPropVector(iBomb, Prop_Send, "m_vecOrigin", bVec); // bomb
				}
				else // if the bomb is carried by a player, use the eye position of the carrier instead
				{
					GetClientEyePosition(iBombOwner, bVec);
				}
				
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", nVec); // nest
				
				current_dist = GetVectorDistance(bVec, nVec);
				
				if( current_dist < smallest_dist )
				{
					iTargetTele = i;
					smallest_dist = current_dist;
				}
			}
		}
	}
	
	return iTargetTele;
}

// TeleportPlayerToEntity but for teleporters
void SpawnOnTeleporter(int teleporter,int client)
{
	float OriginVec[3];
	float Scale = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
	if( IsValidEntity(teleporter) )
	{
		GetEntPropVector(teleporter, Prop_Send, "m_vecOrigin", OriginVec);
		
		if( Scale <= 1.0 )
		{
			OriginVec[2] += 16;
		}
		else if( Scale >= 1.1 && Scale <= 1.4 )
		{
			OriginVec[2] += 20;
		}
		else if( Scale >= 1.5 && Scale <= 1.6 )
		{
			OriginVec[2] += 23;
		}		
		else if( Scale >= 1.7 && Scale <= 1.8 )
		{
			OriginVec[2] += 26;
		}
		else if( Scale >= 1.9 )
		{
			OriginVec[2] += 50;
		}
		
		TF2_AddCondition(client, TFCond_UberchargedCanteen, 5.1); // 0.1 sec to compensate for a small delay
		TeleportEntity(client, OriginVec, NULL_VECTOR, NULL_VECTOR);
		EmitGameSoundToAll("MVM.Robot_Teleporter_Deliver", teleporter, SND_NOFLAGS, teleporter, OriginVec);
	}
}

// emits game sound to all players in RED
void EmitGSToRed(const char[] gamesound)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if( IsClientInGame(i) && !IsFakeClient(i) )
		{
			if( TF2_GetClientTeam(i) == TFTeam_Red )
			{
				EmitGameSoundToClient(i, gamesound);
			}
		}
	}
}

// emits sound to all players in RED
/* void EmitSoundToRed(const char[] soundpath)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if( IsClientInGame(i) && !IsFakeClient(i) )
		{
			if( TF2_GetClientTeam(i) == TFTeam_Red )
			{
				EmitSoundToClient(i, soundpath);
			}
		}
	}
} */

// announces when a robot engineer is killed.
void AnnounceEngineerDeath(int client)
{
	bool bFoundTele = false;
	int i = -1;
	int iOwner = -1;
	
	if( IsClientInGame(client) && !IsFakeClient(client) )
	{
		while( (i = FindEntityByClassname(i, "obj_teleporter" )) != -1 )
		{
			if( IsValidEntity(i) )
			{
				if( GetEntProp( i, Prop_Send, "m_iTeamNum" ) == view_as<int>(TFTeam_Blue) )
				{				
					iOwner = GetEntPropEnt( i, Prop_Send, "m_hBuilder" );
					if( iOwner == client )
					{
						bFoundTele = true;
						break;
					}
				}
			}
		}
		if( bFoundTele ) // found a teleporter
		{
			EmitGSToRed("Announcer.MVM_An_Engineer_Bot_Is_Dead_But_Not_Teleporter");
		}
		else if( GameRules_GetRoundState() == RoundState_RoundRunning )
		{
			EmitGSToRed("Announcer.MVM_An_Engineer_Bot_Is_Dead");
		}
	}
}

// returns the number of classes in a team.
int GetClassCount(TFClassType TFClass, TFTeam Team, bool bIncludeBots = false, bool bIncludeDead = true)
{
	int iClassNum = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if( IsClientInGame(i) )
		{
			if( bIncludeBots )
			{
				if( TF2_GetClientTeam(i) == Team )
				{
					if( TF2_GetPlayerClass(i) == TFClass )
					{
						if( bIncludeDead )
							iClassNum++;
						else if( IsPlayerAlive(i) )
							iClassNum++;
					}
				}
			}
			else
			{
				if( !IsFakeClient(i) )
				{
					if( TF2_GetClientTeam(i) == Team )
					{
						if( TF2_GetPlayerClass(i) == TFClass )
						{
							if( bIncludeDead )
								iClassNum++;
							else if( IsPlayerAlive(i) )
								iClassNum++;
						}
					}
				}
			}
		}
	}
	
	return iClassNum;
}

// returns the entity index of the first available weapon
int GetFirstAvailableWeapon(int client)
{
	int iWeapon = -1;
	int iSlot = 0;
	
	while( iSlot <= 5 )
	{
		iWeapon = GetPlayerWeaponSlot(client, iSlot);
		iSlot++;
		if( iWeapon != -1 )
		{
			break;
		}
	}
	
	return iWeapon;
}

void BlockBombPickup(int client)
{
	if( IsFakeClient(client) )
		return;
	
	// This attribute works when added to a client
	TF2Attrib_SetByName(client, "cannot pick up intelligence", 1.0);
}

// add particle to the robot engineer teleporter
void AddParticleToTeleporter(int entity)
{
	int particle = CreateEntityByName("info_particle_system");

	char targetname[64];
	float VecOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", VecOrigin);
	VecOrigin[2] -= 500;
	TeleportEntity(particle, VecOrigin, NULL_VECTOR, NULL_VECTOR);

	FormatEx(targetname, sizeof(targetname), "tele_target_%i", entity);
	DispatchKeyValue(entity, "targetname", targetname);

	DispatchKeyValue(particle, "targetname", "bwrr_tele_particle");
	DispatchKeyValue(particle, "parentname", targetname);
	DispatchKeyValue(particle, "effect_name", "teleporter_mvm_bot_persist");
	DispatchSpawn(particle);
	SetVariantString(targetname);
	AcceptEntityInput(particle, "SetParent", particle, particle);
	SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
}

void OnDestroyedTeleporter(const char[] output, int caller, int activator, float delay)
{
	AcceptEntityInput(caller,"KillHierarchy");
}
// Fires a bunch of tracers to check if there is enough space for robots (and giants) to spawn.
// The player size can be found here: https://developer.valvesoftware.com/wiki/TF2/Team_Fortress_2_Mapper's_Reference
// Remember that giant's size is multiplied by 1.75 (some bosses uses 1.9).
bool CheckTeleportClamping(int teleporter, int client)
{
	float VecTeleporter[3], RayEndPos[3];
	// Array of angles to check, remember to change array size when adding/removing angles
	//								straigh up 1		angled roof 																		// floor6		7					8
	static float RayAngles[13][3] = { {270.0,0.0,0.0}, {225.0,0.0,0.0}, {225.0,90.0,0.0}, {225.0,180.0,0.0}, {225.0,270.0,0.0}, {0.0,0.0,0.0}, {0.0,90.0,0.0}, {0.0,180.0,0.0}, {0.0,270.0,0.0}, 
	{0.0,45.0,0.0}, {0.0,135.0,0.0}, {0.0,225.0,0.0}, {0.0,315.0,0.0},};
	// the minimum distances is not the same for each angle
	//										1 								5										10		
	static float flMinDists_Normal[13] = { 185.0 ,110.0 ,110.0 ,110.0 ,110.0 ,64.0 ,64.0 ,64.0 ,64.0 ,64.0 ,64.0 ,64.0 ,64.0};
	static float flMinDists_Small[13] = { 120.0 ,80.0 ,80.0 ,80.0 ,80.0 ,48.0 ,48.0 ,48.0 ,48.0 ,48.0 ,48.0 ,48.0 ,48.0};
	float fldistance;
	GetEntPropVector(teleporter, Prop_Send, "m_vecOrigin", VecTeleporter);
	VecTeleporter[2] += 5;
	
	bool bSmallMap = IsSmallMap();
	Handle Tracer = null;
	
	for(int i = 0;i < sizeof(RayAngles);i++)
	{
		Tracer = TR_TraceRayFilterEx(VecTeleporter, RayAngles[i], MASK_SHOT, RayType_Infinite, TraceFilterIgnorePlayers, teleporter);
		if( Tracer != null && TR_DidHit(Tracer) ) // tracer hit something
		{
			TR_GetEndPosition(RayEndPos, Tracer);
			fldistance = GetVectorDistance(VecTeleporter, RayEndPos);
			if( bSmallMap ) // Small map mode?
			{
				if(fldistance < flMinDists_Small[i])
				{
					TE_SetupBeamPoints(VecTeleporter, RayEndPos, g_iLaserSprite, g_iHaloSprite, 0, 0, 5.0, 1.0, 1.0, 1, 1.0, {255, 0, 0, 255}, 0); // show a red beam to help with teleporter placement
					TE_SendToClient(client, 0.1);
					CloseHandle(Tracer);
					return true;
				}
			}
			else
			{
				if(fldistance < flMinDists_Normal[i])
				{
					TE_SetupBeamPoints(VecTeleporter, RayEndPos, g_iLaserSprite, g_iHaloSprite, 0, 0, 5.0, 1.0, 1.0, 1, 1.0, {255, 0, 0, 255}, 0); // show a red beam to help with teleporter placement
					TE_SendToClient(client, 0.1);
					CloseHandle(Tracer);
					return true;
				}			
			}
			if(IsDebugging())
			{
				TE_SetupBeamPoints(VecTeleporter, RayEndPos, g_iLaserSprite, g_iHaloSprite, 0, 0, 5.0, 1.0, 1.0, 1, 1.0, {255, 255, 255, 255}, 0); // if debug is enabled, create a white beam to visualize the rays
				TE_SendToClient(client, 0.1);				
			}
		}
		else
		{
			if(IsDebugging())
			{
				PrintToConsole(client, "Ray ID: %i was null or did not hit something", i);
				PrintToConsole(client, "Ray Angles for ray %d: %f %f %f", i, RayAngles[i][0], RayAngles[i][1], RayAngles[i][2]);
			}
		}
		CloseHandle( Tracer );
		Tracer = null;
	}

	return false;
}

bool TraceFilterIgnorePlayers(int entity, int contentsMask)
{
    if(entity >= 1 && entity <= MaxClients)
    {
        return false;
    }
    if(entity != 0)
        return false;
  
    return true;
}

// explodes the bomb hatch using the tank's logic_relay
void TriggerHatchExplosion()
{
	int i = -1;
	
	// Method 1: Trigger round win by exploding the hatch using the tank relay.
	// At least on official MVM maps, the tank relay will also trigger game_round_win
	while ((i = FindEntityByClassname(i, "logic_relay")) != -1)
	{
		if(IsValidEntity(i))
		{
			char strName[50];
			GetEntPropString(i, Prop_Data, "m_iName", strName, sizeof(strName));
			if(strcmp(strName, g_strHatchTrigger, false) == 0)
			{
				AcceptEntityInput(i, "Trigger");
				return;
			}
		} 
	}
	
	// Method 2: Tank trigger could not be found or can not be used ( eg: doesn't trigger game_round_win for some reason )
	// So this time the plugin will search for the game_round_win itself and trigger it manually.
	i = -1;
	while ((i = FindEntityByClassname(i, "game_round_win")) != -1)
	{
		if(IsValidEntity(i))
		{
			char strName[50];
			GetEntPropString(i, Prop_Data, "m_iName", strName, sizeof(strName));
			if( GetEntProp(i, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Blue) )
			{
				AcceptEntityInput(i, "RoundWin");
			}
		} 
	}
	
	// Finally we check if we have a relay to trigger the cinematic explosion of the bomb hatch
	// Make sure the relay used here doesn't trigger game_round_win again.
	i = -1;
	while ((i = FindEntityByClassname(i, "logic_relay")) != -1)
	{
		if(IsValidEntity(i))
		{
			char strName[50];
			GetEntPropString(i, Prop_Data, "m_iName", strName, sizeof(strName));
			if(strcmp(strName, g_strExploTrigger, false) == 0)
			{
				AcceptEntityInput(i, "Trigger"); // 
				return;
			}
		} 
	}
}

void CreateTEParticle(	char strParticle[128],
						float OriginVec[3]=NULL_VECTOR,
						float StartVec[3]=NULL_VECTOR,
						float AnglesVec[3]=NULL_VECTOR,
						float flDelay=0.0,
						int iEntity=-1,
						int iAttachType=-1,
						int iAttachPoint=-1 )
{
	int ParticleTable = FindStringTable("ParticleEffectNames");
	if( ParticleTable == INVALID_STRING_TABLE )
	{
		LogError("Could not find String Table \"ParticleEffectNames\"");
		return;
	}
	int iCounter = GetStringTableNumStrings(ParticleTable);
	int iParticleIndex = INVALID_STRING_INDEX;
	char Temp[128];
	
	for(int i = 0;i < iCounter; i++)
	{
		ReadStringTable(ParticleTable, i, Temp, sizeof(Temp));
		if(StrEqual(Temp, strParticle, false))
		{
			iParticleIndex = i;
			break;
		}
	}
	if( iParticleIndex == INVALID_STRING_INDEX )
	{
		LogError("Could not find particle named \"%s\"", strParticle);
		return;
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", OriginVec[0]);
	TE_WriteFloat("m_vecOrigin[1]", OriginVec[1]);
	TE_WriteFloat("m_vecOrigin[2]", OriginVec[2]);
	TE_WriteFloat("m_vecStart[0]", StartVec[0]);
	TE_WriteFloat("m_vecStart[1]", StartVec[1]);
	TE_WriteFloat("m_vecStart[2]", StartVec[2]);
	TE_WriteVector("m_vecAngles", AnglesVec);
	TE_WriteNum("m_iParticleSystemIndex", iParticleIndex);
	
	if( iEntity != -1 )
	{
		TE_WriteNum("entindex", iEntity);
	}
	if( iAttachType != -1 )
	{
		TE_WriteNum("m_iAttachType", iAttachType);
	}
	if( iAttachPoint != -1 )
	{
		TE_WriteNum("m_iAttachmentPointIndex", iAttachPoint);
	}
	
	TE_SendToAll(flDelay);
}

void SentryBuster_Explode( client )
{
	if( !IsPlayerAlive(client) )
		return;
	
	CreateTimer( 1.98, Timer_SentryBuster_Explode, client, TIMER_FLAG_NO_MAPCHANGE );
	float BusterPosVec[3];
	GetClientAbsOrigin(client, BusterPosVec);
	EmitGameSoundToAll("MVM.SentryBusterSpin", client, SND_NOFLAGS, client, BusterPosVec);
	
	SetEntProp( client, Prop_Data, "m_takedamage", 0, 1 );
}

bool CanSeeTarget(int iEntity,int iOther, float flMaxDistance = 0.0 )
{
	if( iEntity <= 0 || iOther <= 0 || !IsValidEntity(iEntity) || !IsValidEntity(iOther) )
		return false;
	
	float vecStart[3], vecStartMaxs[3], vecTarget[3], vecTargetMaxs[3], vecEnd[3];
	
	GetEntPropVector( iEntity, Prop_Data, "m_vecOrigin", vecStart );
	GetEntPropVector( iEntity, Prop_Send, "m_vecMaxs", vecStartMaxs );
	GetEntPropVector( iOther, Prop_Data, "m_vecOrigin", vecTarget );
	GetEntPropVector( iOther, Prop_Send, "m_vecMaxs", vecTargetMaxs );
	
	vecStart[2] += vecStartMaxs[2] / 2.0;
	vecTarget[2] += vecTargetMaxs[2] / 2.0;
	
	if( flMaxDistance > 0.0 )
	{
		float flDistance = GetVectorDistance( vecStart, vecTarget );
		if( flDistance > flMaxDistance )
		{
			return false;
		}
	}
	
	Handle hTrace = TR_TraceRayFilterEx( vecStart, vecTarget, MASK_VISIBLE, RayType_EndPoint, TraceFilterSentryBuster, iOther );
	if( !TR_DidHit( hTrace ) )
	{
		CloseHandle( hTrace );
		return false;
	}
	
	int iHitEnt = TR_GetEntityIndex( hTrace );
	TR_GetEndPosition( vecEnd, hTrace );
	CloseHandle( hTrace );
	
	if( iHitEnt == iOther || GetVectorDistanceMeter( vecEnd, vecTarget ) <= 1.0 )
	{
		return true;
	}
	
	return false;
}

float GetVectorDistanceMeter( const float vec1[3], const float vec2[3], bool squared = false )
{
	return ( GetVectorDistance( vec1, vec2, squared ) / 50.00 );
}

bool TraceFilterSentryBuster(int iEntity,int iContentsMask, any iOther )
{
	if( iEntity < 0 || !IsValidEntity(iEntity) )
		return false;
		
	if( iEntity == iOther )
		return true;
		
	if( IsValidClient(iEntity) )
	{
		if( IsClientInGame(iEntity) && IsPlayerAlive(iEntity) && TF2_GetClientTeam(iEntity) == TFTeam_Red )
		{
			return true;
		}
	}
	
	char strClassName[64];
	GetEntityClassname(iEntity, strClassName, sizeof(strClassName));
	
	if( StrContains(strClassName, "obj_", false ) )
	{
		if( GetEntProp( iEntity, Prop_Send, "m_iTeamNum" ) != view_as<int>(TFTeam_Blue) )
		{
			return true;
		}
		else
			return false;
	}
	
	return false;
}

void DealDamage(int entity, int inflictor, int attacker, float damage, int damageType, int weapon=-1, const float damageForce[3]=NULL_VECTOR, const float damagePosition[3]=NULL_VECTOR)
{
	if( entity > 0 && IsValidEntity(entity) && ( entity > MaxClients || IsClientInGame(entity) && IsPlayerAlive(entity) ) && damage > 0 )
	{
		SDKHooks_TakeDamage(entity, inflictor, attacker, damage, damageType, weapon, damageForce, damagePosition);
	}
}

int CreateParticle( float flOrigin[3], const char[] strParticle, float flDuration = -1.0 )
{
	int iParticle = CreateEntityByName( "info_particle_system" );
	if( IsValidEdict( iParticle ) )
	{
		DispatchKeyValue( iParticle, "effect_name", strParticle );
		DispatchKeyValue( iParticle, "targetname", "bwrr_particle_effect" );
		DispatchSpawn( iParticle );
		TeleportEntity( iParticle, flOrigin, NULL_VECTOR, NULL_VECTOR );
		ActivateEntity( iParticle );
		AcceptEntityInput( iParticle, "Start" );
		if( flDuration >= 0.0 )
			CreateTimer( flDuration, Timer_DeleteParticle, EntIndexToEntRef(iParticle) );
	}
	return iParticle;
}

void Robot_GibGiant(int client, float OriginVec[3])
{
	if( IsFakeClient(client) )
		return;

	int Ent;

	//Initialize:
	Ent = CreateEntityByName("tf_ragdoll");

	//Write:
	SetEntPropVector(Ent, Prop_Send, "m_vecRagdollOrigin", OriginVec); 
	SetEntProp(Ent, Prop_Send, "m_iPlayerIndex", client); 
	SetEntPropVector(Ent, Prop_Send, "m_vecForce", NULL_VECTOR);
	SetEntPropVector(Ent, Prop_Send, "m_vecRagdollVelocity", NULL_VECTOR);
	SetEntProp(Ent, Prop_Send, "m_bGib", 1);

	//Send:
	DispatchSpawn(Ent);

	//Remove Body:
	CreateTimer(0.05, Timer_RemoveBody, client, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(8.0, Timer_RemoveGibs, Ent, TIMER_FLAG_NO_MAPCHANGE);
}

// Initialze config
void Config_Init()
{
	g_aSpyTeleport = new ArrayList(3);
	g_aEngyTeleport = new ArrayList(3);
}

// load spies teleport position
void Config_LoadSpyTelePos()
{
	char mapname[64], buffer[256];
	float OriginVec[3];
	
	g_aSpyTeleport.Clear();
	
	GetCurrentMap(buffer, sizeof(buffer));
	
	// Some servers might use workshop
	if( !GetMapDisplayName(buffer, mapname, sizeof(mapname)) )
	{
		strcopy(mapname, sizeof(mapname), buffer); // use the result from GetCurrentMap if this fails.
	}

	BuildPath(Path_SM, g_strConfigFile, sizeof(g_strConfigFile), "configs/bwrr/spy/");
	
	Format(g_strConfigFile, sizeof(g_strConfigFile), "%s%s.cfg", g_strConfigFile, mapname);
	
	if(!FileExists(g_strConfigFile))
	{
		LogMessage("Spy teleport config file not found for map \"%s\"", mapname);
		return;
	}
	
	KeyValues kv = new KeyValues("SpyTeleport");
	kv.ImportFromFile(g_strConfigFile);
	
	// Jump into the first subsection
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		return;
	}
	
	do
	{
		kv.GetVector("origin", OriginVec, NULL_VECTOR);
		g_aSpyTeleport.PushArray(OriginVec);
	} while (kv.GotoNextKey());
	
	if( IsDebugging() )
		LogMessage("Loaded %i spy teleport positions.", g_aSpyTeleport.Length);
	
	delete kv;
}

// load engineer teleport position
void Config_LoadEngyTelePos()
{
	char mapname[64], buffer[256];
	float OriginVec[3];
	
	g_aEngyTeleport.Clear();
	
	GetCurrentMap(buffer, sizeof(buffer));
	
	// Some servers might use workshop
	if( !GetMapDisplayName(buffer, mapname, sizeof(mapname)) )
	{
		strcopy(mapname, sizeof(mapname), buffer); // use the result from GetCurrentMap if this fails.
	}

	BuildPath(Path_SM, g_strConfigFile, sizeof(g_strConfigFile), "configs/bwrr/engy/");
	
	Format(g_strConfigFile, sizeof(g_strConfigFile), "%s%s.cfg", g_strConfigFile, mapname);
	
	if(!FileExists(g_strConfigFile))
	{
		//LogMessage("Engineer teleport config file not found for map \"%s\"", mapname);
		return;
	}
	
	KeyValues kv = new KeyValues("EngyTeleport");
	kv.ImportFromFile(g_strConfigFile);
	
	// Jump into the first subsection
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		return;
	}
	
	do
	{
		kv.GetVector("origin", OriginVec, NULL_VECTOR);
		g_aEngyTeleport.PushArray(OriginVec);
	} while (kv.GotoNextKey());
	
	delete kv;
	
	if( IsDebugging() )
		LogMessage("Loaded %i engineer teleport positions.", g_aEngyTeleport.Length);
}

// Gets an origin to teleport a spy
// If target_player is set, try to find one near the target
// returns true if a spot is found
bool GetSpyTeleportFromConfig(float origin[3], int target_player = -1)
{
	float tVec[3], rVec[3]; // target_player's vector, return vector
	int iBestCell = -1, iCellMax = (g_aSpyTeleport.Length - 1);
	float current_dist, smallest_dist = 999999.0;
	
	if( g_aSpyTeleport.Length < 1 )
		return false;
	
	if( IsValidClient(target_player) )
	{
		GetClientAbsOrigin(target_player, tVec);
		
		for(int i = 0;i < iCellMax;i++)
		{
		
			g_aSpyTeleport.GetArray(i, rVec);
			
			current_dist = GetVectorDistance(rVec, tVec);
			
			if( current_dist < smallest_dist && current_dist > 256.0 ) 
			{
				smallest_dist = current_dist;
				iBestCell = i;
			}
		}
		
		if( iBestCell != -1 )
		{
			g_aSpyTeleport.GetArray(iBestCell, origin);
			return true;
		}
		else
			return false;
	}
	else
	{
		g_aSpyTeleport.GetArray(GetRandomInt(0, (g_aSpyTeleport.Length - 1)), origin);
		return true;
	}
}

// Gets an origin to teleport an engineer
// returns true if a spot is found
bool GetEngyTeleportFromConfig(float origin[3], float bombpos[3])
{
	float rVec[3];
	int iBestCell = -1, iCellMax = (g_aEngyTeleport.Length - 1);
	float current_dist, min_dist = 750.0, smallest_dist = 999999.0;
	
	
	if( g_aEngyTeleport.Length < 1 )
		return false;
	
	for(int i = 0;i < iCellMax;i++)
	{
	
		g_aEngyTeleport.GetArray(i, rVec);
		
		current_dist = GetVectorDistance(rVec, bombpos);
		
		if( current_dist < smallest_dist && current_dist > min_dist ) 
		{
			smallest_dist = current_dist;
			iBestCell = i;
		}
	}
	
	if( iBestCell != -1 )
	{
		g_aEngyTeleport.GetArray(iBestCell, origin);
		return true;
	}
	else
		return false;
}

// map specific config
void Config_LoadMap()
{
	char mapname[64], buffer[256];
	
	GetCurrentMap(buffer, sizeof(buffer));
	
	// Some servers might use workshop
	if( !GetMapDisplayName(buffer, mapname, sizeof(mapname)) )
	{
		strcopy(mapname, sizeof(mapname), buffer); // use the result from GetCurrentMap if this fails.
	}

	BuildPath(Path_SM, g_strConfigFile, sizeof(g_strConfigFile), "configs/bwrr/map/");
	
	Format(g_strConfigFile, sizeof(g_strConfigFile), "%s%s.cfg", g_strConfigFile, mapname);
	
	if(!FileExists(g_strConfigFile))
	{
		SetFailState("Map \"%s\" configuration not found.", mapname);
	}
	
	KeyValues kv = new KeyValues("MapConfig");
	kv.ImportFromFile(g_strConfigFile);
	
	// Jump into the first subsection
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		return;
	}
	
	do
	{
		kv.GetSectionName(buffer, sizeof(buffer));
		if( StrEqual(buffer, "SpawnPoints", false) )
		{
			kv.GetString("normal", g_strNormalSpawns, sizeof(g_strNormalSpawns));
			kv.GetString("giant", g_strGiantSpawns, sizeof(g_strGiantSpawns));
			kv.GetString("sniper", g_strSniperSpawns, sizeof(g_strSniperSpawns));
			kv.GetString("spy", g_strSpySpawns, sizeof(g_strSpySpawns));
		}
		else if( StrEqual(buffer, "HatchTrigger", false) )
		{
			kv.GetString("tank_relay", g_strHatchTrigger, sizeof(g_strHatchTrigger), "boss_deploy_relay");
			kv.GetString("cap_relay", g_strExploTrigger, sizeof(g_strExploTrigger), "cap_destroy_relay");
		}
	} while (kv.GotoNextKey());
	
	delete kv;
	
	g_iSplitSize[0] = ExplodeString(g_strNormalSpawns, ",", g_strNormalSplit, sizeof(g_strNormalSplit), sizeof(g_strNormalSplit[]));
	g_iSplitSize[1] = ExplodeString(g_strGiantSpawns, ",", g_strGiantSplit, sizeof(g_strGiantSplit), sizeof(g_strGiantSplit[]));
	g_iSplitSize[2] = ExplodeString(g_strSniperSpawns, ",", g_strSniperSplit, sizeof(g_strSniperSplit), sizeof(g_strSniperSplit[]));
	g_iSplitSize[3] = ExplodeString(g_strSpySpawns, ",", g_strSpySplit, sizeof(g_strSpySplit), sizeof(g_strSpySplit[]));
}

// searches for red sentry guns
// also checks for kill num
bool ShouldDispatchSentryBuster()
{
	int i = -1;
	int iKills;
	while ((i = FindEntityByClassname(i, "obj_sentrygun")) != -1)
	{
		if( IsValidEntity(i) )
		{
			if( GetEntProp( i, Prop_Send, "m_iTeamNum" ) == view_as<int>(TFTeam_Red) )
			{
				iKills = GetEntProp(i, Prop_Send, "SentrygunLocalData", _, 0);
				if( iKills >= c_iBusterMinKills.IntValue ) // found threat
					return true;
			}
		}
	}
	
	return false;
}

// gives wallhacks to sentry busters
void BusterWallhack(int client)
{
	int i = -1;
	int iKills;
	float origin[3];
	float start[3];
	GetClientEyePosition(client, start);
	
	while ((i = FindEntityByClassname(i, "obj_sentrygun")) != -1)
	{
		if( IsValidEntity(i) )
		{
			if( GetEntProp( i, Prop_Send, "m_iTeamNum" ) == view_as<int>(TFTeam_Red) )
			{
				iKills = GetEntProp(i, Prop_Send, "SentrygunLocalData", _, 0);
				if( iKills >= c_iBusterMinKills.IntValue ) // found threat
				{
					GetEntPropVector( i, Prop_Data, "m_vecOrigin", origin );
					TE_SetupBeamPoints(start, origin, g_iLaserSprite, g_iHaloSprite, 0, 0, 0.5, 1.0, 1.0, 1, 1.0, {0, 0, 255, 255}, 0);
					TE_SendToClient(client, 0.0);
				}
			}
		}
	}	
}

void TF2_PlaySequence(int client, const char[] sequence)
{
	SDKCall(g_hSDKPlaySpecificSequence, client, sequence);
}

// code from Pelipoika's bot control
void DisableAnim(int userid)
{
	static int iCount = 0;

	int client = GetClientOfUserId(userid);
	if(client > 0)
	{
		if(iCount > 6)
		{		
			SetVariantString("1");
			AcceptEntityInput(client, "SetCustomModelRotates");
			
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);
			
			iCount = 0;
		}
		else
		{
			TF2_PlaySequence(client, "primary_deploybomb");			
			RequestFrame(DisableAnim, userid);
			iCount++;
		}
	}
}