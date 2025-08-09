GLOBAL_VAR_INIT(LOOC_COLOR, null)//If this is null, use the CSS for OOC. Otherwise, use a custom colour.
GLOBAL_VAR_INIT(normal_looc_colour, "#6699CC")

/client/verb/looc(msg as text)
	set name = "LOOC"
	set desc = "Local OOC, seen only by those in view."
	set category = "OOC"

	if(GLOB.say_disabled)	//This is here to try to identify lag problems
		to_chat(usr, "<span class='danger'> Speech is currently admin-disabled.</span>")
		return

	if(!mob)
		return

	msg = copytext_char(sanitize(msg), 1, MAX_MESSAGE_LEN)
	if(!msg)
		return

	if(!(prefs.chat_toggles & CHAT_OOC))
		to_chat(src, "<span class='danger'> You have OOC muted.</span>")
		return
	if(jobban_isbanned(mob, "OOC"))
		to_chat(src, "<span class='danger'>You have been banned from OOC.</span>")
		return

	if(!holder)
		if(!GLOB.looc_allowed)
			to_chat(src, "<span class='danger'> LOOC is globally muted</span>")
			return
		if(prefs.muted & MUTE_OOC)
			to_chat(src, "<span class='danger'> You cannot use OOC (muted).</span>")
			return
		if(handle_spam_prevention(msg,MUTE_OOC))
			return
		if(findtext(msg, "byond://"))
			to_chat(src, "<B>Advertising other servers is not allowed.</B>")
			log_admin("[key_name(src)] has attempted to advertise in LOOC: [msg]")
			return
		//if(mob.stat)
		//	to_chat(src, "<span class='danger'>You cannot use LOOC while unconscious or dead.</span>")
		//	return
		//if(isdead(mob))
		//	to_chat(src, "<span class='danger'>You cannot use LOOC while ghosting.</span>")
		//	return
		//GS13 - removed LOOC limits for ghosts (paraphrased from old code)
		if(HAS_TRAIT(mob, TRAIT_LOOC_MUTE))
			to_chat(src, "<span class='danger'>You cannot use LOOC right now.</span>")
			return


	msg = emoji_parse(msg)

	mob.log_talk(msg,LOG_OOC, tag="LOOC")

	// GS13 - LOOC tweaks - Observers, mobs in containers can properly hear LOOC
	// Search everything in the view for anything that might be a mob, or contain a mob.
	var/list/client/targets = list()
	var/list/turf/in_view = list()
	for(var/turf/viewed_turf in view(get_turf(mob)))
		in_view[viewed_turf] = TRUE
	for(var/client/client in GLOB.clients)
		if(!client.mob || !(usr.client.prefs.chat_toggles & CHAT_LOOC) || (client in GLOB.admins))
			continue
		if(in_view[get_turf(client.mob)] && (client.mob.client.prefs.chat_toggles & CHAT_LOOC))
			targets |= client
			to_chat(client, "<span class='looc'><span class='prefix'>LOOC:</span> <EM>[src.mob.name]:</EM> <span class='message'>[msg]</span></b></font>")

	for(var/client/client in GLOB.admins)
		if(!(client.prefs.chat_toggles & CHAT_LOOC))
			continue
		var/prefix = "(R)LOOC"
		to_chat(client, "<span class='looc'><span class='prefix'>[prefix]:</span> <EM>[ADMIN_LOOKUPFLW(usr)]:</EM> <span class='message'>[msg]</span></span>", avoid_highlighting = (client == src))
