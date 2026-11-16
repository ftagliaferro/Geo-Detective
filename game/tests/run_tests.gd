## Headless test runner:  godot --headless --path game --script res://tests/run_tests.gd
extends SceneTree

const GameData = preload("res://core/game_data.gd")
const CaseState = preload("res://core/case_state.gd")
const Deduction = preload("res://core/deduction.gd")
const Geo = preload("res://core/geo.gd")
const Loc = preload("res://core/loc.gd")
const ChaseView = preload("res://ui/chase_view.gd")
const RoofChase = preload("res://ui/roof_chase.gd")
const ClueReveal = preload("res://ui/clue_reveal.gd")
const Progress = preload("res://core/progress.gd")
const EscapeState = preload("res://core/escape_state.gd")

var passed := 0
var failed := 0
var data


func _init() -> void:
	data = GameData.new()
	data.load_all()
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			call(n)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: " + msg)


func test_distance_buenos_aires_lisbon() -> void:
	var a = data.cities["buenos_aires"]
	var b = data.cities["lisbon"]
	var km := Geo.distance_km(a["lat"], a["lon"], b["lat"], b["lon"])
	check(abs(km - 9580.0) < 150.0, "BA-Lisbon distance ~9580 km, got %f" % km)
	check(Geo.travel_hours(km) == 14, "BA-Lisbon 14 h, got %d" % Geo.travel_hours(km))


func test_data_loaded() -> void:
	check(data.cities.size() >= 30, "world city pool loaded")
	check(data.suspects.size() == 32, "32 suspects loaded")
	check(data.cases.size() == 15, "15 cases loaded")
	check(data.trait_ids.size() == 5, "5 traits")


func _pin(s, city: String) -> Dictionary:
	var c: Dictionary = data.cities[city]
	return s.travel_to_pin(c["lat"] + 0.5, c["lon"] - 0.5)


func _win_path(s) -> void:
	for i in range(s.last_stop()):
		for spot in CaseState.SPOTS:
			s.visit(spot)
		_pin(s, s.route()[i + 1])


func test_full_win() -> void:
	var s = CaseState.new(data, "case_01", 42)
	_win_path(s)
	check(s.is_final(), "reached final city")
	check(not s.can_travel(), "no travel from final city")
	s.issue_warrant(s.case_def["culprit"])
	check(s.arrest(true) == "won", "arrest wins")
	check(s.stars() == 3, "perfect run + chase gets 3 stars, got %d" % s.stars())
	check(s.avg_precision_km() < 100.0, "precision recorded")


func test_win_without_chase_bonus() -> void:
	var s = CaseState.new(data, "case_01", 42)
	_win_path(s)
	s.issue_warrant(s.case_def["culprit"])
	s.arrest(false)
	check(s.status == "won" and s.stars() == 2, "won without chase = 2 stars")


func test_wrong_warrant() -> void:
	var s = CaseState.new(data, "case_01", 42)
	_win_path(s)
	s.issue_warrant(_innocent(s))
	check(s.arrest() == "lost_wrong", "wrong warrant loses")


func test_no_warrant() -> void:
	var s = CaseState.new(data, "case_01", 42)
	_win_path(s)
	check(s.arrest() == "lost_nowarrant", "no warrant loses")


func test_cannot_arrest_before_final() -> void:
	var s = CaseState.new(data, "case_01", 42)
	s.issue_warrant(s.case_def["culprit"])
	check(s.arrest() == "playing", "arrest ignored outside final city")


func test_pin_within_radius_hits() -> void:
	var s = CaseState.new(data, "case_01", 42)
	var r: Dictionary = s.travel_to_pin(40.42, -3.70)  # Madrid, ~500 km from Lisbon
	check(r["hit"] and s.current == "lisbon" and s.stop == 1, "pin near Lisbon lands on trail")


func test_pin_miss_lands_elsewhere() -> void:
	var s = CaseState.new(data, "case_01", 42)
	var r: Dictionary = s.travel_to_pin(35.6, 139.7)  # Tokyo
	check(not r["hit"] and s.current == "tokyo", "miss lands at nearest city")
	check(not s.on_trail() and s.misses == 1, "off trail after miss")
	check(s.visit("wiretap")["kind"] == "deadend", "miss gives dead end")


func test_recover_from_miss_to_next_city() -> void:
	var s = CaseState.new(data, "case_01", 42)
	s.travel_to_pin(35.6, 139.7)
	_pin(s, "lisbon")
	check(s.on_trail() and s.stop == 1, "can jump from dead end straight to next city")


func test_recover_from_miss_back() -> void:
	var s = CaseState.new(data, "case_01", 42)
	s.travel_to_pin(35.6, 139.7)
	_pin(s, "buenos_aires")
	check(s.on_trail() and s.stop == 0, "flying back to last good city works")


func test_pin_on_current_city_does_not_stay() -> void:
	var s = CaseState.new(data, "case_01", 42)
	var r: Dictionary = s.resolve_pin(-34.6, -58.4)
	check(r["city"] != "buenos_aires", "never lands on the city you are in")


func test_repeat_visit_free() -> void:
	var s = CaseState.new(data, "case_01", 42)
	s.visit("wiretap")
	var h: int = s.hours_used
	s.visit("wiretap")
	check(s.hours_used == h, "repeat visit costs nothing")


func test_time_runs_out() -> void:
	var s = CaseState.new(data, "case_01", 42)
	var guard := 0
	while s.status == "playing" and guard < 20:
		s.travel_to_pin(35.6, 139.7)
		_pin(s, "buenos_aires")
		guard += 1
	check(s.status == "lost_time", "time runs out")


func test_latlon_roundtrip() -> void:
	for p in [Vector2(0, 0), Vector2(-34.6, -58.38), Vector2(47.5, 19.04), Vector2(64.1, -21.9), Vector2(-36.8, 174.7)]:
		var back: Vector2 = Geo.vec_to_lat_lon(Geo.lat_lon_to_vec(p.x, p.y))
		check(abs(back.x - p.x) < 0.001 and abs(back.y - p.y) < 0.001, "lat/lon roundtrip %s -> %s" % [p, back])


func test_nearest_city() -> void:
	check(Geo.nearest_city(data.cities, 48.0, 16.0) == "vienna", "nearest to (48,16) is Vienna")


func _innocent(s) -> String:
	for sid in data.suspects:
		if data.suspects[sid]["network"] == s.case_def["network"] and sid != s.case_def["culprit"]:
			return sid
	return ""


func _network_pool(net: String) -> Dictionary:
	var pool := {}
	for sid in data.suspects:
		if data.suspects[sid]["network"] == net:
			pool[sid] = data.suspects[sid]
	return pool


func test_every_case_is_solvable_from_trail() -> void:
	for cid in data.cases:
		var s = CaseState.new(data, cid, 7)
		var sel := {}
		for i in range(s.last_stop()):
			var c: Dictionary = s.plan[i]["money"]
			if c["kind"] == "trait":
				sel[c["trait"]] = c["value"]
		var m: Array = Deduction.matching(_network_pool(s.case_def["network"]), sel)
		check(m == [s.case_def["culprit"]], "%s: trail clues single out culprit (got %s)" % [cid, m])


func test_every_case_full_playthrough() -> void:
	for cid in data.cases:
		var s = CaseState.new(data, cid, 11)
		for stop_i in range(s.last_stop()):
			for spot in CaseState.SPOTS:
				s.visit(spot)
			_pin(s, s.route()[stop_i + 1])
		s.issue_warrant(s.case_def["culprit"])
		check(s.arrest(true) == "won", "%s: perfect playthrough wins (status %s, %d/%d h)" % [cid, s.status, s.hours_used, s.budget])


func test_clue_tiers_respected() -> void:
	var s = CaseState.new(data, "case_15", 3)
	for i in range(s.last_stop()):
		check(int(s.plan[i]["wiretap"]["text"].get("tier", 0)) == 3, "case 15 uses tier-3 wiretaps")


func test_long_route_money_gives_destination() -> void:
	var s = CaseState.new(data, "case_15", 3)
	check(s.plan[5]["money"]["kind"] == "dest", "after 5 traits, money trail points to destination")


func test_cctv_enhance() -> void:
	var s = CaseState.new(data, "case_04", 3)
	var c: Dictionary = s.visit("cctv")
	check(c.get("hint_locked", false), "case 4 CCTV hint starts locked")
	var h: int = s.hours_used
	c = s.enhance_cctv()
	check(not c["hint_locked"] and s.hours_used == h + 1, "enhancing costs 1 h and unlocks hint")
	s.enhance_cctv()
	check(s.hours_used == h + 1, "enhancing twice is free")


func test_progress_unlock_and_rank() -> void:
	var p = Progress.new("user://test_progress.json")
	var by_num := {}
	for cid in data.cases:
		by_num[int(data.cases[cid]["number"])] = data.cases[cid]
	check(p.is_unlocked(1, by_num) and not p.is_unlocked(2, by_num), "only case 1 unlocked at start")
	p.record("case_01", 2)
	p.record("case_01", 1)
	check(p.best("case_01") == 2, "best stars kept")
	check(p.is_unlocked(2, by_num), "solving case 1 unlocks case 2")
	p.save_file()
	var q = Progress.new("user://test_progress.json")
	q.load_file()
	check(q.best("case_01") == 2, "progress persists")
	check(str(q.rank()["en"]) == "Rookie", "rank from stars")


func test_deduction_filter() -> void:
	var pool := _network_pool("paper_saints")
	check(Deduction.matching(pool, {}).size() == 6, "empty selection matches whole network")
	var d: Dictionary = pool["dimitri_vask"]["traits"]
	check("dimitri_vask" in Deduction.matching(pool, {"vehicle": d["vehicle"]}), "filter by vehicle")


func test_loc() -> void:
	var l = Loc.new(data.strings, "es")
	check(l.s("back") == "Volver", "spanish string")
	l.toggle()
	check(l.s("back") == "Back", "english string")
	check(l.s("hours", {"used": 2, "budget": 96}) == "Hours: 2 / 96", "format args")


func _run_chase(dodge: bool) -> Variant:
	var chase = ChaseView.new()
	root.add_child(chase)
	var result := [null]
	chase.finished.connect(func(caught: bool): result[0] = caught)
	chase.start(1234)
	var guard := 0
	while chase.running and guard < 2000:
		if dodge:
			for o in chase.obstacles:
				if absf(o.position.x - chase.player.position.x) < 0.9 and o.position.z > -12.0:
					chase.lane = (chase.lane + 1) % 3
		chase._process(0.05)
		guard += 1
	chase.queue_free()
	return result[0]


func test_chase_finishes() -> void:
	var r = _run_chase(true)
	check(r != null, "chase emits finished")


func test_chase_clean_run_catches() -> void:
	var chase = ChaseView.new()
	root.add_child(chase)
	var result := [null]
	chase.finished.connect(func(caught: bool): result[0] = caught)
	chase.start(1)
	var guard := 0
	while chase.running and guard < 2000:
		for o in chase.obstacles.duplicate():
			chase._remove(o)  # perfect driving: no collisions
		chase._process(0.05)
		guard += 1
	check(result[0] == true, "perfect run catches the suspect before time runs out")
	chase.queue_free()


func test_suggestions_include_destination() -> void:
	for cid in data.cases:
		var s = CaseState.new(data, cid, 5)
		for i in range(s.last_stop()):
			var sug: Array = s.plan[i]["suggest"]
			var target: String = data.cities[s.route()[i + 1]]["country_code"]
			check(sug.size() == 4 and target in sug, "%s leg %d: 4 suggestions incl. %s (got %s)" % [cid, i, target, sug])


func test_hard_case_suggestions_are_neighbours() -> void:
	var s = CaseState.new(data, "case_13", 5)
	var target: Dictionary = data.countries[data.cities[s.route()[1]]["country_code"]]
	for code in s.plan[0]["suggest"]:
		var c: Dictionary = data.countries[code]
		check(Geo.distance_km(target["lat"], target["lon"], c["lat"], c["lon"]) < 3500.0, "hard decoys are nearby (%s)" % code)


func test_contact_gives_other_destination_clue() -> void:
	var s = CaseState.new(data, "case_13", 9)
	var w: Dictionary = s.plan[0]["wiretap"]["text"]
	var c: Dictionary = s.plan[0]["contact"]["text"]
	check(int(c.get("tier", 0)) == 2 and c != w, "hard case contact gives a tier-2 clue distinct from the wiretap")
	var h: int = s.hours_used
	s.visit("contact")
	check(s.hours_used == h + 3, "contact costs 3 h")


# ---------------- Fugitive mode ----------------

func _epin(e, city: String) -> Dictionary:
	var c: Dictionary = data.cities[city]
	return e.travel_to_pin(c["lat"] + 0.3, c["lon"] + 0.3)


func test_escape_starts_with_head_start() -> void:
	var e = EscapeState.new(data, "escape_01", 1)
	check(is_equal_approx(e.lead(), float(e.def["head_start"])), "lead starts at head start")


func test_escape_actions_cost_time() -> void:
	var e = EscapeState.new(data, "escape_01", 1)
	var l0: float = e.lead()
	var m: Dictionary = e.act("message")
	check(m["kind"] == "message" and is_equal_approx(e.lead(), l0 - 1.0), "message costs 1 h of lead")
	check(e.act("message").is_empty(), "same message cannot be bought twice")


func test_escape_leaving_city_gains_inspector_time() -> void:
	var e = EscapeState.new(data, "escape_01", 1)
	var l0: float = e.lead()
	_epin(e, e.route()[1])
	check(is_equal_approx(e.lead(), l0 + float(e.def["inspector_hours"])), "leaving a city adds her investigation time")


func test_escape_clean_and_decoy() -> void:
	var a = EscapeState.new(data, "escape_01", 1)
	var b = EscapeState.new(data, "escape_01", 1)
	b.act("clean")
	_epin(a, a.route()[1])
	_epin(b, b.route()[1])
	check(is_equal_approx(b.lead() - a.lead(), float(EscapeState.CLEAN_BONUS - EscapeState.COST["clean"])), "cleaning tracks nets +3 h")
	var c = EscapeState.new(data, "escape_01", 1)
	c.act("decoy")
	_epin(c, c.route()[1])
	check(is_equal_approx(c.lead() - a.lead(), float(EscapeState.DECOY_BONUS - EscapeState.COST["decoy"])), "false lead nets +8 h")
	c.act("decoy")
	_epin(c, c.route()[2])
	check(c.decoys_left == 0 and not c.can_act("decoy"), "only two false leads per escape")


func test_escape_wrong_pin_hurts() -> void:
	var a = EscapeState.new(data, "escape_02", 1)
	var b = EscapeState.new(data, "escape_02", 1)
	_epin(a, a.route()[1])
	b.travel_to_pin(35.6, 139.7)  # Tokyo, far off
	check(b.status == "playing" or b.status == "caught", "wrong flight resolves")
	if b.status == "playing":
		_epin(b, b.route()[1])
	check(b.wrong_flights == 1 and (b.status == "caught" or b.lead() < a.lead()), "a detour costs lead (she flies straight)")


func test_escape_caught_when_dawdling() -> void:
	var e = EscapeState.new(data, "escape_05", 1)
	var guard := 0
	while e.status == "playing" and guard < 30:
		e.travel_to_pin(64.1, -21.9)  # Reykjavik detours
		e.travel_to_pin(-36.8, 174.7)  # Auckland detours
		guard += 1
	check(e.status == "caught", "the inspector catches a fugitive who wanders")


func test_every_escape_winnable() -> void:
	for eid in data.escapes:
		var e = EscapeState.new(data, eid, 3)
		for i in range(e.last_stop()):
			e.act("message")
			if e.can_act("decoy"):
				e.act("decoy")
			_epin(e, e.route()[i + 1])
		if e.status == "chase":
			e.finish_chase(true)
		check(e.status == "escaped", "%s: careful play escapes (lead %.1f)" % [eid, e.lead()])
		check(e.stars() >= 2, "%s: clean run earns 2+ stars (got %d)" % [eid, e.stars()])


func test_escape_map_contains_destination() -> void:
	for eid in data.escapes:
		var e = EscapeState.new(data, eid, 4)
		for i in range(e.last_stop()):
			var target: String = data.cities[e.route()[i + 1]]["country_code"]
			check(target in e.leg_info[i]["map"]["countries"], "%s leg %d: map includes destination" % [eid, i])


func test_escape_chase_when_close() -> void:
	var e = EscapeState.new(data, "escape_05", 2)
	for i in range(e.last_stop()):
		e.act("message")
		e.act("message2")
		e.act("map")
		if e.status != "playing":
			break
		_epin(e, e.route()[i + 1])
		if e.status != "playing":
			break
	check(e.status in ["chase", "caught", "escaped"], "slow play ends in chase, capture or narrow escape")
	if e.status == "chase":
		check(e.finish_chase(false) == "caught" and e.stars() == 0, "losing the final chase means capture")


func test_escape_chase_clean_run_survives() -> void:
	var chase = ChaseView.new()
	root.add_child(chase)
	chase.set_escape_mode()
	var result := [null]
	chase.finished.connect(func(ok: bool): result[0] = ok)
	chase.start(1)
	var guard := 0
	while chase.running and guard < 2000:
		for o in chase.obstacles.duplicate():
			chase._remove(o)
		chase._process(0.05)
		guard += 1
	check(result[0] == true, "escape chase: clean driving gets away")
	chase.queue_free()


func test_escape_chase_crashes_get_caught() -> void:
	var chase = ChaseView.new()
	root.add_child(chase)
	chase.set_escape_mode()
	var result := [null]
	chase.finished.connect(func(ok: bool): result[0] = ok)
	chase.start(1)
	var guard := 0
	while chase.running and guard < 2000:
		for o in chase.obstacles:
			o.position.x = chase.player.position.x  # steer into every barrier
		chase._process(0.05)
		guard += 1
	check(result[0] == false, "escape chase: crashing repeatedly gets you caught")
	chase.queue_free()


# ---------------- Action events (ADR-0011) ----------------

func test_wiretap_discount() -> void:
	var s = CaseState.new(data, "case_01", 1)
	s.visit("wiretap", 1)
	check(s.hours_used == 1, "fast tuning makes the wiretap cost 1 h")
	s.visit("contact", 9)
	check(s.hours_used == 2, "discounts never go below 1 h")


func test_sightings_scheduled_and_refund() -> void:
	var any := false
	for cid in data.cases:
		var s = CaseState.new(data, cid, 2)
		for i in range(s.last_stop()):
			if s.plan[i].get("sighting", false):
				any = true
				check(i > 0, "%s: no sighting in the crime city" % cid)
	check(any, "some legs have sightings")
	var s2 = CaseState.new(data, "case_05", 2)
	var leg := -1
	for i in range(1, s2.last_stop()):
		if s2.plan[i]["sighting"]:
			leg = i
			break
	for i in range(leg):
		for spot in CaseState.SPOTS:
			s2.visit(spot)
		_pin(s2, s2.route()[i + 1])
	check(s2.has_sighting(), "sighting available on arrival")
	var h: int = s2.hours_used
	check(s2.resolve_sighting(true) == 3 and s2.hours_used == h - 3, "winning a sighting refunds 3 h")
	check(not s2.has_sighting(), "sighting is once per city")


func test_checkpoint_penalty() -> void:
	var e = EscapeState.new(data, "escape_03", 2)
	var leg := -1
	for i in range(1, e.last_stop()):
		if e.checkpoints.get(i, false):
			leg = i
			break
	check(leg > 0, "escape has passport controls")
	for i in range(leg):
		e.act("message")
		_epin(e, e.route()[i + 1])
	check(e.has_checkpoint(), "checkpoint on arrival")
	var t0: int = e.now
	check(e.resolve_checkpoint(false) == 3 and e.now == t0 + 3, "failing passport control costs 3 h")
	check(not e.has_checkpoint(), "checkpoint resolved once")


# ---------------- Arrest variety (ADR-0012) ----------------

func _run_roof(escape: bool, clean: bool) -> Variant:
	var rc = RoofChase.new()
	rc.size = Vector2(900, 480)
	root.add_child(rc)
	if escape:
		rc.set_escape_mode()
	var result := [null]
	rc.finished.connect(func(ok: bool): result[0] = ok)
	rc.start(5)
	var guard := 0
	while rc.running and guard < 3000:
		if clean:
			rc.obstacles.clear()
		else:
			for o in rc.obstacles:
				o[0] = rc._player_x() - 10.0   # run straight into every chimney
		rc._process(0.05)
		guard += 1
	rc.queue_free()
	return result[0]


func test_roof_chase_pursue() -> void:
	check(_run_roof(false, true) == true, "rooftop chase: clean run catches the thief")
	check(_run_roof(false, false) == false, "rooftop chase: stumbling on everything lets them escape")


func test_roof_chase_escape() -> void:
	check(_run_roof(true, true) == true, "rooftop escape: clean run gets away")
	check(_run_roof(true, false) == false, "rooftop escape: stumbling gets you caught")


func test_canal_theme_chase() -> void:
	var chase = ChaseView.new()
	root.add_child(chase)
	chase.set_canal_theme()
	var result := [null]
	chase.finished.connect(func(ok: bool): result[0] = ok)
	chase.start(3)
	var guard := 0
	while chase.running and guard < 2000:
		for o in chase.obstacles.duplicate():
			chase._remove(o)
		chase._process(0.05)
		guard += 1
	check(chase.theme_name == "canal" and result[0] == true, "canal chase works and is winnable")
	chase.queue_free()


# ---------------- Clue mini-game variants (ADR-0012) ----------------

func _reveal(kind: String, variant: String):
	var rv = ClueReveal.new()
	root.add_child(rv)
	var texts := {"body": "clue", "interro_status": "%d/%d", "receipts": ["a", "b", "c"],
		"tone_nervous": "T-nervous", "tone_greedy": "T-greedy", "tone_proud": "T-proud"}
	rv.setup(kind, texts, null, {"id": "x", "traits": {}}, variant)
	return rv


func test_interrogation_rewards_reading_the_mood() -> void:
	var rv = _reveal("contact", "interrogate")
	for r in range(3):
		var want: String = "T-" + str(rv._mood)
		for b in rv._round_box.get_children():
			if b is Button and b.text == want:
				b.pressed.emit()
				break
	check(rv._game_over and rv.bonus, "3 right answers: interrogation earns the bonus")
	rv.queue_free()
	var rv2 = _reveal("contact", "interrogate")
	for r in range(3):
		for b in rv2._round_box.get_children():
			if b is Button and b.text != "T-" + str(rv2._mood):
				b.pressed.emit()
				break
	check(rv2._game_over and not rv2.bonus, "wrong tone every time: clue but no bonus")
	rv2.queue_free()


func test_order_receipts() -> void:
	var rv = _reveal("money", "order")
	var btns: Array = rv._order_btns.duplicate()
	btns.sort_custom(func(a, b): return a.text < b.text)   # "HH:MM" sorts chronologically
	for b in btns:
		b.pressed.emit()
	check(rv._game_over and rv.bonus, "tapping receipts in time order earns the bonus")
	rv.queue_free()
	var rv2 = _reveal("money", "order")
	var b2: Array = rv2._order_btns.duplicate()
	b2.sort_custom(func(a, b): return a.text > b.text)
	b2[0].pressed.emit()   # latest first = mistake
	b2.reverse()
	for b in b2:
		b.pressed.emit()
	check(rv2._game_over and not rv2.bonus, "a mistake removes the bonus but still gives the clue")
	rv2.queue_free()


func test_voice_and_focus_variants_build() -> void:
	for v in [["wiretap", "voice"], ["cctv", "focus"]]:
		var rv = _reveal(v[0], v[1])
		check(rv.variant == v[1] and not rv._game_over, "%s variant starts" % v[1])
		rv.debug_solve()
		check(rv._game_over and rv.bonus, "%s variant can be solved" % v[1])
		rv.queue_free()
	var slow = _reveal("cctv", "focus")
	slow._elapsed = 99.0
	slow._slider.value = slow._target
	for i in range(20):
		slow._process(0.05)
	check(slow._game_over and not slow.bonus, "focusing too late gives no bonus")
	slow.queue_free()
