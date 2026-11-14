## State machine for one case: clock, location, evidence, pin-drop travel,
## arrest order and arrest. Engine-agnostic (no nodes, no UI) so it can be
## unit-tested and ported (ADR-0002, ADR-0006).
extends RefCounted

const Geo = preload("res://core/geo.gd")

const SPOTS := ["wiretap", "cctv", "contact", "money"]
const SPOT_HOURS := 2
const SPOT_COST := {"wiretap": 2, "cctv": 2, "contact": 3, "money": 2}
const ENHANCE_HOURS := 1

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
	hours_used += int(SPOT_COST.get(spot, SPOT_HOURS))
	var clue: Dictionary
	if on_trail():
		clue = plan[stop][spot]
	else:
		clue = {"kind": "deadend"}
	visited[spot] = clue
	_check_time()
	return clue


## Pay to analyse CCTV footage and reveal what to look at (cases without free hints).
func enhance_cctv() -> Dictionary:
	if status != "playing" or not visited.has("cctv"):
		return {}
	var c: Dictionary = visited["cctv"]
	if not c.get("hint_locked", false):
		return c
	hours_used += ENHANCE_HOURS
	c = c.duplicate()
	c["hint_locked"] = false
	visited["cctv"] = c
	_check_time()
	return c


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


## 1 star for solving, +1 for a clean run (no missed pins), +1 for winning the chase.
func stars() -> int:
	if status != "won":
		return 0
	var s := 1
	if misses == 0:
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
	var tiers: Array = case_def.get("tiers", [1, 3])
	var free_hint: bool = case_def.get("cctv_hint_free", true)
	plan.clear()
	for i in range(route().size()):
		var p := {}
		if i < last_stop():
			var nxt_id: String = route()[i + 1]
			var nxt: Dictionary = data.cities[nxt_id]
			var pool := _clues_in_tiers(nxt["clues"], tiers)
			var first: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			p["wiretap"] = {"kind": "dest", "text": first}
			# Local contact: a clue from a tier just outside the case range (pricier, different angle).
			var ct: int = int(tiers[0]) - 1 if int(tiers[0]) > 1 else int(tiers[1]) + 1
			var cpool := _clues_in_tiers(nxt["clues"], [ct, ct])
			cpool = cpool.filter(func(c): return c != first)
			if cpool.is_empty():
				cpool = pool if not pool.is_empty() else [first]
			p["contact"] = {"kind": "dest", "source": "contact", "text": cpool[rng.randi_range(0, cpool.size() - 1)]}
			if i < order.size():
				p["money"] = _trait_clue(order[i], culprit)
			else:
				# Long routes: the money trail points to the destination instead.
				var extra: Dictionary = pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else first
				p["money"] = {"kind": "dest", "source": "money", "text": extra}
			p["cctv"] = {"kind": "street", "city": nxt_id, "street": nxt["street"], "hint_locked": not free_hint}
			p["suggest"] = _suggestions(str(nxt.get("country_code", "")), int(tiers[1]))
		else:
			for j in range(SPOTS.size()):
				var idx: int = mini(last_stop(), order.size()) + j
				if idx < order.size():
					var c := _trait_clue(order[idx], culprit)
					c["near"] = true
					p[SPOTS[j]] = c
				else:
					p[SPOTS[j]] = {"kind": "near"}
		plan.append(p)


## The "analyst" shortlist: the real destination country plus three decoys.
## Easy cases use far-away decoys; harder cases use the target's neighbours.
func _suggestions(target: String, max_tier: int) -> Array:
	if target == "" or not data.countries.has(target):
		return []
	var t: Dictionary = data.countries[target]
	var candidates: Array = []
	for cid in data.countries:
		var c: Dictionary = data.countries[cid]
		if cid != target and int(c["rank"]) <= 4:
			candidates.append([Geo.distance_km(t["lat"], t["lon"], c["lat"], c["lon"]), cid])
	candidates.sort()
	var picks: Array = []
	if max_tier <= 1:
		var far := candidates.filter(func(x): return x[0] > 2500.0)
		while picks.size() < 3 and not far.is_empty():
			picks.append(far.pop_at(rng.randi_range(0, far.size() - 1))[1])
	else:
		var near_n := 3 if max_tier >= 3 else 6
		var near := candidates.slice(0, near_n)
		while picks.size() < 3 and not near.is_empty():
			picks.append(near.pop_at(rng.randi_range(0, near.size() - 1))[1])
	picks.append(target)
	_shuffle(picks)
	return picks


## Suggested destination countries for the current leg ([] when travel is over).
func suggested_countries() -> Array:
	if not can_travel():
		return []
	return plan[stop].get("suggest", [])


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Clues whose tier is within [min, max]; falls back to all clues if none match.
static func _clues_in_tiers(clues: Array, tiers: Array) -> Array:
	var out: Array = []
	for c in clues:
		var t: int = int(c.get("tier", 1))
		if t >= int(tiers[0]) and t <= int(tiers[1]):
			out.append(c)
	if out.is_empty():
		out = clues.duplicate()
	return out


func _trait_clue(trait_id: String, culprit: Dictionary) -> Dictionary:
	var value: String = culprit["traits"][trait_id]
	var clues: Array = data.traits[trait_id]["values"][value]["clues"]
	return {"kind": "trait", "trait": trait_id, "value": value, "text": clues[rng.randi_range(0, clues.size() - 1)]}
