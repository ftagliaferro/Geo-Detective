## Pure geography helpers (engine-agnostic logic, see ADR-0002).
extends RefCounted

const EARTH_RADIUS_KM := 6371.0
const KM_PER_HOUR := 800.0
const BOARDING_HOURS := 2
## A pin this close to a game city means "that city" (closest game cities are 214 km apart).
const SNAP_KM := 80.0


## Great-circle distance between two lat/lon points (haversine).
static func distance_km(a_lat: float, a_lon: float, b_lat: float, b_lon: float) -> float:
	var p1 := deg_to_rad(a_lat)
	var p2 := deg_to_rad(b_lat)
	var dp := p2 - p1
	var dl := deg_to_rad(b_lon - a_lon)
	var h := pow(sin(dp / 2.0), 2) + cos(p1) * cos(p2) * pow(sin(dl / 2.0), 2)
	return 2.0 * EARTH_RADIUS_KM * asin(sqrt(clampf(h, 0.0, 1.0)))


## In-game hours needed to fly a distance.
static func travel_hours(km: float) -> int:
	return BOARDING_HOURS + int(round(km / KM_PER_HOUR))


## Unit-sphere position matching Godot's SphereMesh UV layout with an
## equirectangular texture (u = (lon + 180) / 360, v = (90 - lat) / 180).
static func lat_lon_to_vec(lat: float, lon: float) -> Vector3:
	var phi := deg_to_rad(lat)
	var a := (lon + 180.0) / 360.0 * TAU
	return Vector3(sin(a) * cos(phi), sin(phi), cos(a) * cos(phi))


## Inverse of lat_lon_to_vec. Returns Vector2(lat, lon).
static func vec_to_lat_lon(v: Vector3) -> Vector2:
	var n := v.normalized()
	var lat := rad_to_deg(asin(clampf(n.y, -1.0, 1.0)))
	var a := atan2(n.x, n.z)
	if a < 0.0:
		a += TAU
	var lon := a / TAU * 360.0 - 180.0
	return Vector2(lat, lon)


## Id of the closest city to a point, skipping ids in `exclude`.
static func nearest_city(cities: Dictionary, lat: float, lon: float, exclude: Array = []) -> String:
	var best := ""
	var best_km := INF
	for id in cities:
		if id in exclude:
			continue
		var c: Dictionary = cities[id]
		var km := distance_km(lat, lon, c["lat"], c["lon"])
		if km < best_km:
			best_km = km
			best = id
	return best


## Game city right under a pin (within SNAP_KM), skipping `exclude`; "" if none.
static func city_under_pin(cities: Dictionary, lat: float, lon: float, exclude: Array = []) -> String:
	var id := nearest_city(cities, lat, lon, exclude)
	if id != "" and distance_km(lat, lon, cities[id]["lat"], cities[id]["lon"]) <= SNAP_KM:
		return id
	return ""


## Shortlist of four countries: the target plus three decoys (shared by both modes).
## Decoys come only from `eligible` (countries that have a game city, minus the one
## you are in), so every suggestion is a real place you can land in.
## Easy (max_tier <= 1): far-away decoys. Harder: the target's nearest eligible neighbours.
static func suggest_countries(countries: Dictionary, target: String, max_tier: int, rng: RandomNumberGenerator, eligible: Array = []) -> Array:
	if target == "" or not countries.has(target):
		return []
	var t: Dictionary = countries[target]
	var candidates: Array = []
	for cid in countries:
		if cid == target:
			continue
		if not eligible.is_empty():
			if not cid in eligible:
				continue
		elif int(countries[cid]["rank"]) > 4:
			continue
		var c: Dictionary = countries[cid]
		candidates.append([distance_km(t["lat"], t["lon"], c["lat"], c["lon"]), cid])
	candidates.sort()
	var picks: Array = []
	var pool: Array
	if max_tier <= 1:
		pool = candidates.filter(func(x): return x[0] > 2500.0)
	else:
		pool = candidates.slice(0, 3 if max_tier >= 3 else 6)
	while picks.size() < 3 and not pool.is_empty():
		picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1))[1])
	for c in candidates:   # top up if the preferred pool was too small
		if picks.size() >= 3:
			break
		if not c[1] in picks:
			picks.append(c[1])
	picks.append(target)
	for i in range(picks.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	return picks


## Country codes that have at least one game city, excluding `exclude_codes`.
static func landable_countries(cities: Dictionary, exclude_codes: Array) -> Array:
	var out: Array = []
	for id in cities:
		var code := str(cities[id].get("country_code", ""))
		if code != "" and not code in out and not code in exclude_codes:
			out.append(code)
	out.sort()
	return out


## Clues whose tier is within [lo, hi]; falls back to all clues if none match.
static func clues_in_tiers(clues: Array, lo: int, hi: int) -> Array:
	var out: Array = []
	for c in clues:
		var t: int = int(c.get("tier", 1))
		if t >= lo and t <= hi:
			out.append(c)
	if out.is_empty():
		out = clues.duplicate()
	return out
