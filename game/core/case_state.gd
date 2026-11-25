## State machine for one case: clock, location, evidence, travel, events, the
## thief's lead, gang twists, gear and objectives. Engine-agnostic (no nodes, no
## UI) so it can be unit-tested and ported (ADR-0002, ADR-0006, ADR-0015).
extends RefCounted

const Geo = preload("res://core/geo.gd")
const Gadgets = preload("res://core/gadgets.gd")

const SPOTS := ["wiretap", "cctv", "contact", "money"]
const WHERE_SPOTS := ["wiretap", "cctv", "contact"]
const TIER_COST := {1: 3, 2: 2, 3: 1}     # clear clues cost more (ADR-0015 §1)
const FACT_COST := 1
const CCTV_COST := 2
const MONEY_COST := 2
const FLAT_COST := 2                      # off the trail / final city sources
const ACTIONS_PER_CITY := 2
const COLD_SURCHARGE := 3
const ENHANCE_HOURS := 1
const DECRYPT_HOURS := 1
const RAID_HOURS := 3
const SIGHTING_REFUND := 3
const THIEF_STAY := 5
const SIGHT_LEAD := 2.0
const REACT_LEAD := 4.0
const FAR_LEAD := 9.0
# Kept for older callers (SPOT_COST[spot] = the base price of a trail source).
const SPOT_COST := {"wiretap": 2, "cctv": 2, "contact": 3, "money": 2}

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
var plan: Array = []            # per stop of route A
var plan_b: Array = []          # per stop of the short branch after the split (two-thieves cases)
var sightings_done: Dictionary = {}

# --- ADR-0015 ---
var objective := "pursuit"      # pursuit | recover | rescue | split
var branch := ""                # "" until a two-thieves split is decided, then "a" | "b"
var gadgets: Array = []         # equipped gear ids
var gadget_used: Dictionary = {}
var actions_used := 0           # investigations made in the current city
var action_bonus := 0           # events: +1 / -1 for this city
var free_next := false          # the next investigation costs nothing
var next_flight_extra := 0
var jet_armed := false
var lead_adjust := 0
var known_traits: Dictionary = {}    # trait id -> value (culprit)
var known_hideout: Dictionary = {}   # attr -> value (recover)
var hideout_order: Array = []
var places: Array = []               # recover: six candidate hideouts
var target_place := ""
var raided: Array = []
var raid_first := false
var eliminated: Dictionary = {}      # stop -> [country codes dropped from the analyst list]
var pending_event: Dictionary = {}   # {"deck", "card", "stop"} waiting for a choice
var pending_minigame: Array = []     # [kind, success_effects, fail_effects]
var message: Dictionary = {}         # intercepted thief message for this city {"type", "index"}
var reacted_at := -10
var sight_ok: Dictionary = {}        # stop -> sighting available (thief close on arrival)
var events_seen: Array = []          # event card ids shown in this case
var detector_spot := ""              # spot the lie detector exposed in this city


func _init(p_data, case_id: String, p_seed: int = 0, p_gadgets: Array = []) -> void:
	data = p_data
	case_def = data.cases[case_id]
	budget = int(case_def["hours"])
	radius_km = float(case_def["radius_km"])
	objective = str(case_def.get("objective", "pursuit"))
	gadgets = p_gadgets.duplicate()
	rng.seed = p_seed if p_seed != 0 else hash(case_id)
	current = route()[0]
	_prepare()
	if has_gadget("file"):
		_reveal_who(true)


# ======================================================================
# Route, branches, basics
# ======================================================================

func route() -> Array:
	if branch == "b":
		return (case_def["route"] as Array).slice(0, split_at() + 1) + (case_def["route_b"] as Array)
	return case_def["route"]


func split_at() -> int:
	return int(case_def.get("split_at", -1))


func is_split_city() -> bool:
	return objective == "split" and branch == "" and on_trail() and stop == split_at()


func culprit() -> String:
	return str(case_def["culprit_b"]) if branch == "b" else str(case_def["culprit"])


func trait_order() -> Array:
	return case_def["trait_order_b"] if branch == "b" else case_def["trait_order"]


## Traits that are safe to reveal now: before a two-thieves split, only the ones both
## thieves share (anything else could point at the thief you will not follow).
func _who_order() -> Array:
	if objective == "split" and branch == "":
		return (case_def["trait_order"] as Array).slice(0, split_at() + 1)
	return trait_order()


## Plan entry for a stop of the current branch.
func plan_at(i: int) -> Dictionary:
	if branch == "b" and i > split_at():
		return plan_b[i - split_at() - 1]
	return plan[i]


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


func has_gadget(id: String) -> bool:
	return id in gadgets


func case_number() -> int:
	return int(case_def.get("number", 0))


# ======================================================================
# Investigations (ADR-0015 §1)
# ======================================================================

## Investigations allowed before the trail cools in this city.
func action_limit() -> int:
	return maxi(0, (3 if has_gadget("book") else ACTIONS_PER_CITY) + action_bonus)


func is_cold() -> bool:
	return actions_used >= action_limit()


## Base price of a source in this city (before the cold surcharge, discounts or freebies).
func source_cost(spot: String) -> int:
	var c := peek(spot)
	match c.get("kind", ""):
		"dest":
			return int(TIER_COST.get(int(c.get("tier", 2)), 2))
		"fact":
			return FACT_COST
		"street":
			return CCTV_COST
		"trait", "hide":
			return MONEY_COST if on_trail() and not is_final() else FLAT_COST
	return FLAT_COST


## What investigating `spot` would charge right now.
func action_cost(spot: String, discount := 0) -> int:
	if visited.has(spot):
		return 0
	if free_next:
		return 0
	return maxi(1, source_cost(spot) - discount) + (COLD_SURCHARGE if is_cold() else 0)


func is_burned(spot: String) -> bool:
	return on_trail() and plan_at(stop).get("burned", "") == spot


## What a spot would reveal, without spending time (used to animate the reveal first).
func peek(spot: String) -> Dictionary:
	if visited.has(spot):
		return visited[spot]
	if not on_trail():
		return {"kind": "deadend"}
	var c: Dictionary = plan_at(stop).get(spot, {"kind": "near"})
	if c.get("kind") == "street":
		c = c.duplicate()
		if has_gadget("lens"):
			c["hint_locked"] = false
	if c.get("kind") == "dest" and c.get("jammed", false) and has_gadget("decoder"):
		c = c.duplicate()
		c["jammed"] = false
	if (c.get("kind") == "trait" or c.get("kind") == "hide") and is_final():
		c = _final_who()
	return c


## Investigate an evidence source in the current city. Repeat visits are free.
func visit(spot: String, discount := 0) -> Dictionary:
	if status != "playing" or not spot in SPOTS or is_burned(spot) or not pending_event.is_empty():
		return {}
	if visited.has(spot):
		return visited[spot]
	var clue := peek(spot)
	hours_used += action_cost(spot, discount)
	free_next = false
	actions_used += 1
	visited[spot] = clue
	_learn(clue)
	_check_time()
	return clue


func _learn(clue: Dictionary) -> void:
	match clue.get("kind", ""):
		"trait":
			known_traits[clue["trait"]] = clue["value"]
		"hide":
			known_hideout[clue["attr"]] = clue["value"]


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


## Zero Signal: pay to clean a jammed wiretap (does not use an investigation).
func decrypt() -> Dictionary:
	if status != "playing" or not visited.has("wiretap"):
		return {}
	var c: Dictionary = visited["wiretap"]
	if not c.get("jammed", false):
		return c
	hours_used += DECRYPT_HOURS
	c = c.duplicate()
	c["jammed"] = false
	visited["wiretap"] = c
	_check_time()
	return c


# ======================================================================
# Gear (ADR-0015 §5)
# ======================================================================

func gadget_available(id: String) -> bool:
	if status != "playing" or not has_gadget(id) or gadget_used.has(id):
		return false
	match id:
		"interpol":
			return can_travel() and on_trail() and suggested_countries().size() > 2 and not eliminated.has(stop)
		"jet":
			return can_travel() and not jet_armed
		"detector":
			return on_trail() and not is_final()
	return false


## Use a once-per-case gadget. Returns what it did ({} if it could not be used).
func use_gadget(id: String) -> Dictionary:
	if not gadget_available(id):
		return {}
	gadget_used[id] = true
	match id:
		"interpol":
			_eliminate()
			return {"eliminated": eliminated.get(stop, [])}
		"jet":
			jet_armed = true
			return {"jet": true}
		"detector":
			detector_spot = ""
			for spot in ["wiretap", "contact"]:
				if plan_at(stop).get(spot, {}).get("fake", false):
					detector_spot = spot
			return {"fake": detector_spot}
	return {}


# ======================================================================
# Thief's lead, sightings, messages (ADR-0015 §3)
# ======================================================================

## Hours since the thief left the city the trail is at (negative = still there).
func lead() -> float:
	var r := route()
	var t := -float(case_def.get("lead0", 11))
	for j in range(stop + 1):
		t += THIEF_STAY
		if j < stop:
			t += _flight_between(r[j], r[j + 1])
	return hours_used + lead_adjust - t


func _flight_between(a: String, b: String) -> int:
	var ca: Dictionary = data.cities[a]
	var cb: Dictionary = data.cities[b]
	return Geo.travel_hours(Geo.distance_km(ca["lat"], ca["lon"], cb["lat"], cb["lon"]))


## Quick-reaction "sighting": available when you arrive while the thief is close.
func has_sighting() -> bool:
	return status == "playing" and on_trail() and stop > 0 and stop < last_stop() \
		and sight_ok.get(stop, false) and not sightings_done.has(stop)


## Resolve the sighting: success gives hours back (you learn their moves faster).
func resolve_sighting(success: bool) -> int:
	if not has_sighting():
		return 0
	sightings_done[stop] = success
	if success:
		var back := mini(SIGHTING_REFUND, hours_used)
		hours_used -= back
		return back
	return 0


func _message_index(kind: String, salt: int) -> int:
	var n: int = (data.story.get("messages", {}).get(kind, []) as Array).size()
	return 0 if n == 0 else abs(hash(str(case_def["id"]) + kind + str(salt))) % n


# ======================================================================
# Travel
# ======================================================================

func flight_hours(city_id: String) -> int:
	var h := _flight_between(current, city_id) + next_flight_extra
	if jet_armed:
		h = int(ceil(h / 2.0))
	return h


## Where a pin at (lat, lon) would land, without spending time.
## Returns {"city": id, "hit": bool, "km_off": float}.
func resolve_pin(lat: float, lon: float) -> Dictionary:
	var targets: Array = []
	if is_split_city():
		targets.append((case_def["route"] as Array)[stop + 1])
		targets.append((case_def["route_b"] as Array)[0])
	elif stop < last_stop():
		targets.append(route()[stop + 1])
	if not on_trail():
		targets.append(route()[stop])  # flying back to the last good city also works
	# A pin on a game city always lands in that city (picking a decoy never "hits").
	var under := Geo.city_under_pin(data.cities, lat, lon, [current])
	if under != "":
		if under in targets:
			var cu: Dictionary = data.cities[under]
			return {"city": under, "hit": true, "km_off": Geo.distance_km(lat, lon, cu["lat"], cu["lon"])}
		return {"city": under, "hit": false, "km_off": -1.0}
	for t in targets:
		var c: Dictionary = data.cities[t]
		var km := Geo.distance_km(lat, lon, c["lat"], c["lon"])
		if km <= radius_km and t != current:
			return {"city": t, "hit": true, "km_off": km}
	var landing := Geo.nearest_city(data.cities, lat, lon, targets + [current])
	return {"city": landing, "hit": false, "km_off": -1.0}


## Drop a pin and fly there.
func travel_to_pin(lat: float, lon: float) -> Dictionary:
	if not can_travel() or not pending_event.is_empty():
		return {}
	var r := resolve_pin(lat, lon)
	hours_used += flight_hours(r["city"])
	next_flight_extra = 0
	jet_armed = false
	var advanced := false
	if r["hit"]:
		if is_split_city():
			branch = "b" if r["city"] == (case_def["route_b"] as Array)[0] else "a"
		if stop < last_stop() and r["city"] == route()[stop + 1]:
			stop += 1
			precision_km.append(r["km_off"])
			advanced = true
	else:
		misses += 1
	current = r["city"]
	visited.clear()
	actions_used = 0
	action_bonus = 0
	detector_spot = ""
	message = {}
	_check_time()
	if status == "playing":
		if advanced:
			_arrive()
		elif not r["hit"]:
			message = {"type": "miss", "index": _message_index("miss", misses)}
	return r


## Arrival on the trail: sightings, the thief's reaction, the planned event, the message.
func _arrive() -> void:
	if stop >= last_stop():
		return
	var l := lead()
	sight_ok[stop] = l <= SIGHT_LEAD
	var p := plan_at(stop)
	var reaction := ""
	if case_number() >= 3 and l <= REACT_LEAD and reacted_at != stop - 1:
		reaction = _pick_reaction(p)
	if reaction != "":
		reacted_at = stop
		pending_event = {"deck": "reactions", "card": _card("reactions", reaction), "stop": stop}
	elif str(p.get("event", "")) != "":
		pending_event = {"deck": "events", "card": _card("events", p["event"]), "stop": stop}
	if not pending_event.is_empty():
		events_seen.append(pending_event["card"]["id"])
	var kind := ""
	if l <= 0.0:
		kind = "here"
	elif reaction == "plant":
		kind = "plant"
	elif l <= REACT_LEAD:
		kind = "close"
	elif l >= FAR_LEAD:
		kind = "far"
	if kind != "":
		message = {"type": kind, "index": _message_index(kind, stop)}


func _card(deck: String, id: String) -> Dictionary:
	for c in data.events.get(deck, []):
		if c["id"] == id:
			return c
	return {}


func _pick_reaction(p: Dictionary) -> String:
	var options: Array = ["tipoff", "thugs"]
	if not p.get("burned", "") and p.get("contact", {}).get("kind") in ["dest", "fact"] and not p.get("contact", {}).get("fake", false):
		options.append("burned")
	if str(p.get("twist", "")) == "" and _plantable(p) != "":
		options.append("plant")
	return options[abs(hash(str(case_def["id"]) + "react" + str(stop))) % options.size()]


## A text source that can carry a planted fake ("" if none: facts, twists, split city).
func _plantable(p: Dictionary) -> String:
	if is_split_city():
		return ""
	for spot in ["contact", "wiretap"]:
		var c: Dictionary = p.get(spot, {})
		if c.get("kind") == "dest" and not c.get("fake", false):
			return spot
	return ""


# ======================================================================
# Events (ADR-0015 §2)
# ======================================================================

## Choose an option of the pending event card. Returns {"minigame": [...]} when the
## option starts a mini-game (resolve it with resolve_event_minigame), else
## {"clue": {...}} with anything it revealed (possibly empty).
func choose_event(option: int) -> Dictionary:
	if pending_event.is_empty() or status != "playing":
		return {}
	var opts: Array = pending_event["card"]["options"]
	if option < 0 or option >= opts.size():
		return {}
	var effects: Array = opts[option]["effects"]
	pending_event = {}
	for e in effects:
		if e[0] == "minigame":
			pending_minigame = [e[1], e[2], e[3]]
			return {"minigame": pending_minigame}
	return {"clue": _apply(effects)}


func resolve_event_minigame(success: bool) -> Dictionary:
	if pending_minigame.is_empty():
		return {}
	var effects: Array = pending_minigame[1] if success else pending_minigame[2]
	pending_minigame = []
	return {"clue": _apply(effects)}


## Apply effects; returns the last clue revealed ({} if none).
func _apply(effects: Array) -> Dictionary:
	var clue := {}
	for e in effects:
		match str(e[0]):
			"hours":
				hours_used = maxi(0, hours_used + int(e[1]))
			"next_flight":
				next_flight_extra += int(e[1])
			"free_action":
				free_next = true
			"extra_action":
				action_bonus += 1
			"lose_action":
				action_bonus -= 1
			"eliminate":
				_eliminate()
			"reveal_who":
				clue = _reveal_who(false)
			"reveal_fact":
				clue = _reveal_fact()
			"lead":
				lead_adjust += int(e[1])
			"burn":
				if on_trail() and stop < last_stop():
					plan_at(stop)["burned"] = str(e[1])
			"plant":
				_plant()
	_check_time()
	return clue


func _eliminate() -> void:
	if not on_trail() or stop >= last_stop() or eliminated.has(stop):
		return
	var sug: Array = plan_at(stop).get("suggest", [])
	var targets := _leg_targets_codes()
	var decoys: Array = sug.filter(func(c): return not c in targets)
	var drop: Array = []
	while drop.size() < 2 and not decoys.is_empty():
		drop.append(decoys.pop_at(abs(hash(str(case_def["id"]) + "elim" + str(stop) + str(drop.size()))) % decoys.size()))
	eliminated[stop] = drop


func _leg_targets_codes() -> Array:
	var out: Array = []
	if is_split_city():
		out.append(data.cities[(case_def["route"] as Array)[stop + 1]]["country_code"])
		out.append(data.cities[(case_def["route_b"] as Array)[0]]["country_code"])
	elif stop < last_stop():
		out.append(data.cities[route()[stop + 1]]["country_code"])
	return out


## Next unknown WHO fact: a culprit trait (or a hideout detail in recover cases).
func _reveal_who(from_end: bool) -> Dictionary:
	if objective == "recover":
		var attrs: Array = hideout_order.duplicate()
		if from_end:
			attrs.reverse()
		for a in attrs:
			if not known_hideout.has(a):
				var c := _hide_clue(a)
				_learn(c)
				return c
		return {}
	var order: Array = _who_order().duplicate()
	if from_end:
		order.reverse()
	for t in order:
		if not known_traits.has(t):
			var c := _trait_clue(t, data.suspects[culprit()])
			_learn(c)
			return c
	return {}


## A fact about the current leg's destination (falls back to a medium text clue).
func _reveal_fact() -> Dictionary:
	if not on_trail() or stop >= last_stop():
		return {}
	var dest: String = route()[stop + 1]
	var code: String = data.cities[dest]["country_code"]
	var vals: Dictionary = data.facts.get("countries", {}).get(code, {})
	var cats: Array = (data.facts.get("categories", []) as Array).filter(func(cat): return vals.get(cat) != null)
	if cats.is_empty():
		return {"kind": "dest", "tier": 2, "text": _tier_text(dest, 2)}
	var cat: String = cats[abs(hash(str(case_def["id"]) + "fact" + str(stop))) % cats.size()]
	return _fact_clue(cat, str(vals[cat]))


## The thief plants a fake text clue in this city (reaction card "plant").
func _plant() -> void:
	if not on_trail() or stop >= last_stop():
		return
	var p := plan_at(stop)
	var spot := _plantable(p)
	if spot != "" and not visited.has(spot):
		var fake := _fake_clue(p, int(p[spot].get("tier", 2)))
		if not fake.is_empty():
			p[spot] = fake


# ======================================================================
# Warrant, arrest, raid, stars
# ======================================================================

func issue_warrant(suspect_id: String) -> void:
	if status == "playing" and data.suspects.has(suspect_id):
		warrant = suspect_id


## Arrest at the end of the chase. `caught` = the player won the arcade chase.
func arrest(caught: bool = true) -> String:
	if status != "playing" or not is_final() or objective == "recover":
		return status
	chase_caught = caught
	if warrant == "":
		status = "lost_nowarrant"
	elif warrant != culprit():
		status = "lost_wrong"
	else:
		status = "won"
	return status


## Recover objective: raid one of the candidate places in the final city.
func raid(place_id: String) -> Dictionary:
	if status != "playing" or objective != "recover" or not is_final() or place_id in raided:
		return {}
	if not places.any(func(p): return p["id"] == place_id):
		return {}
	raided.append(place_id)
	hours_used += RAID_HOURS
	if place_id == target_place:
		raid_first = raided.size() == 1
		status = "won"
		return {"found": true}
	_check_time()
	return {"found": false}


func avg_precision_km() -> float:
	if precision_km.is_empty():
		return 0.0
	var total := 0.0
	for k in precision_km:
		total += k
	return total / precision_km.size()


## 1 star for solving, +1 for a clean run (no missed pins), +1 for winning the chase
## (recover: for finding the loot on the first raid).
func stars() -> int:
	if status != "won":
		return 0
	var s := 1
	if misses == 0:
		s += 1
	if (raid_first if objective == "recover" else chase_caught):
		s += 1
	return s


func _check_time() -> void:
	if status == "playing" and hours_used > budget:
		status = "lost_time"


# ======================================================================
# Analyst shortlist
# ======================================================================

## Suggested destination countries for the current leg ([] when travel is over or the
## leg is by sea without the port radar).
func suggested_countries() -> Array:
	if not can_travel() or not on_trail():
		return []
	var p := plan_at(stop)
	if p.get("sea", false) and not has_gadget("radar"):
		return []
	var drop: Array = eliminated.get(stop, [])
	return (p.get("suggest", []) as Array).filter(func(c): return not c in drop)


func is_sea_leg() -> bool:
	return can_travel() and on_trail() and plan_at(stop).get("sea", false)


func _suggestions(targets: Array, max_tier: int, here_city: String) -> Array:
	var here_code := str(data.cities[here_city].get("country_code", "")) if data.cities.has(here_city) else ""
	var eligible := Geo.landable_countries(data.cities, [here_code])
	var first: String = targets[0]
	var sug := Geo.suggest_countries(data.countries, first, max_tier, rng, eligible.filter(func(c): return not c in targets))
	if targets.size() > 1:
		# Two thieves: both destinations on the list, keep four entries.
		var decoys := sug.filter(func(c): return not c in targets)
		while decoys.size() > 2:
			decoys.pop_back()
		sug = targets + decoys
		_shuffle(sug)
	return sug


# ======================================================================
# Plan
# ======================================================================

## Tiers the two text sources of a trail city get from the case band (mirrors the generator).
static func source_tiers(band: Array) -> Array:
	var lo := int(band[0])
	var hi := int(band[1])
	if lo != hi:
		return [lo, hi]
	return [lo, lo + 1] if lo < 3 else [lo, lo - 1]


func _prepare() -> void:
	plan = _plan_route(case_def["route"], case_def["trait_order"], str(case_def["culprit"]), 0)
	if objective == "split":
		var full: Array = (case_def["route"] as Array).slice(0, split_at() + 1) + (case_def["route_b"] as Array)
		var pb := _plan_route(full, case_def["trait_order_b"], str(case_def["culprit_b"]), split_at() + 1)
		plan_b = pb.slice(split_at() + 1)
		_plan_split_city()
	if objective == "recover":
		_plan_places()
	_plan_twists()
	_plan_combos()
	_plan_events()


## Plan for a route: from `from_i` on (earlier entries are placeholders).
func _plan_route(r: Array, order: Array, culprit_id: String, from_i: int) -> Array:
	var tiers: Array = case_def.get("tiers", [1, 3])
	var pair := source_tiers(tiers)
	var free_hint: bool = case_def.get("cctv_hint_free", true)
	var who: Dictionary = data.suspects[culprit_id]
	var out: Array = []
	var last := r.size() - 1
	for i in range(r.size()):
		var p := {}
		if i < from_i:
			out.append(p)
			continue
		if i < last:
			var nxt_id: String = r[i + 1]
			var nxt: Dictionary = data.cities[nxt_id]
			var t_a: int = pair[0]
			var t_b: int = pair[1]
			if rng.randf() < 0.5:
				t_a = pair[1]
				t_b = pair[0]
			p["wiretap"] = {"kind": "dest", "tier": t_a, "text": _tier_text(nxt_id, t_a)}
			p["contact"] = {"kind": "dest", "tier": t_b, "source": "contact", "text": _tier_text(nxt_id, t_b)}
			p["cctv"] = {"kind": "street", "city": nxt_id, "street": nxt["street"], "hint_locked": not free_hint}
			p["money"] = _money_clue(i, order, who, nxt_id, pair)
			p["suggest"] = _suggestions([str(nxt.get("country_code", ""))], int(tiers[1]), r[i])
			p["event"] = ""
			p["twist"] = ""
		else:
			p = _final_plan()
		out.append(p)
	return out


func _money_clue(i: int, order: Array, who: Dictionary, nxt_id: String, pair: Array) -> Dictionary:
	if objective == "recover":
		if hideout_order.is_empty():
			# kind + zone together already name a single place, so the detail is always one
			# of the first two hints (two hints narrow it down, the third settles it).
			var first: String = ["zone", "kind"][rng.randi_range(0, 1)]
			hideout_order = [first, "detail", "kind" if first == "zone" else "zone"]
		if i < hideout_order.size():
			return {"pending_hide": hideout_order[i]}   # filled once places exist
	elif i < order.size():
		return _trait_clue(order[i], who)
	# Long routes: the money trail points to the destination instead.
	var t: int = maxi(int(pair[0]), int(pair[1]))
	return {"kind": "dest", "tier": t, "source": "money", "text": _tier_text(nxt_id, t)}


## Final city: every source is about WHO (filled lazily from what is still unknown).
func _final_plan() -> Dictionary:
	var p := {}
	for spot in SPOTS:
		p[spot] = {"kind": "trait"} if objective != "recover" else {"kind": "hide"}
	return p


## Final city source result: the next unknown trait (or hideout detail), else "near".
func _final_who() -> Dictionary:
	if objective == "recover":
		for a in hideout_order:
			if not known_hideout.has(a) and not _pending_final_attr(a):
				var c := _hide_clue(a)
				c["near"] = true
				return c
		return {"kind": "near"}
	for t in trait_order():
		if not known_traits.has(t) and not _pending_final_trait(t):
			var c := _trait_clue(t, data.suspects[culprit()])
			c["near"] = true
			return c
	return {"kind": "near"}


## A trait already shown in another final-city source this visit (so two sources differ).
func _pending_final_trait(t: String) -> bool:
	for c in visited.values():
		if c.get("kind") == "trait" and c.get("trait") == t:
			return true
	return false


func _pending_final_attr(a: String) -> bool:
	for c in visited.values():
		if c.get("kind") == "hide" and c.get("attr") == a:
			return true
	return false


## Two thieves: the split city's clues point to both destinations.
func _plan_split_city() -> void:
	var s := split_at()
	var p: Dictionary = plan[s]
	var a_id: String = (case_def["route"] as Array)[s + 1]
	var b_id: String = (case_def["route_b"] as Array)[0]
	p["wiretap"] = {"kind": "dest", "tier": int(p["wiretap"]["tier"]), "text": _tier_text(a_id, int(p["wiretap"]["tier"])), "thief": "a"}
	p["contact"] = {"kind": "dest", "tier": int(p["contact"]["tier"]), "source": "contact", "text": _tier_text(b_id, int(p["contact"]["tier"])), "thief": "b"}
	var tiers: Array = case_def.get("tiers", [1, 3])
	var codes := [str(data.cities[a_id]["country_code"]), str(data.cities[b_id]["country_code"])]
	p["suggest"] = _suggestions(codes, int(tiers[1]), (case_def["route"] as Array)[s])
	p["split"] = true


## Recover: six candidate hideouts in the final city, the loot in one of them.
## All three WHO details single it out; any two leave at least two candidates.
func _plan_places() -> void:
	var names: Array = data.hideout.get("names", [])
	var details: Array = (data.hideout["values"]["detail"] as Dictionary).keys()
	for _attempt in range(500):
		var pool: Array = names.duplicate()
		_shuffle(pool)
		var chosen: Array = pool.slice(0, 6)
		var ps: Array = []
		for k in range(chosen.size()):
			ps.append({"id": "place_%d" % k, "kind": chosen[k]["kind"], "zone": chosen[k]["zone"],
				"detail": details[rng.randi_range(0, details.size() - 1)], "name": chosen[k]["name"]})
		var target: Dictionary = ps[rng.randi_range(0, ps.size() - 1)]
		var all3: Array = ps.filter(func(p): return hideout_order.all(func(a): return p[a] == target[a]))
		var two: Array = ps.filter(func(p): return hideout_order.slice(0, 2).all(func(a): return p[a] == target[a]))
		if all3.size() == 1 and two.size() >= 2:
			places = ps
			target_place = target["id"]
			break
	# Fill the money-trail hideout hints now that the target exists.
	for p in plan:
		if p.get("money", {}).has("pending_hide"):
			p["money"] = _hide_clue(p["money"]["pending_hide"])


func _target_place() -> Dictionary:
	for p in places:
		if p["id"] == target_place:
			return p
	return {}


func _hide_clue(attr: String) -> Dictionary:
	var value: String = str(_target_place().get(attr, ""))
	var v: Dictionary = data.hideout["values"][attr].get(value, {})
	return {"kind": "hide", "attr": attr, "value": value, "text": v.get("hint", {"es": "", "en": ""}), "label": v.get("label", {})}


## Gang twists (ADR-0015 §3): `twists` cities of the case, one twist per city.
func _plan_twists() -> void:
	var n := int(case_def.get("twists", 0))
	if n <= 0:
		return
	var gang_twist: String = str(data.story.get("gang_twist", {}).get(case_def.get("network", ""), ""))
	var cands: Array = []
	for i in range(1, plan.size() - 1):
		if not (objective == "split" and i == split_at()):
			cands.append(i)
	_shuffle(cands)
	var kinds := ["forged", "sea", "jam", "double"]
	for i in cands.slice(0, n):
		var kind := gang_twist
		if kind == "mixed" or kind == "":
			kind = kinds[rng.randi_range(0, kinds.size() - 1)]
		_apply_twist(plan[i], kind)


func _apply_twist(p: Dictionary, kind: String) -> void:
	match kind:
		"forged":
			var spot: String = ["wiretap", "contact"][rng.randi_range(0, 1)]
			var fake := _fake_clue(p, int(p[spot].get("tier", 2)))
			if fake.is_empty():
				return
			p[spot] = fake
		"sea":
			p["sea"] = true
		"jam":
			p["wiretap"]["jammed"] = true
		"double":
			var decoy := _decoy_city(p)
			if decoy == "":
				return
			p["cctv"] = {"kind": "street", "city": decoy, "street": data.cities[decoy]["street"], "hint_locked": p["cctv"]["hint_locked"], "double": true}
	p["twist"] = kind


## A decoy city of this leg's shortlist with clues and a street photo ("" if none).
func _decoy_city(p: Dictionary) -> String:
	var target_city: String = p["cctv"]["city"] if not p["cctv"].get("double", false) else ""
	var target_code: String = data.cities[target_city]["country_code"] if target_city != "" else ""
	var codes: Array = (p.get("suggest", []) as Array).filter(func(c): return c != target_code)
	_shuffle(codes)
	for code in codes:
		for id in data.cities:
			var c: Dictionary = data.cities[id]
			if c.get("country_code") == code and not (c.get("clues", []) as Array).is_empty() and c.get("street", {}).get("image") != null:
				return id
	return ""


func _fake_clue(p: Dictionary, tier: int) -> Dictionary:
	var decoy := _decoy_city(p)
	if decoy == "":
		return {}
	return {"kind": "dest", "tier": tier, "text": _tier_text(decoy, tier), "fake": true, "points_to": decoy}


## Combined clues (ADR-0015 §7): both text sources become half-clues.
func _plan_combos() -> void:
	var n := case_number()
	if n < 4:
		return
	var p_combo := 0.3 if n < 10 else 0.5
	for i in range(0, plan.size() - 1):
		var p: Dictionary = plan[i]
		if str(p.get("twist", "")) != "" or p.get("split", false) or p.get("sea", false):
			continue
		if rng.randf() >= p_combo:
			continue
		var dest: String = (case_def["route"] as Array)[i + 1]
		var code: String = data.cities[dest]["country_code"]
		var pair := _combo_pair(code, p.get("suggest", []))
		if pair.is_empty():
			continue
		var vals: Dictionary = data.facts["countries"][code]
		p["wiretap"] = _fact_clue(pair[0], str(vals[pair[0]]))
		p["contact"] = _fact_clue(pair[1], str(vals[pair[1]]))
		p["contact"]["source"] = "contact"
		p["combo"] = true


## Two fact categories whose values fit the destination; each alone fits two or more
## of the shortlist, both together only the destination ([] if none).
func _combo_pair(code: String, shortlist: Array) -> Array:
	var facts: Dictionary = data.facts.get("countries", {})
	if not facts.has(code):
		return []
	var cats: Array = data.facts.get("categories", [])
	var tv: Dictionary = facts[code]
	var found: Array = []
	for x in range(cats.size()):
		for y in range(x + 1, cats.size()):
			var c1: String = cats[x]
			var c2: String = cats[y]
			if tv.get(c1) == null or tv.get(c2) == null:
				continue
			var m1 := shortlist.filter(func(k): return _fact_fits(k, c1, tv[c1]))
			var m2 := shortlist.filter(func(k): return _fact_fits(k, c2, tv[c2]))
			var both := shortlist.filter(func(k): return _fact_fits(k, c1, tv[c1]) and _fact_fits(k, c2, tv[c2]))
			if m1.size() >= 2 and m2.size() >= 2 and both == [code]:
				found.append([c1, c2])
	if found.is_empty():
		return []
	return found[rng.randi_range(0, found.size() - 1)]


## Could country `code` have this fact? Unknown (null) counts as "could be".
func _fact_fits(code: String, cat: String, value) -> bool:
	var v = data.facts.get("countries", {}).get(code, {}).get(cat)
	return v == null or v == value


func _fact_clue(cat: String, value: String) -> Dictionary:
	var lbl: Dictionary = data.facts["values"][cat].get(value, {"es": value, "en": value})
	var tpl: Dictionary = data.facts["texts"][cat]
	return {"kind": "fact", "cat": cat, "value": value,
		"text": {"es": str(tpl["es"]).replace("{v}", lbl["es"]), "en": str(tpl["en"]).replace("{v}", lbl["en"])}}


## Surprise events (ADR-0015 §2): case 2 gets one gentle card; from case 3 ~40% of cities.
func _plan_events() -> void:
	var n := case_number()
	if n < 2:
		return
	var cands: Array = []
	for i in range(1, plan.size() - 1):
		if not (objective == "split" and i == split_at()):
			cands.append(i)
	if cands.is_empty():
		return
	var chosen: Array = []
	if n == 2:
		chosen = [cands[mini(1, cands.size() - 1)]]
	else:
		for i in cands:
			if rng.randf() < 0.4:
				chosen.append(i)
		if chosen.is_empty():
			chosen = [cands[rng.randi_range(0, cands.size() - 1)]]
	var gentle := ["envelope", "colleague", "storm"]
	var used: Array = []
	for i in chosen:
		var p: Dictionary = plan[i]
		var deck: Array = (data.events.get("events", []) as Array).filter(func(c):
			if c["id"] in used:
				return false
			if n == 2 and not c["id"] in gentle:
				return false
			if "analyst" in c.get("needs", []) and p.get("sea", false):
				return false
			return true)
		if deck.is_empty():
			continue
		var card: Dictionary = deck[rng.randi_range(0, deck.size() - 1)]
		p["event"] = card["id"]
		used.append(card["id"])


# ======================================================================
# Helpers
# ======================================================================

func _tier_text(city_id: String, tier: int) -> Dictionary:
	var clues: Array = data.cities[city_id].get("clues", [])
	for c in clues:
		if int(c.get("tier", 1)) == tier:
			return {"es": c["es"], "en": c["en"]}
	return {"es": clues[0]["es"], "en": clues[0]["en"]} if not clues.is_empty() else {"es": "", "en": ""}


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _trait_clue(trait_id: String, who: Dictionary) -> Dictionary:
	var value: String = who["traits"][trait_id]
	var clues: Array = data.traits[trait_id]["values"][value]["clues"]
	return {"kind": "trait", "trait": trait_id, "value": value, "text": clues[rng.randi_range(0, clues.size() - 1)]}
