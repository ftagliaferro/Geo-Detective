## Stylised district map of a city (ADR-0015 §9): streets, water (coast or river),
## parks, the landmark and tappable places. Drawn in code and deterministic per city,
## so the same city always looks the same. Two uses:
##   setup_sources(...)  the four evidence places + the airport (trail cities)
##   setup_hideouts(...) the six candidate hideouts (recover objective, final city)
extends Control

signal place_pressed(id: String)

const Style = preload("res://ui/style.gd")
const IconView = preload("res://ui/icon_view.gd")

const LAND := Color("f3ede2")
const BLOCK := Color("e9e1d3")
const STREET := Color("fffdf8")
const AVENUE := Color("fff7e6")
const WATER := Color("bfdcf0")
const WATER_EDGE := Color("9cc6e6")
const PARK := Color("cfe5c4")
const PIN_R := 19.0

var city_id := ""
var water := "none"
var landmark := ""
var pins: Array = []        # [{id, pos (0..1), kind: "source"/"airport"/"hideout", icon, label, done, letter}]
var selected := ""
var _rng := RandomNumberGenerator.new()
var _water_side := 0        # coast: 0 bottom, 1 right, 2 left
var _river_y := 0.5
var _parks: Array = []
var _icons: Dictionary = {}
var _px: Dictionary = {}       # pin id -> pixel centre after label overlaps were resolved
var _px_size := Vector2.ZERO   # map size those were computed for
var labels_shown := true       # false when the names don't fit (small phone maps)
var _lm_px := Vector2.INF
var _lm_size := Vector2.ZERO
static var _layout_cache := {} # same city, size and places -> same layout: compute once


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func _layout_seed(id: String, p_water: String, p_landmark: String) -> void:
	city_id = id
	water = p_water
	landmark = p_landmark
	_rng.seed = hash("map_" + id)
	_water_side = _rng.randi_range(0, 2)
	_river_y = _rng.randf_range(0.42, 0.62)
	_parks.clear()
	for i in range(3):
		_parks.append(Rect2(_rng.randf_range(0.05, 0.8), _rng.randf_range(0.08, 0.75), _rng.randf_range(0.08, 0.14), _rng.randf_range(0.08, 0.14)))


## Where land is (normalised): keeps pins out of the water.
func _on_land(p: Vector2) -> bool:
	match water:
		"coast":
			match _water_side:
				0:
					return p.y < 0.74
				1:
					return p.x < 0.76
				_:
					return p.x > 0.24
		"river":
			return absf(p.y - _river_y_at(p.x)) > 0.12
	return true


func _river_y_at(x: float) -> float:
	return _river_y + sin(x * TAU * 0.8 + hash(city_id) % 7) * 0.06


## Four evidence places + airport. `places` = [{id, icon, label, done}] in display order.
func setup_sources(id: String, p_water: String, p_landmark: String, places: Array, airport_label := "") -> void:
	_layout_seed(id, p_water, p_landmark)
	pins.clear()
	var slots := [Vector2(0.2, 0.25), Vector2(0.55, 0.2), Vector2(0.3, 0.6), Vector2(0.68, 0.55)]
	for k in range(places.size()):
		var base: Vector2 = slots[k % slots.size()]
		pins.append({"id": places[k]["id"], "pos": _free_spot(base), "kind": "source", "icon": places[k]["icon"],
			"label": places[k]["label"], "done": places[k].get("done", false), "disabled": places[k].get("disabled", false)})
	pins.append({"id": "airport", "pos": _free_spot(Vector2(0.88, 0.12)), "kind": "airport", "icon": "globe", "label": airport_label})
	_rebuild_icons()


## Six hideouts placed by zone: by the water, downtown, on the outskirts.
func setup_hideouts(id: String, p_water: String, p_landmark: String, places: Array) -> void:
	_layout_seed(id, p_water, p_landmark)
	pins.clear()
	var used := {}
	for k in range(places.size()):
		var zone: String = places[k]["zone"]
		var base := Vector2(0.5, 0.45)
		match zone:
			"water":
				base = _water_anchor()
			"outskirts":
				base = [Vector2(0.12, 0.15), Vector2(0.88, 0.2), Vector2(0.15, 0.82), Vector2(0.85, 0.8)][used.get(zone, 0) % 4]
			_:
				base = [Vector2(0.45, 0.4), Vector2(0.6, 0.48), Vector2(0.4, 0.55)][used.get(zone, 0) % 3]
		used[zone] = used.get(zone, 0) + 1
		pins.append({"id": places[k]["id"], "pos": _free_spot(base, zone == "water"), "kind": "hideout", "icon": "",
			"label": places[k]["label"], "letter": char(65 + k), "done": places[k].get("done", false), "disabled": places[k].get("disabled", false)})
	_rebuild_icons()


func _water_anchor() -> Vector2:
	match water:
		"coast":
			match _water_side:
				0:
					return Vector2(_rng.randf_range(0.2, 0.8), 0.66)
				1:
					return Vector2(0.68, _rng.randf_range(0.2, 0.8))
				_:
					return Vector2(0.32, _rng.randf_range(0.2, 0.8))
		"river":
			var x := _rng.randf_range(0.2, 0.8)
			return Vector2(x, _river_y_at(x) - 0.16)
	return Vector2(_rng.randf_range(0.3, 0.7), 0.5)


## A land spot near `base` that keeps clear of other pins.
func _free_spot(base: Vector2, near_water := false) -> Vector2:
	var best := base
	for attempt in range(40):
		var p := base + Vector2(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.08, 0.08)) * (1.0 + attempt * 0.05)
		p = p.clamp(Vector2(0.08, 0.1), Vector2(0.92, 0.88))
		if not near_water and not _on_land(p):
			continue
		if near_water and not _on_land(p):
			continue
		var clear := true
		for q in pins:
			if (q["pos"] as Vector2).distance_to(p) < 0.17:
				clear = false
				break
		if clear:
			return p
		best = p
	return best


func set_selected(id: String) -> void:
	selected = id
	queue_redraw()


func _rebuild_icons() -> void:
	_px_size = Vector2.ZERO
	_lm_size = Vector2.ZERO
	for c in get_children():
		c.queue_free()
	_icons.clear()
	for pin in pins:
		if pin["icon"] == "":
			continue
		var ic := IconView.new()
		ic.setup(pin["icon"], Color.WHITE, 22)
		ic.size = Vector2(22, 22)
		add_child(ic)
		_icons[pin["id"]] = ic
	queue_redraw()


func _pin_px(pin: Dictionary) -> Vector2:
	if _px_size != size or not _px.has(pin["id"]):
		_resolve_overlaps()
	return _px.get(pin["id"], Vector2(pin["pos"].x * size.x, pin["pos"].y * size.y))


## Pin + its label as drawn, around pixel centre `c`.
func _footprint(pin: Dictionary, c: Vector2) -> Rect2:
	var tw := 0.0
	if labels_shown and str(pin["label"]) != "":
		if not pin.has("_lw"):
			pin["_lw"] = Style.font("ui_bold").get_string_size(pin["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
		tw = pin["_lw"]
	var half := maxf(PIN_R + 2.0, tw / 2.0)
	var bottom := PIN_R + (22.0 if tw > 0.0 else 2.0)
	return Rect2(c.x - half, c.y - PIN_R - 2.0, half * 2.0, PIN_R + 2.0 + bottom)


## Lay the pins out in pixels (the map's aspect ratio and the label widths are only
## known here): push them apart until no pin or label covers another, keeping them on
## land and on the map. If the labels can't all fit (long names on a small phone map),
## show the pins alone: the list next to the map names every place anyway.
func _resolve_overlaps() -> void:
	_px_size = size
	_px.clear()
	if size.x < 10.0 or size.y < 10.0:
		return
	var key := "%s|%s|%s" % [city_id, size, ",".join(pins.map(func(p): return "%s:%s:%s" % [p["id"], p["label"], p["pos"]]))]
	_lm_size = size
	if _layout_cache.has(key):
		labels_shown = _layout_cache[key][0]
		_px = (_layout_cache[key][1] as Dictionary).duplicate()
		_lm_px = _layout_cache[key][2]
		return
	labels_shown = true
	var pos: Array = []
	var lm := Vector2.INF
	if landmark != "":
		# Best case: the landmark sits at its spot and the pins make room around it.
		lm = _find_landmark_spot([])
		if lm != Vector2.INF:
			pos = _first_clear_layout([landmark_rect(lm).grow(4.0)])
			if pos.is_empty():
				lm = Vector2.INF
	if pos.is_empty():
		pos = _first_clear_layout([])
	if pos.is_empty():
		labels_shown = false
		pos = _first_clear_layout([])
		if pos.is_empty():
			pos = _push_apart()
	for k in range(pins.size()):
		_px[pins[k]["id"]] = pos[k]
	if lm == Vector2.INF and landmark != "":
		# Otherwise it takes whatever room the pins left (or stays out).
		var rects: Array = []
		for k in range(pins.size()):
			rects.append(_footprint(pins[k], pos[k]).grow(4.0))
		lm = _find_landmark_spot(rects)
	_lm_px = lm
	if _layout_cache.size() > 200:
		_layout_cache.clear()
	_layout_cache[key] = [labels_shown, _px.duplicate(), _lm_px]


## Try a few layout strategies, return the first with no overlaps ([] if none).
func _first_clear_layout(fixed: Array) -> Array:
	var natural: Array = range(pins.size())
	var widest := natural.duplicate()
	widest.sort_custom(func(i, j): return _footprint(pins[i], Vector2.ZERO).size.x > _footprint(pins[j], Vector2.ZERO).size.x)
	for strategy in [func(): return _relax(natural, fixed), func(): return _relax(widest, fixed), _push_apart]:
		var pos: Array = strategy.call()
		if not pos.is_empty() and _layout_clear(pos, fixed):
			return pos
	return []


## Pins in `order` each take the free spot nearest to where they want to be
## (searched in growing square rings around it). [] as soon as one finds no room.
func _relax(order: Array, fixed: Array) -> Array:
	var pos: Array = []
	pos.resize(pins.size())
	var placed: Array = fixed.duplicate()
	var step := 8.0
	var reach := int(ceil(maxf(size.x, size.y) / step)) + 1
	for k in order:
		var pin: Dictionary = pins[k]
		var want := Vector2(pin["pos"].x * size.x, pin["pos"].y * size.y)
		var best := _clamp_in(pin, want)
		var found := false
		# Grid steps that keep the candidate on the map, in each direction.
		var lo_x := -int(floor(want.x / step))
		var hi_x := int(floor((size.x - want.x) / step))
		var lo_y := -int(floor(want.y / step))
		var hi_y := int(floor((size.y - want.y) / step))
		for r in range(reach + 1):
			if r > maxi(maxi(-lo_x, hi_x), maxi(-lo_y, hi_y)):
				break
			for dy in range(maxi(-r, lo_y), mini(r, hi_y) + 1):
				var xs: Array = range(maxi(-r, lo_x), mini(r, hi_x) + 1) if absi(dy) == r else ([-r, r] if r > 0 else [0])
				for dx in xs:
					if dx < lo_x or dx > hi_x:
						continue
					var c := _clamp_in(pin, want + Vector2(dx, dy) * step)
					if not _on_land(Vector2(c.x / size.x, c.y / size.y)):
						continue
					var fp := _footprint(pin, c).grow(3.0)
					var free := true
					for q in placed:
						if fp.intersects(q):
							free = false
							break
					if free:
						best = c
						found = true
						break
				if found:
					break
			if found:
				break
		if not found:
			return []
		pos[k] = best
		placed.append(_footprint(pin, best).grow(3.0))
	return pos


## Start from the wanted spots and push overlapping pins apart along the cheaper axis.
func _push_apart() -> Array:
	var pos: Array = []
	for pin in pins:
		var start := _clamp_in(pin, Vector2(pin["pos"].x * size.x, pin["pos"].y * size.y))
		pos.append(start)
	for it in range(120):
		var moved := false
		for i in range(pins.size()):
			for j in range(i + 1, pins.size()):
				var a := _footprint(pins[i], pos[i]).grow(3.0)
				var b := _footprint(pins[j], pos[j]).grow(3.0)
				if not a.intersects(b):
					continue
				var ov := a.intersection(b)
				var push := Vector2.ZERO
				if ov.size.y <= ov.size.x:
					push.y = (ov.size.y / 2.0 + 0.5) * (1.0 if pos[j].y >= pos[i].y else -1.0)
				else:
					push.x = (ov.size.x / 2.0 + 0.5) * (1.0 if pos[j].x >= pos[i].x else -1.0)
				pos[i] = _step_to(pins[i], pos[i], pos[i] - push)
				pos[j] = _step_to(pins[j], pos[j], pos[j] + push)
				moved = true
		if not moved:
			break
	return pos


## Move a pin towards `p`, staying on the map and out of the water.
func _step_to(pin: Dictionary, old: Vector2, p: Vector2) -> Vector2:
	for c in [_clamp_in(pin, p), _clamp_in(pin, Vector2(p.x, old.y)), _clamp_in(pin, Vector2(old.x, p.y))]:
		if _on_land(Vector2(c.x / size.x, c.y / size.y)):
			return c
	return old


func _layout_clear(pos: Array, fixed: Array) -> bool:
	for i in range(pins.size()):
		var a := _footprint(pins[i], pos[i])
		if a.position.x < -0.5 or a.position.y < -0.5 or a.end.x > size.x + 0.5 or a.end.y > size.y + 0.5:
			return false
		for f in fixed:
			if a.intersects(f):
				return false
		for j in range(i + 1, pins.size()):
			if a.intersects(_footprint(pins[j], pos[j])):
				return false
	return true


func _clamp_in(pin: Dictionary, p: Vector2) -> Vector2:
	var fp := _footprint(pin, p)
	var c := p
	c.x += maxf(0.0, 2.0 - fp.position.x) - maxf(0.0, fp.end.x - size.x + 2.0)
	c.y += maxf(0.0, 2.0 - fp.position.y) - maxf(0.0, fp.end.y - size.y + 2.0)
	return c


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var best_d := PIN_R * 1.8
		for pin in pins:
			var d := _pin_px(pin).distance_to(event.position)
			if d < best_d and not pin.get("disabled", false):
				best_d = d
				best = pin["id"]
		if best != "":
			selected = best
			place_pressed.emit(best)
			queue_redraw()
			accept_event()


func _process(_delta: float) -> void:
	for pin in pins:
		if _icons.has(pin["id"]):
			var ic: Control = _icons[pin["id"]]
			ic.position = _pin_px(pin) - Vector2(11, 11)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), LAND)
	# blocks between streets
	var step := 46.0
	var y := 0.0
	while y < h:
		var x := 0.0
		while x < w:
			draw_rect(Rect2(x + 4, y + 4, step - 8, step - 8), BLOCK)
			x += step
		y += step
	# parks
	for r in _parks:
		draw_rect(Rect2(r.position.x * w, r.position.y * h, r.size.x * w, r.size.y * h), PARK)
	# streets
	var gx := 0.0
	while gx < w:
		draw_line(Vector2(gx, 0), Vector2(gx, h), STREET, 4.0)
		gx += step
	var gy := 0.0
	while gy < h:
		draw_line(Vector2(0, gy), Vector2(w, gy), STREET, 4.0)
		gy += step
	draw_line(Vector2(0, h * 0.9), Vector2(w, h * 0.1), AVENUE, 10.0)
	draw_line(Vector2(w * 0.1, 0), Vector2(w * 0.7, h), AVENUE, 8.0)
	# water
	match water:
		"coast":
			var pts := PackedVector2Array()
			match _water_side:
				0:
					pts = PackedVector2Array([Vector2(0, h * 0.8), Vector2(w * 0.3, h * 0.77), Vector2(w * 0.6, h * 0.82), Vector2(w, h * 0.78), Vector2(w, h), Vector2(0, h)])
				1:
					pts = PackedVector2Array([Vector2(w * 0.82, 0), Vector2(w * 0.79, h * 0.4), Vector2(w * 0.84, h * 0.7), Vector2(w * 0.8, h), Vector2(w, h), Vector2(w, 0)])
				_:
					pts = PackedVector2Array([Vector2(0, 0), Vector2(w * 0.18, 0), Vector2(w * 0.21, h * 0.35), Vector2(w * 0.16, h * 0.7), Vector2(w * 0.2, h), Vector2(0, h)])
			draw_colored_polygon(pts, WATER)
			draw_polyline(pts.slice(0, pts.size() - 2), WATER_EDGE, 3.0)
		"river":
			var top := PackedVector2Array()
			var bottom := PackedVector2Array()
			for i in range(0, 41):
				var fx := i / 40.0
				var cy := _river_y_at(fx) * h
				top.append(Vector2(fx * w, cy - 16))
				bottom.append(Vector2(fx * w, cy + 16))
			var poly := top.duplicate()
			var rev := bottom.duplicate()
			rev.reverse()
			poly.append_array(rev)
			draw_colored_polygon(poly, WATER)
			draw_polyline(top, WATER_EDGE, 2.0)
			draw_polyline(bottom, WATER_EDGE, 2.0)
	# landmark
	var lp := _landmark_px()
	if lp != Vector2.INF:
		_star(lp, 13.0, Style.GOLD.darkened(0.15))
		var f := Style.font("ui_bold")
		var tw := f.get_string_size(landmark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_rect(Rect2(lp.x - tw / 2 - 6, lp.y + 15, tw + 12, 18), Color(1, 1, 1, 0.85))
		draw_string(f, Vector2(lp.x - tw / 2, lp.y + 28), landmark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Style.INK2)
	# pins
	for pin in pins:
		var c := _pin_px(pin)
		var col: Color = Style.NAVY
		match pin["kind"]:
			"source":
				col = Style.SKY if pin["icon"] != "money" else Style.ROSE
			"airport":
				col = Style.CORAL
			"hideout":
				col = Style.NAVY
		if pin.get("disabled", false):
			col = Style.MUTED
		if pin["id"] == selected:
			draw_circle(c, PIN_R + 7, Color(Style.CORAL, 0.25))
		draw_circle(c + Vector2(0, 2), PIN_R + 1, Color(0, 0, 0, 0.15))
		draw_circle(c, PIN_R, col)
		draw_arc(c, PIN_R, 0, TAU, 32, Color.WHITE, 2.5)
		if pin["kind"] == "hideout":
			var f := Style.font("display")
			var lw := f.get_string_size(pin["letter"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(f, c + Vector2(-lw / 2, 7), pin["letter"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		if pin.get("done", false):
			draw_circle(c + Vector2(PIN_R * 0.75, -PIN_R * 0.75), 8, Style.GREEN)
			draw_polyline(PackedVector2Array([c + Vector2(PIN_R * 0.75 - 4, -PIN_R * 0.75), c + Vector2(PIN_R * 0.75 - 1, -PIN_R * 0.75 + 3), c + Vector2(PIN_R * 0.75 + 4, -PIN_R * 0.75 - 3)]), Color.WHITE, 2.0)
		var label: String = pin["label"]
		if label != "" and labels_shown:
			var f2 := Style.font("ui_bold")
			var tw2 := f2.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var lx := clampf(c.x - tw2 / 2, 4.0, w - tw2 - 4.0)
			draw_rect(Rect2(lx - 5, c.y + PIN_R + 4, tw2 + 10, 18), Color(1, 1, 1, 0.9))
			draw_string(f2, Vector2(lx, c.y + PIN_R + 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Style.INK)


## Star + name of the landmark around pixel point `lp`.
func landmark_rect(lp: Vector2) -> Rect2:
	var tw := Style.font("ui_bold").get_string_size(landmark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var half := maxf(14.0, tw / 2.0 + 6.0)
	return Rect2(lp.x - half, lp.y - 14.0, half * 2.0, 47.0)


## Where the landmark goes: a spot on land, on the map and clear of every pin
## (Vector2.INF = no room, then it is left out; it is only decoration).
func _landmark_px() -> Vector2:
	if landmark == "" or size.x < 10.0:
		return Vector2.INF
	if _px_size != size or _lm_size != size:
		_resolve_overlaps()
	return _lm_px


## Nearest spot to a per-city preferred point (10 px grid) that is on land, on the
## map and clear of `rects`.
func _find_landmark_spot(rects: Array) -> Vector2:
	# Nearest free spot to a per-city preferred point, on a 10 px grid.
	var want := Vector2((_hash01(0) * 0.6 + 0.2) * size.x, (_hash01(1) * 0.5 + 0.2) * size.y)
	var cands: Array = []
	var y := 16.0
	while y < size.y - 32.0:
		var x := 16.0
		while x < size.x - 16.0:
			cands.append(Vector2(x, y))
			x += 10.0
		y += 10.0
	cands.sort_custom(func(u: Vector2, v: Vector2): return u.distance_squared_to(want) < v.distance_squared_to(want))
	for lp in cands:
		if not _on_land(Vector2(lp.x / size.x, lp.y / size.y)):
			continue
		var r := landmark_rect(lp)
		if r.position.x < 2.0 or r.position.y < 2.0 or r.end.x > size.x - 2.0 or r.end.y > size.y - 2.0:
			continue
		if rects.all(func(q): return not (q as Rect2).intersects(r)):
			return lp
	return Vector2.INF


func _hash01(salt: int) -> float:
	return float(abs(hash(city_id + "lm" + str(salt))) % 1000) / 1000.0


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, Color.WHITE, 1.5)
