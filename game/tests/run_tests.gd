## Headless test runner:  godot --headless --path game --script res://tests/run_tests.gd
extends SceneTree

const GameData = preload("res://core/game_data.gd")
const CaseState = preload("res://core/case_state.gd")
const Deduction = preload("res://core/deduction.gd")
const Geo = preload("res://core/geo.gd")
const Loc = preload("res://core/loc.gd")
const ChaseView = preload("res://ui/chase_view.gd")
const Progress = preload("res://core/progress.gd")

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
	for spot in CaseState.SPOTS:
		s.visit(spot)
	_pin(s, "lisbon")
	for spot in CaseState.SPOTS:
		s.visit(spot)
	_pin(s, "budapest")


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
