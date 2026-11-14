## Loads the JSON content files (cities, traits, suspects, cases, strings).
extends RefCounted

var cities: Dictionary = {}
var traits: Dictionary = {}
var trait_ids: Array = []
var suspects: Dictionary = {}
var cases: Dictionary = {}
var strings: Dictionary = {}
var countries: Dictionary = {}


func load_all(base: String = "res://data") -> void:
	cities = _index(_read(base + "/cities.json")["cities"])
	var trait_list: Array = _read(base + "/traits.json")["traits"]
	traits = {}
	trait_ids = []
	for t in trait_list:
		var values := {}
		for v in t["values"]:
			values[v["id"]] = v
		traits[t["id"]] = {"id": t["id"], "name": t["name"], "values": values, "order": t["values"].map(func(v): return v["id"])}
		trait_ids.append(t["id"])
	suspects = _index(_read(base + "/suspects.json")["suspects"])
	cases = _index(_read(base + "/cases.json")["cases"])
	strings = _read(base + "/i18n/strings.json")["strings"]
	countries = _index(_read(base + "/countries.json")["countries"])


static func _index(items: Array) -> Dictionary:
	var out := {}
	for item in items:
		out[item["id"]] = item
	return out


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "Cannot open data file: " + path)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert(parsed is Dictionary, "Invalid JSON in: " + path)
	return parsed
