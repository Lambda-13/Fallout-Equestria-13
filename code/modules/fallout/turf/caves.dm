//Fallout 13 caves and mining system, classics of SS13 circa 2012

/**********************Mineral deposits**************************/

var/global/list/rockTurfEdgeCache
#define NORTH_EDGING	"north"
#define SOUTH_EDGING	"south"
#define EAST_EDGING		"east"
#define WEST_EDGING		"west"
turf/var/rockpick=null
turf/closed/mineral/proc/randomizerock(mineraltype)
	icon_state = pick("rock1","rock2","rock3","rock4","rock5","rock6")
	spawn(50)
		spawn(1)
			for(var/turf/t in orange(1,src))
				t.updateMineralOverlays()
	switch(mineraltype)
		if("iron")
			icon_state = pick("rock_Iron1","rock_Iron2","rock_Iron3")
		if("gold")
			icon_state = pick("rock_Gold1","rock_Gold2","rock_Gold3")
		if("silver")
			icon_state = pick("rock_Silver1","rock_Silver2","rock_Silver3")
		if("uranium")
			icon_state = pick("rock_Uranium1","rock_Uranium2","rock_Uranium3")
		if("diamond")
			icon_state = pick("rock_Diamond1","rock_Diamond2","rock_Diamond3")
		if("plasma")
			icon_state = pick("rock_Plasma1","rock_Plasma2","rock_Plasma3")
		if("bscrystal")
			icon_state = pick("rock_Iron1","rock_Iron2","rock_Iron3")
		if("bananium")
			icon_state = pick("rock_Clown1","rock_Clown2","rock_Clown3")

/turf/closed/mineral //wall piece
	name = "rock"
	icon = 'icons/fallout/turfs/mining.dmi'
	icon_state = "rock2"
	//var/smooth_icon = 'icons/turf/smoothrocks.dmi'
	//smooth = SMOOTH_MORE|SMOOTH_BORDER
	canSmoothWith
	baseturf = /turf/open/indestructible/ground/mountain
	initial_gas_mix = "TEMP=2.7"
	opacity = 1
	density = 1
	blocks_air = 1
	layer = TURF_LAYER + 0.1
	temperature = TCMB
	var/environment_type = "asteroid"
	var/turf/open/turf_type = /turf/open/indestructible/ground/mountain
	var/mineralType = null
	var/mineraltype
	var/mineralAmt = 3
	var/spread = 0 //will the seam spread?
	var/spreadChance = 0 //the percentual chance of an ore spreading to the neighbouring tiles
	var/last_act = 0
	var/scan_state = null //Holder for the image we display when we're pinged by a mining scanner
	var/defer_change = 0

/turf/closed/mineral/New()
	..()
	if (mineralType && mineralAmt && spread && spreadChance)
		for(var/dir in cardinal)
			if(prob(spreadChance))
				var/turf/T = get_step(src, dir)
				if(istype(T, /turf/closed/mineral/random))
					Spread(T)
	//spawn(15)
		//randomizerock(mineraltype)
/turf/closed/mineral/shuttleRotate(rotation)
	setDir(angle2dir(rotation+dir2angle(dir)))
	queue_smooth(src)

/turf/closed/mineral/ChangeTurf(path, defer_change = FALSE, ignore_air = FALSE)
	for(var/turf/t in range(1,src))
		t.clearMineralOverlays()
	..()
	for(var/turf/t in range(1,src))
		t.updateMineralOverlays()


/turf/closed/mineral/attackby(obj/item/weapon/pickaxe/P, mob/user, params)

	if (!user.IsAdvancedToolUser())
		usr << "<span class='warning'>You don't have the dexterity to do this!</span>"
		return

	if (istype(P, /obj/item/weapon/pickaxe))
		var/turf/T = user.loc
		if (!isturf(T))
			return

		if(last_act+P.digspeed > world.time)//prevents message spam
			return
		last_act = world.time
		user << "<span class='notice'>You start mining...</span>"
		P.playDigSound()

		if(do_after(user,P.digspeed, target = src))
			if(ismineralturf(src))
				user << "<span class='notice'>You finish cutting into the rock.</span>"
				gets_drilled(user)
				feedback_add_details("pick_used_mining","[P.type]")
	else
		return attack_hand(user)
	return

/turf/closed/mineral/proc/gets_drilled()
	if (mineralType && (src.mineralAmt > 0) && (src.mineralAmt < 11))
		var/i
		for (i=0;i<mineralAmt;i++)
			new mineralType(src)
		feedback_add_details("ore_mined","[mineralType]|[mineralAmt]")
	ChangeTurf(turf_type, defer_change)
	addtimer(CALLBACK(src, PROC_REF(AfterChange)), 1, TIMER_UNIQUE)
	playsound(src, 'sound/effects/break_stone.ogg', 50, 1) //beautiful destruction
	fullUpdateJunctionOverlays()
	return

/turf/closed/mineral/attack_animal(mob/living/simple_animal/user)
	if(user.environment_smash >= 2)
		gets_drilled()
	..()

/turf/closed/mineral/attack_alien(mob/living/carbon/alien/M)
	M << "<span class='notice'>You start digging into the rock...</span>"
	playsound(src, 'sound/effects/break_stone.ogg', 50, 1)
	if(do_after(M,40, target = src))
		M << "<span class='notice'>You tunnel into the rock.</span>"
		gets_drilled(M)

/turf/closed/mineral/Bumped(AM as mob|obj)
	..()
	if(ishuman(AM))
		var/mob/living/carbon/human/H = AM
		var/obj/item/I = H.is_holding_item_of_type(/obj/item/weapon/pickaxe)
		if(I)
			attackby(I,H)
		return
	else if(iscyborg(AM))
		var/mob/living/silicon/robot/R = AM
		if(istype(R.module_active,/obj/item/weapon/pickaxe))
			src.attackby(R.module_active,R)
			return
/*	else if(istype(AM,/obj/mecha))
		var/obj/mecha/M = AM
		if(istype(M.selected,/obj/item/mecha_parts/mecha_equipment/drill))
			src.attackby(M.selected,M)
			return*/
//Aparantly mechs are just TOO COOL to call Bump(), so fuck em (for now)
	else
		return

/turf/closed/mineral/acid_melt()
	ChangeTurf(baseturf)

/turf/closed/mineral/ex_act(severity, target)
	..()
	switch(severity)
		if(3)
			if (prob(75))
				src.gets_drilled(null, 1)
		if(2)
			if (prob(90))
				src.gets_drilled(null, 1)
		if(1)
			src.gets_drilled(null, 1)
	return

/turf/closed/mineral/Spread(turf/T)
	T.ChangeTurf(type)

/turf/closed/mineral/random
	var/mineralSpawnChanceList
		//Currently, Adamantine won't spawn as it has no uses. -Durandan
	var/mineralChance = 13
	var/display_icon_state = "rock"

/*/turf/closed/mineral/random/New()
	..()
	if (prob(mineralChance))
		mineralSpawnChanceList = list(
			/turf/closed/mineral/uranium = 5, /turf/closed/mineral/diamond = 1, /turf/closed/mineral/gold = 10,
			/turf/closed/mineral/silver = 12, /turf/closed/mineral/plasma = 20, /turf/closed/mineral/iron = 40, /turf/closed/mineral/titanium = 11,
			/turf/closed/mineral/gibtonite = 4, /turf/open/indestructible/ground/mountain = 2, /turf/closed/mineral/bscrystal = 1)
		var/mName = pickweight(mineralSpawnChanceList) //temp mineral name
		if (mName)
			var/turf/closed/mineral/M
			switch(mName)
				if("Uranium")
					M = new/turf/closed/mineral/uranium(src)
					M.randomizerock("uranium")
				if("Iron")
					M = new/turf/closed/mineral/iron(src)
					M.randomizerock("iron")
				if("Diamond")
					M = new/turf/closed/mineral/diamond(src)
					M.randomizerock("diamond")
				if("Gold")
					M = new/turf/closed/mineral/gold(src)
					M.randomizerock("gold")
				if("Silver")
					M = new/turf/closed/mineral/silver(src)
					M.randomizerock("silver")
				if("Plasma")
					M = new/turf/closed/mineral/plasma(src)
					M.randomizerock("plasma")
					new/turf/open/indestructible/ground/mountain(src)
				if("Gibtonite")
					M = new/turf/closed/mineral/gibtonite(src)
					M.randomizerock("gibtonite")
				if("Bananium")
					M = new/turf/closed/mineral/clown(src)
					M.randomizerock("bananium")
				if("BScrystal")
					M = new/turf/closed/mineral/bscrystal(src)
					M.randomizerock("bscrystal")
				/*if("Adamantine")
					M = new/turf/closed/mineral/adamantine(src)*/
			if(M)
				M.mineralAmt = rand(1, 5)
				M.environment_type = src.environment_type
				M.turf_type = src.turf_type
				M.baseturf = src.baseturf
				src = M
				M.levelupdate()
	return
*/

/turf/closed/mineral/random/New()
	if (!mineralSpawnChanceList)
		mineralSpawnChanceList = list(
			/turf/closed/mineral/uranium = 5, /turf/closed/mineral/diamond = 1, /turf/closed/mineral/gold = 10,
			/turf/closed/mineral/silver = 12, /turf/closed/mineral/plasma = 20, /turf/closed/mineral/iron = 40, /turf/closed/mineral/titanium = 11,
			/turf/closed/mineral/gibtonite = 4, /turf/open/indestructible/ground/mountain = 2, /turf/closed/mineral/bscrystal = 1)
	if (display_icon_state)
		icon_state = display_icon_state
	..()
	if (prob(mineralChance))
		var/path = pickweight(mineralSpawnChanceList)
		var/turf/T = ChangeTurf(path,FALSE,TRUE)

		if(T && ismineralturf(T))
			var/turf/closed/mineral/M = T
			M.mineralAmt = rand(1, 5)
			M.environment_type = src.environment_type
			M.turf_type = src.turf_type
			M.randomizerock(M.mineraltype)
			M.baseturf = src.baseturf
			src = M
			M.levelupdate()
			M.recalc_atom_opacity()

/turf/closed/mineral/random/high_chance
	icon_state = "rock_highchance"
	mineralChance = 25
	mineralSpawnChanceList = list(
		/turf/closed/mineral/uranium = 35, /turf/closed/mineral/diamond = 30, /turf/closed/mineral/gold = 45, /turf/closed/mineral/titanium = 45,
		/turf/closed/mineral/silver = 50, /turf/closed/mineral/plasma = 50, /turf/closed/mineral/bscrystal = 20)

/turf/closed/mineral/random/high_chance/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/lava/smooth/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1
	mineralSpawnChanceList = list(
		/turf/closed/mineral/uranium/volcanic = 35, /turf/closed/mineral/diamond/volcanic = 30, /turf/closed/mineral/gold/volcanic = 45, /turf/closed/mineral/titanium/volcanic = 45,
		/turf/closed/mineral/silver/volcanic = 50, /turf/closed/mineral/plasma/volcanic = 50, /turf/closed/mineral/bscrystal/volcanic = 20)



/turf/closed/mineral/random/low_chance
	icon_state = "rock_lowchance"
	mineralChance = 6
	mineralSpawnChanceList = list(
		/turf/closed/mineral/uranium = 2, /turf/closed/mineral/diamond = 1, /turf/closed/mineral/gold = 4, /turf/closed/mineral/titanium = 4,
		/turf/closed/mineral/silver = 6, /turf/closed/mineral/plasma = 15, /turf/closed/mineral/iron = 40,
		/turf/closed/mineral/gibtonite = 2, /turf/closed/mineral/bscrystal = 1)


/turf/closed/mineral/random/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/lava/smooth/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1

	mineralChance = 10
	mineralSpawnChanceList = list(
		/turf/closed/mineral/uranium/volcanic = 5, /turf/closed/mineral/diamond/volcanic = 1, /turf/closed/mineral/gold/volcanic = 10, /turf/closed/mineral/titanium/volcanic = 11,
		/turf/closed/mineral/silver/volcanic = 12, /turf/closed/mineral/plasma/volcanic = 20, /turf/closed/mineral/iron/volcanic = 40,
		/turf/closed/mineral/gibtonite/volcanic = 4, /turf/open/floor/plating/asteroid/airless/cave/volcanic = 1, /turf/closed/mineral/bscrystal/volcanic = 1)


/turf/closed/mineral/random/labormineral
	mineralSpawnChanceList = list(
		/turf/closed/mineral/uranium = 2, /turf/closed/mineral/diamond = 1, /turf/closed/mineral/gold = 3, /turf/closed/mineral/titanium = 4,
		/turf/closed/mineral/silver = 6, /turf/closed/mineral/plasma = 15, /turf/closed/mineral/iron = 80,
		/turf/closed/mineral/gibtonite = 3)
	icon_state = "rock_labor"


/turf/closed/mineral/random/labormineral/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/lava/smooth/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1
	mineralSpawnChanceList = list(
		/turf/closed/mineral/uranium/volcanic = 2, /turf/closed/mineral/diamond/volcanic = 1, /turf/closed/mineral/gold/volcanic = 3, /turf/closed/mineral/titanium/volcanic = 4,
		/turf/closed/mineral/silver/volcanic = 6, /turf/closed/mineral/plasma/volcanic = 15, /turf/closed/mineral/iron/volcanic = 80,
		/turf/closed/mineral/gibtonite/volcanic = 3)


/turf/closed/mineral/iron
	icon_state = "rock_Iron"
	mineralType = /obj/item/weapon/ore/iron
	mineraltype ="iron"
	spreadChance = 20
	spread = 1
	scan_state = "rock_Iron"
	New()


/turf/closed/mineral/iron/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1


/turf/closed/mineral/uranium
	mineralType = /obj/item/weapon/ore/uranium
	mineraltype ="uranium"
	spreadChance = 5
	spread = 1
	scan_state = "rock_Uranium"

/turf/closed/mineral/uranium/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1


/turf/closed/mineral/diamond
	mineralType = /obj/item/weapon/ore/diamond
	mineraltype ="diamond"
	spreadChance = 0
	spread = 1
	scan_state = "rock_Diamond"

/turf/closed/mineral/diamond/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1


/turf/closed/mineral/gold
	mineralType = /obj/item/weapon/ore/gold
	mineraltype ="gold"
	spreadChance = 5
	spread = 1
	scan_state = "rock_Gold"

/turf/closed/mineral/gold/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1

/turf/closed/mineral/cooper
	mineralType = /obj/item/weapon/ore/cooper
	mineraltype ="cooper"
	spreadChance = 5
	spread = 1
	scan_state = "rock_Cooper"

/turf/closed/mineral/cooper/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1

/turf/closed/mineral/silver
	mineralType = /obj/item/weapon/ore/silver
	mineraltype ="silver"
	spreadChance = 5
	spread = 1
	scan_state = "rock_Silver"

/turf/closed/mineral/silver/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1


/turf/closed/mineral/titanium
	mineralType = /obj/item/weapon/ore/titanium
	spreadChance = 5
	spread = 1
	scan_state = "rock_Titanium"

/turf/closed/mineral/titanium/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1


/turf/closed/mineral/plasma
	mineralType = /obj/item/weapon/ore/plasma
	mineraltype ="plasma"
	spreadChance = 8
	spread = 1
	scan_state = "rock_Plasma"

/turf/closed/mineral/plasma/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1


/turf/closed/mineral/clown
	mineralType = /obj/item/weapon/ore/bananium
	mineraltype ="bananium"
	mineralAmt = 3
	spreadChance = 0
	spread = 0
	scan_state = "rock_Clown"


/turf/closed/mineral/bscrystal
	mineralType = /obj/item/weapon/ore/bluespace_crystal
	mineraltype ="bscrystal"
	mineralAmt = 1
	spreadChance = 0
	spread = 0
	scan_state = "rock_BScrystal"

/turf/closed/mineral/bscrystal/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1


/turf/closed/mineral/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt
	baseturf = /turf/open/floor/plating/asteroid/basalt
	initial_gas_mix = "o2=14;n2=23;TEMP=300"

/turf/closed/mineral/volcanic/lava_land_surface
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/lava/smooth/lava_land_surface
	defer_change = 1

/turf/closed/mineral/ash_rock //wall piece
	name = "rock"
	icon = 'icons/turf/mining.dmi'
	//smooth_icon = 'icons/turf/walls/rock_wall.dmi'
	icon_state = "rock2"
	smooth = SMOOTH_MORE|SMOOTH_BORDER
	canSmoothWith = list (/turf/closed)
	baseturf = /turf/open/floor/plating/ashplanet/wateryrock
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	environment_type = "waste"
	turf_type = /turf/open/floor/plating/ashplanet/rocky
	defer_change = 1


//GIBTONITE

/turf/closed/mineral/gibtonite
	mineralAmt = 1
	spreadChance = 0
	spread = 0
	scan_state = "rock_Gibtonite"
	var/det_time = 8 //Countdown till explosion, but also rewards the player for how close you were to detonation when you defuse it
	var/stage = 0 //How far into the lifecycle of gibtonite we are, 0 is untouched, 1 is active and attempting to detonate, 2 is benign and ready for extraction
	var/activated_ckey = null //These are to track who triggered the gibtonite deposit for logging purposes
	var/activated_name = null
	var/activated_image = null

/turf/closed/mineral/gibtonite/New()
	det_time = rand(8,10) //So you don't know exactly when the hot potato will explode
	..()

/turf/closed/mineral/gibtonite/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/device/mining_scanner) || istype(I, /obj/item/device/t_scanner/adv_mining_scanner) && stage == 1)
		user.visible_message("<span class='notice'>[user] holds [I] to [src]...</span>", "<span class='notice'>You use [I] to locate where to cut off the chain reaction and attempt to stop it...</span>")
		defuse()
	..()

/turf/closed/mineral/gibtonite/proc/explosive_reaction(mob/user = null, triggered_by_explosion = 0)
	if(stage == 0)
		var/image/I = image('icons/turf/smoothrocks.dmi', loc = src, icon_state = "rock_Gibtonite_active", layer = ON_EDGED_TURF_LAYER)
		add_overlay(I)
		activated_image = I
		name = "gibtonite deposit"
		desc = "An active gibtonite reserve. RUN!"
		stage = 1
		visible_message("<span class='danger'>There was gibtonite inside! It's going to explode!</span>")
		var/turf/bombturf = get_turf(src)
		var/area/A = get_area(bombturf)

		var/notify_admins = 0
		if(z != 5)
			notify_admins = 1
			if(!triggered_by_explosion)
				message_admins("[key_name_admin(user)]<A HREF='?_src_=holder;adminmoreinfo=\ref[user]'>?</A> (<A HREF='?_src_=holder;adminplayerobservefollow=\ref[user]'>FLW</A>) has triggered a gibtonite deposit reaction at <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[bombturf.x];Y=[bombturf.y];Z=[bombturf.z]'>[A.name] (JMP)</a>.")
			else
				message_admins("An explosion has triggered a gibtonite deposit reaction at <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[bombturf.x];Y=[bombturf.y];Z=[bombturf.z]'>[A.name] (JMP)</a>.")

		if(!triggered_by_explosion)
			log_game("[key_name(user)] has triggered a gibtonite deposit reaction at [A.name] ([A.x], [A.y], [A.z]).")
		else
			log_game("An explosion has triggered a gibtonite deposit reaction at [A.name]([bombturf.x],[bombturf.y],[bombturf.z])")

		countdown(notify_admins)

/turf/closed/mineral/gibtonite/proc/countdown(notify_admins = 0)
	set waitfor = 0
	while(istype(src, /turf/closed/mineral/gibtonite) && stage == 1 && det_time > 0 && mineralAmt >= 1)
		det_time--
		sleep(5)
	if(istype(src, /turf/closed/mineral/gibtonite))
		if(stage == 1 && det_time <= 0 && mineralAmt >= 1)
			var/turf/bombturf = get_turf(src)
			mineralAmt = 0
			stage = 3
			explosion(bombturf,1,3,5, adminlog = notify_admins)

/turf/closed/mineral/gibtonite/proc/defuse()
	if(stage == 1)
		overlays -= activated_image
		var/image/I = image('icons/turf/smoothrocks.dmi', loc = src, icon_state = "rock_Gibtonite_inactive", layer = ON_EDGED_TURF_LAYER)
		add_overlay(I)
		desc = "An inactive gibtonite reserve. The ore can be extracted."
		stage = 2
		if(det_time < 0)
			det_time = 0
		visible_message("<span class='notice'>The chain reaction was stopped! The gibtonite had [src.det_time] reactions left till the explosion!</span>")

/turf/closed/mineral/gibtonite/gets_drilled(mob/user, triggered_by_explosion = 0)
	if(stage == 0 && mineralAmt >= 1) //Gibtonite deposit is activated
		playsound(src,'sound/effects/hit_on_shattered_glass.ogg',50,1)
		explosive_reaction(user, triggered_by_explosion)
		return
	if(stage == 1 && mineralAmt >= 1) //Gibtonite deposit goes kaboom
		var/turf/bombturf = get_turf(src)
		mineralAmt = 0
		stage = 3
		explosion(bombturf,1,2,5, adminlog = 0)
	if(stage == 2) //Gibtonite deposit is now benign and extractable. Depending on how close you were to it blowing up before defusing, you get better quality ore.
		var/obj/item/weapon/twohanded/required/gibtonite/G = new /obj/item/weapon/twohanded/required/gibtonite/(src)
		if(det_time <= 0)
			G.quality = 3
			G.icon_state = "Gibtonite ore 3"
		if(det_time >= 1 && det_time <= 2)
			G.quality = 2
			G.icon_state = "Gibtonite ore 2"

	ChangeTurf(turf_type, defer_change)
	addtimer(CALLBACK(src, PROC_REF(AfterChange)), 1, TIMER_UNIQUE)


/turf/closed/mineral/gibtonite/volcanic
	environment_type = "basalt"
	turf_type = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	baseturf = /turf/open/floor/plating/asteroid/basalt/lava_land_surface
	initial_gas_mix = "o2=14;n2=23;TEMP=300"
	defer_change = 1
