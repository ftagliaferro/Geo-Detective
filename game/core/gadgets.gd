## Gear the detective takes into a case (ADR-0015 §5): unlocked by total stars,
## two slots (three from 30 stars). "once" = one use per case; "passive" = always on.
extends RefCounted

const LIST := [
	{"id": "interpol", "unlock": 2, "kind": "once"},     # two decoys off the analyst list
	{"id": "lens", "unlock": 5, "kind": "passive"},      # camera hints readable; doubles exposed
	{"id": "book", "unlock": 9, "kind": "passive"},      # three investigations per city
	{"id": "jet", "unlock": 13, "kind": "once"},         # one flight at half the hours
	{"id": "decoder", "unlock": 17, "kind": "passive"},  # no wiretap interference
	{"id": "detector", "unlock": 21, "kind": "once"},    # marks a forged clue in the city
	{"id": "file", "unlock": 26, "kind": "passive"},     # start knowing one fact about WHO
	{"id": "radar", "unlock": 31, "kind": "passive"},    # analyst works on sea legs
]
const THIRD_SLOT_STARS := 30


static func ids() -> Array:
	return LIST.map(func(g): return g["id"])


static func get_def(id: String) -> Dictionary:
	for g in LIST:
		if g["id"] == id:
			return g
	return {}


static func is_unlocked(id: String, total_stars: int) -> bool:
	var g := get_def(id)
	return not g.is_empty() and total_stars >= int(g["unlock"])


static func unlocked(total_stars: int) -> Array:
	return LIST.filter(func(g): return total_stars >= int(g["unlock"])).map(func(g): return g["id"])


static func slots(total_stars: int) -> int:
	return 3 if total_stars >= THIRD_SLOT_STARS else 2
