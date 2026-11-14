## State machine for one case: clock, location, clues, travel, warrant, arrest.
## Engine-agnostic (no nodes, no UI) so it can be unit-tested and ported (ADR-0002).
extends RefCounted

const Geo = preload("res://core/geo.gd")

const SPOTS := ["witness", "informant", "street"]
const SPOT_HOURS := 2

var data
var case_def: Dictionary
var rng := RandomNumberGenerator.new()
var budget: int = 0
var hours_used: int = 0
var stop: int = 0          # index in route of the furthest correct city reached
var current: String = ""   # city the player is in now
var visited: Dictionary = {}
var warrant: String = ""
var wrong_trips: int = 0
var status: String = "playing"  # playing | won | lost_time | lost_wrong | lost_nowarrant
var plan: Array = []


func _init(p_data, case_id: String, p_seed: int = 0) -> void:
	data = p_data
	case_def = data.cases[case_id]
	budget = int(case_def["hours"])
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


func hours_left() -> int:
	return budget - hours_used


## Investigate a spot in the current city. Repeat visits are free.
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


## Cities the player can fly to from here.
func travel_options() -> Array:
	if not on_trail():
		return [route()[stop]]  # dead end: only way is back
	if stop < last_stop():
		return plan[stop]["options"]
	return []


func travel_cost(city_id: String) -> int:
	var a: Dictionary = data.cities[current]
	var b: Dictionary = data.cities[city_id]
	return Geo.travel_hours(Geo.distance_km(a["lat"], a["lon"], b["lat"], b["lon"]))


func travel(city_id: String) -> bool:
	if status != "playing" or not city_id in travel_options():
		return false
	hours_used += travel_cost(city_id)
	if on_trail():
		if city_id == route()[stop + 1]:
			stop += 1
		else:
			wrong_trips += 1
	current = city_id
	visited.clear()
	_check_time()
	return true


func issue_warrant(suspect_id: String) -> void:
	if status == "playing" and data.suspects.has(suspect_id):
		warrant = suspect_id


func arrest() -> String:
	if status != "playing" or not is_final():
		return status
	if warrant == "":
		status = "lost_nowarrant"
	elif warrant != case_def["culprit"]:
		status = "lost_wrong"
	else:
		status = "won"
	return status


func stars() -> int:
	if status != "won":
		return 0
	var ratio := float(hours_left()) / float(budget)
	if ratio >= 0.5 and wrong_trips == 0:
		return 3
	if ratio >= 0.25:
		return 2
	return 1


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
			p["witness"] = {"kind": "dest", "text": dclues[rng.randi_range(0, dclues.size() - 1)]}
			p["informant"] = _trait_clue(order[i], culprit)
			p["street"] = {"kind": "street", "city": nxt_id, "street": nxt["street"]}
			var opts: Array = case_def["decoys"][i].duplicate()
			opts.append(nxt_id)
			_shuffle(opts)
			p["options"] = opts
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


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
