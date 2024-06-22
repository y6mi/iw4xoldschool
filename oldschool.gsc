#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
/*
	Money In The Bank
	Objective: 	Collect money from drop points around the map and cash in at various locations to add to your score.
	Map ends:	When one player reaches the score limit, or time limit is reached
	Respawning:	No wait / Away from other players

	Level requirements
	------------------
		Spawnpoints:
			classname		mp_dm_spawn
			All players spawn from these. The spawnpoint chosen is dependent on the current locations of enemies at the time of spawn.
			Players generally spawn away from enemies.

		Spectator Spawnpoints:
			classname		mp_global_intermission
			Spectators spawn from these and intermission is viewed from these positions.
			Atleast one is required, any more and they are randomly chosen between.
*/

/*QUAKED mp_dm_spawn (1.0 0.5 0.0) (-16 -16 0) (16 16 72)
Players spawn away from enemies at one of these positions.*/


/////////original by iaegle, fixed by yami for iw4x


main()
{
	maps\mp\gametypes\_globallogic::init();
	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	maps\mp\gametypes\_globallogic::SetupCallbacks();

	registerTimeLimitDvar( level.gameType, 10, 0, 1440 );
	registerScoreLimitDvar( level.gameType, 100000, 0, 5000 );
	registerWinLimitDvar( level.gameType, 1, 0, 5000 );
	registerRoundLimitDvar( level.gameType, 1, 0, 10 );
	registerNumLivesDvar( level.gameType, 0, 0, 10 );
	registerHalfTimeDvar( level.gameType, 0, 0, 1 );

	level.onStartGameType = ::onStartGameType;
	level.getSpawnPoint = ::getSpawnPoint;
	level.teamBased = true;
    level.prematchWaitForTeams = false;
	SetDvar( "ui_allow_teamchange", 1 );
	SetDvar( "scr_teambalance", 1 );

	game["dialog"]["gametype"] = "moneyinthebank";

	level thread mitblogic();
}


onStartGameType()
{
	setClientNameMode("auto_change");

	setObjectiveText( "allies", &"OBJECTIVES_DM" );
	setObjectiveText( "axis", &"OBJECTIVES_DM" );

	if ( level.splitscreen )
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_DM" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_DM" );
	}
	else
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_DM_SCORE" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_DM_SCORE" );
	}
	setObjectiveHintText( "allies", &"OBJECTIVES_DM_HINT" );
	setObjectiveHintText( "axis", &"OBJECTIVES_DM_HINT" );

	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_dm_spawn" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_dm_spawn" );
	level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );
	
	allowed[0] = "dm";
	maps\mp\gametypes\_gameobjects::main(allowed);

	maps\mp\gametypes\_rank::registerScoreInfo( "kill", 50 );
	maps\mp\gametypes\_rank::registerScoreInfo( "headshot", 50 );
	maps\mp\gametypes\_rank::registerScoreInfo( "assist", 10 );
	maps\mp\gametypes\_rank::registerScoreInfo( "suicide", 0 );
	maps\mp\gametypes\_rank::registerScoreInfo( "teamkill", 0 );
	
	level.QuickMessageToAll = true;
}


getSpawnPoint()
{
	spawnPoints = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( self.pers["team"] );
	spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_DM( spawnPoints );

	return spawnPoint;
}


mitblogic()
{


	level.groundfxred	 			= loadfx( maps\mp\gametypes\_teams::getTeamFlagFX( "allies" ) );
	level.groundfxgreen  			= loadfx( maps\mp\gametypes\_teams::getTeamFlagFX( "axis" ) );
    level.glowFxRed		 			= loadfx( "misc/flare_ambient" );
    level.glowFxGreen	 			= loadfx( "misc/flare_ambient_green" );
	level.prematchPeriod 			= 5;
	level.weaponSpawns	 			= [];
	level.perkSpawns	 			= [];
	level.inDev						= 1;
	level.oldschoolHints = [];
	level.oldschoolHints[ "weaponHint" ] 	= "Press ^3[{+activate}] ^7to swap for ";
	level.oldschoolHints[ "unavailable" ] 	= "Weapon is currently unavailable";
	level.oldschoolHints[ "perkHint" ] 		= "Press ^3[{+activate}] ^7to pick up ";
	level.oldschoolHints[ "gotPerk"	] 		= "You already have ";
	level.oldschoolHints[ "unavailable2" ] 	= "Perk is currently unavailable";
	
	oldschoolKeys = getArrayKeys( level.oldschoolHints ); 
	for ( i = 0; i < oldschoolKeys.size; i++ )
		precacheString( level.oldschoolHints[ oldschoolKeys[i] ] );
	
	precacheShader( "specialty_lightweight" );
	precacheShader( "specialty_fastreload" );
	precacheShader( "specialty_bulletdamage" );
	precacheShader( "specialty_marathon" );
	precacheShader( "specialty_commando" );
	precacheShader( "specialty_hardline" );
	precacheShader( "specialty_pistoldeath" );
	precacheShader( "specialty_scavenger" );
		
	setDvar( "scr_showperksonspawn", 0 );
	setDvar( "scr_oldschool", 1);
	setDvar( "jump_height", 64 );
	setDvar( "jump_slowdownEnable", 0 );
	setDvar( "bg_fallDamageMinHeight", 256 );
	setDvar( "bg_fallDamageMaxHeight", 512 );
	setDvar( "player_sprintUnlimited", 1 );
	setDvar( "ui_gametype", "Old School");
		
	level thread initPickups();
	level thread onPlayerConnect();



}

onPlayerConnect() 
{
	for(;;) 
	{
		level waittill( "connected", player );
		player thread createHudStrings();
		player thread onJoinedTeam();
	}
}

onJoinedTeam() 
{
	self endon("disconnect");

	for(;;)	
	{
		self waittill( "joined_team" );
		self thread onPlayerSpawned();
	}
}


onPlayerSpawned()
{
	self endon("disconnect");
	self.numPerks = 0;
	for(;;)
	{
		self waittill("spawned_player");
		wait .01;
		self thread infoText();
		self.hudInfo = 1;
		
	}
}



infoText()
{
	self endon("disconnect");
	self endon("death");
	
	self notifyOnPlayerCommand("displayInfo", "+smoke");
	
	for(;;)
	{
		self waittill("displayInfo");
		{
			if(self.hudInfo == 0)
			{
				self.infoHeader.alpha = 1;
				self.infoText.alpha = 1;
				self.hudInfo = 0;
			}
			else if(self.hudInfo == 0)
			{
				self.infoHeader.alpha = 0;
				self.infoText.alpha = 0;
				self.hudInfo = 0;
			}
		}
	}
}



initPickups()
{
	level.groundfxred	 			= loadfx( setGroundFx( 0 ) );
	level.groundfxgreen  			= loadfx( setGroundFx( 1 ) );
	level thread getPickups();
	wait 1;
	wepPickups = level.weaponSpawns;
	for ( w = 0; w < wepPickups.size; w++ )
		level thread createWeapon(wepPickups[w].weapon, wepPickups[w].name, wepPickups[w].location);
		
	perkPickups = level.perkSpawns;
	for ( p = 0; p < perkPickups.size; p++ )
		level thread createPerk(perkPickups[p].perk, perkPickups[p].name, perkPickups[p].location, perkPickups[p].shader);
}



/////////////////////////////// HUD / UI LOGIC ////////////////////////////////////////////////////////

createHudStrings()
{
	self.HintText = self createFontString("default", 1.5);
	self.HintText setPoint("CENTER", "CENTER", 0, 115);
	self.HintText.hidewheninmenu = true;
	self.HintText.alpha = .6;
	
	self.nvText = self createFontString( "objective", 0.7 );
	self.nvText setPoint( "TOP", "TOP", -60, 450 );
	self.nvText setText("[[{+actionslot 1}]]\n[Nightvision]");
	self.nvText.hidewheninmenu = true;
	self.nvText.alpha = .6;
	
	self.modText = self createFontString( "objective", 0.7 );
	self.modText setPoint( "TOP", "TOP", 60, 450 );
	self.modText setText("[[{+smoke}]]\n[Mod Info]");
	self.modText.hidewheninmenu = true;
	self.modText.alpha = .6;
	
	self.infoHeader = self createFontString("bigfixed", 0.5);
	self.infoHeader setPoint("TOPLEFT", "TOPLEFT", 110, 5);
	self.infoHeader setText( "Old School (Close: ^2[{+smoke}]^7)" );
	self.infoHeader.hidewheninmenu = true;
	self.infoHeader.alpha = 1;

	self.infoText = self createFontString("default", 0.78);
	self.infoText setPoint("TOPLEFT", "TOPLEFT", 110, 15);
	self.infoText.hidewheninmenu = true;
	self.infoText.alpha = 1;
}



miniMapIcons( icon, origin)
{
	if(!isDefined(origin))
		origin = self.origin;
	curObjID = maps\mp\gametypes\_gameobjects::getNextObjID();	
	objective_add( curObjID, "invisible", (0,0,0) );
	objective_position( curObjID, origin );
	objective_state( curObjID, "active" );
		if(isDefined(icon))
	objective_icon( curObjID, icon );
	self waittill("death");
	objective_delete( curObjID );
}



respawnHint( location, item )
{
	respawntrigger = spawn( "trigger_radius", location, 0, 35, 50 );
	while(1)
	{
		respawntrigger waittill("trigger", player);
		
		if(distance(location, player.origin) < 50)
		{
			if(isDefined(item))
				player.hint = level.oldschoolHints["unavailable"];
			else
				player.hint = level.oldschoolHints["unavailable2"];
		}
		
		if(self.einde)
			respawntrigger delete();
		
		wait .05;
	}
}


/////////////////////////////////////////////////////////////////////////////////////////////////


///////////////////////////////////PICKUPS / FX LOGIC////////////////////////

pickupFX( ent, location, effect, glow )
{
		trace = bulletTrace( ent.origin + (0,0,32), ent.origin + (0,0,-32), false, undefined );
		upangles = vectorToAngles( trace["normal"] );
		forward = anglesToForward( upangles );
		right = anglesToRight( upangles );

		baseEffect = spawnFx( effect, location+(0, 0, 3), forward, right );
		baseEffect.angles = (270, 0, 0);
		triggerFx( baseEffect );
		
		if(isDefined( glow ))
		{
			glowEffect = spawnFx( glow, location+(0, 0, 3), forward, right );
			glowEffect.angles = (270, 0, 0);
			triggerFx( glowEffect );
			
			ent thread deleteOnDeath( glowEffect );
		}
		
		ent thread deleteOnDeath( baseEffect );
}


spinPickup( ent )
{
	self endon( "death" );
	
	spin = spawn( "script_origin", ent.origin );
	spin endon( "death" );
	
	ent linkto( spin );
	ent thread deleteOnDeath( spin );
	
	while(1)
	{
		spin rotateYaw( 360, 3 );
		wait 2.9;
	}
}

deleteOnDeath( ent )
{
	ent endon("death");
	self waittill("death");
	ent destroy();
	ent delete();
}


setGroundFx( color )
{
	if(color == 0)
		return ( tableLookup( "mp/factionTable.csv", 0, "militia", 13 ) );
	else
		return ( tableLookup( "mp/factionTable.csv", 0, "opforce_composite", 13 ) );
}


////////////////////////////////////////PERKS LOGIC///////////////

createPerk(perk, perkName, location, shader)
{
	perkSpawn = spawn( "script_model", location, 1 );
//	perkSpawn.angle = angles;
	perkSpawn thread perkThink(perk, perkName, location, shader);
	perkSpawn thread pickupFX( perkSpawn, location, level.groundfxgreen, level.glowFxGreen );
	foreach(player in level.players)
	{
		if(distance(location, player.origin) < 500)
			player playLocalSound("oldschool_return");
	}
	perkSpawn miniMapIcons( shader );
	wait .1;
}




perkThink(perk, perkName, location, shader)
{
	self endon("disconnect");
	perktrigger = spawn( "trigger_radius", location, 0, 35, 50 );
	while(1)
	{
		perktrigger waittill( "trigger", player );
		if(distance(location, player.origin) < 50)
		{
			if (!player _hasPerk(perk))
			{
				player.hint = level.oldschoolHints["perkHint"] + perkName;
				if(player useButtonPressed())
				{
					player maps\mp\perks\_perks::givePerk( perk );
					player showPerk( player.numPerks, perk, -50, shader, perkName );
					player thread hidePerkNameAfterTime( player.numperks, 4.0 );
					player.numPerks++;
					player iprintln("You picked up " + perkName);
					player playLocalSound("oldschool_pickup");
					
					self delete();
					perktrigger delete();
					self.headIcon destroy();
					
					level thread perkRespawnThink(perk, perkName, location, shader);
				}
			}
			else
			{
				player.hint = level.oldschoolHints["gotPerk"] + perkName;
			}
		}
		wait .05;
	}
}

perkRespawnThink(perk, perkName, location, shader)
{
	unavailable = spawn( "script_origin", location, 1 );
	unavailable thread pickupFX( unavailable, location, level.groundfxred, level.glowFxRed );
	unavailable thread respawnHint( location );
	unavailable.einde = 0;
	wait 25;
	unavailable.einde = 1;
	unavailable delete();
	createPerk(perk, perkName, location, shader);
}

hidePerk( index, fadetime, hideTextOnly )
{
	if ( game["state"] == "postgame" )
	{
		assert( !isdefined( self.perkicon[ index ] ) );
		assert( !isdefined( self.perkname[ index ] ) );
		return;
	}
	
	assert( isdefined( self.perkicon[ index ] ) );
	assert( isdefined( self.perkname[ index ] ) );
	
	if ( isdefined( fadetime ) )
	{
		if ( !isDefined( hideTextOnly ) || !hideTextOnly )
			self.perkicon[ index ] fadeOverTime( fadetime );
			
		self.perkname[ index ] fadeOverTime( fadetime );
	}
	
	if ( !isDefined( hideTextOnly ) || !hideTextOnly )
		self.perkicon[ index ].alpha = 0;
		
	self.perkname[ index ].alpha = 0;
}

hidePerkNameAfterTime( index, delay )
{
	self endon("disconnect");
	
	wait delay;
	
	self thread hidePerk( index, 1.0, true );
}

clearPerksOnDeath()
{
	self endon("disconnect");
	self waittill("death");
	
	self _clearPerks();
	for ( i = 0; i < self.numPerks; i++ )
	{
		self hidePerk( i, 0.05 );
	}
	self.numPerks = 0;
}


showPerk( index, perk, ypos, shader, perkName )
{
	assert( game["state"] != "postgame" );
	
	if ( !isdefined( self.perkicon ) )
	{
		self.perkicon = [];
		self.perkname = [];
	}
	
	iconsize = 32;
	
	if ( !isdefined( self.perkicon[ index ] ) )
	{
		assert( !isdefined( self.perkname[ index ] ) );
		
		xpos = -5;
		ypos = 0 - (105 + iconsize * (2 - index));
		
		icon = createIcon( shader, iconsize, iconsize );
		icon setPoint( "BOTTOMRIGHT", undefined, xpos, ypos );
		icon.archived = false;
		icon.foreground = false;
		
		text = createFontString( "default", 1.4 );
		text setParent( icon );
		text setPoint( "RIGHT", "LEFT", -5, 0 );
		text setText( perkName );
		text.archived = false;
		text.alignX = "right";
		text.alignY = "middle";
		text.foreground = true;

		self.perkicon[ index ] = icon;
		self.perkname[ index ] = text;
	}
		
	icon = self.perkicon[ index ];
	text = self.perkname[ index ];
	
	if ( perk == "specialty_null" )
	{
		icon.alpha = 0;
		text.alpha = 0;
	}
	else
	{
		assertex( isDefined( shader ), perk );
		assertex( isDefined( perkName ), perk );
		
		icon.alpha = 1;
		icon setShader( shader, iconsize, iconsize );
		
		text.alpha = 1;
		text setText( perkName );
	}
}

perkSpawns(perk, perkName, location, shader)
{
    perkz = spawnstruct();
	perkz.perk = perk;
	perkz.name = perkName;
    perkz.location = location;
    perkz.shader = shader;
    return perkz;
}



////////////////////////////END PERKS/////////////////////////////////////////



/////////////////////////////////////////////WEAPON SPAWN LOGIC////////////////////


weaponSpawns(weapon, weaponName, location, hudicon, iconX, iconY)
{
    weapons = spawnstruct();
	weapons.weapon = weapon;
	weapons.name = weaponName;
	weapons.location = location;
    return weapons;
}

CreateWeapon(weapon, weaponName, location)
{
	Camo = 1+randomInt(8);
	weaponModel = getWeaponModel( weapon, camo );
	akimbo = 0;
	
	if( weaponModel == "" )
		weaponModel = weapon;

	weaponSpawn = spawn( "script_model", location + (0, 0, 40), 1 );
	weaponSpawn setModel( weaponModel );
	weaponSpawn thread WeaponThink(weapon, weaponName, location);
	weaponSpawn thread pickupFX( weaponSpawn, location, level.groundfxgreen, level.glowFxGreen );
	weaponSpawn.Camo = Camo;
	foreach(player in level.players)
	{
		if(distance(location, player.origin) < 500)
			player playLocalSound("oldschool_return");
	}
	weaponSpawn thread spinPickup( weaponSpawn );
	
	tags = GetWeaponHideTags(weapon);
	attachments = GetArrayKeys(tags);
	foreach(attachment in attachments)
	{
		weaponSpawn HidePart(tags[attachment]);
	}
	weaponSpawn miniMapIcons();
	wait 0.01;
}

WeaponThink(weapon, weaponName, location)
{
	self endon("disconnect");
	weptrigger = spawn( "trigger_radius", location, 0, 35, 50 );
	while(1)
	{
		weptrigger waittill( "trigger", player );		
		if(distance(location, player.origin) < 50)
		{		
			player.heeftWapen = 0;
			weaponsList = player GetWeaponsListAll();
			foreach( playerWeapon in weaponsList )
			{
				if( playerWeapon == weapon )
					player.heeftWapen = 1;
			}
			
			if(player.heeftWapen && weapon != "riotshield_mp")
			{
				player giveMaxAmmo( weapon );
				player playLocalSound("scavenger_pack_pickup");
				player iprintln("You picked up ammo for " + weaponName);
				
				self delete();
				weptrigger delete();
				level thread weaponRespawnThink(weapon, weaponName, location);
			}
			else
			{
				player.hint = level.oldschoolHints["weaponHint"] + weaponName;
				if(player useButtonPressed())
				{
					player.wepList = player GetWeaponsListAll();
					if( player.wepList.size > 2 )
					{
						player takeWeapon(player getCurrentWeapon());
					}
					player giveWeapon( weapon, self.Camo, false );
					player switchToWeapon( weapon );
					player playLocalSound("oldschool_pickup");
					player iprintln("You picked up " + weaponName);
					
					self delete();
					weptrigger delete();

					level thread weaponRespawnThink(weapon, weaponName, location);
				}
			}
		}
		wait .01;
	}
}

weaponRespawnThink(weapon, weaponName, location)
{
	unavailable = spawn( "script_origin", location, 1 );
	unavailable thread pickupFX( unavailable, location, level.groundfxred, level.glowFxRed );
	unavailable thread respawnHint( location, true );
	unavailable.einde = 0;
	wait 15;
	unavailable.einde = 1;
	unavailable delete();
	createWeapon(weapon, weaponName, location);
}


getPickups()
{
	switch(getDvar("mapname")) 
	{
		case "mp_terminal":
			level.weaponSpawns[0] = weaponSpawns( "uzi_xmags_mp", "Mini Uzi Extended Mags", (1255.43, 5546.35, 192.125), "hud_rpg", 60, 15 );
			level.weaponSpawns[1] = weaponSpawns( "m4_fmj_reflex_mp", "M4A1 Bling", (246.174, 5929.15, 192.125), "hud_desert_eagle", 60, 30 );
			level.weaponSpawns[2] = weaponSpawns( "m21_acog_mp", "M21 ACOG Sight", (617.971, 3769.44, 202.625), "hud_tavor", 60, 30 );
			level.weaponSpawns[3] = weaponSpawns( "ranger_mp", "Ranger", (320.646, 4909.71, 192.125), "hud_kriss", 60, 30 );
			level.weaponSpawns[4] = weaponSpawns( "sa80_acog_heartbeat_mp", "L86 Bling", (1666.89, 4603.5, 174.839), "hud_striker", 60, 30 );
			level.weaponSpawns[5] = weaponSpawns( "masada_shotgun_mp", "ACR w/ Shotgun", (2431.53, 3685.18, 48.125), "hud_mg4", 60, 30 );
			level.weaponSpawns[6] = weaponSpawns( "beretta393_eotech_mp", "M93 Raffica Holographic", (2710.85, 4851.71, 192.125), "hud_riot_shield", 30, 30 );
			level.weaponSpawns[7] = weaponSpawns( "aa12_eotech_xmags_mp", "AA-12 Bling", (2575.07, 5624.43, 192.125), "hud_mp5k", 60, 30 );
			level.weaponSpawns[8] = weaponSpawns( "fal_fmj_gl_mp", "FAL Bling", (852.389, 3259.82, 179.7), "hud_cheytec", 60, 30 );
			level.weaponSpawns[9] = weaponSpawns( "javelin_mp", "Javelin", (1515.19, 4053.92, 304.125), "hud_famas", 60, 30 );
			level.weaponSpawns[10] = weaponSpawns( "deserteagle_mp", "Desert Eagle", (1034.86, 4514.01, 40.125), "hud_p90", 60, 30 );
			level.perkSpawns[0] = perkSpawns( "specialty_bulletdamage", "Stopping Power", (1454.33, 6084.2, 192.125), "specialty_bulletdamage");
			level.perkSpawns[1] = perkSpawns( "specialty_marathon", "Marathon", (1623.5, 3319.4, 40.125), "specialty_marathon");
			level.perkSpawns[2] = perkSpawns( "specialty_pistoldeath", "Last Stand", (1155.6, 4910.29, 192.125), "specialty_pistoldeath");		
			break;
		case "mp_rust":
			level.weaponSpawns[0] = weaponSpawns( "rpg_mp", "RPG-7", (688.536, 1055.71, 266.327), "hud_rpg", 60, 15 );
			level.weaponSpawns[1] = weaponSpawns( "deserteaglegold_mp", "Desert Eagle Gold", (-423.393, 1736.09, -236.841), "hud_desert_eagle", 60, 30 );
			level.weaponSpawns[2] = weaponSpawns( "tavor_eotech_mp", "TAR-21 Holosight", (53.5573, 1520.46, -127.002), "hud_tavor", 60, 30 );
			level.weaponSpawns[3] = weaponSpawns( "kriss_eotech_silencer_mp", "Vector Bling", (-52.9876, 486.034, -234.995), "hud_kriss", 60, 30 );
			level.weaponSpawns[4] = weaponSpawns( "striker_fmj_xmags_mp", "Striker Bling", (719.619, 1354.75, 2.9551), "hud_striker", 60, 30 );
			level.weaponSpawns[5] = weaponSpawns( "mg4_grip_mp", "MG4 Grip", (1047, 522.969, -240.903), "hud_mg4", 60, 30 );
			level.weaponSpawns[6] = weaponSpawns( "riotshield_mp", "Riot Shield", (-366.673, -144.648, -232.752), "hud_riot_shield", 30, 30 );
			level.weaponSpawns[7] = weaponSpawns( "mp5k_mp", "MP5k", (1046.32, 758.945, -5.60439), "hud_mp5k", 60, 30 );
			level.weaponSpawns[8] = weaponSpawns( "cheytac_thermal_mp", "Intervention Thermal Scope", (1554.6, 912.853, -132.875), "hud_cheytec", 60, 30 );
			level.weaponSpawns[9] = weaponSpawns( "famas_mp", "FAMAS", (1246.6, -165.367, -232.966), "hud_famas", 60, 30 );
			level.perkSpawns[0] = perkSpawns( "specialty_lightweight", "Lightweight", (23.7521, 1129.37, -237.155), "specialty_lightweight");
			level.perkSpawns[1] = perkSpawns( "specialty_fastreload", "Sleight of Hand", (1153.9, 1045.64, -236.723), "specialty_fastreload");
			level.perkSpawns[2] = perkSpawns( "specialty_pistoldeath", "Last Stand", (677.279, 219.307, -243.641), "specialty_pistoldeath");			
			break;
		case "mp_brecourt":

			break;
		case "mp_boneyard":
			level.weaponSpawns[0] = weaponSpawns( "scar_fmj_silencer_mp", "SCAR-H Silenced w/ FMJ", (2169.49, 122.945, -151.875), "hud_scar_h", 60, 30 );
			level.weaponSpawns[1] = weaponSpawns( "deserteaglegold_mp", "Desert Eagle Gold", (1204.04, -173.363, -141.834), "hud_desert_eagle", 60, 30 );
			level.weaponSpawns[2] = weaponSpawns( "spas12_eotech_grip_mp", "SPAS-12 Grip w/ Holo Sight", (-775.351, -526.887, -139.966), "hud_spas12", 60, 30 );
			level.weaponSpawns[3] = weaponSpawns( "ak47_mp", "AK-74", (-1521.39, 563.538, -127.875), "hud_ak47", 60, 30 );
			level.weaponSpawns[4] = weaponSpawns( "coltanaconda_tactical_mp", "Magnum Tactical Knife", (-1329.62, 1344.85, -138.472), "hud_colt_anaconda", 60, 30 );
			level.weaponSpawns[5] = weaponSpawns( "pp2000_eotech_silencer_mp", "PP2000 Silenced w/ Holo Sight", (284.461, 1427.35, -71.875), "hud_pp2000", 60, 30 );
			level.weaponSpawns[6] = weaponSpawns( "rpd_mp", "RPD", (1800.24, 1565.4, -83.2569), "hud_rpd", 60, 30 );
			level.weaponSpawns[7] = weaponSpawns( "m16_acog_mp", "M16A3 ACOG Sight", (753.089, 360.838, -119.135), "hud_m16a4", 60, 30 );
			level.weaponSpawns[8] = weaponSpawns( "aug_silencer_xmags_mp", "AUG Silenced w/ Extended Mags", (-295.393, 380.258, -127.733), "hud_steyr", 60, 30 );
			level.weaponSpawns[9] = weaponSpawns( "ump45_silencer_mp", "UMP45 Silenced", (-967.415, 476.021, -21.175), "hud_ump45", 60, 30 );
			level.weaponSpawns[10] = weaponSpawns( "p90_eotech_mp", "P90 Holographic Sight", (431.79, 623.292, -69.375), "hud_p90", 60, 30 );
			level.perkSpawns[0] = perkSpawns( "specialty_pistoldeath", "Last Stand", (631.051, -434.508, -135.875), "specialty_pistoldeath");
			break;
		case "mp_nightshift":
			level.weaponSpawns[0] = weaponSpawns( "uzi_xmags_mp", "Mini Uzi Extended Mags", (436.368, -1488.28, -7.875), "hud_rpg", 60, 15 );
			level.weaponSpawns[1] = weaponSpawns( "m4_fmj_reflex_mp", "M4A1 Bling", (1179.25, 97.7593, -7.875), "hud_desert_eagle", 60, 30 );
			level.weaponSpawns[2] = weaponSpawns( "m21_acog_mp", "M21 ACOG Sight", (-447.478, -622.085, -3.875), "hud_tavor", 60, 30 );
			level.weaponSpawns[3] = weaponSpawns( "ranger_mp", "Ranger", (-478.642, 837.716, 80.125), "hud_kriss", 60, 30 );
			level.weaponSpawns[4] = weaponSpawns( "sa80_acog_heartbeat_mp", "L86 Bling", (-601.169, -616.043, 136.125), "hud_striker", 60, 30 );
			level.weaponSpawns[5] = weaponSpawns( "masada_shotgun_mp", "ACR w/ Shotgun", (-909.571, -2181.03, 80.125), "hud_mg4", 60, 30 );
			level.weaponSpawns[6] = weaponSpawns( "beretta393_eotech_mp", "M93 Raffica Holographic", (-1756.82, -1949.29, -11.875), "hud_riot_shield", 30, 30 );
			level.weaponSpawns[7] = weaponSpawns( "aa12_eotech_xmags_mp", "AA-12 Bling", (-1619.48, -46.0062, -7.875), "hud_mp5k", 60, 30 );
			level.weaponSpawns[8] = weaponSpawns( "fal_fmj_gl_mp", "FAL Bling", (-2357.98, -461.892, 128.125), "hud_cheytec", 60, 30 );
			level.weaponSpawns[9] = weaponSpawns( "javelin_mp", "Javelin", (-407.024, -1888.04, 0.125), "hud_famas", 60, 30 );
			level.perkSpawns[0] = perkSpawns( "specialty_bulletdamage", "Stopping Power", (-357.336, 99.3574, 176.125), "specialty_bulletdamage");
			level.perkSpawns[1] = perkSpawns( "specialty_marathon", "Marathon", (733.807, -690.983, 0.116952), "specialty_marathon");
			level.perkSpawns[2] = perkSpawns( "specialty_pistoldeath", "Last Stand", (-1574.73, -801.84, -7.875), "specialty_pistoldeath");
			break;
		case "mp_afghan":
			level.weaponSpawns[0] = weaponSpawns( "wa2000_heartbeat_silencer_mp", "WA2000 Bling", (377.028, -329.49, -21.6725), "hud_rpg", 60, 15 );
			level.weaponSpawns[1] = weaponSpawns( "m240_reflex_mp", "M240 Red Dot", (-465.453, 1491.27, 194.18), "hud_desert_eagle", 60, 30 );
			level.weaponSpawns[2] = weaponSpawns( "m16_eotech_mp", "M16 Holographic", (625.759, 1535.08, 134.211), "hud_tavor", 60, 30 );
			level.weaponSpawns[3] = weaponSpawns( "m1014_mp", "M1014", (2065.99, 3607.26, 213.04), "hud_kriss", 60, 30 );
			level.weaponSpawns[4] = weaponSpawns( "sa80_acog_heartbeat_mp", "L86 Bling", (3396.55, 2383.95, -40.9165), "hud_striker", 60, 30 );
			level.weaponSpawns[5] = weaponSpawns( "masada_shotgun_mp", "ACR w/ Shotgun", (2484.33, 2176.08, 0.125001), "hud_mg4", 60, 30 );
			level.weaponSpawns[6] = weaponSpawns( "beretta393_eotech_mp", "M93 Raffica Holographic", (1370.62, 1251.63, 65.0899), "hud_riot_shield", 30, 30 );
			level.weaponSpawns[7] = weaponSpawns( "aa12_eotech_xmags_mp", "AA-12 Bling", (2109.01, -106.83, 136.125), "hud_mp5k", 60, 30 );
			level.weaponSpawns[8] = weaponSpawns( "fal_fmj_gl_mp", "FAL Bling", (30.9622, 2447.9, 168.833), "hud_cheytec", 60, 30 );
			level.weaponSpawns[9] = weaponSpawns( "javelin_mp", "Javelin", (2719.02, 848.139, 200.125), "hud_famas", 60, 30 );
			level.weaponSpawns[10] = weaponSpawns( "deserteagle_mp", "Desert Eagle", (1365.8, 233.078, -0.856198), "hud_p90", 60, 30 );
			level.perkSpawns[0] = perkSpawns( "specialty_hardline", "Hardline", (655.562, 3098.95, 224.125), "specialty_hardline");
			level.perkSpawns[1] = perkSpawns( "specialty_fastreload", "Marathon", (1711.21, 748.827, 45.8981), "specialty_fastreload");
			level.perkSpawns[2] = perkSpawns( "specialty_pistoldeath", "Last Stand", (3650.19, 682.715, 69.8054), "specialty_pistoldeath");
			break;
		case "mp_favela":
			level.weaponSpawns[0] = weaponSpawns( "uzi_xmags_mp", "Mini Uzi Extended Mags", (-1149.95, -223.736, 4.62773), "hud_rpg", 60, 15 );
			break;
		case "mp_subbase":
			level.weaponSpawns[0] = weaponSpawns( "uzi_xmags_mp", "Mini Uzi Extended Mags", (-699.233, -2217.65, 0.124997), "hud_rpg", 60, 15 );
			level.weaponSpawns[1] = weaponSpawns( "m4_fmj_reflex_mp", "M4A1 Bling", (601.852, -2316.27, 0.808621), "hud_desert_eagle", 60, 30 );
			level.weaponSpawns[2] = weaponSpawns( "m21_acog_mp", "M21 ACOG Sight", (822.861, -1384.89, 272.125), "hud_tavor", 60, 30 );
			level.weaponSpawns[3] = weaponSpawns( "ranger_mp", "Ranger", (-1207.01, -1043.45, 256.125), "hud_kriss", 60, 30 );
			level.weaponSpawns[4] = weaponSpawns( "sa80_acog_heartbeat_mp", "L86 Bling", (-1148.01, -340.985, 120.125), "hud_striker", 60, 30 );
			level.weaponSpawns[5] = weaponSpawns( "masada_shotgun_mp", "ACR w/ Shotgun", (255.402, -607.828, 88.125), "hud_mg4", 60, 30 );
			level.weaponSpawns[6] = weaponSpawns( "beretta393_eotech_mp", "M93 Raffica Holographic", (638.676, 195.219, 312.125), "hud_riot_shield", 30, 30 );
			level.weaponSpawns[7] = weaponSpawns( "aa12_eotech_xmags_mp", "AA-12 Bling", (1463.12, 1154.47, 32.125), "hud_mp5k", 60, 30 );
			level.weaponSpawns[8] = weaponSpawns( "fal_fmj_gl_mp", "FAL Bling", (323.031, 819.827, 32.125), "hud_cheytec", 60, 30 );
			level.weaponSpawns[9] = weaponSpawns( "javelin_mp", "Javelin", (-1056.08, 980.3, 94.6381), "hud_famas", 60, 30 );
			level.perkSpawns[0] = perkSpawns( "specialty_bulletdamage", "Stopping Power", (418.763, 42.1563, 48.125), "specialty_bulletdamage");
			level.perkSpawns[1] = perkSpawns( "specialty_marathon", "Marathon", (-248.505, -1565.51, 48.125), "specialty_marathon");
			level.perkSpawns[2] = perkSpawns( "specialty_pistoldeath", "Last Stand", (1612.94, -673.881, 0.124998), "specialty_pistoldeath");
			break;
		case "mp_highrise":
			level.weaponSpawns[0] = weaponSpawns( "uzi_xmags_mp", "Mini Uzi Extended Mags", (-705.3, 6851.44, 2736.13), "hud_rpg", 60, 15 );
			level.weaponSpawns[1] = weaponSpawns( "m4_fmj_reflex_mp", "M4A1 Bling", (319.639, 7477.32, 2824.13), "hud_desert_eagle", 60, 30 );
			level.weaponSpawns[2] = weaponSpawns( "m21_acog_mp", "M21 ACOG Sight", (281.94, 5985.43, 2824.13), "hud_tavor", 60, 30 );
			level.weaponSpawns[3] = weaponSpawns( "ranger_mp", "Ranger", (-596.334, 5570.32, 2776.13), "hud_kriss", 60, 30 );
			level.weaponSpawns[4] = weaponSpawns( "sa80_acog_heartbeat_mp", "L86 Bling", (-1397.25, 6265.44, 2648.13), "hud_striker", 60, 30 );
			level.weaponSpawns[5] = weaponSpawns( "masada_shotgun_mp", "ACR w/ Shotgun", (-1187.57, 6850.74, 2770.26), "hud_mg4", 60, 30 );
			level.weaponSpawns[6] = weaponSpawns( "beretta393_eotech_mp", "M93 Raffica Holographic", (-1341.6, 5644.75, 2976.13), "hud_riot_shield", 30, 30 );
			level.weaponSpawns[7] = weaponSpawns( "aa12_eotech_xmags_mp", "AA-12 Bling", (-2192, 5808.24, 2776.13), "hud_mp5k", 60, 30 );
			level.weaponSpawns[8] = weaponSpawns( "fal_fmj_gl_mp", "FAL Bling", (-2977.11, 5308.11, 2824.13), "hud_cheytec", 60, 30 );
			level.weaponSpawns[9] = weaponSpawns( "javelin_mp", "Javelin", (-3376.59, 6292.17, 2824.13), "hud_famas", 60, 30 );
			level.weaponSpawns[10] = weaponSpawns( "deserteagle_mp", "Desert Eagle", (-1952.96, 6875.31, 2824.13), "hud_p90", 60, 30 );
			level.perkSpawns[0] = perkSpawns( "specialty_bulletdamage", "Stopping Power", (-537.748, 6307.69, 2864.13), "specialty_bulletdamage");
			level.perkSpawns[1] = perkSpawns( "specialty_marathon", "Marathon", (-1354.04, 7507.9, 2944.13), "specialty_marathon");
			level.perkSpawns[2] = perkSpawns( "specialty_pistoldeath", "Last Stand", (-2263.89, 6070.82, 2912.13), "specialty_pistoldeath");
			break;
		case "mp_compact":
		
			break;
		case "mp_checkpoint":
		
			break;
		case "mp_underpass":
		
			break;
		case "mp_quarry":
		
			break;
		case "mp_trailerpark":
		
			break;
		case "mp_vacant":
		
			break;
		case "mp_invasion":
		
			break;
	}
}
