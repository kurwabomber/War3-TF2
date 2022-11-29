#include <war3source>

#pragma semicolon 1

//#include "W3SIncs/War3Source_Interface"
#assert GGAMETYPE_JAILBREAK == JAILBREAK_OFF

#define RACE_ID_NUMBER 550

public Plugin:myinfo =
{
	name = "War3Source - Race - Illusionist",
	author = "MrRick AKA Carlos Spicy Weiner",
	description = "The Illusionist race for War3Source:EVO."
};


new thisRaceID;
bool HooksLoaded = false;
public void Load_Hooks()
{
	if(HooksLoaded) return;
	HooksLoaded = true;

	W3Hook(W3Hook_OnW3TakeDmgAllPre, OnW3TakeDmgAllPre);
	W3Hook(W3Hook_OnUltimateCommand, OnUltimateCommand);
	W3Hook(W3Hook_OnAbilityCommand, OnAbilityCommand);
	W3Hook(W3Hook_OnWar3EventSpawn, OnWar3EventSpawn);
}
public void UnLoad_Hooks()
{
	if(!HooksLoaded) return;
	HooksLoaded = false;

	W3UnhookAll(W3Hook_OnW3TakeDmgAllPre);
	W3UnhookAll(W3Hook_OnUltimateCommand);
	W3UnhookAll(W3Hook_OnAbilityCommand);
	W3UnhookAll(W3Hook_OnWar3EventSpawn);
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

new HaloSprite;
new GlowSprite;


//Max time to leap back.(DO NOT CHANGE THIS)
new LeapCvar=3;

//Cooldown between Ability
new Float:ConfuseCvar=15.0;

//Cooldown for Undo.
new Float:LeapCooldownCvar=20.0;

new Float:ConfuseDistance[9]={0.0,150.0,250.0,350.0,450.0,500.0,550.0,600.0,650.0};

new EvasionChance[9]={0,4,6,8,10,11,12,13,14};
new HallucinationChance[9]={0,2,4,6,8,9,10,11,12};

new HealthRewindChance[5]={0,25,50,75,100};

new TimeIncrease[5]={0,1,2,3,4};
new SKILL_CONFUSE, SKILL_ELUDE, SKILL_HALLUCINATE,SKILL_UNDO,SKILL_IMPROVED;

new String:teleportSound[]="war3source/blinkarrival.mp3";

// Because we compile for many different games, its preferable
// to use MAXPLAYERSCUSTOM over MAXPLAYERS+1 for war3source

float PlayerPositionsLog[MAXPLAYERSCUSTOM][10][3];
float PlayerAngleLog[MAXPLAYERSCUSTOM][10][3];
int PlayerHealthLog[MAXPLAYERSCUSTOM][10];
UserMsg g_FadeUserMsgId;
//Counters for the timer.

// Enums help make stuff easier to read and can allow floats, bool, etc.
// put f for float, i for integer, and b for bool when creating a Enum
// to help make reading what it is easier.
enum DrugEnum
{
	Float:fTimer=0,
	iTarget
}

int DrugTimer[MAXPLAYERSCUSTOM][DrugEnum];

public OnPluginStart()
{
	g_FadeUserMsgId = GetUserMessageId("Fade");

	CreateTimer(1.0,Timer_1Second_Loop,_,TIMER_REPEAT);
}
public OnAllPluginsLoaded()
{
	War3_RaceOnPluginStart("illusionist");
}
public OnWar3PluginReady()
{
	new GetRaceID=War3_GetRaceIDByShortname("humanally");
	if(GetRaceID>0)
	{
		War3_SetRaceDependency(thisRaceID, GetRaceID, 32);
	}
	else
	{
		SetFailState("Could Not Find Human Ally Race on Load.");
	}
	GetRaceID=War3_GetRaceIDByShortname("chronos");
	if(GetRaceID>0)
	{
		War3_SetRaceDependency(thisRaceID, GetRaceID, 32);
	}
	else
	{
		SetFailState("Could Not Chronos Race on Load.");
	}
}

public OnPluginEnd()
{
	if(LibraryExists("RaceClass"))
	{
		War3_RaceOnPluginEnd("illusionist");
	}
}
public OnWar3LoadRaceOrItemOrdered2(num,reloadrace_id,String:shortname[])
{
	if(num==RACE_ID_NUMBER||(reloadrace_id>=0&&StrEqual("illusionist",shortname,false))){

		thisRaceID=War3_CreateNewRace("Illusionist","illusionist",reloadrace_id,"Trick minds of others.");
		SKILL_CONFUSE=War3_AddRaceSkill(thisRaceID,"Confuse","Reverses the target's movements.\n(+ability) 150 to 650 HU range\nCannot fire for 1 second",false,8);
		SKILL_HALLUCINATE=War3_AddRaceSkill(thisRaceID,"Hallucination","2 to 12% chance to give the other player hallucinations!",false,8);
		SKILL_ELUDE=War3_AddRaceSkill(thisRaceID,"Elusive","Evasion chance of 4 to 14%. On evade, gain 50% movement speed and become 50% visible for 3 seconds.",false,8);
		SKILL_UNDO=War3_AddRaceSkill(thisRaceID,"Undo","Leaps back in time a few seconds.\nEach level increases undo by 1 second\n(+ultimate)",true,4);
		SKILL_IMPROVED=War3_AddRaceSkill(thisRaceID,"Improved Undo","25/50/75/100% chance to rewind your health.",false,4);

		// IMPORTANT!
		// Do not put anything else between War3_CreateNewRace and War3_CreateRaceEnd other than AddRaceSkill functions!
		War3_CreateRaceEnd(thisRaceID);

		// All other race settings after Create Race End:
		War3_SetDependency(thisRaceID,SKILL_IMPROVED,SKILL_UNDO,4);


		new GetRaceID=War3_GetRaceIDByShortname("humanally");
		if(GetRaceID>0)
		{
			War3_SetRaceDependency(thisRaceID, GetRaceID, 32);
		}
		else
		{
			SetFailState("Could Not Find Human Ally Race on Load.");
		}
		GetRaceID=War3_GetRaceIDByShortname("chronos");
		if(GetRaceID>0)
		{
			War3_SetRaceDependency(thisRaceID, GetRaceID, 32);
		}
		else
		{
			SetFailState("Could Not Chronos Race on Load.");
		}

		W3SkillCooldownOnSpawn(thisRaceID,SKILL_UNDO,10.0,true);
		W3SkillCooldownOnSpawn(thisRaceID,SKILL_ELUDE,3.0,false);
	}
}


public OnMapStart()
{
	UnLoad_Hooks();

	HaloSprite=PrecacheModel("materials/sprites/halo01.vmt");
	GlowSprite=PrecacheModel("materials/sprites/blueflare1.vmt");
}

public OnAddSound(sound_priority)
{
	if(sound_priority==PRIORITY_MEDIUM)
	{
		War3_AddSound(teleportSound);
	}
}


public void OnWar3EventSpawn (int client)
{
	if(RaceDisabled)
	{
		return;
	}
	if(ValidPlayer(client))
	{
		if(War3_GetRace(client)==thisRaceID)
		{
			InitPassiveSkills(client);
		}
	}
}

public OnRaceChanged(client,oldrace,newrace)
{
	if(newrace==thisRaceID)
	{
		InitPassiveSkills(client);
	}
}

public void OnSkillLevelChanged(int client, int currentrace, int skill, int newskilllevel, int oldskilllevel)
{
	if(RaceDisabled)
	{
		return;
	}

	if(currentrace==thisRaceID)
	{
		if(!ValidPlayer(client,true)) return;

		if(skill == SKILL_UNDO && newskilllevel>0)
		{

			float curPos[3], curAngle[3];
			War3_CachedPosition(client,curPos);
			War3_CachedAngle(client,curAngle);

			int health = GetClientHealth(client);
			for(int i=1;i<LeapCvar-1+TimeIncrease[newskilllevel];i++)
			{
				PlayerPositionsLog[client][i]=curPos;
				PlayerAngleLog[client][i]=curAngle;
				PlayerHealthLog[client][i]=health;
			}
		}

		War3_SetBuff(client,fInvisibilitySkill,thisRaceID,1.0,client);
		War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0,client);
	}
}

public OnClientPutInServer(client)
{
	for(new attacker=1;attacker<MaxClients+1;attacker++)
	{
		if(DrugTimer[attacker][iTarget]==client)
		{
			DrugTimer[attacker][iTarget]=0;
			DrugTimer[attacker][fTimer]=0.0;
		}
	}
}

public OnClientDisconnect(client)
{
	for(new attacker=1;attacker<MaxClients+1;attacker++)
	{
		if(DrugTimer[attacker][iTarget]==client)
		{
			DrugTimer[attacker][iTarget]=0;
			DrugTimer[attacker][fTimer]=0.0;
		}
	}
}

InitPassiveSkills(client)
{
	if(RaceDisabled)
	{
		return;
	}

	// checks for valid player and checks if they are alive too
	if(ValidPlayer(client,true))
	{
		float curPos[3], curAngle[3];
		War3_CachedPosition(client,curPos);
		War3_CachedAngle(client,curAngle);

		int health = GetClientHealth(client);
		int level=War3_GetSkillLevel(client,thisRaceID,SKILL_UNDO);
		for(int i=1;i<LeapCvar-1+TimeIncrease[level];i++)
		{
			PlayerPositionsLog[client][i]=curPos;
			PlayerAngleLog[client][i]=curAngle;
			PlayerHealthLog[client][i]=health;
		}

		War3_SetBuff(client,fInvisibilitySkill,thisRaceID,1.0,client);
		War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0,client);
	}
}

public void OnAbilityCommand(int client, int ability, bool pressed, bool bypass)
{
	if(RaceDisabled)
	{
		return;
	}

	if(pressed && ValidPlayer(client,true) && War3_GetRace(client)==thisRaceID)
	{
		if(!Silenced(client))
		{
			if(ability==0 && War3_SkillNotInCooldown(client,thisRaceID,SKILL_CONFUSE,true))
			{

				new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_CONFUSE);
				if(HasLevels(client,skill_level))
				{
					new Float:myVecs[3];
					new Float:enemyVecs[3];
					new Float:angEnemy[3];
					new Float:resultVecs[3];
					new Float:distance;
					War3_CachedPosition(client,myVecs);
					new hitcount;
					for(new target=1;target<MaxClients+1;target++){
						if(ValidPlayer(target) && IsPlayerAlive(target) && target != client  && GetClientTeam(target) != GetClientTeam(client) && !W3HasImmunity(target,Immunity_Skills))
						{
							War3_CachedPosition(target,enemyVecs);
							distance =GetVectorDistance(myVecs,enemyVecs);
							//DP("%f",distance);
							if(distance<=ConfuseDistance[skill_level]){
								SubtractVectors(myVecs,enemyVecs,resultVecs);
								GetVectorAngles(resultVecs,angEnemy);
								if(angEnemy[1] >0){
									angEnemy[1]= -(180-angEnemy[1]);
								}else{
									angEnemy[1]= (180+angEnemy[1]);
								}

								if(angEnemy[0] >180){
									angEnemy[0]-=360;
								}
								TeleportEntity(target,NULL_VECTOR,angEnemy,NULL_VECTOR);
								W3Hint(target,HINT_SKILL_STATUS,5.0,"You've been confused!");
								hitcount++;
							}
						}
					}
					if(hitcount){
						W3Hint(client,HINT_SKILL_STATUS,5.0,"You confused %i enemies!", hitcount);
						War3_CooldownMGR(client,ConfuseCvar,thisRaceID,SKILL_CONFUSE, true,true);
						CreateTimer(1.0,ConfuseReArmPlayer,client);
						War3_SetBuff(client,bDisarm,thisRaceID,true);
					}
				}
			}
		}
	}
}

public void OnUltimateCommand(int client, int race, bool pressed, bool bypass)
{
	if(RaceDisabled)
	{
		return;
	}
	if( pressed  && ValidPlayer(client,true) && War3_GetRace(client)==thisRaceID && War3_SkillNotInCooldown(client,thisRaceID,SKILL_UNDO,true))
	{
		new level=War3_GetSkillLevel(client,thisRaceID,SKILL_UNDO);
		if(HasLevels(client,level))
		{

			movePositionsUp(client);
			TeleportEntity(client,PlayerPositionsLog[client][0],PlayerAngleLog[client][0],NULL_VECTOR);

			new randint=GetRandomInt(1,100);
			new level2=War3_GetSkillLevel(client,thisRaceID,SKILL_IMPROVED);
			// I DO NOT WANT IT TO NOTIFY THAT YOU DONT HAVE LEVELS FOR IMPROVED. That's why I'm not using HasLevels
			if(level2 >0 && randint<=HealthRewindChance[level2])
			{
				SetEntityHealth(client,PlayerHealthLog[client][0]);
			}
			ShowGlowAndReset(client);
			W3Hint(client,HINT_SKILL_STATUS,5.0,"You have leaped back in time!");
			War3_CooldownMGR(client,LeapCooldownCvar,thisRaceID,SKILL_UNDO, true,true);

		}
	}

}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////SKILLS BELOW///////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////





///////////////////////////////////////////////FUNCTIONS FOR CONFUSE//////////////////////////////////////////////////////////
public Action:ConfuseReArmPlayer(Handle:h,any:client){
	// WTF?
	//if(ValidPlayer(true)){
	// Player does not have to exist to set it, but make sure the client
	// number is in range.
	if(client>0 && client<=MaxClients){
		War3_SetBuff(client,bDisarm,thisRaceID,false);
	}
	return Plugin_Stop;
}
////////////////////////////////////////////////FUCTIONS FOR LEAP/////////////////////////////////////////////////////////////

//public ShowGlowAndReset(client){
ShowGlowAndReset(client)
{
	new level=War3_GetSkillLevel(client,thisRaceID,SKILL_UNDO);
	for(new i=0;i<LeapCvar+TimeIncrease[level];i++)
	{
		PlayerPositionsLog[client][i][2]+=50;
	}
	for(new i=0;i<LeapCvar-1+TimeIncrease[level];i++)
	{
		// Color {25,25,255,255} is blue
		new team = GetClientTeam(client);
		if(team==3){
			TE_SetupBeamPoints(PlayerPositionsLog[client][i],PlayerPositionsLog[client][i+1],GlowSprite, HaloSprite, 0, 10, 5.0, 10.0, 10.0, 10, 5.0,{25,25,255,255}, 100);
		}else if (team==2){
			TE_SetupBeamPoints(PlayerPositionsLog[client][i],PlayerPositionsLog[client][i+1],GlowSprite, HaloSprite, 0, 10, 5.0, 10.0, 10.0, 10, 5.0,{255,25,25,255}, 100);
		}
		TE_SendToAll(0.0);
		//DP("(%f,%f,%f)",PlayerPositionsLog[client][i][0],PlayerPositionsLog[client][i][1],PlayerPositionsLog[client][i][2]);
	}


	War3_EmitSoundToAll(teleportSound,client);
}

public bool IsDrugged(int client)
{
	int CountDrugs=0;
	for(int attacker=1;attacker<MaxClients+1;attacker++)
	{
		if(DrugTimer[attacker][iTarget]==client)
		{
			if(DrugTimer[attacker][fTimer]>GetGameTime())
			{
				CountDrugs++;
			}
		}
	}
	return CountDrugs>0?true:false;
}

public Action:Timer_1Second_Loop(Handle:h)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if(ValidPlayer(client,true))
		{
			//int iFOV = GetEntProp(client, Prop_Send, "m_iFOV");
			char MyName[64];
			GetClientName(client,STRING(MyName));
			//PrintToChatAll("%s has %d FOV",MyName,iFOV);

			if(War3_GetRace(client)==thisRaceID)
			{
				if(War3_GetSkillLevel(client,thisRaceID,SKILL_UNDO)>0)
				{
					movePositionsUp(client);
				}

			/*
			// OLD CODE:
			int Drugtarget=DrugTimer[client][iTarget];
			//checking for Drugtarget>0 first probably would be better
			//and faster checking to fail before it reaches a function.
			if(Drugtarget>0 && ValidPlayer(Drugtarget,true)){
				if(DrugTimer[client][fTimer]>GetGameTime()){
					DrugEffect(Drugtarget);
					//DP("%i  >  %i",DrugTimer[client][iTarget],RoundToCeil(GetGameTime()));
				}else{
					//SetEntProp(Drugtarget, Prop_Send, "m_iFOV", 90);
					//DrugTimer[client][iTarget]=0;
					KillDrug(Drugtarget);
				}
			}else{
				DrugTimer[client][iTarget]=0;
			}*/
			}

			if(IsDrugged(client)) // don't test for race as someone could change race before that person can get it removed
			{
				DrugEffect(client);
			}
			else if(GetEntProp(client, Prop_Send, "m_iFOV")==130)
			{
				KillDrug(client);
			}
		}
	}
	return Plugin_Continue;
}

movePositionsUp(client)
{
	new Float:curPos[3];
	War3_CachedPosition(client,curPos);
	new Float:curAngle[3];
	War3_CachedAngle(client,curAngle);

	new health = GetClientHealth(client);

	new level=War3_GetSkillLevel(client,thisRaceID,SKILL_UNDO);
	for(new i=1;i<LeapCvar+TimeIncrease[level];i++)
	{
		PlayerPositionsLog[client][i-1]=PlayerPositionsLog[client][i];
		PlayerAngleLog[client][i-1]=PlayerAngleLog[client][i];
		PlayerHealthLog[client][i-1]=PlayerHealthLog[client][i];
	}
	new time=LeapCvar+TimeIncrease[level];
	PlayerPositionsLog[client][time-1]=curPos;
	PlayerAngleLog[client][time-1]=curAngle;
	PlayerHealthLog[client][time-1]=health;
}
////////////////////////////////////////////////FUCTIONS FOR HALLUCINATE//////////////////////////////////////////////////////


public Action OnW3TakeDmgAllPre(int victim, int attacker, float damage)
{
	if(RaceDisabled)
	{
		return;
	}

	if(ValidPlayer(victim,true))
	{
		if(ValidPlayer(attacker,true) && War3_GetRace(attacker)==thisRaceID)
		{
			if(!W3HasImmunity(victim,Immunity_Skills))
			{
				new level=War3_GetSkillLevel(attacker,thisRaceID,SKILL_HALLUCINATE);
				if(level > 0  && War3_SkillNotInCooldown(attacker,thisRaceID,SKILL_HALLUCINATE,false) && damage >= 5)
				{
					if(!(W3GetDamageType() & DMG_BURN))
					{
						new randint=GetRandomInt(1,100);
						if(randint<=HallucinationChance[level])
						{
							if(DrugTimer[attacker][iTarget]==0 && victim != attacker && GetClientTeam(victim) != GetClientTeam(attacker))
							{
								//SetEntProp(victim, Prop_Send, "m_iFOV", 130);
								//DrugEffect(victim);
								War3_CooldownMGR(attacker,10.0,thisRaceID,SKILL_HALLUCINATE, true,false);
								W3Hint_Skill(attacker,"You have drugged someone!");
								W3Hint_Skill(victim,"You are having hallucinations!");
								DrugTimer[attacker][fTimer]=GetGameTime()+5.0;
								DrugTimer[attacker][iTarget]=victim;
								//PrintToChatAll("Not afterburn damage");
							}
						}
					}
				}
			}
		}
		if(War3_GetRace(victim)==thisRaceID)
		{
			new level2=War3_GetSkillLevel(victim,thisRaceID,SKILL_ELUDE);
			if(level2 > 0 && War3_SkillNotInCooldown(victim,thisRaceID,SKILL_ELUDE,false) && ValidPlayer(attacker) && victim != attacker && GetClientTeam(victim) != GetClientTeam(attacker))
			{
				new randint=GetRandomInt(1,100);
				if(randint<=EvasionChance[level2])
				{
					War3_EvadeDamage(victim, attacker);
					War3_CooldownMGR(victim,13.0,thisRaceID,SKILL_ELUDE, true,false);
					War3_SetBuff(victim,fInvisibilitySkill,thisRaceID,0.5,victim);
					War3_SetBuff(victim,fMaxSpeed,thisRaceID,1.5,victim);

					// Since we aren't affecting everyone over an extended time,
					// a short createtimer is fine.
					CreateTimer(3.0, RemoveElude, victim);
				}
				//DP("%i",randint);
			}
		}
	}
}

public Action:RemoveElude(Handle:Timer, any:client)
{
	if(ValidPlayer(client))
	{
		War3_SetBuff(client,fInvisibilitySkill,thisRaceID,1.0,client);
		War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0,client);
	}
}

/////////////////////////////////HALLUCINATIONS///////////////////////////////////////////////////////
KillDrug(client)
{
	SetEntProp(client, Prop_Send, "m_iFOV", 0);
	for(new attacker=1;attacker<MaxClients+1;attacker++)
	{
		if(DrugTimer[attacker][iTarget]==client)
		{
			DrugTimer[attacker][iTarget]=0;
			DrugTimer[attacker][fTimer]=0.0;
		}
	}

	new Float:angs[3];
	GetClientEyeAngles(client, angs);

	angs[2] = 0.0;

	TeleportEntity(client, NULL_VECTOR, angs, NULL_VECTOR);

	new clients[2];
	clients[0] = client;

	new duration = 1536;
	new holdtime = 1536;
	new flags = (0x0001 | 0x0010);
	new color[4] = { 0, 0, 0, 0 };

	new Handle:message = StartMessageEx(g_FadeUserMsgId, clients, 1);

	if(message!=INVALID_HANDLE)
	{
		if (GetUserMessageType() == UM_Protobuf)
		{
			PbSetInt(message, "duration", duration);
			PbSetInt(message, "hold_time", holdtime);
			PbSetInt(message, "flags", flags);
			PbSetColor(message, "clr", color);
		}
		else
		{
			BfWriteShort(message, duration);
			BfWriteShort(message, holdtime);
			BfWriteShort(message, flags);
			BfWriteByte(message, color[0]);
			BfWriteByte(message, color[1]);
			BfWriteByte(message, color[2]);
			BfWriteByte(message, color[3]);
		}
		EndMessage();
	}
}

DrugEffect(client)
{
	if (!IsClientInGame(client))
	{
		return;
	}

	if (!IsPlayerAlive(client))
	{
		KillDrug(client);

		return;
	}

	SetEntProp(client, Prop_Send, "m_iFOV", 130);

	int clients[2];
	clients[0] = client;

	int duration = 255;
	int holdtime = 255;
	new flags = 0x0002;
	new color[4] = { 0, 0, 0, 64 };
	color[0] = GetRandomInt(0,255);
	color[1] = GetRandomInt(0,255);
	color[2] = GetRandomInt(0,255);

	new Handle:message = StartMessageEx(g_FadeUserMsgId, clients, 1);

	if(message!=INVALID_HANDLE)
	{
		if (GetUserMessageType() == UM_Protobuf)
		{
			PbSetInt(message, "duration", duration);
			PbSetInt(message, "hold_time", holdtime);
			PbSetInt(message, "flags", flags);
			PbSetColor(message, "clr", color);
		}
		else
		{
			BfWriteShort(message, duration);
			BfWriteShort(message, holdtime);
			BfWriteShort(message, flags);
			BfWriteByte(message, color[0]);
			BfWriteByte(message, color[1]);
			BfWriteByte(message, color[2]);
			BfWriteByte(message, color[3]);
		}

		EndMessage();
	}
}

//
#if GGAMETYPE == GGAME_TF2
public OnW3SupplyLocker(client)
{
	if(RaceDisabled)
		return;

	if(ValidPlayer(client) && IsDrugged(client))
	{
		if(IsDrugged(client))
		{
			//PrintToChatAll("killed illusionist drugs via Supply Locker");
			//SetEntProp(client, Prop_Send, "m_iFOV", 90);
			KillDrug(client);
		}
		if(GetEntProp(client, Prop_Send, "m_iFOV")==130)
		{
			//PrintToChatAll("killed illusionist drugs via Supply Locker");
			KillDrug(client);
		}
	}
}
#endif
public OnW3HealthPickup(const String:output[], caller, activator, Float:delay)
{
	if(RaceDisabled)
		return;

	if(ValidPlayer(activator))
	{
		KillDrug(activator);
	}
}
