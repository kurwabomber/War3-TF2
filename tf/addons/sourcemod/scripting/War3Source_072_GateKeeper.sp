#include <war3source>

//#if defined do_not_compile_this_code
//	#endinput
//#endif
#assert GGAMEMODE == MODE_WAR3SOURCE

#if GGAMETYPE != GGAME_TF2
	#endinput
#endif

// Save file as a another name and uncomment below and begin working on a new race.
//#assert GGAMETYPE == DONTCOMPILE

#define RACE_ID_NUMBER 720
#define RACE_LONGNAME "Gate Keeper"
#define RACE_SHORTNAME "gatekeeper"
#define RACE_MYINFO_NAME "Race - Gate Keeper"
#define RACE_MYINFO_DESC "The Gate Keeper race."

#pragma semicolon 1

float emptypos[3];

int Ward_BehaviorIndex;

int MaximumWards[]={0,1,2,3,4,5,6,7,8};
int WardData[]={0,1,1,1,1,1,1,1,1};

float TeleporterMaxDistance[9] = { 1.0, 1000.0, 2000.0, 4000.0, 8000.0, 10000.0, 12000.0, 14000.0, 15000.0};

int TeleporterCache[34] = {-1,...}; //34 maxclients static number

int thisRaceID;

int SKILL_TELEPORT_MENU, SKILL_TELEPORT_WARD; //,SKILL_2,ABILITY_1,ULT;

public Plugin:myinfo =
{
	name = RACE_MYINFO_NAME,
	author = "El Diablo",
	description = RACE_MYINFO_DESC,
	version = "1.0",
	url = "http://war3evo.info"
};

bool HooksLoaded = false;
public void Load_Hooks()
{
	if(HooksLoaded) return;
	HooksLoaded = true;

	W3Hook(W3Hook_OnAbilityCommand, OnAbilityCommand);
}
public void UnLoad_Hooks()
{
	if(!HooksLoaded) return;
	HooksLoaded = false;

	W3UnhookAll(W3Hook_OnAbilityCommand);
}
bool RaceDisabled=true;
public OnWar3RaceEnabled(newrace)
{
	if(newrace==thisRaceID)
	{
		Load_Hooks();

		RaceDisabled=false;
	}
}
public OnWar3RaceDisabled(oldrace)
{
	if(oldrace==thisRaceID)
	{
		RaceDisabled=true;

		UnLoad_Hooks();
	}
}

bool RoundInProgress = true;

public OnPluginStart()
{
	HookEvent("teamplay_round_start", HookRoundStart, EventHookMode_Post);
	HookEvent("teamplay_waiting_begins", HookRoundStart, EventHookMode_Post);

	HookEvent("teamplay_round_win", HookRoundEnd, EventHookMode_Post);
	HookEvent("teamplay_waiting_ends", HookRoundEnd, EventHookMode_Post);
	HookEvent("teamplay_round_stalemate", HookRoundEnd, EventHookMode_Post);

	Ward_BehaviorIndex = War3_CreateWardBehavior("gateward", "Gate ward", "Teleports allies to your last teleport point");
}

public HookRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	RoundInProgress = true;
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	RoundInProgress = false;
}

// War3Source Functions
public OnAllPluginsLoaded()
{
	//LoadTranslations("w3s.race.undead.phrases");
	War3_RaceOnPluginStart(RACE_SHORTNAME);
}

public OnPluginEnd()
{
	if(LibraryExists("RaceClass"))
		War3_RaceOnPluginEnd(RACE_SHORTNAME);
}
public OnWar3LoadRaceOrItemOrdered2(num,reloadrace_id,String:shortname[])
{
	if(num==RACE_ID_NUMBER||(reloadrace_id>0&&StrEqual(RACE_SHORTNAME,shortname,false)))
	{
		thisRaceID=War3_CreateNewRace(RACE_LONGNAME,RACE_SHORTNAME,reloadrace_id,"Teleports,Wards,Fun");

		SKILL_TELEPORT_WARD=War3_AddRaceSkill(thisRaceID,"Teleporter Ward","(+ability) Teleports players to the last location you teleported to.\nAllows for 1 to 8 wards.",false,8);
		SKILL_TELEPORT_MENU=War3_AddRaceSkill(thisRaceID,"Teleporter Menu","(+ability2) Brings up a menu of all teleporters on the map,\nand allows you to teleport to them.\nYou can travel 1000 to 15000 units away.",false,8);
		//SKILL_3=War3_AddRaceSkill(thisRaceID,"SKILL_3_NAME","SKILL_3_DESCRIPTION",false,4);
		//ABILITY_1=War3_AddRaceSkill(thisRaceID,"ABILITY_1_NAME","ABILITY_1_DESCRIPTION",false,4);
		//ABILITY_2=War3_AddRaceSkill(thisRaceID,"ABILITY_2_NAME","ABILITY_2_DESCRIPTION",false,4);
		//ULT=War3_AddRaceSkill(thisRaceID,"ULTIMATE_NAME","(+ultimate) ULTIMATE_DESCRIPTION",true,4);

		War3_CreateRaceEnd(thisRaceID);

		Ward_BehaviorIndex = War3_CreateWardBehavior("gateward", "Gate ward", "Teleports allies to your last teleport point");

		//W3SkillCooldownOnSpawn(thisRaceID,ULT_OVERLOAD,10.0,_); //translated doesnt use this "Chain Lightning"
		int GetRaceID=War3_GetRaceIDByShortname("hyperC");
		if(GetRaceID>0)
		{
			War3_SetRaceDependency(thisRaceID, GetRaceID, 30);
		}
		GetRaceID=War3_GetRaceIDByShortname("humanally");
		if(GetRaceID>0)
		{
			War3_SetRaceDependency(thisRaceID, GetRaceID, 32);
		}
	}
}

public OnWar3PluginReady()
{
	int GetRaceID=War3_GetRaceIDByShortname("hyperC");
	if(GetRaceID>0)
	{
		War3_SetRaceDependency(thisRaceID, GetRaceID, 30);
	}
	GetRaceID=War3_GetRaceIDByShortname("humanally");
	if(GetRaceID>0)
	{
		War3_SetRaceDependency(thisRaceID, GetRaceID, 32);
	}
}

//public public void OnWar3EventSpawn (int client)
//{
//}

// This race wont run without the other races
/*
public OnMapStart()
{
}

public OnAddSound(sound_priority)
{
	if(sound_priority==PRIORITY_MEDIUM)
	{
		War3_AddSound(overload1);
		War3_AddSound(overloadzap);
		War3_AddSound(overloadstate);
	}
}*/

//public OnWar3PluginReady()
//{
//}

public OnRaceChanged(client,oldrace,newrace)
{
	if(newrace==thisRaceID)
	{
		InitPassiveSkills(client);
	}
	else //if(newrace==oldrace)
	{
		RemovePassiveSkills(client);
	}
}

/* ****************************** InitPassiveSkills ************************** */
public InitPassiveSkills(client)
{
	if(ValidPlayer(client))
	{
	}
}
/* ****************************** RemovePassiveSkills ************************** */
public RemovePassiveSkills(client)
{
	if(ValidPlayer(client))
	{
	}
}

public void OnSkillLevelChanged(int client, int currentrace, int skill, int newskilllevel, int oldskilllevel)
{
	if(ValidPlayer(client))
	{
		InitPassiveSkills(client);
	}
}
/*
public OnW3Denyable(W3DENY:event,client)
{
	if(RaceDisabled)
		return;

	if((event == DN_CanBuyItem1) && (W3GetVar(EventArg1) == War3_GetItemIdByShortname("mask")))
	{
		if(War3_GetRace(client)==thisRaceID)
		{
			W3Deny();
		}
	}
}*/


public void OnAbilityCommand(int client, int ability, bool pressed, bool bypass)
{
	if(RaceDisabled)
		return;

	if(War3_GetRace(client)==thisRaceID && ability==2 && pressed && IsPlayerAlive(client))
	{
		new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_TELEPORT_MENU);
		if(skill_level>0&&!Silenced(client))
		{
			if(!Spying(client))
			{
				if(War3_SkillNotInCooldown(client,thisRaceID,SKILL_TELEPORT_MENU,true))
				{
					if(RoundInProgress)
					{
						ShowTeleporterMenu(client);
						War3_CooldownMGR(client,15.0,thisRaceID,SKILL_TELEPORT_MENU,_,_);
					}
					else
					{
						War3_ChatMessage(client,"You must wait until round starts to use this ability.");
					}
				}
			}
			else
			{
				War3_ChatMessage(client,"You can not be invis or disguised while using this ability.");
			}
		}
	}
	else if(War3_GetRace(client)==thisRaceID && ability==0 && pressed && IsPlayerAlive(client))
	{
		new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_TELEPORT_WARD);
		if(skill_level>0&&!Silenced(client))
		{
			if(!Spying(client))
			{
				if(War3_SkillNotInCooldown(client,thisRaceID,SKILL_TELEPORT_WARD,true))
				{
					if(RoundInProgress)
					{
						if(War3_GetWardCount(client)<MaximumWards[skill_level])
						{
							War3_CastSpell(client, 0, SpellEffectsLight, SPELLCOLOR_VIOLET, thisRaceID, SKILL_TELEPORT_WARD, 2.5);
							War3_CooldownMGR(client,2.0,thisRaceID,SKILL_TELEPORT_WARD,_,_);
						}
						else
						{
							W3MsgNoWardsLeft(client);
						}
					}
					else
					{
						War3_ChatMessage(client,"You must wait until round starts to use this ability.");
					}
				}
			}
			else
			{
				War3_ChatMessage(client,"You can not be invis or disguised while using this ability.");
			}
		}
	}
	/*
	if(War3_GetRace(client)==thisRaceID && ability==2 && pressed && IsPlayerAlive(client))
	{
		new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_3);
		if(skill_level>0)
		{
			if(War3_SkillNotInCooldown(client,thisRaceID,SKILL_3,true))
			{
				if(!Silenced(client))
				{
				}
			}
		}
	}*/
}

/*
public Action OnW3TakeDmgBulletPre(int victim, int attacker, float damage, int damagecustom)
{
	if(RaceDisabled)
		return;
}*/

/*
public void OnUltimateCommand(int client, int race, bool pressed, bool bypass)
{
	if(RaceDisabled)
		return;

	if(race==thisRaceID && pressed && IsPlayerAlive(client))
	{
		new skill=War3_GetSkillLevel(client,thisRaceID,ULT_OVERLOAD);
		if(skill>0)
		{
			if(!Silenced(client)&&(bypass||War3_SkillNotInCooldown(client,thisRaceID,ULT_OVERLOAD,true)))
			{
			}
		}
		else
		{
			W3MsgUltNotLeveled(client);
		}
	}
}*/

public ShowTeleporterMenu(client)
{
	Handle MenuHandle = CreateMenu(TeleporterMenu_Select);
	SetMenuExitButton(MenuHandle,true);
	//SetMenuExitBackButton(MenuHandle, true);

	SetMenuTitle(MenuHandle,"[+ABILITY] Teleporters in Range:");

	int iEnt;
	int TeleporterOwner;
	char sClientName[32];
	char sMenuItem[128];
	char sMenuEntity[128];

	float TeleporterPosition[3];
	float ClientPosition[3];

	float dist;

	int skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_TELEPORT_MENU);

	int CountTeleporters = 0;

	//native War3_CachedPosition(client,Float:position[3]);

	War3_CachedPosition(client,ClientPosition);

	while ((iEnt = FindEntityByClassname(iEnt, "obj_teleporter")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", TeleporterPosition);

		dist=GetVectorDistance(ClientPosition,TeleporterPosition);

		if(dist<=TeleporterMaxDistance[skill_level])
		{
			TeleporterOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hBuilder");

			if(ValidPlayer(TeleporterOwner))
			{
				GetClientName(TeleporterOwner,STRING(sClientName));

				if(TF2_GetObjectMode(iEnt) == TFObjectMode_Entrance)
				{
					Format(sMenuItem, sizeof(sMenuItem), "Entrance - %s - %s",sClientName,GetClientTeam(TeleporterOwner)==2?"RED":"BLUE");
				}
				else
				{
					Format(sMenuItem, sizeof(sMenuItem), "Exit - %s - %s",sClientName,GetClientTeam(TeleporterOwner)==2?"RED":"BLUE");
				}

				Format(sMenuEntity, sizeof(sMenuEntity), "%d", iEnt);

				AddMenuItem(MenuHandle,sMenuEntity,sMenuItem,ITEMDRAW_DEFAULT);

				CountTeleporters++;
			}
		}
	}

	if(CountTeleporters>0)
	{
		DisplayMenu(MenuHandle,client,20);
	}
	else
	{
		War3_ChatMessage(client,"You detect no teleporters within range.");
	}
}


public TeleporterMenu_Select(Handle:menu,MenuAction:action,client,selection)
{
	if(action==MenuAction_Select)
	{
		char SelectionInfo[32];
		char SelectionDispText[256];
		new SelectionStyle;
		GetMenuItem(menu,selection,SelectionInfo,sizeof(SelectionInfo),SelectionStyle, SelectionDispText,sizeof(SelectionDispText));
		int TeleporterEnt=StringToInt(SelectionInfo);

		if(ValidPlayer(client) && IsValidEntity(TeleporterEnt))
		{
			TeleporterCache[client] = TeleporterEnt;

			float TeleporterPosition[3];
			GetEntPropVector(TeleporterEnt, Prop_Send, "m_vecOrigin", TeleporterPosition);
			TeleporterPosition[2] += 40.0;

			decl Float:special[3];
			decl Float:top[3];
			GetClientEyePosition(client, special);
			special[2] += 11.0;
			top = special;
			top[2] -= 30.0;

			if (GetClientTeam(client) == 2) {
				TimedParticle(TeleporterEnt, "smoke_rocket_steam", TeleporterPosition, 10.0);
				TimedParticle(client, "smoke_rocket_steam", special, 10.0);
				TimedParticle(client, "smoke_rocket_steam", special, 10.0);
				TimedParticle(client, "smoke_rocket_steam", top, 10.0);
				TimedParticle(client, "smoke_rocket_steam", top, 10.0);
				TimedParticle(client, "player_recent_teleport_red", top, 10.0);
			}
			else {
				TimedParticle(TeleporterEnt, "smoke_rocket_steam", TeleporterPosition, 10.0);
				TimedParticle(client, "smoke_rocket_steam", special, 10.0);
				TimedParticle(client, "smoke_rocket_steam", special, 10.0);
				TimedParticle(client, "smoke_rocket_steam", top, 10.0);
				TimedParticle(client, "smoke_rocket_steam", top, 10.0);
				TimedParticle(client, "player_recent_teleport_blue", top, 10.0);
			}

			War3_CastSpell(client, 0, SpellEffectsLight, SPELLCOLOR_VIOLET, thisRaceID, SKILL_TELEPORT_MENU, 5.0);
		}
	}
	if(action==MenuAction_End)
	{
		CloseHandle(menu);
	}
}


//====================================================================================
//						OnWar3CastingFinished
//====================================================================================
public OnWar3CastingFinished(client, target, W3SpellEffects:spelleffect, String:SpellColor[], raceid, skillid)
{
	//DP("casting finished");
	if(ValidPlayer(client,true) && raceid==thisRaceID)
	{
		if(skillid == SKILL_TELEPORT_MENU)
		{
			if(!Spying(client))
			{
				new skill_level=War3_GetSkillLevel(client,raceid,SKILL_TELEPORT_MENU);
				if(skill_level>0)
				{
					if(IsValidEntity(TeleporterCache[client]))
					{
						// teleport
						float TeleporterPosition[3];
						GetEntPropVector(TeleporterCache[client], Prop_Send, "m_vecOrigin", TeleporterPosition);

						// offset above teleport a little bit
						TeleporterPosition[2] += 20;

						int TeleporterOwner = GetEntPropEnt(TeleporterCache[client], Prop_Send, "m_hBuilder");

						if(GetClientTeam(TeleporterOwner) != GetClientTeam(client))
						{
							TF2_AddCondition(TeleporterOwner, TFCond_Ubercharged, 5.0);
						}

						TeleportEntity(client, TeleporterPosition, NULL_VECTOR, NULL_VECTOR);
/*
						decl Float:special[3];
						decl Float:top[3];
						GetClientEyePosition(client, special);
						special[2] += 11.0;
						top = special;
						top[2] -= 30.0;

						if (GetClientTeam(client) == 2) {
							TimedParticle(client, "smoke_rocket_steam", TeleporterPosition, 4.0);
							TimedParticle(client, "smoke_rocket_steam", special, 3.0);
							TimedParticle(client, "smoke_rocket_steam", special, 3.5);
							TimedParticle(client, "smoke_rocket_steam", top, 3.5);
							TimedParticle(client, "smoke_rocket_steam", top, 3.0);
							TimedParticle(client, "player_recent_teleport_red", top, 3.5);
						}
						else {
							TimedParticle(client, "smoke_rocket_steam", TeleporterPosition, 4.0);
							TimedParticle(client, "smoke_rocket_steam", special, 3.0);
							TimedParticle(client, "smoke_rocket_steam", special, 3.5);
							TimedParticle(client, "smoke_rocket_steam", top, 3.5);
							TimedParticle(client, "smoke_rocket_steam", top, 3.0);
							TimedParticle(client, "player_recent_teleport_blue", top, 3.5);
						}*/

						//TeleporterCache[client] = -1; // was uncommented
					}
					War3_CooldownMGR(client,10.0,thisRaceID,SKILL_TELEPORT_MENU,true,true);
				}
			}
			else
			{
				War3_ChatMessage(client,"You can not be invis or disguised while using this ability.");
			}
		}
		else if(skillid == SKILL_TELEPORT_WARD)
		{
			if(!Spying(client))
			{
				int skill_level=War3_GetSkillLevel(client,raceid,SKILL_TELEPORT_WARD);
				if(skill_level>0)
				{
					float location[3];
					GetClientAbsOrigin(client, location);
					if(War3_CreateWardMod(client, location, 60, 60.0, 2.0, "gateward", SKILL_TELEPORT_WARD, WardData, WARD_TARGET_TEAMMATES|WARD_TARGET_ENEMYS, false)>-1)
					{
						W3MsgCreatedWard(client, War3_GetWardCount(client), MaximumWards[skill_level]);
					}
				}
			}
			else
			{
				War3_ChatMessage(client,"You can not be invis or disguised while using this ability.");
			}
		}
	}
}


//====================================================================================
//						OnWar3CancelSpell_Post
//====================================================================================
public OnWar3CancelSpell_Post(client, raceid, skillid, target)
{
	if(ValidPlayer(client,true) && raceid==thisRaceID)
	{
		if(skillid == SKILL_TELEPORT_MENU)
		{
			War3_CooldownMGR(client,10.0,thisRaceID,SKILL_TELEPORT_MENU,false,true);
		}
		else if(skillid == SKILL_TELEPORT_WARD)
		{
			War3_CooldownMGR(client,10.0,thisRaceID,SKILL_TELEPORT_WARD,false,true);
		}
	}
}




TimedParticle(ent, String:name[], Float:pos[3], Float:time) {
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEntity(particle)) return;
	DispatchKeyValue(particle, "effect_name", name);
	TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(particle);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");

	if (ent > 0) {
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", ent, particle, 0);
	}
	CreateTimer(time, Timer_ParticleEnd, particle);
}

// *********************************************************************************************************************************************


public Action:Timer_ParticleEnd(Handle:timer, any:particle) {
	if (!IsValidEntity(particle)) return;
	char classn[32];
	GetEdictClassname(particle, classn, sizeof(classn));
	if (strcmp(classn, "info_particle_system") != 0) return;
	RemoveEdict(particle);
}



public OnWardExpire(wardindex, owner, behaviorID)
{
	if(RaceDisabled)
		return;

	if(ValidPlayer(owner) && War3_GetRace(owner)==thisRaceID)
	{
		new skill_level=War3_GetSkillLevel(owner,thisRaceID,SKILL_TELEPORT_WARD);
		W3Hint(owner,HINT_COOLDOWN_EXPIRED,4.0,"You now have %d/%d Teleporter Wards.", War3_GetWardCount(owner)-1, MaximumWards[skill_level]);
	}
}


//====================================================================================
//						OnWardPulse
//====================================================================================
public OnWardPulse(wardindex, behavior, wardtarget)
{
	if(RaceDisabled)
		return;

	if(behavior != Ward_BehaviorIndex)
	{
		return;
	}

	int beamcolor[4];
	int team = GetClientTeam(War3_GetWardOwner(wardindex));

	if (behavior == Ward_BehaviorIndex)
	{
		beamcolor = {186, 85, 211, 255};
		/*
		if(team == 2)
		{
			beamcolor = {186, 85, 211, 255};
		}
		else if(team == 3)
		{
			beamcolor = {0, 0, 128, 255};
		}*/
		War3_WardVisualEffect(wardindex, beamcolor, team, wardtarget, true);
	}
}

//====================================================================================
//						OnWardTrigger
//====================================================================================
public OnWardTrigger(wardindex, victim, owner, behavior)
{
	if(RaceDisabled)
		return;

	if (behavior == Ward_BehaviorIndex)
	{
		if(W3HasImmunity(victim, Immunity_Wards))
		{
			W3MsgSkillBlocked(victim, _, "Wards");
		}
		else
		{
			if(ValidPlayer(victim) && ValidPlayer(owner) && IsValidEntity(TeleporterCache[owner]))
			{
				// teleport
				float TeleporterPosition[3];
				GetEntPropVector(TeleporterCache[owner], Prop_Send, "m_vecOrigin", TeleporterPosition);

				// offset above teleport a little bit
				TeleporterPosition[2] += 20;

				emptypos[0]=0.0;
				emptypos[1]=0.0;
				emptypos[2]=0.0;

				getEmptyLocationHull(victim,TeleporterPosition);

				float special[3];
				float top[3];
				GetClientEyePosition(victim, special);
				special[2] += 11.0;
				top = special;
				top[2] -= 30.0;

				if(GetVectorLength(emptypos)>1.0){
					if (GetClientTeam(victim) == 2) {
						TimedParticle(TeleporterCache[owner], "smoke_rocket_steam", TeleporterPosition, 10.0);
						TimedParticle(victim, "critgun_weaponmodel_red", special, 10.0);
						TimedParticle(victim, "critgun_weaponmodel_red", special, 10.0);
						TimedParticle(victim, "critgun_weaponmodel_red", top, 10.0);
						TimedParticle(victim, "critgun_weaponmodel_red", top, 10.0);
						TimedParticle(victim, "player_recent_teleport_red", top, 10.0);
					}
					else if(GetClientTeam(victim) == 3){
						TimedParticle(TeleporterCache[owner], "smoke_rocket_steam", TeleporterPosition, 10.0);
						TimedParticle(victim, "critgun_weaponmodel_blu", special, 10.0);
						TimedParticle(victim, "critgun_weaponmodel_blu", special, 10.0);
						TimedParticle(victim, "critgun_weaponmodel_blu", top, 10.0);
						TimedParticle(victim, "critgun_weaponmodel_blu", top, 10.0);
						TimedParticle(victim, "player_recent_teleport_blue", top, 10.0);
					}

					int TeleporterOwner = GetEntPropEnt(TeleporterCache[owner], Prop_Send, "m_hBuilder");

					if(GetClientTeam(TeleporterOwner) != GetClientTeam(victim))
					{
						TF2_AddCondition(TeleporterOwner, TFCond_Ubercharged, 5.0);
					}

					TeleportEntity(victim, TeleporterPosition, NULL_VECTOR, NULL_VECTOR);
				}
				//TeleportEntity(victim, TeleporterPosition, NULL_VECTOR, NULL_VECTOR);
			}

			/*
			new team1=2;
			new team2=3;
			if(ValidPlayer(owner) && ValidPlayer(victim))
			{
				team1=GetClientTeam(victim);
				team2=GetClientTeam(owner);
			}
			if(team1==team2 && (GetClientButtons(victim) & IN_JUMP))
			{
				W3Hint(victim,HINT_SKILL_STATUS,5.0,"Type antiward in chat to be immune to wards like this!");
				//decl data[MAXWARDDATA];
				//War3_GetWardData(wardindex, data);
				//new damage = data[GetSkillLevel(owner, GetRace(owner), War3_GetWardSkill(wardindex))];

				decl Float:WardLoC[3];

				War3_GetWardLocation(wardindex, WardLoC);

				pullClient(victim,WardLoC);

				War3_WardVisualEffect(wardindex, {128, 128, 128, 255}, 0, WARD_TARGET_ENEMYS, true);
			}
			else if(team1!=team2)
			{*/
			//decl data[MAXWARDDATA];
			//War3_GetWardData(wardindex, data);
			//new damage = data[GetSkillLevel(owner, GetRace(owner), War3_GetWardSkill(wardindex))];

			//W3Hint(victim,HINT_SKILL_STATUS,5.0,"Type antiward in chat to be immune to wards like this!");
			//decl Float:WardLoC[3];
			//War3_GetWardLocation(wardindex, WardLoC);
			//pullClient(victim,WardLoC);
			//War3_WardVisualEffect(wardindex, {128, 128, 128, 255}, 0, WARD_TARGET_ENEMYS|WARD_TARGET_SELF, true);
			//}
		}
	}
}

//====================================================================================
//						OnWardNotTrigger
//====================================================================================
/*public OnWardNotTrigger(wardindex, victim, owner, behavior)
{
	if(ValidPlayer(victim,true) && ValidPlayer(owner))
	{
		if(behavior==Ward_BehaviorIndex)
		{
			// Remove Slow and Remove Ward ID
			HasWardID[victim][BEHAVIOR_SLOW]=-1;
			SetBuff(victim,fSlow,GetRace(owner),1.0);
			SetBuff(victim,fMaxSpeed,GetRace(owner),1.0);
		}
	}
}*/



//new absincarray[]={0,4,-4,8,-8,12,-12,18,-18,22,-22,25,-25};//,27,-27,30,-30,33,-33,40,-40}; //for human it needs to be smaller
new absincarray[]={0,4,-4,8,-8,12,-12,18,-18,22,-22,25,-25,27,-27,30,-30,33,-33,40,-40,-50,-75,-90,-110}; //for human it needs to be smaller

public bool:getEmptyLocationHull(client,Float:originalpos[3]){


	new Float:mins[3];
	new Float:maxs[3];
	GetClientMins(client,mins);
	GetClientMaxs(client,maxs);

	new absincarraysize=sizeof(absincarray);

	new limit=5000;
	for(new x=0;x<absincarraysize;x++){
		if(limit>0){
			for(new y=0;y<=x;y++){
				if(limit>0){
					for(new z=0;z<=y;z++){
						new Float:pos[3]={0.0,0.0,0.0};
						AddVectors(pos,originalpos,pos);
						pos[0]+=float(absincarray[x]);
						pos[1]+=float(absincarray[y]);
						pos[2]+=float(absincarray[z]);

						TR_TraceHullFilter(pos,pos,mins,maxs,MASK_SOLID,Teleport_CanHitThis,client);
						//new ent;
						if(!TR_DidHit(_))
						{
							AddVectors(emptypos,pos,emptypos); ///set this gloval variable
							limit=-1;
							break;
						}

						if(limit--<0){
							break;
						}
					}

					if(limit--<0){
						break;
					}
				}
			}

			if(limit--<0){
				break;
			}

		}

	}

}


public bool:Teleport_CanHitThis(entityhit, mask, any:data)
{
	if(entityhit == data )
	{// Check if the TraceRay hit the itself.
		return false; // Don't allow self to be hit, skip this result
	}
	if(ValidPlayer(entityhit)&&ValidPlayer(data)&&GetClientTeam(entityhit)==GetClientTeam(data)){
		return false; //skip result, prend this space is not taken cuz they on same team
	}
	return true; // It didn't hit itself
}

