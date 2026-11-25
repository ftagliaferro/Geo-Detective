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
	_clear_events(s)
	var c: Dictionary = data.cities[city]
	return s.travel_to_pin(c["lat"] + 0.5, c["lon"] - 0.5)


## Resolve any pending event card (option `opt`, mini-game won or lost).
func _clear_events(s, opt := 0, mg_success := true) -> void:
	var guard := 0
	while s is CaseState and not s.pending_event.is_empty() and guard < 5:
		guard += 1
		var n: int = (s.pending_event["card"]["options"] as Array).size()
		var r: Dictionary = s.choose_event(mini(opt, n - 1))
		if r.has("minigame"):
			s.resolve_event_minigame(mg_success)


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
	var r: Dictionary = s.travel_to_pin(38.57, -7.91)  # Evora countryside, ~110 km from Lisbon
	check(r["hit"] and s.current == "lisbon" and s.stop == 1, "pin near Lisbon lands on trail")
	var m = CaseState.new(data, "case_01", 42)
	var r2: Dictionary = m.travel_to_pin(40.42, -3.70)  # on Madrid itself: you land in Madrid
	check(not r2["hit"] and m.current == "madrid", "pin on another game city lands there")


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
		for seed_value in [7, 8]:
			for b in ["a", "b"]:
				var s = CaseState.new(data, cid, seed_value)
				if b == "b" and s.objective != "split":
					continue
				s.branch = b if s.objective == "split" else ""
				if s.objective == "recover":
					var known := {}
					for i in range(s.last_stop()):
						var c: Dictionary = s.plan_at(i)["money"]
						if c["kind"] == "hide":
							known[c["attr"]] = c["value"]
					var fits: Array = s.places.filter(func(p): return known.keys().all(func(a): return p[a] == known[a]))
					check(fits.size() == 1 and fits[0]["id"] == s.target_place, "%s: hideout clues single out the place (got %d)" % [cid, fits.size()])
					continue
				var sel := {}
				for i in range(s.last_stop()):
					var c: Dictionary = s.plan_at(i)["money"]
					if c["kind"] == "trait":
						sel[c["trait"]] = c["value"]
				var m: Array = Deduction.matching(_network_pool(s.case_def["network"]), sel)
				check(m == [s.culprit()], "%s/%s: trail clues single out culprit (got %s)" % [cid, b, m])


func test_every_case_full_playthrough() -> void:
	for cid in data.cases:
		var s = _bot(cid, 11, "safe")
		check(s.status == "won", "%s: careful playthrough wins (status %s, %d/%d h)" % [cid, s.status, s.hours_used, s.budget])


func test_clue_tiers_respected() -> void:
	for cid in data.cases:
		var s = CaseState.new(data, cid, 3)
		var want: Array = CaseState.source_tiers(s.case_def["tiers"])
		want.sort()
		for i in range(s.last_stop()):
			var p: Dictionary = s.plan[i]
			if p.get("combo", false):
				continue
			var got := [int(p["wiretap"]["tier"]), int(p["contact"]["tier"])]
			got.sort()
			check(got == want, "%s stop %d: text sources use tiers %s (got %s)" % [cid, i, want, got])


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


func test_progress_flags_roundtrip() -> void:
	var p = Progress.new("user://test_flags.json")
	p.record("case_01", 2)
	p.set_flag("tutorial_detective_done")
	p.save_file()
	var q = Progress.new("user://test_flags.json")
	q.load_file()
	check(q.flag("tutorial_detective_done") and not q.flag("other") and q.best("case_01") == 2, "progress flags survive save/load")
	var f := FileAccess.open("user://test_flags_old.json", FileAccess.WRITE)
	f.store_string('{"version": 1, "stars": {"case_01": 3}}')
	f.close()
	var o = Progress.new("user://test_flags_old.json")
	o.load_file()
	check(o.best("case_01") == 3 and o.flags.is_empty(), "old save files without flags still load")


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
	# Hard cases: decoys are the target's nearest landable countries (not the one you are in).
	var s = CaseState.new(data, "case_13", 5)
	for i in range(s.last_stop()):
		var here: String = data.cities[s.route()[i]]["country_code"]
		var code: String = data.cities[s.route()[i + 1]]["country_code"]
		var t: Dictionary = data.countries[code]
		var ranked: Array = []
		for c in Geo.landable_countries(data.cities, [here, code]):
			ranked.append([Geo.distance_km(t["lat"], t["lon"], data.countries[c]["lat"], data.countries[c]["lon"]), c])
		ranked.sort()
		var nearest: Array = ranked.slice(0, 3).map(func(x): return x[1])
		for d in s.plan[i]["suggest"]:
			if d != code:
				check(d in nearest, "case_13 leg %d: hard decoy %s is a nearest neighbour of %s" % [i, d, code])


func _check_landable(label: String, sug: Array, here: String, target: String) -> void:
	var landable: Array = Geo.landable_countries(data.cities, [])
	check(sug.size() == 4, "%s: 4 suggestions (got %s)" % [label, sug])
	check(target in sug, "%s: includes destination %s" % [label, target])
	check(here == target or not here in sug, "%s: never suggests the country you are in (%s)" % [label, here])
	var seen := {}
	for c in sug:
		check(c in landable, "%s: suggested %s has a city you can land in" % [label, c])
		check(not seen.has(c), "%s: no duplicate %s" % [label, c])
		seen[c] = true


func _check_chip_landings(label: String, st, sug: Array) -> void:
	var target: String = st.route()[st.stop + 1]
	var targets: Array = [target]
	if st is CaseState and st.is_split_city():
		targets = [st.case_def["route"][st.stop + 1], st.case_def["route_b"][0]]
	for code in sug:
		var hits := 0
		for cid in data.cities:
			if data.cities[cid]["country_code"] != code or cid == st.current:
				continue
			var r: Dictionary = st.resolve_pin(data.cities[cid]["lat"], data.cities[cid]["lon"])
			check(r["city"] == cid, "%s: picking %s/%s lands in %s" % [label, code, cid, r["city"]])
			check(bool(r["hit"]) == (cid in targets), "%s: %s hit=%s (target %s)" % [label, cid, r["hit"], targets])
			hits += 1
		check(hits > 0, "%s: chip %s has a city to land in" % [label, code])


func test_every_chip_lands_where_chosen() -> void:
	for seed_value in [1, 5, 9]:
		for cid in data.cases:
			var s = CaseState.new(data, cid, seed_value)
			for i in range(s.last_stop()):
				_check_chip_landings("%s/%d leg %d" % [cid, seed_value, i], s, s.plan_at(i)["suggest"])
				_clear_events(s)
				var nxt: Dictionary = data.cities[s.route()[i + 1]]
				s.travel_to_pin(nxt["lat"], nxt["lon"])
				check(s.stop == i + 1, "%s leg %d: flying to target advances" % [cid, i])
		for eid in data.escapes:
			var e = EscapeState.new(data, eid, seed_value)
			for i in range(e.last_stop()):
				_check_chip_landings("%s/%d leg %d" % [eid, seed_value, i], e, e.leg_info[i]["map"]["countries"])
				e.now = 0
				var nxt: Dictionary = data.cities[e.route()[i + 1]]
				e.travel_to_pin(nxt["lat"], nxt["lon"])
				check(e.stop == i + 1, "%s leg %d: fleeing to target advances" % [eid, i])


func test_pin_on_decoy_neighbour_is_a_miss() -> void:
	# Vienna and Budapest are 214 km apart: a pin on Budapest must land in Budapest.
	for cid in data.cases:
		var s = CaseState.new(data, cid, 1)
		for i in range(s.last_stop()):
			var tgt: String = s.route()[i + 1]
			for other in data.cities:
				if other == tgt or other == s.current:
					continue
				var c: Dictionary = data.cities[other]
				var r: Dictionary = s.resolve_pin(c["lat"], c["lon"])
				if r["city"] != other:
					check(false, "%s leg %d: pin on %s landed in %s" % [cid, i, other, r["city"]])
			_clear_events(s)
			s.travel_to_pin(data.cities[tgt]["lat"], data.cities[tgt]["lon"])


func test_every_suggestion_is_landable() -> void:
	for seed_value in [1, 2, 3, 7, 42]:
		for cid in data.cases:
			var s = CaseState.new(data, cid, seed_value)
			for i in range(s.last_stop()):
				_check_landable("%s/%d leg %d" % [cid, seed_value, i], s.plan_at(i)["suggest"],
					data.cities[s.route()[i]]["country_code"], data.cities[s.route()[i + 1]]["country_code"])
		for eid in data.escapes:
			var e = EscapeState.new(data, eid, seed_value)
			for i in range(e.route().size() - 1):
				_check_landable("%s/%d leg %d" % [eid, seed_value, i], e.leg_info[i]["map"]["countries"],
					data.cities[e.route()[i]]["country_code"], data.cities[e.route()[i + 1]]["country_code"])


func test_contact_gives_other_destination_clue() -> void:
	var s = CaseState.new(data, "case_13", 9)
	var p: Dictionary = s.plan[0]
	if p.get("combo", false):
		p = s.plan[1]
	check(p["wiretap"]["text"] != p["contact"]["text"] and p["wiretap"]["tier"] != p["contact"]["tier"], "the two text sources give different clues at different clarity")


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
	var base: int = s.source_cost("wiretap")
	s.visit("wiretap", 1)
	check(s.hours_used == maxi(1, base - 1), "a mini-game bonus makes the clue 1 h cheaper")
	var h: int = s.hours_used
	s.visit("contact", 9)
	check(s.hours_used == h + 1, "discounts never go below 1 h")


func test_sightings_scheduled_and_refund() -> void:
	# Sightings now come from the thief's lead: arrive within 2 h of their departure.
	var s2 = CaseState.new(data, "case_05", 2)
	s2.hours_used = 0
	_pin(s2, s2.route()[1])
	s2.hours_used = 0
	s2.lead_adjust = -100     # force "the thief is right here"
	s2.pending_event = {}
	s2.stop = 1
	s2._arrive()
	check(s2.has_sighting(), "sighting available when arriving right behind the thief")
	s2.hours_used = 5
	check(s2.resolve_sighting(true) == 3 and s2.hours_used == 2, "winning a sighting refunds 3 h")
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


# ================= Depth update (ADR-0015) =================

const Gadgets = preload("res://core/gadgets.gd")


## Hours an event option costs in the worst case (used to pick safe / worst options).
func _option_cost(opt: Dictionary, worst: bool) -> int:
	var c := 0
	for e in opt["effects"]:
		match str(e[0]):
			"hours":
				c += int(e[1])
			"next_flight":
				c += int(e[1])
			"lose_action":
				c += 2
			"minigame":
				if worst:
					for f in e[3]:
						if str(f[0]) == "hours":
							c += int(f[1])
	return c


func _bot_events(s, policy: String) -> void:
	var guard := 0
	while not s.pending_event.is_empty() and guard < 5:
		guard += 1
		var opts: Array = s.pending_event["card"]["options"]
		var best := 0
		for k in range(opts.size()):
			var ck: int = _option_cost(opts[k], policy == "worst")
			var cb: int = _option_cost(opts[best], policy == "worst")
			if (policy == "worst" and ck > cb) or (policy != "worst" and ck < cb):
				best = k
		var r: Dictionary = s.choose_event(best)
		if r.has("minigame"):
			s.resolve_event_minigame(policy != "worst")


## The clearest truthful where-source of the city ("" if only facts / photo).
func _clearest_truthful(s) -> String:
	var best := ""
	for spot in ["wiretap", "contact"]:
		var c: Dictionary = s.peek(spot)
		if c.get("kind") == "dest" and not c.get("fake", false) and not s.is_burned(spot):
			if best == "" or int(c["tier"]) < int(s.peek(best)["tier"]):
				best = spot
	return best


## A player who knows the answers: per city the clearest truthful where-clue + the
## money trail, straight flights, the right warrant / raid. "worst" = most expensive
## event options, lost mini-games and sightings, and one extra (cold) investigation per city.
func _bot(cid: String, seed_value: int, policy := "safe", gear: Array = [], take_b := false):
	var s = CaseState.new(data, cid, seed_value, gear)
	var guard := 0
	while s.status == "playing" and guard < 100:
		guard += 1
		_bot_events(s, policy)
		if s.has_sighting():
			s.resolve_sighting(policy != "worst")
		if s.is_final():
			if s.objective == "recover":
				s.raid(s.target_place)
			else:
				s.visit("money")
				s.visit("wiretap")
				s.issue_warrant(s.culprit())
				s.arrest(policy != "worst")
			break
		var where: String = _clearest_truthful(s)
		s.visit(where if where != "" else "wiretap")
		if not s.is_burned("money"):
			s.visit("money")
		if policy == "worst":
			s.visit("cctv")
		if "jet" in gear and s.gadget_available("jet"):
			s.use_gadget("jet")
		var target: String = s.route()[s.stop + 1]
		if s.is_split_city():
			target = s.case_def["route_b"][0] if take_b else s.case_def["route"][s.stop + 1]
		_pin(s, target)
	return s


func test_bots_win_every_case_and_branch() -> void:
	var worst_lost: Array = []
	var min_ratio := 1.0
	var min_case := ""
	for cid in data.cases:
		for seed_value in [1, 2, 3, 4, 5, 6]:
			for take_b in [false, true]:
				if take_b and data.cases[cid].get("objective") != "split":
					continue
				var s = _bot(cid, seed_value, "safe", [], take_b)
				var ratio: float = float(s.hours_left()) / s.budget
				check(s.status == "won", "%s/%d%s: careful bot wins (status %s, %d/%d h)" % [cid, seed_value, " b" if take_b else "", s.status, s.hours_used, s.budget])
				check(ratio >= 0.10, "%s/%d%s: careful bot keeps 10%% of the hours (%d/%d)" % [cid, seed_value, " b" if take_b else "", s.hours_used, s.budget])
				if ratio < min_ratio:
					min_ratio = ratio
					min_case = "%s/%d" % [cid, seed_value]
				var w = _bot(cid, seed_value, "worst", [], take_b)
				if w.status != "won":
					worst_lost.append("%s/%d(%d/%d)" % [cid, seed_value, w.hours_used, w.budget])
	print("  careful bot: tightest %.0f%% hours left (%s); unlucky bot lost %d runs %s" % [min_ratio * 100.0, min_case, worst_lost.size(), worst_lost])
	# Investigating everything everywhere is no longer free: it should hurt in later cases.
	var greedy_won := 0
	for cid in data.cases:
		var g = CaseState.new(data, cid, 1)
		var guard := 0
		while g.status == "playing" and guard < 100:
			guard += 1
			_bot_events(g, "safe")
			if g.is_final():
				if g.objective == "recover":
					g.raid(g.target_place)
				else:
					g.issue_warrant(g.culprit())
					g.arrest(true)
				break
			for spot in CaseState.SPOTS:
				g.visit(spot)
			var tgt: String = g.route()[g.stop + 1]
			if g.is_split_city():
				tgt = g.case_def["route"][g.stop + 1]
			_pin(g, tgt)
		if g.status == "won":
			greedy_won += 1
		if int(g.case_def["number"]) >= 12:
			check(g.status != "won", "%s: investigating everything everywhere runs out of time late in the campaign" % cid)
	print("  investigate-everything bot won %d of %d cases" % [greedy_won, data.cases.size()])
	# Difficulty curve: affordable while learning, not in the last gang's cases.
	check(greedy_won <= 11, "investigating everything everywhere is not a free win (won %d)" % greedy_won)
	check(worst_lost.size() <= 4, "an unlucky but correct player still wins almost every case (lost %s)" % [worst_lost])


func test_bots_with_all_gear_win() -> void:
	for cid in data.cases:
		var s = _bot(cid, 9, "safe", Gadgets.ids())
		check(s.status == "won", "%s: careful bot with all gear wins (%s)" % [cid, s.status])


func _is_target_text(text: Dictionary, city: String) -> bool:
	for c in data.cities[city].get("clues", []):
		if c["es"] == text["es"]:
			return true
	return false


func test_every_city_has_a_truthful_source() -> void:
	for cid in data.cases:
		for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
			var s = CaseState.new(data, cid, seed_value)
			for i in range(s.plan.size() - 1):
				var p: Dictionary = s.plan[i]
				var dest: String = s.case_def["route"][i + 1]
				var targets: Array = [dest]
				if p.get("split", false):
					targets.append(s.case_def["route_b"][0])
				var truthful := 0
				for spot in ["wiretap", "contact"]:
					var c: Dictionary = p[spot]
					if c["kind"] == "dest" and not c.get("fake", false):
						check(targets.any(func(t): return _is_target_text(c["text"], t)), "%s/%d stop %d: %s points to the destination" % [cid, seed_value, i, spot])
						truthful += 1
					if c.get("fake", false):
						var dc: String = data.cities[c["points_to"]]["country_code"]
						check(dc in p["suggest"] and not c["points_to"] in targets, "%s/%d stop %d: forged clue points to a decoy on the list" % [cid, seed_value, i])
				if p["cctv"]["city"] in targets and not p["cctv"].get("double", false):
					truthful += 1
				if p.get("combo", false):
					truthful += 1
				check(truthful >= 1, "%s/%d stop %d: at least one truthful where-source" % [cid, seed_value, i])
				check(not (p.get("combo", false) and str(p.get("twist", "")) != ""), "%s/%d stop %d: no twist on a combined clue" % [cid, seed_value, i])


func test_combined_clues_are_solvable() -> void:
	var seen := 0
	for cid in data.cases:
		for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
			var s = CaseState.new(data, cid, seed_value)
			for i in range(s.plan.size() - 1):
				var p: Dictionary = s.plan[i]
				if not p.get("combo", false):
					continue
				seen += 1
				var dest_code: String = data.cities[s.case_def["route"][i + 1]]["country_code"]
				var f1: Dictionary = p["wiretap"]
				var f2: Dictionary = p["contact"]
				var sug: Array = p["suggest"]
				var m1: Array = sug.filter(func(k): return s._fact_fits(k, f1["cat"], f1["value"]))
				var m2: Array = sug.filter(func(k): return s._fact_fits(k, f2["cat"], f2["value"]))
				var both: Array = sug.filter(func(k): return s._fact_fits(k, f1["cat"], f1["value"]) and s._fact_fits(k, f2["cat"], f2["value"]))
				check(f1["cat"] != f2["cat"], "%s stop %d: two different kinds of fact" % [cid, i])
				check(m1.size() >= 2 and m2.size() >= 2, "%s stop %d: each half alone is ambiguous" % [cid, i])
				check(both == [dest_code], "%s stop %d: both halves point only to %s (got %s)" % [cid, i, dest_code, both])
				check(data.facts["countries"][dest_code][f1["cat"]] == f1["value"] and data.facts["countries"][dest_code][f2["cat"]] == f2["value"], "%s stop %d: facts are true for the destination" % [cid, i])
				check(not str(f1["text"]["es"]).contains("{") and not str(f2["text"]["en"]).contains("{"), "%s stop %d: fact text filled" % [cid, i])
	check(seen >= 20, "combined clues appear in later cases (%d seen)" % seen)


func test_hideout_is_fair() -> void:
	for cid in data.cases:
		if data.cases[cid].get("objective") != "recover":
			continue
		for seed_value in range(1, 13):
			var s = CaseState.new(data, cid, seed_value)
			check(s.places.size() == 6 and s.target_place != "", "%s/%d: six places, one target" % [cid, seed_value])
			var names := {}
			for p in s.places:
				names[p["name"]["es"]] = true
			check(names.size() == 6, "%s/%d: place names are unique" % [cid, seed_value])
			var two: Array = s.hideout_order.slice(0, 2)
			var t: Dictionary = s._target_place()
			var fits2: Array = s.places.filter(func(p): return two.all(func(a): return p[a] == t[a]))
			check(fits2.size() >= 2, "%s/%d: two hints are not enough (fair, not trivial)" % [cid, seed_value])


func test_actions_and_costs() -> void:
	var s = CaseState.new(data, "case_05", 4)
	var p: Dictionary = s.plan[0]
	for spot in ["wiretap", "contact"]:
		if p[spot]["kind"] == "dest":
			check(s.source_cost(spot) == CaseState.TIER_COST[int(p[spot]["tier"])], "clear clues cost more (%s tier %d)" % [spot, p[spot]["tier"]])
	check(s.source_cost("cctv") == 2 and s.source_cost("money") == 2, "camera and money trail cost 2 h")
	check(s.action_limit() == 2, "two investigations per city")
	var h0: int = s.hours_used
	s.visit("cctv")
	s.visit("money")
	check(s.is_cold(), "the trail cools after two")
	var cost: int = s.action_cost("wiretap")
	check(cost == s.source_cost("wiretap") + CaseState.COLD_SURCHARGE, "a third investigation costs extra")
	s.visit("wiretap")
	check(s.hours_used == h0 + 4 + cost, "hours add up")
	var b = CaseState.new(data, "case_05", 4, ["book"])
	check(b.action_limit() == 3, "the contact book allows three")


func test_event_effects() -> void:
	var s = CaseState.new(data, "case_06", 3)
	_pin(s, s.route()[1])
	_clear_events(s)
	var h: int = s.hours_used
	s._apply([["hours", 2]])
	check(s.hours_used == h + 2, "hours effect")
	s._apply([["hours", -999]])
	check(s.hours_used == 0, "hours never below zero")
	s._apply([["next_flight", 3]])
	var dest: String = s.route()[2]
	check(s.flight_hours(dest) == s._flight_between(s.current, dest) + 3, "next flight effect")
	s._apply([["free_action"]])
	var h1: int = s.hours_used
	s.visit("cctv")
	check(s.hours_used == h1 and not s.free_next, "free investigation")
	s._apply([["extra_action"], ["extra_action"], ["lose_action"]])
	check(s.action_limit() == 3, "extra / lose action")
	s._apply([["lose_action"], ["lose_action"], ["lose_action"], ["lose_action"]])
	check(s.action_limit() == 0, "action limit clamps at zero (investigating still possible, cold)")
	check(s.action_cost("money") >= 3, "cold investigation still allowed")
	if not s.is_sea_leg():
		var before: int = s.suggested_countries().size()
		s._apply([["eliminate"]])
		var after: Array = s.suggested_countries()
		check(after.size() == before - 2 and data.cities[dest]["country_code"] in after, "eliminate drops two decoys, keeps the destination")
	var fact: Dictionary = s._apply([["reveal_fact"]])
	check(fact.get("kind") in ["fact", "dest"], "reveal_fact gives a clue")
	if fact.get("kind") == "fact":
		check(data.facts["countries"][data.cities[dest]["country_code"]][fact["cat"]] == fact["value"], "revealed fact is true")
	var who: Dictionary = s._apply([["reveal_who"]])
	check(who.get("kind") == "trait" and data.suspects[s.culprit()]["traits"][who["trait"]] == who["value"], "reveal_who gives a true trait")
	var l: float = s.lead()
	s._apply([["lead", -3]])
	check(is_equal_approx(s.lead(), l - 3.0), "lead effect")
	s._apply([["burn", "contact"]])
	check(s.is_burned("contact") and s.visit("contact").is_empty(), "burned source cannot be investigated")


func test_every_event_option_is_safe() -> void:
	var cards: Array = data.events["events"] + data.events["reactions"]
	for card in cards:
		for k in range((card["options"] as Array).size()):
			for won in [true, false]:
				var s = CaseState.new(data, "case_09", 5)
				_pin(s, s.route()[1])
				_clear_events(s)
				s.pending_event = {"deck": "test", "card": card, "stop": s.stop}
				var r: Dictionary = s.choose_event(k)
				if r.has("minigame"):
					s.resolve_event_minigame(won)
				var label: String = "%s option %d (%s)" % [card["id"], k, "won" if won else "lost"]
				check(s.pending_event.is_empty() and s.pending_minigame.is_empty(), "%s: resolved" % label)
				check(s.status == "playing", "%s: case continues" % label)
				check(s.is_sea_leg() or s.suggested_countries().size() >= 2, "%s: analyst list never empties" % label)
				_pin(s, s.route()[2])
				check(s.stop == 2, "%s: travel still works" % label)


func test_lead_and_reactions() -> void:
	var s = CaseState.new(data, "case_05", 1)
	check(is_equal_approx(s.lead(), float(s.case_def["lead0"]) - CaseState.THIEF_STAY), "lead starts at head start minus the thief's stay")
	var par: float = s.lead()
	s.hours_used += 5
	check(is_equal_approx(s.lead(), par + 5.0), "time spent grows the lead")
	# Arriving fast enough triggers the thief's reaction (case >= 3), never twice in a row.
	var r = CaseState.new(data, "case_05", 1)
	r.lead_adjust = -50
	_pin(r, r.route()[1])
	check(not r.pending_event.is_empty() and r.pending_event["deck"] == "reactions", "a close pursuer gets a reaction card")
	check(r.message.get("type", "") == "here", "the thief panics when you arrive while they are still in town")
	_clear_events(r)
	_pin(r, r.route()[2])
	check(r.pending_event.is_empty() or r.pending_event["deck"] != "reactions", "no reaction two cities in a row")
	var m = CaseState.new(data, "case_05", 1)
	m.travel_to_pin(64.1, -21.9)   # Reykjavik: a miss
	check(m.message.get("type", "") == "miss", "the thief mocks a wrong flight")
	var t = CaseState.new(data, "case_01", 1)
	t.lead_adjust = -50
	_pin(t, t.route()[1])
	check(t.pending_event.is_empty(), "no reactions in the tutorial case")


func test_twists_follow_the_gang() -> void:
	var kinds_seen := {}
	for cid in data.cases:
		var s = CaseState.new(data, cid, 2)
		var n := 0
		for p in s.plan:
			if str(p.get("twist", "")) != "":
				n += 1
				kinds_seen[p["twist"]] = true
				var g: String = data.story["gang_twist"][s.case_def["network"]]
				check(g == "mixed" or p["twist"] == g, "%s: twist %s matches the gang (%s)" % [cid, p["twist"], g])
		check(n <= int(s.case_def["twists"]) and (int(s.case_def["twists"]) == 0 or n >= 1), "%s: %d twisted cities (want %d)" % [cid, n, s.case_def["twists"]])
	check(kinds_seen.size() == 4, "all four twists appear in the campaign (%s)" % [kinds_seen.keys()])
	var c1 = CaseState.new(data, "case_01", 1)
	check(c1.plan.all(func(p): return str(p.get("twist", "")) == "" and str(p.get("event", "")) == ""), "tutorial case has no twists or events")


func test_gadgets() -> void:
	# Interpol contact
	var s = CaseState.new(data, "case_02", 1, ["interpol"])
	var before: int = s.suggested_countries().size()
	check(s.gadget_available("interpol"), "interpol contact available")
	s.use_gadget("interpol")
	check(s.suggested_countries().size() == before - 2 and not s.gadget_available("interpol"), "interpol drops two decoys, once")
	# Private jet
	var j = CaseState.new(data, "case_02", 1, ["jet"])
	var dest: String = j.route()[1]
	var full: int = j.flight_hours(dest)
	j.use_gadget("jet")
	check(j.flight_hours(dest) == int(ceil(full / 2.0)), "jet halves one flight")
	_pin(j, dest)
	check(not j.jet_armed and not j.gadget_available("jet"), "jet is used up")
	# Contact book, decoder, lens, radar, detector, file
	check(CaseState.new(data, "case_02", 1, ["book"]).action_limit() == 3, "contact book")
	for cid in data.cases:
		var base = CaseState.new(data, cid, 2)
		var geared = CaseState.new(data, cid, 2, ["decoder", "lens", "radar", "detector"])
		for i in range(base.plan.size() - 1):
			var p: Dictionary = base.plan[i]
			if p["wiretap"].get("jammed", false):
				geared.stop = i
				geared.current = geared.route()[i]
				check(not geared.peek("wiretap").get("jammed", false), "%s: decoder clears interference" % cid)
			if p["cctv"].get("double", false):
				geared.stop = i
				geared.current = geared.route()[i]
				check(geared.peek("cctv")["double"] and not geared.peek("cctv")["hint_locked"], "%s: lens reads the double" % cid)
			if p.get("sea", false):
				geared.stop = i
				geared.current = geared.route()[i]
				base.stop = i
				base.current = base.route()[i]
				check(base.suggested_countries().is_empty() and geared.suggested_countries().size() >= 2, "%s: radar works on sea legs" % cid)
			for spot in ["wiretap", "contact"]:
				if p[spot].get("fake", false):
					var d = CaseState.new(data, cid, 2, ["detector"])
					d.stop = i
					d.current = d.route()[i]
					check(d.use_gadget("detector").get("fake", "") == spot, "%s: detector finds the forged %s" % [cid, spot])
	var f = CaseState.new(data, "case_05", 1, ["file"])
	check(f.known_traits.size() == 1, "interpol file reveals one trait at the start")
	var fs = CaseState.new(data, "case_07", 1, ["file"])
	var t: String = fs.known_traits.keys()[0]
	check(t in (fs.case_def["trait_order"] as Array).slice(0, fs.split_at() + 1), "before a split, the file only reveals a shared trait")
	check(Gadgets.slots(0) == 2 and Gadgets.slots(30) == 3, "two slots, three from 30 stars")
	check(Gadgets.unlocked(0).is_empty() and Gadgets.unlocked(60).size() == 8, "unlocks by stars")


func test_split_branches() -> void:
	for cid in ["case_07", "case_14"]:
		for take_b in [false, true]:
			var s = CaseState.new(data, cid, 3)
			while s.stop < s.split_at():
				_pin(s, s.route()[s.stop + 1])
			check(s.is_split_city(), "%s: reached the split" % cid)
			var sug: Array = s.suggested_countries()
			var a_code: String = data.cities[s.case_def["route"][s.stop + 1]]["country_code"]
			var b_code: String = data.cities[s.case_def["route_b"][0]]["country_code"]
			check(a_code in sug and b_code in sug and sug.size() == 4, "%s: both destinations on the list" % cid)
			_pin(s, s.case_def["route_b"][0] if take_b else s.case_def["route"][s.stop + 1])
			check(s.branch == ("b" if take_b else "a") and s.on_trail(), "%s: branch chosen by landing" % cid)
			var want: String = s.case_def["culprit_b"] if take_b else s.case_def["culprit"]
			check(s.culprit() == want, "%s: culprit follows the branch" % cid)
			var w = _bot(cid, 3, "safe", [], take_b)
			check(w.status == "won" and w.branch == ("b" if take_b else "a"), "%s: branch %s can be won" % [cid, "b" if take_b else "a"])


func test_recover_and_rescue() -> void:
	var s = CaseState.new(data, "case_04", 2)
	while not s.is_final():
		_pin(s, s.route()[s.stop + 1])
	var wrong: String = ""
	for p in s.places:
		if p["id"] != s.target_place:
			wrong = p["id"]
			break
	var h: int = s.hours_used
	check(s.raid(wrong).get("found") == false and s.hours_used == h + 3 and s.status == "playing", "a wrong raid costs 3 h")
	check(s.raid(wrong).is_empty(), "the same place cannot be raided twice")
	check(s.raid(s.target_place).get("found") == true and s.status == "won", "the right raid wins")
	check(not s.raid_first and s.stars() <= 2, "no third star after a wrong raid")
	var f = _bot("case_04", 2, "safe")
	check(f.raid_first and f.stars() == 3, "first-try raid earns the third star")
	check(f.arrest(true) == "won", "arrest is not used in recover cases")
	var r = _bot("case_11", 2, "safe")
	check(r.status == "won" and r.objective == "rescue", "rescue cases are won like pursuits")


func test_plan_is_deterministic() -> void:
	for cid in data.cases:
		var a = CaseState.new(data, cid, 77)
		var b = CaseState.new(data, cid, 77)
		check(JSON.stringify(a.plan) == JSON.stringify(b.plan) and JSON.stringify(a.places) == JSON.stringify(b.places), "%s: same seed, same case" % cid)


func test_wrong_flights_are_forgiven() -> void:
	for k in [1, 2]:
		var lost: Array = []
		for cid in data.cases:
			for seed_value in [1, 2, 3, 4]:
				var s = CaseState.new(data, cid, seed_value)
				var wrong := 0
				var guard := 0
				while s.status == "playing" and guard < 100:
					guard += 1
					_bot_events(s, "safe")
					if s.has_sighting():
						s.resolve_sighting(false)
					if s.is_final():
						if s.objective == "recover":
							s.raid(s.target_place)
						else:
							s.issue_warrant(s.culprit())
							s.arrest(true)
						break
					var where: String = _clearest_truthful(s)
					s.visit(where if where != "" else "wiretap")
					s.visit("money")
					var tgt: String = s.route()[s.stop + 1]
					if wrong < k and s.stop >= 1 and s.on_trail():
						# fly to the farthest decoy on the list, then come back
						var far := ""
						var far_km := 0.0
						for code in s.plan_at(s.stop)["suggest"]:
							for id in data.cities:
								if data.cities[id]["country_code"] == code and id != tgt and id != s.current and not (data.cities[id].get("clues", []) as Array).is_empty():
									var km := Geo.distance_km(data.cities[s.current]["lat"], data.cities[s.current]["lon"], data.cities[id]["lat"], data.cities[id]["lon"])
									if km > far_km:
										far_km = km
										far = id
						if far != "":
							wrong += 1
							_pin(s, far)
							s.visit("wiretap")
							_pin(s, s.route()[s.stop])
							continue
					_pin(s, tgt)
				if s.status != "won":
					lost.append("%s/%d %s(%d/%d)" % [cid, seed_value, s.status, s.hours_used, s.budget])
		print("  careful bot + %d worst-case wrong flight(s): lost %d of %d %s" % [k, lost.size(), data.cases.size() * 4, lost])
		if k == 1:
			check(lost.is_empty(), "one wrong flight (even to the farthest decoy) never loses a case: %s" % [lost])
		else:
			check(lost.size() <= 6, "two worst-case wrong flights are forgiven in at least 90%% of runs (lost %s)" % [lost])
