## State machine for one case: clock, location, evidence, pin-drop travel,
## arrest order and arrest. Engine-agnostic (no nodes, no UI) so it can be
## unit-tested and ported (ADR-0002, ADR-0006).
extends RefCounted

const Geo = preload("res://core/geo.gd")

const SPOTS := ["wiretap", "money", "cctv"]
const SPOT_HOURS := 2

var data
var case_def: Dictionary
var rng := RandomNumberGenerator.new()
var budget: int = 0
var radius_km: float = 1000.0
var hours_used: int = 0
var stop: int = 0          # index in route of the furthest correct city reached
var current: String = ""   # city the player is in now
var visited: Dictionary = {}
var warrant: String = ""
var misses: int = 0
var precision_km: Array = []   # km off for each successful pin
var chase_caught: bool = false
var status: String = "playing"  # playing | won | lost_time | lost_wrong | lost_nowarrant
var plan: Array = []


func _init(p_data, case_id: String, p_seed: int = 0) -> void:
	data = p_data
	case_def = data.cases[case_id]
	budget = int(case_def["hours"])
	radius_km = float(case_def["radius_km"])
	rng.seed = p_seed if p_seed != 0 else hash(case_id)
	current = route()[0]
	_prepare()


func route() -> Array:
	return case_def["route"]


func last_stop() -> int:
	return route().size() - 1


func on_trail() -> bool:
	return current == route()[stop]


func is_final() -> bool:
	return on_trail() and stop == last_stop()


func can_travel() -> bool:
	return status == "playing" and not is_final()


func hours_left() -> int:
	return budget - hours_used


## Investigate an evidence source in the current city. Repeat visits are free.
func visit(spot: String) -> Dictionary:
	if status != "playing" or not spot in SPOTS:
		return {}
	if visited.has(spot):
		return visited[spot]
	hours_used += SPOT_HOURS
	var clue: Dictionary
	if on_trail():
		clue = plan[stop][spot]
	else:
		clue = {"kind": "deadend"}
	visited[spot] = clue
	_check_time()
	return clue


func flight_hours(city_id: String) -> int:
	var a: Dictionary = data.cities[current]
	var b: Dictionary = data.cities[city_id]
	return Geo.travel_hours(Geo.distance_km(a["lat"], a["lon"], b["lat"], b["lon"]))


## Where a pin at (lat, lon) would land, without spending time.
## Returns {"city": id, "hit": bool, "km_off": float}.
func resolve_pin(lat: float, lon: float) -> Dictionary:
	var targets: Array = []
	if stop < last_stop():
		targets.append(route()[stop + 1])
	if not on_trail():
		targets.append(route()[stop])  # flying back to the last good city also works
	for t in targets:
		var c: Dictionary = data.cities[t]
		var km := Geo.distance_km(lat, lon, c["lat"], c["lon"])
		if km <= radius_km and t != current:
			return {"city": t, "hit": true, "km_off": km}
	var landing := Geo.nearest_city(data.cities, lat, lon, targets + [current])
	return {"city": landing, "hit": false, "km_off": -1.0}


## Drop a pin and fly there.
func travel_to_pin(lat: float, lon: float) -> Dictionary:
	if not can_travel():
		return {}
	var r := resolve_pin(lat, lon)
	hours_used += flight_hours(r["city"])
	if r["hit"]:
		if stop < last_stop() and r["city"] == route()[stop + 1]:
			stop += 1
			precision_km.append(r["km_off"])
	else:
		misses += 1
	current = r["city"]
	visited.clear()
	_check_time()
	return r


func issue_warrant(suspect_id: String) -> void:
	if status == "playing" and data.suspects.has(suspect_id):
		warrant = suspect_id


## Arrest at the end of the chase. `caught` = the player won the arcade chase.
func arrest(caught: bool = true) -> String:
	if status != "playing" or not is_final():
		return status
	chase_caught = caught
	if warrant == "":
		status = "lost_nowarrant"
	elif warrant != case_def["culprit"]:
		status = "lost_wrong"
	else:
		status = "won"
	return status


func avg_precision_km() -> float:
	if precision_km.is_empty():
		return 0.0
	var total := 0.0
	for k in precision_km:
		total += k
	return total / precision_km.size()


## 1 star for solving, +1 for a clean fast run, +1 for winning the chase.
func stars() -> int:
	if status != "won":
		return 0
	var s := 1
	if float(hours_left()) / float(budget) >= 0.5 and misses == 0:
		s += 1
	if chase_caught:
		s += 1
	return s


func _check_time() -> void:
	if status == "playing" and hours_used > budget:
		status = "lost_time"


func _prepare() -> void:
	var order: Array = case_def["trait_order"]
	var culprit: Dictionary = data.suspects[case_def["culprit"]]
	plan.clear()
	for i in range(route().size()):
		var p := {}
		if i < last_stop():
			var nxt_id: String = route()[i + 1]
			var nxt: Dictionary = data.cities[nxt_id]
			var dclues: Array = nxt["clues"]
			p["wiretap"] = {"kind": "dest", "text": dclues[rng.randi_range(0, dclues.size() - 1)]}
			p["money"] = _trait_clue(order[i], culprit)
			p["cctv"] = {"kind": "street", "city": nxt_id, "street": nxt["street"]}
		else:
			for j in range(SPOTS.size()):
				var idx := last_stop() + j
				if idx < order.size():
					var c := _trait_clue(order[idx], culprit)
					c["near"] = true
					p[SPOTS[j]] = c
				else:
					p[SPOTS[j]] = {"kind": "near"}
		plan.append(p)


func _trait_clue(trait_id: String, culprit: Dictionary) -> Dictionary:
	var value: String = culprit["traits"][trait_id]
	var clues: Array = data.traits[trait_id]["values"][value]["clues"]
	return {"kind": "trait", "trait": trait_id, "value": value, "text": clues[rng.randi_range(0, clues.size() - 1)]}
