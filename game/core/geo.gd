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
	return 2.0 * EARTH_RADIUS_KM * asin(sqrt(h))


## In-game hours needed to fly a distance.
static func travel_hours(km: float) -> int:
	return BOARDING_HOURS + int(round(km / KM_PER_HOUR))
