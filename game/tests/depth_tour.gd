## Visual tour of the depth update (ADR-0015): drives the game into each new situation
## and saves a PNG. Needs a display (xvfb). Usage:
##   xvfb-run godot --path game --rendering-driver opengl3 --resolution 1280x720 \
##     --script res://tests/depth_tour.gd -- <out_dir> [--phone|--landscape]
extends SceneTree

const CaseState = preload("res://core/case_state.gd")

var main
var host: SubViewport
var out_dir := "user://depth_shots"
var n := 0


func _initialize() -> void:
	var phone_size := Vector2i.ZERO
	for a in OS.get_cmdline_user_args():
		if a == "--phone":
			phone_size = Vector2i(390, 844)
		elif a == "--landscape":
			phone_size = Vector2i(844, 390)
		elif not a.begins_with("--"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://ui/main.tscn").instantiate()
	if phone_size != Vector2i.ZERO:
		main.layout_override = "phone"
		host = SubViewport.new()
		host.size = phone_size
		host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(host)
		host.add_child(main)
	else:
		root.add_child(main)
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in range(k):
		await process_frame


func _shot(name: String, wait := 25) -> void:
	await _frames(wait)
	n += 1
	(host.get_texture() if host else root.get_texture()).get_image().save_png(out_dir.path_join("%02d_%s.png" % [n, name]))


func _overlay() -> Node:
	for i in range(main.overlay_center.get_child_count() - 1, -1, -1):
		var c: Node = main.overlay_center.get_child(i)
		if not c.is_queued_for_deletion():
			return c
	return null


func _clear_overlays() -> void:
	for k in range(600):
		await process_frame
		var o := _overlay()
		if o == null and not main.busy and not main.flying:
			return
		if o == null:
			continue
		if o.has_method("debug_solve"):
			o.debug_solve()
			o.done.emit(true)
		elif o.has_method("hit"):
			if o.kind == "sighting":
				for i in range(3):
					o.hit()
			else:
				o.debug_center_needle()
				o._try_pass()
		elif o.has_method("choose"):
			o.choose(0)
		elif o.has_method("_finish"):
			o._finish()
		await _frames(2)


## Start a case (gear on) and stand at stop `target` of its route.
func _case_at(cid: String, target: int, gear: Array = [], seed_v := 7) -> void:
	main.current_case = cid
	main._start_case()
	await _clear_overlays()
	main.case_seed = seed_v
	main.loadout = gear
	main._accept_case()
	await _clear_overlays()
	var st = main.state
	while st.stop < target and st.status == "playing":
		while not st.pending_event.is_empty():
			st.choose_event(0)
			if not st.pending_minigame.is_empty():
				st.resolve_event_minigame(true)
		var c: Dictionary = main.data.cities[st.route()[st.stop + 1]]
		st.travel_to_pin(c["lat"], c["lon"])
	while not st.pending_event.is_empty():
		st.choose_event(0)
		if not st.pending_minigame.is_empty():
			st.resolve_event_minigame(true)
	main.leg_notes.clear()
	main.last_flight = {}
	main.show_city()
	await _frames(3)


## Scroll the page so the named row is in view (to show its result in the shot).
func _show_row(row_name: String) -> void:
	await _frames(3)
	var row: Control = main._find(row_name)
	if row == null:
		return
	var p := row.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p is ScrollContainer:
		(p as ScrollContainer).ensure_control_visible(row)


func _first_stop(cid: String, key: String, value, seed_v := 7) -> int:
	var s = CaseState.new(main.data, cid, seed_v)
	for i in range(s.plan.size() - 1):
		if s.plan[i].get(key) == value:
			return i
	return -1


func _run() -> void:
	await _frames(3)
	main.progress.path = "user://depth_tour_progress.json"
	main.progress.stars = {"case_01": 3, "case_02": 3, "case_03": 3, "case_04": 3, "case_05": 3, "case_06": 3, "case_07": 3, "case_08": 3, "case_09": 3, "case_10": 3, "case_11": 3, "case_12": 2}
	main.progress.flags = {"tutorial_detective_done": true, "tutorial_fugitive_done": true}
	# Tips seen already (the tour shows the gear and cold-trail ones; the rest would cover shots).
	for t in ["lead", "split", "combo", "jam", "sea", "forged", "double"]:
		main.progress.flags["tip_" + t] = true
	main.progress.loadout = []
	main.show_cases()
	await _shot("cases_objectives")
	# Story + briefing with gang file and gear
	main.current_case = "case_05"
	seed(5)
	main._start_case()
	await _shot("story_intro", 40)
	await _clear_overlays()
	main._toggle_gear("decoder")
	main._toggle_gear("lens")
	main._toggle_gear("interpol")
	await _frames(4)
	await _shot("briefing_gear")
	main._on_coach_ok()
	# City map at the crime city
	main.loadout = ["interpol", "lens", "radar"]
	main._accept_case()
	await _clear_overlays()
	await _shot("city_map")
	var st = main.state
	var best: String = "wiretap" if int(st.peek("wiretap").get("tier", 3)) <= int(st.peek("contact").get("tier", 3)) else "contact"
	main._investigate(best)
	await _clear_overlays()
	main._investigate("money")
	await _clear_overlays()
	await _shot("city_two_done")
	main._on_coach_ok()
	main.show_travel()
	await _shot("travel_known")
	# Thief close: lead strip + intercepted message
	st.message = {"type": "close", "index": 0}
	st.lead_adjust -= 4
	main.show_city()
	await _shot("thief_close")
	# Event card + its mini-game
	var c: Dictionary = main.data.cities[st.route()[1]]
	st.travel_to_pin(c["lat"], c["lon"])
	st.pending_event = {"deck": "events", "card": st._card("events", "witness"), "stop": st.stop}
	main.show_city()
	main._run_event()
	await _shot("event_card")
	_overlay().choose(1)
	await _shot("event_reward", 40)
	await _clear_overlays()
	st.pending_event = {"deck": "reactions", "card": st._card("reactions", "thugs"), "stop": st.stop}
	main._run_event()
	await _shot("reaction_card")
	_overlay().choose(0)
	await _shot("event_minigame", 30)
	await _clear_overlays()
	# Sea leg (Blue Harbour) travel screen without the radar
	var sea := _first_stop("case_05", "sea", true)
	if sea >= 0:
		await _case_at("case_05", sea, [])
		main.show_travel()
		await _shot("travel_sea")
	# Interference (Zero Signal)
	for cid in ["case_08", "case_09", "case_07"]:
		var s = CaseState.new(main.data, cid, 1)
		var j := -1
		for i in range(s.plan.size() - 1):
			if s.plan[i]["wiretap"].get("jammed", false):
				j = i
				break
		if j >= 0:
			await _case_at(cid, j, [], 1)
			main._investigate("wiretap")
			await _clear_overlays()
			main._pending_tip = ""
			main.coach.hide_step()
			await _shot("jammed_wiretap")
			break
	# Body double spotted by the lens (Velvet Hands)
	for cid in ["case_10", "case_11", "case_12"]:
		var j2 := _first_stop(cid, "twist", "double")
		if j2 >= 0:
			await _case_at(cid, j2, ["lens"])
			main._investigate("cctv")
			await _clear_overlays()
			await _show_row("Place_cctv")
			await _shot("double_lens")
			break
	# Forged clue marked by the lie detector (Paper Saints)
	for cid in ["case_03", "case_02"]:
		var j3 := _first_stop(cid, "twist", "forged")
		if j3 >= 0:
			await _case_at(cid, j3, ["detector"])
			main._use_gadget("detector")
			await _frames(3)
			await _shot("forged_detector")
			break
	# Combined half-clues on the travel screen
	for cid in ["case_10", "case_12", "case_13", "case_14", "case_15"]:
		var j4 := _first_stop(cid, "combo", true)
		if j4 >= 0:
			await _case_at(cid, j4, [])
			main._investigate("wiretap")
			await _clear_overlays()
			main._investigate("contact")
			await _clear_overlays()
			main._pending_tip = ""
			main.coach.hide_step()
			await _shot("combo_city")
			main.show_travel()
			await _shot("combo_travel")
			break
	# Two thieves: the split city and its travel screen
	await _case_at("case_07", 2, [])
	main._pending_tip = ""
	main.coach.hide_step()
	await _shot("split_city")
	main.show_travel()
	await _shot("split_travel")
	# Recover: raid map and hideout board
	await _case_at("case_04", main.data.cases["case_04"]["route"].size() - 1, [])
	await _shot("raid_map")
	main.show_board()
	await _shot("hideout_board")
	# Rescue finale
	await _case_at("case_11", main.data.cases["case_11"]["route"].size() - 1, [])
	main.state.issue_warrant(main.state.culprit())
	main.show_chase()
	await _shot("rescue_chase")
	# Results + story outro
	main.state.status = "won"
	main.state.chase_caught = true
	main.show_results()
	await _shot("results_outro", 40)
	print("depth tour: %d shots" % n)
	quit(0)
