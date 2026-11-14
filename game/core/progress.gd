## Campaign progress: best stars per case, unlocking and detective rank. Saved to user://.
extends RefCounted

const SAVE_PATH := "user://progress.json"
const RANKS := [
	[0, {"es": "Novato", "en": "Rookie"}],
	[6, {"es": "Agente de campo", "en": "Field Agent"}],
	[14, {"es": "Inspector", "en": "Inspector"}],
	[22, {"es": "Inspector jefe", "en": "Chief Inspector"}],
	[32, {"es": "Comandante", "en": "Commander"}],
	[42, {"es": "Director", "en": "Director"}],
]

var stars: Dictionary = {}   # case_id -> best stars (0..3); 0 = played but not solved
var path: String = SAVE_PATH


func _init(p_path: String = SAVE_PATH) -> void:
	path = p_path


func load_file() -> void:
	stars = {}
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.get("stars") is Dictionary:
		for k in parsed["stars"]:
			stars[k] = int(parsed["stars"][k])


func save_file() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "stars": stars}))


func record(case_id: String, earned: int) -> void:
	stars[case_id] = max(int(stars.get(case_id, 0)), earned)


func best(case_id: String) -> int:
	return int(stars.get(case_id, 0))


func is_solved(case_id: String) -> bool:
	return best(case_id) > 0


## Case N is unlocked when case N-1 is solved (case 1 always).
func is_unlocked(case_number: int, cases_by_number: Dictionary) -> bool:
	if case_number <= 1:
		return true
	var prev = cases_by_number.get(case_number - 1)
	return prev != null and is_solved(prev["id"])


func total_stars() -> int:
	var t := 0
	for k in stars:
		t += int(stars[k])
	return t


func rank() -> Dictionary:
	var current: Dictionary = RANKS[0][1]
	for r in RANKS:
		if total_stars() >= int(r[0]):
			current = r[1]
	return current
