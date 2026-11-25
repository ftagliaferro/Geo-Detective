## City map layout check (ADR-0015 §9): for every city, in both languages and at the
## map sizes the game uses (desktop, phone portrait, phone landscape), no pin or label
## covers another one, everything stays on the map and the places stay on land.
## Run: godot --headless --path game --script res://tests/city_map_check.gd
extends SceneTree

const CityMap = preload("res://ui/city_map.gd")
const GameData = preload("res://core/game_data.gd")

var checks := 0
var failures := 0
var labelled := {}   # size -> [maps with names on the map, maps]
var slowest := 0     # usec for the slowest layout
var landmarks := [0, 0]   # maps showing their landmark, maps


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		if failures <= 40:
			printerr("FAIL: " + msg)


func _initialize() -> void:
	var data = GameData.new()
	data.load_all()
	var strings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/strings.json"))["strings"]
	var source_sizes := [Vector2(780, 260), Vector2(540, 260), Vector2(328, 240), Vector2(358, 270), Vector2(812, 200)]
	var hideout_sizes := [Vector2(1220, 280), Vector2(960, 280), Vector2(328, 300), Vector2(812, 240)]
	var names: Array = data.hideout.get("names", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var maps := 0
	for lang in ["es", "en"]:
		for cid in data.cities.keys():
			var c: Dictionary = data.cities[cid]
			var water := str(c.get("water", "none"))
			var lm := str(c.get("landmark", {}).get(lang, ""))
			# Trail city: four sources + airport.
			var places: Array = []
			for spot in ["wiretap", "cctv", "contact", "money"]:
				places.append({"id": spot, "icon": spot, "label": str(strings["place_" + spot][lang])})
			for sz in source_sizes:
				var m := CityMap.new()
				root.add_child(m)
				m.size = sz
				m.setup_sources(cid, water, lm, places, str(strings["place_airport"][lang]))
				_check_map(m, "%s/%s sources %s" % [lang, cid, sz])
				m.free()
				maps += 1
			# Final city of a recover case: six hideouts (random picks of the name pool).
			for sample in range(4):
				var pool := names.duplicate()
				for i in range(pool.size() - 1, 0, -1):
					var j := rng.randi_range(0, i)
					var t = pool[i]
					pool[i] = pool[j]
					pool[j] = t
				var hs: Array = []
				for k in range(6):
					hs.append({"id": "place_%d" % k, "zone": pool[k]["zone"], "label": str(pool[k]["name"][lang])})
				for sz in hideout_sizes:
					var m := CityMap.new()
					root.add_child(m)
					m.size = sz
					m.setup_hideouts(cid, water, lm, hs)
					_check_map(m, "%s/%s hideouts#%d %s" % [lang, cid, sample, sz])
					m.free()
					maps += 1
	for k in labelled:
		print("  %s: %s in %d of %d" % [k, "shown" if k.ends_with("landmark") else "names on the map", labelled[k][0], labelled[k][1]])
	print("  landmark shown on %d of %d maps" % landmarks)
	print("  slowest layout: %.1f ms" % (slowest / 1000.0))
	check(slowest < 150000, "layout stays quick (%d us)" % slowest)
	print("City maps: %d maps, %d checks, %d failed" % [maps, checks, failures])
	quit(1 if failures > 0 else 0)


func _check_map(m, label: String) -> void:
	var rects: Array = []
	var t0 := Time.get_ticks_usec()
	m._pin_px(m.pins[0])
	var dt := Time.get_ticks_usec() - t0
	slowest = maxi(slowest, dt)
	var key := "%s %dx%d" % ["sources" if m.pins[0]["kind"] == "source" else "hideouts", int(m.size.x), int(m.size.y)]
	var st: Array = labelled.get(key, [0, 0])
	st[0] += 1 if m.labels_shown else 0
	st[1] += 1
	labelled[key] = st
	if m.size.x >= 700.0:
		check(m.labels_shown, "%s: names shown on a wide map" % label)
		check(m.landmark == "" or m._landmark_px() != Vector2.INF, "%s: landmark shown on a wide map" % label)
	for pin in m.pins:
		var c: Vector2 = m._pin_px(pin)
		var r: Rect2 = m._footprint(pin, c)
		rects.append(r)
		check(r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= m.size.x + 0.5 and r.end.y <= m.size.y + 0.5,
			"%s: '%s' fits the map (%s in %s)" % [label, pin["label"], r, m.size])
		check(m._on_land(Vector2(c.x / m.size.x, c.y / m.size.y)), "%s: '%s' is on land" % [label, pin["label"]])
	var lp: Vector2 = m._landmark_px()
	landmarks[1] += 1
	var lk := key + " landmark"
	var ls: Array = labelled.get(lk, [0, 0])
	ls[1] += 1
	if lp != Vector2.INF:
		ls[0] += 1
		landmarks[0] += 1
		var lr: Rect2 = m.landmark_rect(lp)
		check(lr.position.x >= 0.0 and lr.position.y >= 0.0 and lr.end.x <= m.size.x and lr.end.y <= m.size.y, "%s: landmark fits" % label)
		for r in rects:
			check(not lr.intersects(r), "%s: landmark clear of the pins" % label)
	labelled[lk] = ls
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			check(not (rects[i] as Rect2).intersects(rects[j]),
				"%s: '%s' and '%s' overlap (%s / %s)" % [label, m.pins[i]["label"], m.pins[j]["label"], rects[i], rects[j]])
