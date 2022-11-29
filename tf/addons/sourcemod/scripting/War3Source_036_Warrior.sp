#include <war3source>
#include <tf2attributes>
#include <sdkhooks>
#include <sdktools>
#assert GGAMEMODE == MODE_WAR3SOURCE

#define RACE_ID_NUMBER 36
#define raceshortname "warrior"
#define racelongname "Warrior"
#define racedescription "Mana based race"

public Plugin:myinfo =
{
	name = "Race - Warrior",
	author = "Razor",
	description = "Warrior race for War3Source.",
	version = "1.0",
};
public W3ONLY(){}

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

	W3Unhook(W3Hook_OnUltimateCommand, OnUltimateCommand);
	W3Unhook(W3Hook_OnAbilityCommand, OnAbilityCommand);
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

new SKILL_FIRST, SKILL_SECOND, SKILL_THIRD, ULT;

//Bash
new Float:bashDMG[9]={0.0,20.0,22.5,25.0,27.5,28.0,28.5,29.0,30.0};
new Float:bashMULT[9]={1.0,1.5,1.5,1.5,1.5,1.5,1.5,1.55,1.6};
//Charge
new Float:chargeSPEED[9]={0.0,400.0,500.0,600.0,700.0,750.0,800.0,850.0,900.0};
//Uppercut
new Float:uppercutDMG[9]={0.0,30.0,35.0,40.0,45.0,50.0,53.0,56.0,60.0};
//War Scream
new Float:warscreamDMG[9]={0.0,15.0,20.0,25.0,30.0,32.5,35.0,37.5,40.0};
new Float:warscreamDURATION[9]={0.0,4.0,5.0,6.0,7.0,7.5,8.0,9.0,10.0};
new bool:isUppercutted[MAXPLAYERS + 1];
//Mana System
new Float:currentMana[MAXPLAYERS + 1];

new String:explSound[]="weapons/air_burster_explode1.wav";
new String:chargeSound[]="weapons/rocket_pack_boosters_fire.wav";
new String:ultsnd[]="war3source/ultralisk_ult.mp3";

public OnWar3LoadRaceOrItemOrdered2(num,reloadrace_id,String:shortname[])
{
	if(num==RACE_ID_NUMBER||(reloadrace_id>0&&StrEqual(raceshortname,shortname,false)))
	{
		thisRaceID=War3_CreateNewRace(racelongname,raceshortname,reloadrace_id,racedescription);
		SKILL_FIRST=War3_AddRaceSkill(thisRaceID,"Bash","Deal an explosion 100 HU forward. Radius is 250 HU.\nRepeats & the second hit deals 1.5x dmg.\nDMG 20->30.\nRequires 5 mana per cast. (+ability)",false,8);
		SKILL_SECOND=War3_AddRaceSkill(thisRaceID,"Charge","Charge forward with high velocity. Leveling increases velocity.\nRequires 2 mana per cast. (+ability2)",false,8);
		SKILL_THIRD=War3_AddRaceSkill(thisRaceID,"Uppercut","Launch any enemies within 200 HU & 60 degrees FOV.\nDeals 10 damage initially, but deals 30-60 damage coming down.\nRequires 10 mana per cast. (+ability3)",false,8);
		ULT=War3_AddRaceSkill(thisRaceID,"War Scream","Deals 15-40 damage to all victims nearby.\nGives a boost to teammates & you for 4-10 seconds.\nRequires 12 mana per cast. (+ultimate)",true,8);
		War3_CreateRaceEnd(thisRaceID);
	}
}
public OnPluginStart()
{
	CreateTimer(0.1, Timer_Every100MS, _, TIMER_REPEAT);
}
public OnRaceChanged(client,oldrace,newrace)
{
	if(newrace!=thisRaceID)
	{
		War3_SetBuff(client,fArmorPhysical,thisRaceID,0.0);
		War3_SetBuff(client,fArmorMagic,thisRaceID,0.0);
	}
	else
	{
		War3_SetBuff(client,fArmorPhysical,thisRaceID,4.0);
		War3_SetBuff(client,fArmorMagic,thisRaceID,4.0);
	}
	isUppercutted[client] = false;
}
public OnMapStart()
{
	UnLoad_Hooks();
	PrecacheSound(explSound);
	PrecacheSound(chargeSound);
	PrecacheSound(ultsnd);
}
public OnAllPluginsLoaded()
{
	War3_RaceOnPluginStart(raceshortname);
}

public OnPluginEnd()
{
	if(LibraryExists("RaceClass"))
		War3_RaceOnPluginEnd(raceshortname);
}
public Action:Timer_Every100MS(Handle:timer)
{
	for(new client = 1; client < MaxClients; client++)
	{
		if(ValidPlayer(client,true) && War3_GetRace(client) == thisRaceID)
		{
			SetHudTextParams(0.2, 0.05, 0.15, 0, 50, 220, 255, 0);
			new String:MiniHUD_Text[32];
			Format(MiniHUD_Text, sizeof(MiniHUD_Text), "Mana : %.2f", currentMana[client]);
			ShowHudText(client, 9, MiniHUD_Text);
		}
	}
}
public OnGameFrame()
{
	for(new client = 1;client < MaxClients;client++)
	{
		if(ValidPlayer(client,false) && War3_GetRace(client) == thisRaceID)
		{
			new Float:tickInterval = GetTickInterval();
			currentMana[client] += tickInterval;
			
			if(currentMana[client] > 20.0)
			{
				currentMana[client] = 20.0;
			}
		}
	}
}
public Action:doNextBash(Handle:timer, int client) 
{  
	if(ValidPlayer(client,true))
	{
		new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_FIRST);
		new Float:fwd[3],Float:fAngles[3],Float:fOrigin[3];
		GetClientEyeAngles(client, fAngles);
		GetClientEyePosition(client, fOrigin);
		GetAngleVectors(fAngles,fwd, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(fwd, 200.0);
		AddVectors(fOrigin, fwd, fOrigin);
		War3_EmitSoundToAll(explSound,client);
		createExplosionEffect(fOrigin);
		
		for(new i = 1; i < MAXENTITIES; i++)
		{
			if(IsValidForDamage(i) && IsOnDifferentTeams(client,i))
			{
				new Float:targetvec[3];
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", targetvec);
				if(GetVectorDistance(fOrigin, targetvec, false) <= 250.0)
				{
					if(IsPointVisible(fOrigin,targetvec))
					{
						if(!W3HasImmunity(i,Immunity_Skills))
						{
							SDKHooks_TakeDamage(i, client, client, bashDMG[skill_level] * bashMULT[skill_level], DMG_BLAST, -1, NULL_VECTOR, NULL_VECTOR);
						}
						else
						{
							SDKHooks_TakeDamage(i, client, client, bashDMG[skill_level] * 0.5 * bashMULT[skill_level], DMG_BLAST, -1, NULL_VECTOR, NULL_VECTOR);
						}
					}
				}
			}
		}
	}
}
public Action:uppercutFall(Handle:timer, int client) 
{  
	if(ValidPlayer(client,true))
	{
		new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_THIRD);
		if(skill_level > 0)
		{
			for(new i = 1; i < MaxClients; i++)
			{
				if(ValidPlayer(i,true) && IsOnDifferentTeams(client,i))
				{
					if(isUppercutted[i])
					{
						new Float:velocity[3];
						velocity[0]=0.0;
						velocity[1]=0.0;
						velocity[2]=-3000.0;
						TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, velocity);
						if(!W3HasImmunity(i,Immunity_Skills))
						{
							SDKHooks_TakeDamage(i, client, client, uppercutDMG[skill_level], DMG_BLAST, -1, NULL_VECTOR, NULL_VECTOR);
						}
						else
						{
							SDKHooks_TakeDamage(i, client, client, uppercutDMG[skill_level] * 0.5, DMG_BLAST, -1, NULL_VECTOR, NULL_VECTOR);
						}
						isUppercutted[i] = false;
						War3_EmitSoundToAll(explSound,i);
					}
				}
			}
		}
	}
}
public void OnAbilityCommand(int client, int ability, bool pressed, bool bypass)
{
	if(RaceDisabled)
		return;

	if(War3_GetRace(client)==thisRaceID && pressed && IsPlayerAlive(client))
	{
		switch(ability)
		{
			case 0:
			{
				new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_FIRST);
				if(skill_level>0)
				{
					if(!Silenced(client)&&(bypass||War3_SkillNotInCooldown(client,thisRaceID,SKILL_FIRST,true)) && currentMana[client] >= 6.0)
					{
						currentMana[client] -= 6.0;
						War3_CooldownMGR(client,1.0,thisRaceID,SKILL_THIRD,_,_);
						War3_CooldownMGR(client,2.0,thisRaceID,SKILL_FIRST,_,_);
						
						new Float:fwd[3],Float:fAngles[3],Float:fOrigin[3];
						GetClientEyeAngles(client, fAngles);
						GetClientEyePosition(client, fOrigin);
						GetAngleVectors(fAngles,fwd, NULL_VECTOR, NULL_VECTOR);
						ScaleVector(fwd, 100.0);
						AddVectors(fOrigin, fwd, fOrigin);
						War3_EmitSoundToAll(explSound,client);
						createExplosionEffect(fOrigin);
						
						
						for(new i = 1; i < MaxClients; i++)
						{
							if(IsValidForDamage(i) && IsOnDifferentTeams(client,i))
							{
								new Float:targetvec[3];
								GetEntPropVector(i, Prop_Data, "m_vecOrigin", targetvec);
								if(GetVectorDistance(fOrigin, targetvec, false) <= 250.0)
								{
									if(IsPointVisible(fOrigin,targetvec))
									{
										if(!W3HasImmunity(i,Immunity_Skills))
										{
											SDKHooks_TakeDamage(i, client, client, bashDMG[skill_level], DMG_BLAST, -1, NULL_VECTOR, NULL_VECTOR);
										}
										else
										{
											SDKHooks_TakeDamage(i, client, client, bashDMG[skill_level] * 0.5, DMG_BLAST, -1, NULL_VECTOR, NULL_VECTOR);
										}
									}
								}
							}
						}
						CreateTimer(0.5,doNextBash,client);
					}
				}
			}
			case 2:
			{
				new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_SECOND);
				if(skill_level>0)
				{
					if(!Silenced(client)&&(bypass||War3_SkillNotInCooldown(client,thisRaceID,SKILL_SECOND,true)) && currentMana[client] >= 2.0)
					{
						if(!TF2_IsPlayerInCondition(client, TFCond_Slowed))
						{
							currentMana[client] -= 2.0;
							
							new Float:fAngles[3],Float:angleVec[3],Float:velocity[3];
							GetClientEyeAngles(client, fAngles);
							GetAngleVectors(fAngles,angleVec,NULL_VECTOR,NULL_VECTOR);
							
							velocity[0]=angleVec[0] * chargeSPEED[skill_level] * 1.25;
							velocity[1]=angleVec[1] * chargeSPEED[skill_level] * 1.25;
							velocity[2]=300.0;
							
							TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
							War3_EmitSoundToAll(chargeSound,client);
						}
						else
						{
							W3Hint(client,HINT_COOLDOWN_NOTREADY,2.0,"You cannot use charge while slowed.");
						}
					}
				}
			}
			case 3:
			{
				new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_THIRD);
				if(skill_level>0)
				{
					if(!Silenced(client)&&(bypass||War3_SkillNotInCooldown(client,thisRaceID,SKILL_THIRD,true)) && currentMana[client] >= 10.0)
					{
						currentMana[client] -= 10.0;
						War3_CooldownMGR(client,1.0,thisRaceID,SKILL_FIRST,_,_);
						War3_CooldownMGR(client,3.0,thisRaceID,SKILL_THIRD,_,_);
						War3_EmitSoundToAll(explSound,client);
						for(new i = 1;i<MaxClients;i++)
						{
							if(ValidPlayer(i,true) && IsOnDifferentTeams(client, i))
							{
								if(IsTargetInSightRange(client, i, 60.0, 200.0, true, false))
								{
									if(IsAbleToSee(client,i) == true)
									{
										SDKHooks_TakeDamage(i, client, client, 10.0, DMG_BLAST, -1, NULL_VECTOR, NULL_VECTOR);
										new Float:velocity[3];
										velocity[0]=0.0;
										velocity[1]=0.0;
										velocity[2]=1800.0;
										TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, velocity);
										isUppercutted[i] = true;
									}
								}
							}
						}
						CreateTimer(0.5,uppercutFall,client);
					}
				}
			}
		}
	}
}

public void OnUltimateCommand(int client, int race, bool pressed, bool bypass)
{
	if(RaceDisabled)
		return;

	if(race==thisRaceID && pressed && ValidPlayer(client,true))
	{
		new skill_level = War3_GetSkillLevel(client,thisRaceID,ULT);
		if(skill_level > 0)
		{
			if(!Silenced(client)&&War3_SkillNotInCooldown(client,thisRaceID,ULT,true) && currentMana[client] >= 12.0)
			{
				currentMana[client] -= 12.0;
				War3_CooldownMGR(client,4.0,thisRaceID,ULT,_,_);
				War3_EmitSoundToAll(ultsnd,client);
				new team = GetClientTeam(client);
				new victimteam;
				new Float:pos[3];
				GetClientEyePosition(client, pos);
				for(new i = 1;i<MaxClients;i++)
				{
					if(ValidPlayer(i,true))
					{
						victimteam = GetClientTeam(i);
						new Float:victimPos[3],Float:distance;
						GetClientEyePosition(i,victimPos);
						distance = GetVectorDistance(victimPos,pos);
						if(distance <= 600.0)
						{
							if(victimteam != team)
							{
								if(!W3HasImmunity(i,Immunity_Ultimates))
								{
									SDKHooks_TakeDamage(i, client, client, warscreamDMG[skill_level], DMG_BLAST, -1, NULL_VECTOR, NULL_VECTOR);
								}
							}
							else
							{
								TF2_AddCondition(i, TFCond_Buffed, warscreamDURATION[skill_level]);
							}
						}
					}
				}
			}
		}
	}
}
