## Pure geography helpers (engine-agnostic logic, see ADR-0002).
extends RefCounted

const EARTH_RADIUS_KM := 6371.0
const KM_PER_HOUR := 800.0
const BOARDING_HOURS := 2


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
