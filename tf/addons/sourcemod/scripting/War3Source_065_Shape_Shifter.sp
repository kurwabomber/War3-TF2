#include <war3source>

#define PLUGIN_VERSION "0.0.0.1 (6/1/2013)"

#pragma semicolon 1    //WE RECOMMEND THE SEMICOLON
//#pragma tabsize 0     // doesn't mess with how you format your lines

//#include <sourcemod>
//#include "sdkhooks"
//#include <sdktools>
//#include <sourcemod>
//#include <tf2_stocks>
//#include <tf2>
//#include <sdkhooks>

//#include "W3SIncs/War3Source_Interface"

#if GGAMETYPE != GGAME_TF2
	#endinput
#endif

//#if GGAMETYPE2 != GGAME_TF2_NORMAL
//	#endinput
//#endif

#if GGAMEMODE != MODE_WAR3SOURCE
	#endinput
#endif

#if GGAMETYPE_JAILBREAK != JAILBREAK_OFF
	#endinput
#endif

//#assert GGAMETYPE == GGAME_TF2
//#assert GGAMEMODE == MODE_WAR3SOURCE
//#assert GGAMETYPE_JAILBREAK == JAILBREAK_OFF

#define RACE_ID_NUMBER 650

public W3ONLY(){} //unload this?

#define FADE_DELAY		0.5

new TFClassType:playerTargetClass[MAXPLAYERS+1];

new Handle:cvar_Sound;
new Handle:cvar_NewClip;
new Handle:cvar_Effects;
new Handle:cvar_PunishMode;
new Handle:Cvar_ShiftCooldown;
new Handle:Cvar_UltCooldown;

new Float:BloodTap[5] = { 0.0, 0.25, 0.50, 0.75, 1.0 };

new Float:ShapeShiftCoolDown[9] = { 20.0, 20.0, 17.0, 14.0, 10.0 , 9.0, 8.0, 7.0, 6.0};
new Float:ULTShiftCoolDown[9] = { 20.0, 20.0, 17.0, 14.0, 10.0 , 9.0, 8.0, 7.0, 6.0};

new bool:g_bNewClip, bool:g_bEffects, g_iPunishMode, String:g_sSound[PLATFORM_MAX_PATH];
new bool:g_bMapLoaded, Float:g_fPunishTime;

// Preserve only bad conditions
// Jarate, Bleeding, Mad Milk, Fire, Stun, Fan O War effect...
new TFCond:PreserveConditions[] = {
	TFCond_Jarated,
	TFCond_Bleeding,
	TFCond_Milked,
	TFCond_OnFire,
	TFCond_Bonked,
	TFCond_MarkedForDeath,
};

enum ShapeShiftData	{
	Float:lastUseTime,
	bool:inRespawn,
	bool:regenCheck,
	TFClassType:lockedClass,
};

new SData[MAXPLAYERS+1][ShapeShiftData];
new bool:PlayerShiftLocked[MAXPLAYERS+1];


new Float:ConditionTimes[] = {
	10.0,
	10.0,
	10.0,
	10.0,
	10.0,
	10.0
};

new TFCond:ClientConditions[MAXPLAYERS+1][sizeof(PreserveConditions)];

new FadeSteps[] = { 255, 128, 64, 48, 24, 0 };


new UserMsg:fadeMsg;

public Plugin:myinfo =
{
	 name = "Shape Shifter Race",
	 author = "El Diablo",
	 description = "blah.",
	 version = "1.0",
	 url = "http://www.war3evo.com"
};

new thisRaceID;

bool HooksLoaded = false;
public void Load_Hooks()
{
	if(HooksLoaded) return;
	HooksLoaded = true;

	W3Hook(W3Hook_OnUltimateCommand, OnUltimateCommand);
	W3Hook(W3Hook_OnAbilityCommand, OnAbilityCommand);
}
public void UnLoad_Hooks()
{
	if(!HooksLoaded) return;
	HooksLoaded = false;

	W3UnhookAll(W3Hook_OnUltimateCommand);
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
//	if(RaceDisabled)
//		return;


//new thisAuraID;

public chgNewClip(Handle:convar, const String:oldValue[], const String:newValue[])
{ g_bNewClip = StringToInt(newValue) > 0; }
public chgEffects(Handle:convar, const String:oldValue[], const String:newValue[])
{ g_bEffects = StringToInt(newValue) > 0; }
public chgPunishMode(Handle:convar, const String:oldValue[], const String:newValue[])
{ g_iPunishMode = StringToInt(newValue); }
public chgSound(Handle:convar, const String:oldValue[], const String:newValue[]) {
	strcopy(g_sSound, sizeof(g_sSound), newValue);
	if (g_bMapLoaded)
		War3_AddSound(g_sSound,STOCK_SOUND,PRIORITY_TOP);
}



new ABILITY_SHAPE_SHIFT,SKILL_LIFE_CHANNEL,SKILL_BLOOD_TAP,ULT_LOCK_SHIFT;

public OnPluginStart()
{
	CreateConVar("war3evo_ShapeShifter",PLUGIN_VERSION,"War3evo ShapeShifter Job",FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	Cvar_ShiftCooldown=CreateConVar("war3_ss_shifting_cooldown","20.0","Cooldown between shifts");
	Cvar_UltCooldown=CreateConVar("war3_ss_lock_cooldown","20.0","Cooldown between shifts");
//	CreateTimer(0.1,CalcWards,_,TIMER_REPEAT);

	HookConVarChange(cvar_NewClip = CreateConVar("sm_shapeshift_newclip",
		"1", "Permit new clip (you get ammo from nothing)"), chgNewClip);
	HookConVarChange(cvar_Effects = CreateConVar("sm_shapeshift_effects", "1",
		"Shapeshift graphical/sound effects"), chgEffects);
	HookConVarChange(cvar_PunishMode = CreateConVar("sm_shapeshift_punishmode", "0",
		"Shapeshift usage punishment mode", true), chgPunishMode);
	HookConVarChange(cvar_Sound = CreateConVar("sm_shapeshift_sound",
		"npc/ichthyosaur/water_growl5.wav", "Shapeshift Sound"), chgSound);

	HookEvent("post_inventory_application", Event_PostInventoryApp);
	HookEvent("teamplay_round_start", Event_RoundStart);

	g_bNewClip = GetConVarInt(cvar_NewClip) > 0;
	g_bEffects = GetConVarInt(cvar_Effects) > 0;
	g_iPunishMode = GetConVarInt(cvar_PunishMode);
	GetConVarString(cvar_Sound, g_sSound, sizeof(g_sSound));

//	CreateTimer(1.0, Timer_Caching, _, TIMER_REPEAT);
	fadeMsg = GetUserMessageId("Fade");
}
public OnAllPluginsLoaded()
{
	War3_RaceOnPluginStart("shapeshifter2");

	//AutoExecConfig();
}


public OnPluginEnd()
{
	CloseHandle(Cvar_ShiftCooldown);
	CloseHandle(Cvar_UltCooldown);


	UnhookConVarChange(cvar_NewClip, chgNewClip);
	UnhookConVarChange(cvar_Effects, chgEffects);
	UnhookConVarChange(cvar_PunishMode, chgPunishMode);
	UnhookConVarChange(cvar_Sound, chgSound);

	UnhookEvent("post_inventory_application", Event_PostInventoryApp);
	UnhookEvent("teamplay_round_start", Event_RoundStart);

	ResetForAll();

	if(LibraryExists("RaceClass"))
		War3_RaceOnPluginEnd("shapeshifter2");
}

public OnMapStart() {
	g_bMapLoaded = true;
	ResetForAll();
	PrecacheSound(g_sSound);
//	ApplyTag();
//	HookRespawns();

	//AutoExecConfig();
}

public OnMapEnd() {
	g_bMapLoaded = false;
}

public OnRaceChanged(client,oldrace,newrace)
{
	if(newrace==thisRaceID)
	{
		InitPassiveSkills(client);
	}
	else
	{
		RemovePassiveSkills(client);
	}
}

public OnWar3LoadRaceOrItemOrdered2(num,reloadrace_id,String:shortname[])
{
	if(num==RACE_ID_NUMBER||(reloadrace_id>0&&StrEqual("shapeshifter2",shortname,false)))
	{
		thisRaceID=War3_CreateNewRace("Shape Shifter","shapeshifter2",reloadrace_id,"Shape Shifting | some crits");
		ABILITY_SHAPE_SHIFT=War3_AddRaceSkill(thisRaceID,"Shape Shift (+ability)",
		"Shape Shift into the last class you killed.\n20 to 6 seconds cooldown.",false,8);
		SKILL_LIFE_CHANNEL=War3_AddRaceSkill(thisRaceID,"Life Channel",
		"Gain 10 to 60 health when you Shape Shift",false,8);
		SKILL_BLOOD_TAP=War3_AddRaceSkill(thisRaceID,"Blood Tap",
		"25/50/75/100 percent chance to reset cooldown on kill",false,4);
		ULT_LOCK_SHIFT=War3_AddRaceSkill(thisRaceID,"Lock/Unlock Shape Shift","Toggle Shape Shifting Lock between 2 pair.\n20 to 6 seconds cooldown.",true,8);
		//W3SkillCooldownOnSpawn( thisRaceID, ABILITY_CIDER_WARD,5.0);
		//GetConVarFloat(ultCooldownCvar_SPAWN) );
		//DO NOT FORGET THE END!!!
		War3_CreateRaceEnd(thisRaceID);

		W3SkillCooldownOnSpawn( thisRaceID, ABILITY_SHAPE_SHIFT,5.0);

		War3_SetDependency(thisRaceID, SKILL_LIFE_CHANNEL, ABILITY_SHAPE_SHIFT, 1);
		War3_SetDependency(thisRaceID, SKILL_BLOOD_TAP, ABILITY_SHAPE_SHIFT, 1);
		//War3_SetDependency(thisRaceID, SKILL_MAGIC_ARMOR, SKILL_NIGHT_GUARDS_HELM, 4);
		//thisAuraID=W3RegisterAura("Family Reunion",FamilyReunionRange,false);
	}
}

/* OnPlayerDeath()
 */
public OnWar3EventDeath(victim, attacker, deathrace, distance, attacker_hpleft)
{
	if(War3_GetRace(attacker)==thisRaceID && ValidPlayer(attacker) && ValidPlayer(victim))
	{
		new skill_level=War3_GetSkillLevel(attacker,thisRaceID,SKILL_BLOOD_TAP);
		if(War3_Chance(BloodTap[skill_level]))
		{
		 	War3_CooldownReset(attacker, thisRaceID, ABILITY_SHAPE_SHIFT);
		}
		if(!PlayerShiftLocked[attacker] && (playerTargetClass[attacker]!=TF2_GetPlayerClass(victim)))
		{
			playerTargetClass[attacker]=TF2_GetPlayerClass(victim);
			new String:ClassTypeStr[32];
			switch(TF2_GetPlayerClass(victim))
			{
				case TFClass_Unknown:
				{
					ClassTypeStr="NO CHANGE";
				}
				case TFClass_Scout:
				{
					ClassTypeStr="SCOUT";
				}
				case TFClass_Sniper:
				{
					ClassTypeStr="SNIPER";
				}
				case TFClass_Soldier:
				{
					ClassTypeStr="SOLDIER";
				}
				case TFClass_DemoMan:
				{
					ClassTypeStr="DEMOMAN";
				}
				case TFClass_Medic:
				{
					ClassTypeStr="MEDIC";
				}
				case TFClass_Heavy:
				{
					ClassTypeStr="HEAVY";
				}

				case TFClass_Pyro:
				{
					ClassTypeStr="PYRO";
				}
				case TFClass_Spy:
				{
					ClassTypeStr="SPY";
				}
				case TFClass_Engineer:
				{
					ClassTypeStr="ENGINEER";
				}
			}
			W3Hint(attacker,HINT_SKILL_STATUS,5.0,"You are now: %s",ClassTypeStr);
		}
	}
}

/*
public void OnSkillLevelChanged(int client, int currentrace, int skill, int newskilllevel, int oldskilllevel)
{
	if(RaceDisabled)
		return;

	InitPassiveSkills(client);
	//if(race==thisRaceID)
	//{
	  //CloseHandle(SONG_TIMER_HANDLE);
	  //SONG_TIMER_HANDLE=CreateTimer(song_timer_seconds[newskilllevel],Timer_Song,_,TIMER_REPEAT);
	//}
}*/

public InitPassiveSkills(client)
{
	if(War3_GetRace(client)==thisRaceID)
	{
//		new skilllevel=War3_GetSkillLevel(client,thisRaceID,SKILL_FAMILY_REUNION);
//		W3SetAuraFromPlayer(thisAuraID,client,skilllevel>0?true:false,skilllevel);

		/*
		new skilllevel_InitPassiveSkills=War3_GetSkillLevel(client,thisRaceID,SKILL_HEAVYEQUIPMENT);
		War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0);
		War3_SetBuff(client,fSlow,thisRaceID,SSpeed[skilllevel_InitPassiveSkills]);
		War3_SetBuff(client,fArmorPhysical,thisRaceID,PhysicalResistance[skilllevel_InitPassiveSkills]);
		War3_SetBuff(client,fArmorMagic,thisRaceID,MagicalResistance[skilllevel_InitPassiveSkills]);
		*/
	}
}

public RemovePassiveSkills(client)
{
	//W3SetAuraFromPlayer(thisAuraID,client,false);
	//War3_SetBuff(client,fArmorPhysical,thisRaceID,0.0);
	/*
	War3_SetBuff(client,fSlow,thisRaceID,1.0);
	War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0);
	War3_SetBuff(client,fArmorPhysical,thisRaceID,0.0);
	War3_SetBuff(client,fArmorMagic,thisRaceID,0.0);
	War3_SetBuff(client,fDamageModifier,thisRaceID,0.0);
	War3_SetBuff(client,fAttackSpeed,thisRaceID,1.0);
	*/
}

/*
public OnAbilityCommand(client,ability,bool:pressed)
{
	if(War3_GetRace(client)==thisRaceID && ability==0 && pressed && IsPlayerAlive(client))
	{
		new skill_level=War3_GetSkillLevel(client,thisRaceID,ABILITY_CIDER_WARD);
		if(skill_level>0)
		{
			//
		}
	}
//	if(War3_GetRace(client)==thisRaceID && ability==2 && pressed && IsPlayerAlive(client))
//	{
//		new skill_level=War3_GetSkillLevel(client,thisRaceID,ABILITY2_APPLE_BARREL);
		//War3_CooldownMGR(client,10.0,thisRaceID,ABILITY2_APPLE_BARREL,false,_);
//	}
}
*/

//public void OnWar3EventSpawn (int client)
//{
//	RemoveWards(client);
	//War3_SetBuff(client,bBashed,thisRaceID,false);
//}

// *********************************************************************************************************************************************

bool:PlayerReallyAlive(i) {
	if (!IsClientInGame(i) || !IsPlayerAlive(i)) return false;
	return true;
}

// *********************************************************************************************************************************************

public OnClientConnected(client) {
	ResetForClient(client);
	SData[client][lockedClass] = TFClass_Unknown;
}

// *********************************************************************************************************************************************

ResetForAll() {
	for (new i = 0; i <= MAXPLAYERS; i++)
		ResetForClient(i);
}


// *********************************************************************************************************************************************

ResetForClient(client) {
	SData[client][lastUseTime] = 0.0;
	SData[client][inRespawn] = false;
	SData[client][regenCheck] = true;
}


// *********************************************************************************************************************************************


public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	ResetForAll();
	//HookRespawns();
}

// *********************************************************************************************************************************************


TimedParticle(ent, String:name[], Float:pos[3], Float:time) {
	new particle = CreateEntityByName("info_particle_system");
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
	new String:classn[32];
	GetEdictClassname(particle, classn, sizeof(classn));
	if (strcmp(classn, "info_particle_system") != 0) return;
	RemoveEdict(particle);
}

// *********************************************************************************************************************************************

public Event_PostInventoryApp(Handle:event, const String:name[], bool:dontBroadcast) {
	if(RaceDisabled)
		return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (SData[client][regenCheck])	CreateTimer(0.1, Timer_PostInventory, client);
	SData[client][regenCheck] = false;
}


// *********************************************************************************************************************************************

// Removes a perma crit exploit. I might need to do some other cond checks as well
// I've changed how the player is 'shapeshifted,' so this might not be
// necessary anymore
public Action:Timer_PostInventory(Handle:timer, any:client) {
	if(RaceDisabled)
		return Plugin_Continue;

	if (!PlayerReallyAlive(client)) return Plugin_Continue;
	TF2_RemoveCondition(client, TFCond_CritHype);

	return Plugin_Continue;
}

// *********************************************************************************************************************************************


public void OnUltimateCommand(int client, int race, bool pressed, bool bypass)
{
	if(RaceDisabled)
		return;

	new userid=GetClientUserId(client);

	if(race==thisRaceID &&pressed && userid>1 && IsPlayerAlive(client) && !Silenced(client))
	{
		new ult_level=War3_GetSkillLevel(client,race,ULT_LOCK_SHIFT);
		if(ult_level>0 && War3_SkillNotInCooldown(client,thisRaceID,ULT_LOCK_SHIFT,true))
		{
			PlayerShiftLocked[client]=!PlayerShiftLocked[client];
			War3_ChatMessage(client, " {olive}Shape Shifter Lock is toggled %s",PlayerShiftLocked[client] ? "on" : "off");
			new Float:cooldown=GetConVarFloat(Cvar_UltCooldown);
			if(cooldown>ULTShiftCoolDown[ult_level])
				cooldown=ULTShiftCoolDown[ult_level];
			War3_CooldownMGR(client,cooldown,thisRaceID,ULT_LOCK_SHIFT,_,_);
		}
		else
		{
			War3_ChatMessage(client,"{olive} Ultimate may not be leveled yet or skill on cooldown.");
		}
	}
}

public void OnAbilityCommand(int client, int ability, bool pressed, bool bypass)
{
	if(RaceDisabled)
		return;

	new userid=GetClientUserId(client);
	new race=War3_GetRace(client);

	//new team = GetClientTeam(client);
	// ???? if (team != 2 && team != 3) return Plugin_Continue;
	if(race==thisRaceID && ability==0 &&pressed && userid>1 && IsPlayerAlive(client) && !Silenced(client))
	{
		if(playerTargetClass[client]!=TFClass_Unknown)
		{
			new ability_level=War3_GetSkillLevel(client,race,ABILITY_SHAPE_SHIFT);
			if(ability_level>0)
			{
				if(!TF2_IsPlayerInCondition(client, TFCond_Bonked))
				{
					if(War3_SkillNotInCooldown(client,thisRaceID,ABILITY_SHAPE_SHIFT,true)) //not in the 0.2 second delay when we check stuck via moving
					{
						if(TF2_IsPlayerInCondition(client, TFCond:44))
						{
							War3_ChatMessage(client,"{red}You can not shapeshift while having that kind of crits!");
							return;
						}
						new TFClassType:currentClass = TF2_GetPlayerClass(client);
						if(currentClass!=playerTargetClass[client])
						{
							DoShapeShift(client, currentClass, playerTargetClass[client]);
							//SKILL_LIFE_CHANNEL
							switch(War3_GetSkillLevel(client,race,SKILL_LIFE_CHANNEL))
							{
								case 1: War3_HealToBuffHP(client,10);
								case 2: War3_HealToBuffHP(client,20);
								case 3: War3_HealToBuffHP(client,30);
								case 4: War3_HealToBuffHP(client,40);
								case 5: War3_HealToBuffHP(client,45);
								case 6: War3_HealToBuffHP(client,50);
								case 7: War3_HealToBuffHP(client,55);
								case 8: War3_HealToBuffHP(client,60);
							}
							playerTargetClass[client]=currentClass;
							//native  W3Hint(client,W3HintPriority:type=HINT_LOWEST,Float:duration=5.0,String:format[],any:...);
							W3Hint(client,HINT_SKILL_STATUS,5.0,"SHIFTED!");
							new Float:cooldown=GetConVarFloat(Cvar_ShiftCooldown);
							if(cooldown>ShapeShiftCoolDown[ability_level])
								cooldown = ShapeShiftCoolDown[ability_level];
							War3_CooldownMGR(client,cooldown,thisRaceID,ABILITY_SHAPE_SHIFT,_,_);
						}
						else
						{
							War3_ChatMessage(client,"{olive} Shape Shift does not shapeshifting into the same class.");
						}
					}
				}
				else
				{
					War3_ChatMessage(client,"{olive} Shape Shift does not allow bonk.");
				}
			}
			else
			{
				War3_ChatMessage(client,"{olive} Shape Shift ability not leveled yet.");
			}
		}
		else
		{
			War3_ChatMessage(client,"{olive} You must kill someone first before you can shapeshift!");
		}
	}
}


// *********************************************************************************************************************************************


DoShapeShift(client, TFClassType:currentClass, TFClassType:targetClass) {
	TF2_RemoveCondition(client, TFCond:44);

	if (currentClass == TFClass_Engineer)
		KillBuildings(client);			// Else they'll keep em

	new oldAmmo1 = GetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 4, 4);
	new oldAmmo2 = GetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 8, 4);

	// Originally used timers to reapply Conditions, so stored globally
	// Might be necessary again, not sure

	for (new i = 0; i < sizeof(PreserveConditions); i++)
		ClientConditions[client][i] = TFCond:-1;
	new count = 0;
	for (new i = 0; i < sizeof(PreserveConditions); i++) {
		if (TF2_IsPlayerInCondition(client, PreserveConditions[i])) {
			ClientConditions[client][count++] = PreserveConditions[i];
		}
	}

	new oldFlags = GetEntityFlags(client);
	SetEntityFlags(client, oldFlags & ~FL_NOTARGET);	// Remove notarget if it was there
														// for whatever reason, weapons won't be
														// regenerated if FL_NOTARGET is set.

	new oldHealth = GetClientHealth(client);
	TF2_RegeneratePlayer(client);	// Prevents rare crash & gets ammo maxs
	//new oldMaxHealth = GetClientHealth(client);

	// now get the maxs, since the current ammo = max
	new oldMaxAmmo1 = GetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 4, 4);
	new oldMaxAmmo2 = GetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 8, 4);

	TF2_SetPlayerClass(client, targetClass, false, true);
	SData[client][regenCheck] = true;
	SetEntityHealth(client, 1);			// otherwise, if health > max health, you
										// keep current health with RegeneratePlayer
										// getting the new max health requires doing this
	TF2_RegeneratePlayer(client);

	new newMaxAmmo1 = GetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 4, 4);
	new newMaxAmmo2 = GetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 8, 4);

	// If old ammo == oldmaxammo, then use newmaxammmo
	// Avoids rounding

	new scaled1 = RoundFloat(oldMaxAmmo1 == oldAmmo1 ? float(newMaxAmmo1) :
		float(oldAmmo1) * (float(newMaxAmmo1) / float(oldMaxAmmo1)));

	new scaled2 = RoundFloat(oldMaxAmmo2 == oldAmmo2 ? float(newMaxAmmo2) :
		float(oldAmmo2) * (float(newMaxAmmo2) / float(oldMaxAmmo2)));

	new ws1 = GetPlayerWeaponSlot(client, 0);
	new ws2 = GetPlayerWeaponSlot(client, 1);
	new clipMain = -1, clip2nd = -1;
	if (ws1 > 0)
		clipMain = GetEntData(ws1, FindSendPropInfo("CTFWeaponBase", "m_iClip1"));
	if (ws2 > 0)
		clip2nd = GetEntData(ws2, FindSendPropInfo("CTFWeaponBase", "m_iClip1"));

	if (!g_bNewClip) {
		// Setting to 0 bugs certain weapons
		if (clipMain > -1)
			SetEntData(ws1, FindSendPropInfo("CTFWeaponBase", "m_iClip1"), 1);
		if (clip2nd > -1)
			SetEntData(ws2, FindSendPropInfo("CTFWeaponBase", "m_iClip1"), 1);
	}

	SetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 4,
		scaled1);
	SetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 8,
		scaled2);

	// Engies shouldn't get ammo
	if (targetClass == TFClass_Engineer)
		SetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 12, 0, 4);
	/*
	new newMaxHealth = GetClientHealth(client);
	new Float:scaledHealth = oldHealth >= oldMaxHealth ? float(newMaxHealth) :
		float(oldHealth) * (float(newMaxHealth) / float(oldMaxHealth));
	new convertedHealth = RoundFloat(scaledHealth);

	// Prevent Scaling Up health == bad == free health
	// Only permit this if full health in the first place
	if (convertedHealth > oldHealth
		&& oldHealth < oldMaxHealth) convertedHealth = oldHealth;

	if (convertedHealth < 1) convertedHealth = 1;
	//SetEntityHealth(client, convertedHealth);
	*/
	SetEntityHealth(client,oldHealth);

	for (new i = 0; i < sizeof(PreserveConditions); i++) {
		if (ClientConditions[client][i] == TFCond:-1) break;
		if (ClientConditions[client][i] == TFCond_OnFire) {
			// removed because broken - need sourcemod update
			TF2_IgnitePlayer(client, client); continue;
		}
		TF2_AddCondition(client, ClientConditions[client][i], ConditionTimes[i]);
	}

	SData[client][lastUseTime] = GetGameTime();

	if (g_bEffects) {
		decl Float:origin[3];
		GetClientAbsOrigin(client, origin);
		War3_EmitSoundToAll(g_sSound, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,
			0.9, SNDPITCH_NORMAL, -1, origin, NULL_VECTOR, true, 0.0);

		StopFade(client);
		DoFade(client, 255);

		decl Float:special[3];
		decl Float:top[3];
		GetClientEyePosition(client, special);
		special[2] += 11.0;
		top = special;
		top[2] -= 30.0;

		if (GetClientTeam(client) == 2) {
			TimedParticle(client, "teleporter_red_entrance_level1", origin, 4.0);
			TimedParticle(client, "player_sparkles_red", special, 3.0);
			TimedParticle(client, "player_dripsred", special, 3.5);
			TimedParticle(client, "player_dripsred", top, 3.5);
			TimedParticle(client, "critical_rocket_red", top, 3.0);
			TimedParticle(client, "player_recent_teleport_red", top, 3.5);
		}
		else {
			TimedParticle(client, "teleporter_blue_entrance_level1", origin, 4.0);
			TimedParticle(client, "player_sparkles_blue", special, 3.0);
			TimedParticle(client, "player_drips_blue", special, 3.5);
			TimedParticle(client, "player_drips_blue", top, 3.5);
			TimedParticle(client, "critical_rocket_blue", top, 3.0);
			TimedParticle(client, "player_recent_teleport_blue", top, 3.5);
		}

		new Handle:dp = CreateDataPack();
		WritePackCell(dp, client);
		WritePackCell(dp, sizeof(FadeSteps)-1);
		CreateTimer(FADE_DELAY, Timer_Fade, dp, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	new slot;
	if ((slot = GetPlayerWeaponSlot(client, 0)) > -1)
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", slot);

	CreateTimer(1.0, Remove_Cond_44, GetClientUserId(client));

	DoPunish(client);

	//if (readyTimer && g_iDisplayReady > 0)
		//CreateTimer(g_fCooldown, Timer_DisplayReady, client);
}

// force removal of heavy crits
public Action:Remove_Cond_44(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(ValidPlayer(client) && TF2_IsPlayerInCondition(client, TFCond:44))
	{
		TF2_RemoveCondition(client, TFCond:44);
		//CreateTimer(0.2, Remove_Cond_44, GetClientUserId(client));
	}
}

// *********************************************************************************************************************************************

DoPunish(client) {
	switch (g_iPunishMode) {
		case 0: { }
		case 1: {
			TF2_StunPlayer(client, g_fPunishTime, 0.0,
				TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT, 0);
		} case 2: {
			TF2_StunPlayer(client, g_fPunishTime, 0.5,
				TF_STUNFLAG_LIMITMOVEMENT | TF_STUNFLAG_SLOWDOWN, 0);
		} case 3: {
			TF2_StunPlayer(client, g_fPunishTime, 0.0,
				TF_STUNFLAGS_BIGBONK, 0);
		} case 4: {
			TF2_StunPlayer(client, g_fPunishTime, 0.0,
				TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_NOSOUNDOREFFECT, 0);
		} default: {
			TF2_StunPlayer(client, g_fPunishTime, 0.0,
				TF_STUNFLAGS_LOSERSTATE, 0);
		}
	}
}
/*
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if(ValidPlayer(client))
	{
		if(War3_GetRace(client)==thisRaceID)
		{

		}
	}
}*/

// *********************************************************************************************************************************************

public Action:Timer_Fade(Handle:timer, any:dp)
{
	ResetPack(dp);
	new client = ReadPackCell(dp);
	new index = ReadPackCell(dp);
	if (!IsClientInGame(client)) { CloseHandle(dp); return Plugin_Stop; }
	if (index < 1) { StopFade(client); CloseHandle(dp); return Plugin_Stop; }
	//SetPackPosition(dp, 0);
	ResetPack(dp, false);
	WritePackCell(dp, client);
	WritePackCell(dp, index-1);
	StopFade(client);
	DoFade(client, FadeSteps[index]);
	return Plugin_Continue;
}

// *********************************************************************************************************************************************


DoFade(client, amount) {
	new clients[2];
	clients[0] = client;

	new Handle:message = StartMessageEx(fadeMsg, clients, 1);

	if(message!=INVALID_HANDLE)
	{
		if (GetUserMessageType() == UM_Protobuf)
		{
			PbSetInt(message, "duration", 255);
			PbSetInt(message, "hold_time", 255);
			PbSetInt(message, "flags", (0x0002));
			decl color[4] = { 255, 255, 255, 255 };
			PbSetColor(message, "clr", color);
		}
		else
		{
			BfWriteShort(message, 255);
			BfWriteShort(message, 255);
			BfWriteShort(message, (0x0002));
			BfWriteByte(message, 255);
			BfWriteByte(message, 255);
			BfWriteByte(message, 255);
			BfWriteByte(message, amount);
		}
		EndMessage();
	}
}

// *********************************************************************************************************************************************


StopFade(client) {
	new clients[2];
	clients[0] = client;

	new Handle:message = StartMessageEx(fadeMsg, clients, 1);
	BfWriteShort(message, 1536);
	BfWriteShort(message, 1536);
	BfWriteShort(message, (0x0001 | 0x0010));
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	EndMessage();
}


// *********************************************************************************************************************************************


KillBuildings(client) {
	new maxentities = GetMaxEntities();
	for (new i = MaxClients+1; i <= maxentities; i++) {
		if (!IsValidEntity(i)) continue;
		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if (strcmp(netclass, "CObjectSentrygun") == 0 || strcmp(netclass, "CObjectDispenser") == 0 || strcmp(netclass, "CObjectTeleporter") == 0) {
			if (GetEntDataEnt2(i, FindSendPropInfo("CObjectSentrygun","m_hBuilder")) == client)
			{
				SetVariantInt(9999);
				AcceptEntityInput(i, "RemoveHealth");
			}
		}
    }
}
/*
public TF2_OnConditionAdded(client, TFCond:condition)
{
	if(RaceDisabled)
	{
		return;
	}

	if(!ValidPlayer(client))
	{
		return;
	}

	if(War3_GetRace(client)==thisRaceID)
	{
		DP("conditiion = %d",condition);
	}
}
public TF2_OnConditionRemoved(client, TFCond:condition)
{
	if(RaceDisabled)
	{
		return;
	}

	if(!ValidPlayer(client))
	{
		return;
	}

	if(War3_GetRace(client)==thisRaceID)
	{
		DP("conditiion = %d",condition);
	}
}

public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if(RaceDisabled)
	{
		return Plugin_Continue;
	}

	if(!ValidPlayer(client))
	{
		return Plugin_Continue;
	}

	if(War3_GetRace(client)!=thisRaceID)
	{
		return Plugin_Continue;
	}

	// Allow the crit if the player is Crit Boosted
	if (TF2_IsPlayerInCondition(client, TFCond_CritCanteen) || TF2_IsPlayerInCondition(client, TFCond_CritMmmph) || TF2_IsPlayerInCondition(client, TFCond_CritOnKill) || TF2_IsPlayerInCondition(client, TFCond_CritOnWin) ||
		TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood) || TF2_IsPlayerInCondition(client, TFCond_HalloweenCritCandy) || TF2_IsPlayerInCondition(client, TFCond_CritOnFlagCapture) ||
		TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) || TF2_IsPlayerInCondition(client, TFCond_CritDemoCharge) || TF2_IsPlayerInCondition(client, TFCond_CritOnDamage))
	{
		return Plugin_Continue;
	}

	//new index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

	// If Phlogistinator then stop crits
	//if (index == 594)
	//{
		//result = false;
	result = false;

	return Plugin_Handled;
	//}
}*/
