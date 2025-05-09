/*********************Mining Hammer****************/
/obj/item/kinetic_crusher
	icon = 'icons/obj/mining.dmi'
	icon_state = "crusher"
	item_state = "crusher0"
	lefthand_file = 'icons/mob/inhands/weapons/hammers_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/hammers_righthand.dmi'
	name = "proto-kinetic crusher"
	desc = "An early design of the proto-kinetic accelerator, it is little more than an combination of various mining tools cobbled together, forming a high-tech club. \
	While it is an effective mining tool, it did little to aid any but the most skilled and/or suicidal miners against local fauna."
	resistance_flags = FIRE_PROOF //GS13: Fireproof miner equipment
	force = 0 //You can't hit stuff unless wielded
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = ITEM_SLOT_BACK
	throwforce = 5
	throw_speed = 4
	armour_penetration = 10
	custom_materials = list(/datum/material/iron=1150, /datum/material/glass=2075)
	hitsound = 'sound/weapons/bladeslice.ogg'
	attack_verb = list("smashed", "crushed", "cleaved", "chopped", "pulped")
	sharpness = SHARP_EDGED
	actions_types = list(/datum/action/item_action/toggle_light)
	obj_flags = UNIQUE_RENAME
	var/list/trophies = list()
	var/charged = TRUE
	var/charge_time = 15
	var/detonation_damage = 50
	var/backstab_bonus = 30
	var/light_on = FALSE
	var/brightness_on = 7
	var/wielded = FALSE // track wielded status on item

/obj/item/kinetic_crusher/cyborg
	icon_state = "crusher-cyborg"
	item_state = "crusher0-cyborg"
	desc = "An integrated version of the standard kinetic crusher with a kinetic dampener module installed to limit harmful usage misusage against organics. Deals damage equal to the standard crusher against creatures."
	force = 10 //wouldn't want to give a borg a 20 brute melee weapon unemagged now would we
	detonation_damage = 60
	wielded = 1

/obj/item/kinetic_crusher/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_TWOHANDED_WIELD, PROC_REF(on_wield))
	RegisterSignal(src, COMSIG_TWOHANDED_UNWIELD, PROC_REF(on_unwield))

/obj/item/kinetic_crusher/ComponentInitialize()
	. = ..()
	AddComponent(/datum/component/butchering, 60, 110) //technically it's huge and bulky, but this provides an incentive to use it
	AddComponent(/datum/component/two_handed, force_unwielded=0, force_wielded=20)

/obj/item/kinetic_crusher/Destroy()
	QDEL_LIST(trophies)
	return ..()

/// triggered on wield of two handed item
/obj/item/kinetic_crusher/proc/on_wield(obj/item/source, mob/user)
	wielded = TRUE

/// triggered on unwield of two handed item
/obj/item/kinetic_crusher/proc/on_unwield(obj/item/source, mob/user)
	wielded = FALSE

/obj/item/kinetic_crusher/examine(mob/living/user)
	. = ..()
	. += "<span class='notice'>Mark a large creature with the destabilizing force, then hit them in melee to do <b>[force + detonation_damage]</b> damage.</span>"
	. += "<span class='notice'>Does <b>[force + detonation_damage + backstab_bonus]</b> damage if the target is backstabbed, instead of <b>[force + detonation_damage]</b>.</span>"
	for(var/t in trophies)
		var/obj/item/crusher_trophy/T = t
		. += "<span class='notice'>It has \a [T] attached, which causes [T.effect_desc()].</span>"

/obj/item/kinetic_crusher/attackby(obj/item/I, mob/living/user)
	if(I.tool_behaviour == TOOL_CROWBAR)
		if(LAZYLEN(trophies))
			to_chat(user, "<span class='notice'>You remove [src]'s trophies.</span>")
			I.play_tool_sound(src)
			for(var/t in trophies)
				var/obj/item/crusher_trophy/T = t
				T.remove_from(src, user)
		else
			to_chat(user, "<span class='warning'>There are no trophies on [src].</span>")
	else if(istype(I, /obj/item/crusher_trophy))
		var/obj/item/crusher_trophy/T = I
		T.add_to(src, user)
	else
		return ..()

/obj/item/kinetic_crusher/attack(mob/living/target, mob/living/carbon/user)
	if(!wielded)
		to_chat(user, "<span class='warning'>[src] is too heavy to use with one hand.")
		return
	var/datum/status_effect/crusher_damage/C = target.has_status_effect(STATUS_EFFECT_CRUSHERDAMAGETRACKING)
	var/target_health = target.health
	..()
	for(var/t in trophies)
		if(!QDELETED(target))
			var/obj/item/crusher_trophy/T = t
			T.on_melee_hit(target, user)
	if(!QDELETED(C) && !QDELETED(target))
		C.total_damage += target_health - target.health //we did some damage, but let's not assume how much we did

/obj/item/kinetic_crusher/afterattack(atom/target, mob/living/user, proximity_flag, clickparams)
	. = ..()
	if(istype(target, /obj/item/crusher_trophy))
		var/obj/item/crusher_trophy/T = target
		T.add_to(src, user)
	if(!wielded)
		return
	if(!proximity_flag && charged)//Mark a target, or mine a tile.
		var/turf/proj_turf = user.loc
		if(!isturf(proj_turf))
			return
		var/obj/item/projectile/destabilizer/D = new /obj/item/projectile/destabilizer(proj_turf)
		for(var/t in trophies)
			var/obj/item/crusher_trophy/T = t
			T.on_projectile_fire(D, user)
		D.preparePixelProjectile(target, user, clickparams)
		D.firer = user
		D.hammer_synced = src
		playsound(user, 'sound/weapons/plasma_cutter.ogg', 100, 1)
		D.fire()
		charged = FALSE
		update_icon()
		addtimer(CALLBACK(src, PROC_REF(Recharge)), charge_time)
		return
	if(proximity_flag && isliving(target))
		var/mob/living/L = target
		var/datum/status_effect/crusher_mark/CM = L.has_status_effect(STATUS_EFFECT_CRUSHERMARK)
		if(!CM || CM.hammer_synced != src || !L.remove_status_effect(STATUS_EFFECT_CRUSHERMARK))
			return
		var/datum/status_effect/crusher_damage/C = L.has_status_effect(STATUS_EFFECT_CRUSHERDAMAGETRACKING)
		var/target_health = L.health
		for(var/t in trophies)
			var/obj/item/crusher_trophy/T = t
			T.on_mark_detonation(target, user)
		if(!QDELETED(L))
			if(!QDELETED(C))
				C.total_damage += target_health - L.health //we did some damage, but let's not assume how much we did
			new /obj/effect/temp_visual/kinetic_blast(get_turf(L))
			var/backstab_dir = get_dir(user, L)
			var/def_check = L.getarmor(type = BOMB)
			if((user.dir & backstab_dir) && (L.dir & backstab_dir))
				if(!QDELETED(C))
					C.total_damage += detonation_damage + backstab_bonus //cheat a little and add the total before killing it, so certain mobs don't have much lower chances of giving an item
				L.apply_damage(detonation_damage + backstab_bonus, BRUTE, blocked = def_check)
				playsound(user, 'sound/weapons/kenetic_accel.ogg', 100, 1) //Seriously who spelled it wrong
			else
				if(!QDELETED(C))
					C.total_damage += detonation_damage
				L.apply_damage(detonation_damage, BRUTE, blocked = def_check)

			if(user && lavaland_equipment_pressure_check(get_turf(user))) //CIT CHANGE - makes sure below only happens in low pressure environments
				user.adjustStaminaLoss(-30)//CIT CHANGE - makes crushers heal stamina

/obj/item/kinetic_crusher/proc/Recharge()
	if(!charged)
		charged = TRUE
		update_icon()
		playsound(src.loc, 'sound/weapons/kenetic_reload.ogg', 60, 1)

/obj/item/kinetic_crusher/ui_action_click(mob/user, actiontype)
	light_on = !light_on
	playsound(user, 'sound/weapons/empty.ogg', 100, TRUE)
	update_brightness(user)
	update_icon()

/obj/item/kinetic_crusher/proc/update_brightness(mob/user = null)
	if(light_on)
		set_light(brightness_on)
	else
		set_light(0)

/obj/item/kinetic_crusher/update_icon_state()
	item_state = "crusher[wielded]" // this is not icon_state and not supported by 2hcomponent

/obj/item/kinetic_crusher/update_overlays()
	. = ..()
	if(!charged)
		. += "[icon_state]_uncharged"
	if(light_on)
		. += "[icon_state]_lit"

/obj/item/kinetic_crusher/glaive
	name = "proto-kinetic glaive"
	desc = "A modified design of a proto-kinetic crusher, it is still little more of a combination of various mining tools cobbled together \
	and kit-bashed into a high-tech cleaver on a stick - with a handguard and a goliath hide grip. While it is still of little use to any \
	but the most skilled and/or suicidal miners against local fauna, it's an elegant weapon for a more civilized hunter."
	attack_verb = list("stabbed", "diced", "sliced", "cleaved", "chopped", "lacerated", "cut", "jabbed", "punctured")
	icon_state = "crusher-glaive"
	item_state = "crusher0-glaive"
	block_parry_data = /datum/block_parry_data/crusherglaive
	obj_flags = UNIQUE_RENAME
	//ideas: altclick that lets you pummel people with the handguard/handle?
	//parrying functionality?

/datum/block_parry_data/crusherglaive // small perfect window, active for a fair while, time it right or use the Forbidden Technique
	parry_time_windup = 0
	parry_time_active = 8
	parry_time_spindown = 0
	parry_time_perfect = 1
	parry_time_perfect_leeway = 2
	parry_imperfect_falloff_percent = 20
	parry_efficiency_to_counterattack = 100 // perfect parry or you're cringe
	parry_failed_stagger_duration = 1.5 SECONDS // a good time to reconsider your actions...

/obj/item/kinetic_crusher/glaive/on_active_parry(mob/living/owner, atom/object, damage, attack_text, attack_type, armour_penetration, mob/attacker, def_zone, list/block_return, parry_efficiency, parry_time) // if you're dumb enough to go for a parry...
	var/turf/proj_turf = owner.loc // destabilizer bolt, ignoring cooldown
	if(!isturf(proj_turf))
		return
	var/obj/item/projectile/destabilizer/D = new /obj/item/projectile/destabilizer(proj_turf)
	for(var/t in trophies)
		var/obj/item/crusher_trophy/T = t
		T.on_projectile_fire(D, owner)
	D.preparePixelProjectile(attacker, owner)
	D.firer = owner
	D.hammer_synced = src
	playsound(owner, 'sound/weapons/plasma_cutter.ogg', 100, 1)
	D.fire()

/obj/item/kinetic_crusher/glaive/active_parry_reflex_counter(mob/living/owner, atom/object, damage, attack_text, attack_type, armour_penetration, mob/attacker, def_zone, list/return_list, parry_efficiency, list/effect_text)
	if(owner.Adjacent(attacker) && (!attacker.anchored || ismegafauna(attacker))) // free backstab, if you perfect parry
		attacker.dir = get_dir(owner,attacker)

/// triggered on wield of two handed item
/obj/item/kinetic_crusher/glaive/on_wield(obj/item/source, mob/user)
	wielded = TRUE
	item_flags |= (ITEM_CAN_PARRY)

/// triggered on unwield of two handed item
/obj/item/kinetic_crusher/glaive/on_unwield(obj/item/source, mob/user)
	wielded = FALSE
	item_flags &= ~(ITEM_CAN_PARRY)

/obj/item/kinetic_crusher/glaive/update_icon_state()
	item_state = "crusher[wielded]-glaive" // this is not icon_state and not supported by 2hcomponent

/obj/item/kinetic_crusher/glaive/bone
	name = "necropolis bone glaive"
	desc = "Tribals trying to immitate technology have spent a long time to somehow assemble bits and pieces to work together just like the real thing. \
	Although it does take a lot of effort and luck to create, it was a success."
	icon_state = "crusher-bone"
	item_state = "crusher0-bone"

/obj/item/kinetic_crusher/glaive/bone/update_icon_state()
	item_state = "crusher[wielded]-bone"

/obj/item/kinetic_crusher/glaive/gauntlets
	name = "proto-kinetic gauntlets"
	desc = "A pair of scaled-down proto-kinetic crusher destabilizer modules shoved into gauntlets and concealed greaves, \
	often fielded by those who wish to spit in the eyes of God. Sacrifices outright damage for \
	a reliance on backstabs and the ability to stagger fauna on a parry, \
	slowing them and increasing the time between their special attacks."
	attack_verb = list("pummeled", "punched", "jabbed", "hammer-fisted", "uppercut", "slammed")
	hitsound = 'sound/weapons/resonator_blast.ogg'
	sharpness = SHARP_NONE // use your survival dagger or smth
	icon_state = "crusher-hands"
	item_state = "crusher0-fist"
	unique_reskin = list(
		"Gauntlets" =  list("icon_state" = "crusher-hands"),
		"Fingerless" = list("icon_state" = "crusher-hands-bare")
	)
	detonation_damage = 45 // 60 on wield, compared to normal crusher's 70
	backstab_bonus = 70 // 130 on backstab though
	var/combo_on_anything = FALSE // @admins if you're varediting this you don't get to whine at me
	var/streak = "" // you know what time it is
	var/max_streak_length = 2 // changes with style module
	var/mob/living/current_target
	var/datum/gauntlet_style/active_style

/obj/item/kinetic_crusher/glaive/gauntlets/Initialize(mapload)
	. = ..()
	active_style = new /datum/gauntlet_style/brawler
	active_style.on_apply(src)

/obj/item/kinetic_crusher/glaive/gauntlets/examine(mob/living/user)
	. = ..()
	. += "According to a very small display, the currently loaded style is \"[active_style.name]\"."

/obj/item/kinetic_crusher/glaive/gauntlets/examine_more(mob/user)
	return active_style.examine_more_info()

/obj/item/kinetic_crusher/glaive/gauntlets/proc/style_change(datum/gauntlet_style/new_style)
	new_style.on_apply(src)

/obj/item/kinetic_crusher/glaive/gauntlets/ComponentInitialize()
	. = ..()
	AddComponent(/datum/component/two_handed, force_unwielded=0, force_wielded=15)

/obj/item/kinetic_crusher/glaive/gauntlets/active_parry_reflex_counter(mob/living/owner, atom/object, damage, attack_text, attack_type, armour_penetration, mob/attacker, def_zone, list/return_list, parry_efficiency, list/effect_text)
	. = ..()
	if(isliving(attacker))
		var/mob/living/liv_atk = attacker
		if(liv_atk.mob_size >= MOB_SIZE_LARGE) // are you goated with the sauce
			liv_atk.apply_status_effect(STATUS_EFFECT_GAUNTLET_CONC)

/obj/item/kinetic_crusher/glaive/gauntlets/update_icon_state()
	if(current_skin == "Fingerless")
		item_state = "crusher[wielded]-fistbare"
	else
		item_state = "crusher[wielded]-fist"

/obj/item/kinetic_crusher/glaive/gauntlets/attack(mob/living/target, mob/living/carbon/user)
	..()
	if((combo_on_anything || target.mob_size >= MOB_SIZE_LARGE) && wielded)
		switch(user.a_intent)
			if(INTENT_DISARM)
				add_to_streak("D", user, target)
			if(INTENT_GRAB)
				add_to_streak("G", user, target)
			if(INTENT_HARM)
				add_to_streak("H", user, target)
		active_style.check_streak(user, target)

/obj/item/kinetic_crusher/glaive/gauntlets/proc/add_to_streak(element,mob/living/carbon/user, mob/living/target)
	if(target != current_target)
		reset_streak(target, user)
	streak = streak+element
	if(length(streak) > max_streak_length)
		streak = copytext(streak, 1 + length(streak[1]))
	user?.hud_used?.combo_display.update_icon_state(streak)
	return

/obj/item/kinetic_crusher/glaive/gauntlets/proc/reset_streak(mob/living/new_target, mob/living/carbon/user)
	current_target = new_target
	streak = ""
	user?.hud_used?.combo_display.update_icon_state(streak)

//destablizing force
/obj/item/projectile/destabilizer
	name = "destabilizing force"
	icon_state = "pulse1"
	nodamage = TRUE
	damage = 0 //We're just here to mark people. This is still a melee weapon.
	damage_type = BRUTE
	flag = BOMB
	range = 6
	log_override = TRUE
	var/obj/item/kinetic_crusher/hammer_synced

/obj/item/projectile/destabilizer/Destroy()
	hammer_synced = null
	return ..()

/obj/item/projectile/destabilizer/on_hit(atom/target, blocked = FALSE)
	if(isliving(target))
		var/mob/living/L = target
		var/had_effect = (L.has_status_effect(STATUS_EFFECT_CRUSHERMARK)) //used as a boolean
		var/datum/status_effect/crusher_mark/CM = L.apply_status_effect(STATUS_EFFECT_CRUSHERMARK, hammer_synced)
		if(hammer_synced)
			for(var/t in hammer_synced.trophies)
				var/obj/item/crusher_trophy/T = t
				T.on_mark_application(target, CM, had_effect)
	var/target_turf = get_turf(target)
	if(ismineralturf(target_turf))
		var/turf/closed/mineral/M = target_turf
		new /obj/effect/temp_visual/kinetic_blast(M)
		M.gets_drilled(firer)
	..()

//trophies
/obj/item/crusher_trophy
	name = "tail spike"
	desc = "A strange spike with no usage."
	icon = 'icons/obj/lavaland/artefacts.dmi'
	icon_state = "tail_spike"
	var/bonus_value = 10 //if it has a bonus effect, this is how much that effect is
	var/denied_type = /obj/item/crusher_trophy

/obj/item/crusher_trophy/examine(mob/living/user)
	. = ..()
	. += "<span class='notice'>Causes [effect_desc()] when attached to a kinetic crusher.</span>"

/obj/item/crusher_trophy/proc/effect_desc()
	return "errors"

/obj/item/crusher_trophy/attackby(obj/item/A, mob/living/user)
	if(istype(A, /obj/item/kinetic_crusher))
		add_to(A, user)
	else
		..()

/obj/item/crusher_trophy/proc/add_to(obj/item/kinetic_crusher/H, mob/living/user)
	for(var/t in H.trophies)
		var/obj/item/crusher_trophy/T = t
		if(istype(T, denied_type) || istype(src, T.denied_type))
			to_chat(user, "<span class='warning'>You can't seem to attach [src] to [H]. Maybe remove a few trophies?</span>")
			return FALSE
	if(!user.transferItemToLoc(src, H))
		return
	H.trophies += src
	to_chat(user, "<span class='notice'>You attach [src] to [H].</span>")
	return TRUE

/obj/item/crusher_trophy/proc/remove_from(obj/item/kinetic_crusher/H, mob/living/user)
	forceMove(get_turf(H))
	H.trophies -= src
	return TRUE

/obj/item/crusher_trophy/proc/on_melee_hit(mob/living/target, mob/living/user) //the target and the user
/obj/item/crusher_trophy/proc/on_projectile_fire(obj/item/projectile/destabilizer/marker, mob/living/user) //the projectile fired and the user
/obj/item/crusher_trophy/proc/on_mark_application(mob/living/target, datum/status_effect/crusher_mark/mark, had_mark) //the target, the mark applied, and if the target had a mark before
/obj/item/crusher_trophy/proc/on_mark_detonation(mob/living/target, mob/living/user) //the target and the user

//goliath
/obj/item/crusher_trophy/goliath_tentacle
	name = "goliath tentacle"
	desc = "A sliced-off goliath tentacle. Suitable as a trophy for a kinetic crusher."
	icon_state = "goliath_tentacle"
	denied_type = /obj/item/crusher_trophy/goliath_tentacle
	bonus_value = 2
	var/missing_health_ratio = 0.1
	var/missing_health_desc = 10

/obj/item/crusher_trophy/goliath_tentacle/effect_desc()
	return "mark detonation to do <b>[bonus_value]</b> more damage for every <b>[missing_health_desc]</b> health you are missing"

/obj/item/crusher_trophy/goliath_tentacle/on_mark_detonation(mob/living/target, mob/living/user)
	var/missing_health = user.health - user.maxHealth
	missing_health *= missing_health_ratio //bonus is active at all times, even if you're above 90 health
	missing_health *= bonus_value //multiply the remaining amount by bonus_value
	if(missing_health > 0)
		target.adjustBruteLoss(missing_health) //and do that much damage

//watcher
/obj/item/crusher_trophy/watcher_wing
	name = "watcher wing"
	desc = "A wing ripped from a watcher. Suitable as a trophy for a kinetic crusher."
	icon_state = "watcher_wing"
	denied_type = /obj/item/crusher_trophy/watcher_wing
	bonus_value = 10

/obj/item/crusher_trophy/watcher_wing/effect_desc()
	return "mark detonation to prevent certain creatures from using certain attacks for <b>[bonus_value*0.1]</b> second\s"

/obj/item/crusher_trophy/watcher_wing/on_mark_detonation(mob/living/target, mob/living/user)
	if(ishostile(target))
		var/mob/living/simple_animal/hostile/H = target
		if(H.ranged) //briefly delay ranged attacks
			if(H.ranged_cooldown >= world.time)
				H.ranged_cooldown += bonus_value
			else
				H.ranged_cooldown = bonus_value + world.time

//magmawing watcher
/obj/item/crusher_trophy/blaster_tubes/magma_wing
	name = "magmawing watcher wing"
	desc = "A still-searing wing from a magmawing watcher. Suitable as a trophy for a kinetic crusher."
	icon_state = "magma_wing"
	gender = NEUTER
	bonus_value = 5

/obj/item/crusher_trophy/blaster_tubes/magma_wing/effect_desc()
	return "mark detonation to make the next destabilizer shot deal <b>[bonus_value]</b> damage"

/obj/item/crusher_trophy/blaster_tubes/magma_wing/on_projectile_fire(obj/item/projectile/destabilizer/marker, mob/living/user)
	if(deadly_shot)
		marker.name = "heated [marker.name]"
		marker.icon_state = "lava"
		marker.damage = bonus_value
		marker.nodamage = FALSE
		deadly_shot = FALSE

//icewing watcher
/obj/item/crusher_trophy/watcher_wing/ice_wing
	name = "icewing watcher wing"
	desc = "A carefully preserved frozen wing from an icewing watcher. Suitable as a trophy for a kinetic crusher."
	icon_state = "ice_wing"
	bonus_value = 8

//legion
/obj/item/crusher_trophy/legion_skull
	name = "legion skull"
	desc = "A dead and lifeless legion skull. Suitable as a trophy for a kinetic crusher."
	icon_state = "legion_skull"
	denied_type = /obj/item/crusher_trophy/legion_skull
	bonus_value = 3

/obj/item/crusher_trophy/legion_skull/effect_desc()
	return "a kinetic crusher to recharge <b>[bonus_value*0.1]</b> second\s faster"

/obj/item/crusher_trophy/legion_skull/add_to(obj/item/kinetic_crusher/H, mob/living/user)
	. = ..()
	if(.)
		H.charge_time -= bonus_value

/obj/item/crusher_trophy/legion_skull/remove_from(obj/item/kinetic_crusher/H, mob/living/user)
	. = ..()
	if(.)
		H.charge_time += bonus_value

//blood-drunk hunter
/obj/item/crusher_trophy/miner_eye
	name = "eye of a blood-drunk hunter"
	desc = "Its pupil is collapsed and turned to mush. Suitable as a trophy for a kinetic crusher."
	icon_state = "hunter_eye"
	denied_type = /obj/item/crusher_trophy/miner_eye

/obj/item/crusher_trophy/miner_eye/effect_desc()
	return "mark detonation to grant stun immunity and <b>90%</b> damage reduction for <b>1</b> second"

/obj/item/crusher_trophy/miner_eye/on_mark_detonation(mob/living/target, mob/living/user)
	user.apply_status_effect(STATUS_EFFECT_BLOODDRUNK)

//ash drake
/obj/item/crusher_trophy/tail_spike
	desc = "A spike taken from an ash drake's tail. Suitable as a trophy for a kinetic crusher."
	denied_type = /obj/item/crusher_trophy/tail_spike
	bonus_value = 5

/obj/item/crusher_trophy/tail_spike/effect_desc()
	return "mark detonation to do <b>[bonus_value]</b> damage to nearby creatures and push them back"

/obj/item/crusher_trophy/tail_spike/on_mark_detonation(mob/living/target, mob/living/user)
	for(var/mob/living/L in oview(2, user))
		if(L.stat == DEAD)
			continue
		playsound(L, 'sound/magic/fireball.ogg', 20, 1)
		new /obj/effect/temp_visual/fire(L.loc)
		addtimer(CALLBACK(src, PROC_REF(pushback), L, user), 1) //no free backstabs, we push AFTER module stuff is done
		L.adjustFireLoss(bonus_value, forced = TRUE)

/obj/item/crusher_trophy/tail_spike/proc/pushback(mob/living/target, mob/living/user)
	if(!QDELETED(target) && !QDELETED(user) && (!target.anchored || ismegafauna(target))) //megafauna will always be pushed
		step(target, get_dir(user, target))

//bubblegum
/obj/item/crusher_trophy/demon_claws
	name = "demon claws"
	desc = "A set of blood-drenched claws from a massive demon's hand. Suitable as a trophy for a kinetic crusher."
	icon_state = "demon_claws"
	gender = PLURAL
	denied_type = /obj/item/crusher_trophy/demon_claws
	bonus_value = 10
	var/static/list/damage_heal_order = list(BRUTE, BURN, OXY)

/obj/item/crusher_trophy/demon_claws/effect_desc()
	return "melee hits to do <b>[bonus_value * 0.2]</b> more damage and heal you for <b>[bonus_value * 0.1]</b>, with <b>5X</b> effect on mark detonation"

/obj/item/crusher_trophy/demon_claws/add_to(obj/item/kinetic_crusher/H, mob/living/user)
	. = ..()
	if(.)
		H.force += bonus_value * 0.2
		H.detonation_damage += bonus_value * 0.8
		AddComponent(/datum/component/two_handed, force_wielded=(20 + bonus_value * 0.2))

/obj/item/crusher_trophy/demon_claws/remove_from(obj/item/kinetic_crusher/H, mob/living/user)
	. = ..()
	if(.)
		H.force -= bonus_value * 0.2
		H.detonation_damage -= bonus_value * 0.8
		AddComponent(/datum/component/two_handed, force_wielded=20)

/obj/item/crusher_trophy/demon_claws/on_melee_hit(mob/living/target, mob/living/user)
	user.heal_ordered_damage(bonus_value * 0.1, damage_heal_order)

/obj/item/crusher_trophy/demon_claws/on_mark_detonation(mob/living/target, mob/living/user)
	user.heal_ordered_damage(bonus_value * 0.4, damage_heal_order)

//colossus
/obj/item/crusher_trophy/blaster_tubes
	name = "blaster tubes"
	desc = "The blaster tubes from a colossus's arm. Suitable as a trophy for a kinetic crusher."
	icon_state = "blaster_tubes"
	gender = PLURAL
	denied_type = /obj/item/crusher_trophy/blaster_tubes
	bonus_value = 15
	var/deadly_shot = FALSE

/obj/item/crusher_trophy/blaster_tubes/effect_desc()
	return "mark detonation to make the next destabilizer shot deal <b>[bonus_value]</b> damage but move slower"

/obj/item/crusher_trophy/blaster_tubes/on_projectile_fire(obj/item/projectile/destabilizer/marker, mob/living/user)
	if(deadly_shot)
		marker.name = "deadly [marker.name]"
		marker.icon_state = "chronobolt"
		marker.damage = bonus_value
		marker.nodamage = FALSE
		marker.pixels_per_second = TILES_TO_PIXELS(5)
		deadly_shot = FALSE

/obj/item/crusher_trophy/blaster_tubes/on_mark_detonation(mob/living/target, mob/living/user)
	deadly_shot = TRUE
	addtimer(CALLBACK(src, PROC_REF(reset_deadly_shot)), 300, TIMER_UNIQUE|TIMER_OVERRIDE)

/obj/item/crusher_trophy/blaster_tubes/proc/reset_deadly_shot()
	deadly_shot = FALSE

//hierophant
/obj/item/crusher_trophy/vortex_talisman
	name = "vortex talisman"
	desc = "A glowing trinket that was originally the Hierophant's beacon. Suitable as a trophy for a kinetic crusher."
	icon_state = "vortex_talisman"
	denied_type = /obj/item/crusher_trophy/vortex_talisman
	var/vortex_cd

/obj/item/crusher_trophy/vortex_talisman/effect_desc()
	return "mark detonation to create a barrier you can pass that lasts for <b>7.5 seconds</b>, with a cooldown of <b>9 seconds</b> after creation."

/obj/item/crusher_trophy/vortex_talisman/on_mark_detonation(mob/living/target, mob/living/user)
	if(vortex_cd >= world.time)
		return
	var/turf/T = get_turf(user)
	var/obj/effect/temp_visual/hierophant/wall/crusher/W = new (T, user) //a wall only you can pass!
	var/turf/otherT = get_step(T, turn(user.dir, 90))
	if(otherT)
		new /obj/effect/temp_visual/hierophant/wall/crusher(otherT, user)
	otherT = get_step(T, turn(user.dir, -90))
	if(otherT)
		new /obj/effect/temp_visual/hierophant/wall/crusher(otherT, user)
	vortex_cd = world.time + W.duration * 1.2

/obj/effect/temp_visual/hierophant/wall/crusher
	duration = 75
