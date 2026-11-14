## Headless test runner:  godot --headless --path game --script res://tests/run_tests.gd
extends SceneTree

const GameData = preload("res://core/game_data.gd")
const CaseState = preload("res://core/case_state.gd")
const Deduction = preload("res://core/deduction.gd")
const Geo = preload("res://core/geo.gd")
const Loc = preload("res://core/loc.gd")

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
	check(data.cities.size() >= 9, "cities loaded")
	check(data.suspects.has("valentina_roca"), "suspects loaded")
	check(data.cases.has("case_01"), "case loaded")
	check(data.trait_ids.size() == 5, "5 traits")


func _win_path(s) -> void:
	for spot in CaseState.SPOTS:
		s.visit(spot)
	s.travel("lisbon")
	for spot in CaseState.SPOTS:
		s.visit(spot)
	s.travel("budapest")


func test_full_win() -> void:
	var s = CaseState.new(data, "case_01", 42)
	_win_path(s)
	check(s.is_final(), "reached final city")
	s.issue_warrant("valentina_roca")
	check(s.arrest() == "won", "arrest wins")
	check(s.stars() == 3, "perfect run gets 3 stars, got %d" % s.stars())


func test_wrong_warrant() -> void:
	var s = CaseState.new(data, "case_01", 42)
	_win_path(s)
	s.issue_warrant("marcel_dupin")
	check(s.arrest() == "lost_wrong", "wrong warrant loses")


func test_no_warrant() -> void:
	var s = CaseState.new(data, "case_01", 42)
	_win_path(s)
	check(s.arrest() == "lost_nowarrant", "no warrant loses")


func test_cannot_arrest_before_final() -> void:
	var s = CaseState.new(data, "case_01", 42)
	s.issue_warrant("valentina_roca")
	check(s.arrest() == "playing", "arrest ignored outside final city")


func test_dead_end_and_return() -> void:
	var s = CaseState.new(data, "case_01", 42)
	check(s.travel("tokyo"), "can fly to decoy")
	check(not s.on_trail(), "off trail in decoy")
	check(s.visit("witness")["kind"] == "deadend", "decoy gives dead end")
	check(s.travel_options() == ["buenos_aires"], "only option is going back")
	s.travel("buenos_aires")
	check(s.on_trail() and s.wrong_trips == 1, "back on trail, 1 wrong trip")


func test_repeat_visit_free() -> void:
	var s = CaseState.new(data, "case_01", 42)
	s.visit("witness")
	var h: int = s.hours_used
	s.visit("witness")
	check(s.hours_used == h, "repeat visit costs nothing")


func test_time_runs_out() -> void:
	var s = CaseState.new(data, "case_01", 42)
	var guard := 0
	while s.status == "playing" and guard < 20:
		s.travel("tokyo")
		s.travel("buenos_aires")
		guard += 1
	check(s.status == "lost_time", "time runs out")


func test_options_contain_next_city() -> void:
	for seed in [1, 2, 3, 99]:
		var s = CaseState.new(data, "case_01", seed)
		var opts: Array = s.travel_options()
		check(opts.size() == 4 and "lisbon" in opts, "4 options incl. next city (seed %d)" % seed)


func test_informant_traits_identify_culprit() -> void:
	var s = CaseState.new(data, "case_01", 7)
	var sel := {}
	for i in range(s.last_stop()):
		var c: Dictionary = s.plan[i]["informant"]
		sel[c["trait"]] = c["value"]
	check(Deduction.matching(data.suspects, sel) == ["valentina_roca"], "trail clues single out culprit")


func test_deduction_filter() -> void:
	check(Deduction.matching(data.suspects, {}).size() == 4, "empty selection matches all")
	check(Deduction.matching(data.suspects, {"vehicle": "motorcycle"}) == ["dimitri_vask"], "filter by vehicle")


func test_loc() -> void:
	var l = Loc.new(data.strings, "es")
	check(l.s("travel") == "Viajar", "spanish string")
	l.toggle()
	check(l.s("travel") == "Travel", "english string")
	check(l.s("hours", {"used": 2, "budget": 96}) == "Hours: 2 / 96", "format args")
