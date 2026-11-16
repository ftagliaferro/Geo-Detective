## Fugitive mode (ADR-0010): the player is the thief, an AI inspector follows.
## Engine-agnostic state machine, unit-tested like CaseState.
##
## Time model: the heist happens at t = 0 in route[0]; the inspector reaches that
## city at t = head_start. For every later city on the *real* trail she arrives
## after investigating the previous one (inspector_hours, +CLEAN_BONUS if tracks
## were cleaned, +DECOY_BONUS if a false lead was planted) and flying there.
## Off-route detours are NOT followed: she flies straight from the last real
## safe house, so wrong pins cost the player time. Caught when she arrives
## while the player is still in that city.
extends RefCounted

const Geo = preload("res://core/geo.gd")

const ACTIONS := ["message", "message2", "map", "clean", "decoy"]
const COST := {"message": 1, "message2": 2, "map": 2, "clean": 3, "decoy": 2}
const CLEAN_BONUS := 6
const DECOY_BONUS := 10
const MAX_DECOYS := 2
const CHASE_THRESHOLD := 10.0   # arrive at the safe house with less lead -> final chase
const COMFORT_LEAD := 12.0      # star for arriving with at least this lead
const CHECKPOINT_DELAY := 3     # hours lost if passport control stops you

var data
var def: Dictionary
var rng := RandomNumberGenerator.new()
var now := 0
var stop := 0
var current := ""
var path: Array = []          # [{city, on_route, clean, decoy}]
var leg_info: Array = []      # per leg: {message, message2, map}
var revealed: Dictionary = {} # leg index -> {action: payload}
var decoys_left := MAX_DECOYS
var wrong_flights := 0
var status := "playing"       # playing | escaped | caught | chase
var chase_needed := false
var checkpoints: Dictionary = {}       # leg index -> true when that arrival has passport control
var checkpoints_done: Dictionary = {}


func _init(p_data, escape_id: String, p_seed: int = 0) -> void:
	data = p_data
	def = data.escapes[escape_id]
	rng.seed = p_seed if p_seed != 0 else hash(escape_id)
	current = route()[0]
	path.append({"city": current, "on_route": true, "clean": false, "decoy": false})
	_prepare()


func route() -> Array:
	return def["route"]


func last_stop() -> int:
	return route().size() - 1


func on_route() -> bool:
	return current == route()[stop]


func radius_km() -> float:
	return float(def["radius_km"])


## Hours until the inspector reaches the city the player is in now.
func inspector_eta() -> float:
	var anchors: Array = path.filter(func(e): return e["on_route"])
	if not path[-1]["on_route"]:
		anchors.append(path[-1])
	var t := float(def["head_start"])
	for i in range(1, anchors.size()):
		var a: Dictionary = anchors[i - 1]
		var inv := float(def["inspector_hours"]) + (CLEAN_BONUS if a["clean"] else 0) + (DECOY_BONUS if a["decoy"] else 0)
		t += inv + _flight(a["city"], anchors[i]["city"])
	return t


## Positive = hours of lead over the inspector.
func lead() -> float:
	return inspector_eta() - float(now)


func can_act(action: String) -> bool:
	if status != "playing" or not action in ACTIONS:
		return false
	var leg := stop
	if action in ["message", "message2", "map"]:
		return stop < last_stop() and not revealed.get(leg, {}).has(action)
	# clean / decoy only make sense on the real trail and once per city
	var here: Dictionary = path[-1]
	if not here["on_route"]:
		return false
	if action == "clean":
		return not here["clean"]
	return not here["decoy"] and decoys_left > 0


func act(action: String, discount := 0) -> Dictionary:
	if not can_act(action):
		return {}
	now += maxi(1, int(COST[action]) - discount)
	var payload: Dictionary = {}
	match action:
		"message", "message2", "map":
			payload = leg_info[stop][action]
			if not revealed.has(stop):
				revealed[stop] = {}
			revealed[stop][action] = payload
		"clean":
			path[-1]["clean"] = true
			payload = {"kind": "clean"}
		"decoy":
			path[-1]["decoy"] = true
			decoys_left -= 1
			payload = {"kind": "decoy"}
	_check()
	return payload


func flight_hours(city_id: String) -> int:
	return _flight(current, city_id)


func resolve_pin(lat: float, lon: float) -> Dictionary:
	var target: String = route()[stop + 1] if stop < last_stop() else ""
	var under := Geo.city_under_pin(data.cities, lat, lon, [current])
	if under != "":
		var cu: Dictionary = data.cities[under]
		if under == target:
			return {"city": under, "hit": true, "km_off": Geo.distance_km(lat, lon, cu["lat"], cu["lon"])}
		return {"city": under, "hit": false, "km_off": -1.0}
	if target != "":
		var c: Dictionary = data.cities[target]
		var km := Geo.distance_km(lat, lon, c["lat"], c["lon"])
		if km <= radius_km() and target != current:
			return {"city": target, "hit": true, "km_off": km}
	return {"city": Geo.nearest_city(data.cities, lat, lon, [target, current]), "hit": false, "km_off": -1.0}


func travel_to_pin(lat: float, lon: float) -> Dictionary:
	if status != "playing" or stop >= last_stop():
		return {}
	var r := resolve_pin(lat, lon)
	now += flight_hours(r["city"])
	current = r["city"]
	if r["hit"]:
		stop += 1
	else:
		wrong_flights += 1
	path.append({"city": current, "on_route": r["hit"], "clean": false, "decoy": false})
	_check()
	if status == "playing" and r["hit"] and stop == last_stop():
		chase_needed = lead() < CHASE_THRESHOLD
		status = "chase" if chase_needed else "escaped"
	return r


## Passport control on arrival at some safe houses (ADR-0011).
func has_checkpoint() -> bool:
	return status == "playing" and on_route() and checkpoints.get(stop, false) and not checkpoints_done.has(stop)


func resolve_checkpoint(passed: bool) -> int:
	if not has_checkpoint():
		return 0
	checkpoints_done[stop] = passed
	if passed:
		return 0
	now += CHECKPOINT_DELAY
	_check()
	return CHECKPOINT_DELAY


## Resolve the optional final chase (player drives the getaway car).
func finish_chase(escaped: bool) -> String:
	if status == "chase":
		status = "escaped" if escaped else "caught"
	return status


func stars() -> int:
	if status != "escaped":
		return 0
	var s := 1
	if wrong_flights == 0:
		s += 1
	if not chase_needed and lead() >= COMFORT_LEAD:
		s += 1
	return s


func _check() -> void:
	if status == "playing" and lead() <= 0.0:
		status = "caught"


func _flight(a: String, b: String) -> int:
	var ca: Dictionary = data.cities[a]
	var cb: Dictionary = data.cities[b]
	return Geo.travel_hours(Geo.distance_km(ca["lat"], ca["lon"], cb["lat"], cb["lon"]))


func _prepare() -> void:
	var tiers: Array = def["tiers"]
	leg_info.clear()
	for i in range(1, last_stop()):
		checkpoints[i] = i % 2 == 0 or rng.randf() < 0.35
	for i in range(last_stop()):
		var nxt: Dictionary = data.cities[route()[i + 1]]
		var pool := Geo.clues_in_tiers(nxt["clues"], int(tiers[0]), int(tiers[1]))
		var first: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var ct: int = int(tiers[0]) - 1 if int(tiers[0]) > 1 else int(tiers[1]) + 1
		var second_pool := Geo.clues_in_tiers(nxt["clues"], ct, ct).filter(func(c): return c != first)
		if second_pool.is_empty():
			second_pool = pool if not pool.is_empty() else [first]
		leg_info.append({
			"message": {"kind": "message", "text": first},
			"message2": {"kind": "message", "text": second_pool[rng.randi_range(0, second_pool.size() - 1)]},
			"map": {"kind": "map", "countries": Geo.suggest_countries(data.countries, str(nxt.get("country_code", "")), int(tiers[1]), rng,
				Geo.landable_countries(data.cities, [str(data.cities[route()[i]].get("country_code", ""))]))},
		})
