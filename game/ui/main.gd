## Game UI. Presentation only: all rules live in res://core (ADR-0002, ADR-0006).
extends Control

const GameData = preload("res://core/game_data.gd")
const CaseState = preload("res://core/case_state.gd")
const Geo = preload("res://core/geo.gd")
const Loc = preload("res://core/loc.gd")
const GlobeView = preload("res://ui/globe_view.gd")
const ChaseView = preload("res://ui/chase_view.gd")
const Progress = preload("res://core/progress.gd")
const SuspectPortrait = preload("res://ui/suspect_portrait.gd")
const FONT_TITLE := preload("res://assets/fonts/BebasNeue-Regular.ttf")
const FONT_MONO := preload("res://assets/fonts/SpaceMono-Regular.ttf")

const BG_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.16, 0.18, 0.20), vec3(0.10, 0.11, 0.13), uv.y);
	float v = smoothstep(1.2, 0.3, length(uv - 0.5) * 1.3);
	COLOR = vec4(col * (0.75 + 0.25 * v), 1.0);
}
"""



# Classic detective-dossier palette: charcoal, paper, stamp red, brass.
const C_BG := Color("1f2328")
const C_PANEL := Color("2b3036")
const C_PINK := Color("c0392b")   # stamp red (primary accent)
const C_CYAN := Color("d9a441")   # brass / amber (secondary accent)
const C_TEXT := Color("ece7dc")
const C_MUTED := Color("9aa0a6")
const C_PAPER := Color("e9dfc6")
const C_INK := Color("1c1a17")
const C_CORK := Color("8a5a33")
const C_RED := Color("c8102e")

var data
var loc
var state
var current_case := "case_01"
var notebook: Array = []
var evidence: Array = []   # notebook lines that describe the suspect
var last_clue: Dictionary = {}
var last_flight: Dictionary = {}
var crossed: Dictionary = {}
var pin: Vector2 = Vector2.INF
var chase_result := ""
var progress
var recorded := false
var flying := false

var title_label: Label
var clock_label: Label
var lang_btn: Button
var content: VBoxContainer
var actions: VBoxContainer
var ad_bar: PanelContainer
var ad_label: Label
var screen := "menu"


func _ready() -> void:
	data = GameData.new()
	data.load_all()
	progress = Progress.new()
	progress.load_file()
	loc = Loc.new(data.strings, "es" if OS.get_locale_language() == "es" else "en")
	theme = _make_theme()
	_build_layout()
	show_menu()


# ---------- layout & helpers ----------

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.material = _canvas_shader(BG_SHADER)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_font_override("font", FONT_TITLE)
	title_label.add_theme_color_override("font_color", C_PINK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	clock_label = Label.new()
	clock_label.add_theme_color_override("font_color", C_CYAN)
	clock_label.add_theme_font_size_override("font_size", 32)
	clock_label.add_theme_font_override("font", FONT_TITLE)
	top.add_child(clock_label)
	lang_btn = Button.new()
	lang_btn.pressed.connect(func():
		loc.toggle()
		_refresh())
	top.add_child(lang_btn)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	root.add_child(mid)

	var left := PanelContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	mid.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	mid.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	actions = VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 10)
	rscroll.add_child(actions)

	ad_bar = PanelContainer.new()
	ad_bar.custom_minimum_size = Vector2(0, 50)
	ad_label = Label.new()
	ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ad_label.add_theme_color_override("font_color", C_MUTED)
	ad_bar.add_child(ad_label)
	root.add_child(ad_bar)



func _canvas_shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("353b42")
	btn.border_color = Color("5c646e")
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(6)
	btn.set_content_margin_all(12)
	var hov := btn.duplicate()
	hov.bg_color = Color("424a53")
	hov.border_color = C_CYAN
	var dis := btn.duplicate()
	dis.bg_color = Color("2a2e33")
	dis.border_color = Color("3b4148")
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", hov)
	th.set_stylebox("pressed", "Button", hov)
	th.set_stylebox("disabled", "Button", dis)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_hover_color", "Button", C_CYAN)
	th.set_color("font_disabled_color", "Button", C_MUTED)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(C_PANEL, 0.95)
	panel.border_color = Color("434a52")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(16)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_color("font_color", "Label", C_TEXT)
	return th


func _clear() -> void:
	for box in [content, actions]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()


func _label(parent: Control, text: String, size := 20, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if size >= 26:
		l.add_theme_font_override("font", FONT_TITLE)
		l.add_theme_font_size_override("font_size", int(size * 1.35))
	parent.add_child(l)
	return l


func _mono(l: Label) -> Label:
	l.add_theme_font_override("font", FONT_MONO)
	return l


func _button(text: String, cb: Callable, disabled := false, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	(parent if parent else actions).add_child(b)
	return b


func _flat_panel(color: Color, border := Color.TRANSPARENT, width := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	return sb


func _chrome(title: String, show_ad: bool) -> void:
	_clear()
	title_label.text = title
	lang_btn.text = loc.s("lang_button")
	clock_label.text = loc.s("hours", {"used": state.hours_used, "budget": state.budget}) if state else ""
	ad_bar.visible = show_ad
	ad_label.text = loc.s("ad_placeholder")


func _refresh() -> void:
	match screen:
		"menu": show_menu()
		"cases": show_cases()
		"briefing": show_briefing()
		"city": show_city()
		"travel": show_travel()
		"board": show_board()
		"chase": show_chase()
		"results": show_results()


func _city(id: String) -> String:
	return loc.t(data.cities[id]["name"])


# ---------- screens ----------

func show_menu() -> void:
	screen = "menu"
	state = null
	_chrome("", true)
	var logo := _label(content, loc.s("game_title"), 60, C_PINK)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_color", C_PAPER)
	var tag := _label(content, loc.s("tagline"), 20, C_CYAN)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hero := GlobeView.new()
	hero.custom_minimum_size = Vector2(0, 300)
	hero.interactive = false
	hero.auto_spin = 0.25
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hero)
	hero.focus(20.0, -30.0)
	hero.camera.position.z = 3.2
	hero.home_marker.visible = false
	_label(content, "Pre-alpha", 14, C_MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(actions, loc.s("rank_line", {"rank": loc.t(progress.rank()), "stars": progress.total_stars(), "max": data.cases.size() * 3}), 20, C_CYAN)
	var next := _next_case()
	if next != "":
		_button(loc.s("continue_case", {"title": loc.t(data.cases[next]["title"])}), func():
			current_case = next
			_start_case())
	_button(loc.s("cases"), show_cases)


func _cases_by_number() -> Dictionary:
	var by := {}
	for cid in data.cases:
		by[int(data.cases[cid]["number"])] = data.cases[cid]
	return by


## First unlocked case that is not solved yet (or the last case if all are solved).
func _next_case() -> String:
	var by := _cases_by_number()
	var nums: Array = by.keys()
	nums.sort()
	for n in nums:
		if progress.is_unlocked(n, by) and not progress.is_solved(by[n]["id"]):
			return by[n]["id"]
	return by[nums[-1]]["id"] if not nums.is_empty() else ""


func show_cases() -> void:
	screen = "cases"
	state = null
	_chrome(loc.s("cases"), true)
	var by := _cases_by_number()
	var nums: Array = by.keys()
	nums.sort()
	var last_net := ""
	for n in nums:
		var cd: Dictionary = by[n]
		if cd["network"] != last_net:
			last_net = cd["network"]
			_label(content, loc.t(cd["network_name"]), 26, C_CYAN)
		var row := HBoxContainer.new()
		content.add_child(row)
		var unlocked: bool = progress.is_unlocked(n, by)
		var best: int = progress.best(cd["id"])
		var txt: String = loc.t(cd["title"])
		if unlocked:
			txt += "   " + loc.s("case_stars", {"stars": best})
		else:
			txt += "   " + loc.s("locked")
		var b := _button(txt, func():
			current_case = cd["id"]
			_start_case(), not unlocked, row)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(actions, loc.s("rank_line", {"rank": loc.t(progress.rank()), "stars": progress.total_stars(), "max": data.cases.size() * 3}), 20, C_CYAN)
	_label(actions, loc.s("cases_help"), 16, C_MUTED)
	_button(loc.s("menu"), show_menu)


func _start_case() -> void:
	state = CaseState.new(data, current_case, randi() % 100000 + 1)
	notebook.clear()
	evidence.clear()
	last_clue = {}
	last_flight = {}
	crossed = {}
	chase_result = ""
	recorded = false
	pin = Vector2.INF
	show_briefing()


func show_briefing() -> void:
	screen = "briefing"
	var cd: Dictionary = state.case_def
	_chrome(loc.s("briefing"), false)
	_label(content, loc.t(cd["network_name"]), 18, C_CYAN)
	_label(content, loc.t(cd["title"]), 28, C_PINK)
	_label(content, loc.t(cd["crime"]), 22, C_PAPER)
	var arc := int((int(cd["number"]) - 1) / 3) + 1
	_label(content, loc.s("difficulty", {"n": arc, "stops": cd["route"].size(), "radius": int(state.radius_km)}), 18, C_MUTED)
	_label(content, loc.s("budget_info", {"hours": state.budget, "radius": int(state.radius_km)}), 20, C_CYAN)
	_button(loc.s("start"), show_city)


func show_city() -> void:
	if state.status != "playing":
		show_results()
		return
	screen = "city"
	_chrome(_city(state.current), false)
	var c: Dictionary = data.cities[state.current]
	if not last_flight.is_empty():
		var key := "flight_hit" if last_flight["hit"] else "flight_miss"
		_label(content, loc.s(key, {"city": _city(last_flight["city"]), "km": int(last_flight["km_off"])}), 20, C_CYAN if last_flight["hit"] else C_PINK)
	else:
		_label(content, loc.s("you_are_in", {"city": loc.t(c["name"]), "country": loc.t(c["country"])}), 22, C_CYAN)
	if not last_clue.is_empty():
		_render_clue(last_clue)
	_label(content, loc.s("notebook"), 18, C_PINK)
	if notebook.is_empty():
		_label(content, loc.s("notebook_empty"), 18, C_MUTED)
	for line in notebook:
		_mono(_label(content, "• " + line, 16, C_PAPER))

	for spot in CaseState.SPOTS:
		var done: bool = state.visited.has(spot)
		var txt: String = loc.s("spot_" + spot) + "  " + (loc.s("done") if done else loc.s("spot_cost"))
		_button(txt, _on_spot.bind(spot))
	var cc: Dictionary = state.visited.get("cctv", {})
	if cc.get("hint_locked", false):
		_button(loc.s("enhance"), _on_enhance)
	if state.can_travel():
		_button(loc.s("travel"), show_travel)
	_button(loc.s("board"), show_board)
	if state.is_final():
		_button(loc.s("arrest"), show_chase)


func _on_spot(spot: String) -> void:
	var clue: Dictionary = state.visit(spot)
	if clue.is_empty():
		show_city()
		return
	var line := _clue_text(clue)
	if not line in notebook:
		notebook.append(line)
		if clue.get("kind") == "trait":
			evidence.append(line)
	last_clue = clue
	show_city()


func _on_enhance() -> void:
	var old := _clue_text(state.visited["cctv"])
	var clue: Dictionary = state.enhance_cctv()
	notebook.erase(old)
	var line := _clue_text(clue)
	if not line in notebook:
		notebook.append(line)
	last_clue = clue
	show_city()


func _clue_text(clue: Dictionary) -> String:
	var city: String = _city(state.current)
	match clue.get("kind", ""):
		"dest":
			if clue.get("source", "") == "money":
				return city + " — " + loc.s("money_dest", {"text": loc.t(clue["text"])})
			return city + " — " + loc.s("wiretap_says", {"text": loc.t(clue["text"])})
		"trait":
			if clue.get("near", false):
				return city + " — " + loc.s("near_evidence", {"text": loc.t(clue["text"])})
			return city + " — " + loc.s("money_says", {"text": loc.t(clue["text"])})
		"street":
			if clue.get("hint_locked", false):
				return city + " — " + loc.s("cctv_locked")
			return city + " — " + loc.s("cctv_note", {"hint": loc.t(clue["street"]["hint"])})
		"near":
			return city + " — " + loc.s("near_only")
		_:
			return city + " — " + loc.s("deadend")


func _render_clue(clue: Dictionary) -> void:
	if clue.get("kind") == "street":
		_label(content, loc.s("cctv_title"), 18, C_PINK)
		var street: Dictionary = clue["street"]
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(0, 280)
		frame.add_theme_stylebox_override("panel", _flat_panel(Color("111316"), Color("434a52"), 2))
		var img_path = street.get("image")
		if img_path != null and ResourceLoader.exists(img_path):
			var tr := TextureRect.new()
			tr.texture = load(img_path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			frame.add_child(tr)
		else:
			var l := Label.new()
			l.text = loc.s("cctv_pending")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.add_theme_color_override("font_color", C_MUTED)
			frame.add_child(l)
		var osd := Label.new()
		osd.text = "[REC]  CAM-%02d   %02d:%02d" % [state.stop + 3, (state.hours_used / 1) % 24, (state.hours_used * 7) % 60]
		osd.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		osd.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		osd.add_theme_color_override("font_color", Color("ff4040"))
		osd.add_theme_color_override("font_outline_color", Color.BLACK)
		osd.add_theme_constant_override("outline_size", 5)
		frame.add_child(osd)
		content.add_child(frame)
		if street.has("credit"):
			var cr: Dictionary = street["credit"]
			_label(content, loc.s("photo_credit", {"artist": cr["artist"], "license": cr["license"]}), 13, C_MUTED)
	_mono(_label(content, _clue_text(clue), 19, C_TEXT))


# ---------- pin-drop travel ----------

func show_travel() -> void:
	screen = "travel"
	_chrome(loc.s("travel"), true)
	var globe := GlobeView.new()
	globe.name = "TravelGlobe"
	globe.custom_minimum_size = Vector2(0, 470)
	content.add_child(globe)
	var here: Dictionary = data.cities[state.current]
	globe.focus(here["lat"], here["lon"])
	if pin != Vector2.INF:
		globe.set_pin(pin.x, pin.y)

	_label(actions, loc.s("globe_from", {"city": _city(state.current)}), 20, C_CYAN)
	_label(actions, loc.s("globe_help"), 17, C_MUTED)
	var info := _label(actions, "", 18, C_PAPER)
	var fly := _button(loc.s("fly_here"), _on_fly, true)
	_button(loc.s("back"), show_city)
	var update_info := func():
		if pin == Vector2.INF:
			info.text = loc.s("pin_none")
			fly.disabled = true
		else:
			var km := Geo.distance_km(here["lat"], here["lon"], pin.x, pin.y)
			info.text = loc.s("pin_at", {"lat": _fmt_lat(pin.x), "lon": _fmt_lon(pin.y), "hours": Geo.travel_hours(km)})
			fly.disabled = false
	update_info.call()
	globe.pin_dropped.connect(func(lat: float, lon: float):
		pin = Vector2(lat, lon)
		update_info.call())


func _fmt_lat(v: float) -> String:
	return "%.1f°%s" % [absf(v), "N" if v >= 0 else "S"]


func _fmt_lon(v: float) -> String:
	return "%.1f°%s" % [absf(v), "E" if v >= 0 else "W"]


func _on_fly() -> void:
	if pin == Vector2.INF or flying:
		return
	flying = true
	var from: Dictionary = data.cities[state.current]
	last_flight = state.travel_to_pin(pin.x, pin.y)
	pin = Vector2.INF
	last_clue = {}
	var to: Dictionary = data.cities[state.current]
	var globe := content.find_child("TravelGlobe", true, false)
	for b in actions.get_children():
		if b is Button:
			b.disabled = true
	if globe:
		globe.clear_pin()
		globe.fly(from["lat"], from["lon"], to["lat"], to["lon"])
		await globe.flight_done
		await get_tree().create_timer(0.3).timeout
	flying = false
	show_city()


# ---------- corkboard ----------

func show_board() -> void:
	var scroll := content.get_parent() as ScrollContainer
	var keep := scroll.scroll_vertical if screen == "board" else 0
	screen = "board"
	_chrome(loc.s("board"), false)
	var cork := PanelContainer.new()
	cork.add_theme_stylebox_override("panel", _flat_panel(C_CORK, Color("5a3a20"), 6))
	content.add_child(cork)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	cork.add_child(col)

	_label(col, loc.s("cork_title"), 16, C_PAPER)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	var ids: Array = data.suspects.keys().filter(func(i): return data.suspects[i]["network"] == state.case_def["network"])
	ids.sort()
	for sid in ids:
		grid.add_child(_suspect_card(sid))

	# Evidence notes pinned in the side panel
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", _flat_panel(Color("fff3a8")))
	actions.add_child(note)
	var nv := VBoxContainer.new()
	note.add_child(nv)
	_label(nv, loc.s("cork_evidence"), 15, C_RED)
	for line in evidence:
		_label(nv, "• " + line, 14, C_INK)
	if evidence.is_empty():
		_label(nv, loc.s("cork_no_evidence"), 14, C_INK)

	var remaining := ids.filter(func(i): return not crossed.get(i, false))
	if state.warrant != "":
		_label(actions, loc.s("warrant_for", {"name": data.suspects[state.warrant]["name"]}), 20, C_CYAN)
	if remaining.size() == 1 and state.warrant != remaining[0]:
		_button(loc.s("issue_warrant_for", {"name": data.suspects[remaining[0]]["name"]}), func():
			state.issue_warrant(remaining[0])
			show_board())
	elif remaining.size() != 1:
		_label(actions, loc.s("issue_warrant_hint"), 17, C_MUTED)
	_button(loc.s("back"), show_city)
	await get_tree().process_frame
	scroll.scroll_vertical = keep


func _suspect_card(sid: String) -> Control:
	var s: Dictionary = data.suspects[sid]
	var is_out: bool = crossed.get(sid, false)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _flat_panel(C_PAPER, C_RED if sid == state.warrant else Color("b9ab88"), 3))
	card.rotation_degrees = [-1.2, 0.8, 1.0, -0.6][abs(hash(sid)) % 4]
	var v := VBoxContainer.new()
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var portrait := SuspectPortrait.new()
	portrait.custom_minimum_size = Vector2(54, 64)
	portrait.setup(s, is_out)
	portrait.tooltip_text = loc.s("discarded") if is_out else ""
	head.add_child(portrait)
	var name_l := _label(head, str(s["name"]), 15, C_INK)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tid in data.trait_ids:
		var tr: Dictionary = data.traits[tid]
		var val: String = s["traits"][tid]
		var tl := _label(v, "%s: %s" % [loc.t(tr["name"]), loc.t(tr["values"][val]["label"])], 12, C_INK)
		tl.add_theme_constant_override("line_spacing", -2)
	if is_out:
		card.modulate = Color(1, 1, 1, 0.55)
	var b := _button(loc.s("restore") if is_out else loc.s("cross_out"), func():
		crossed[sid] = not is_out
		show_board(), false, v)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 13)
	var bs := _flat_panel(Color("353b42"), Color("5c646e"), 1)
	bs.set_content_margin_all(4)
	b.add_theme_stylebox_override("normal", bs)
	v.add_theme_constant_override("separation", 0)
	return card


# ---------- chase & results ----------

func show_chase() -> void:
	screen = "chase"
	_chrome(loc.s("chase_title"), false)
	var chase := ChaseView.new()
	chase.custom_minimum_size = Vector2(0, 470)
	chase.labels = {"time": loc.s("chase_time"), "gap": loc.s("chase_gap"), "help": ""}
	content.add_child(chase)
	_label(actions, loc.s("chase_text", {"city": _city(state.current)}), 20, C_PAPER)
	if state.warrant == "":
		_label(actions, loc.s("chase_no_warrant"), 18, C_PINK)
		_button(loc.s("board"), show_board)
	_label(actions, loc.s("chase_help"), 16, C_MUTED)
	var start_btn := _button(loc.s("chase_start"), func(): pass)
	start_btn.pressed.connect(func():
		start_btn.disabled = true
		chase.start())
	chase.finished.connect(func(caught: bool):
		chase_result = "chase_caught" if caught else "chase_escaped"
		state.arrest(caught)
		await get_tree().create_timer(0.8).timeout
		show_results())
	_button(loc.s("back"), show_city)


func show_results() -> void:
	screen = "results"
	_chrome(loc.s("game_title"), true)
	var msg: String
	match state.status:
		"won": msg = loc.s("won", {"name": data.suspects[state.case_def["culprit"]]["name"]})
		_: msg = loc.s(state.status)
	_label(content, msg, 28, C_CYAN if state.status == "won" else C_PINK)
	if chase_result != "" and state.status == "won":
		_label(content, loc.s(chase_result), 20, C_PAPER)
	_label(content, loc.s("stars", {"stars": state.stars()}), 24, C_PAPER)
	_label(content, loc.s("summary", {"used": state.hours_used, "budget": state.budget, "misses": state.misses, "km": int(state.avg_precision_km())}), 20, C_TEXT)
	if not recorded:
		recorded = true
		var old_rank: String = loc.t(progress.rank())
		progress.record(state.case_def["id"], state.stars())
		progress.save_file()
		if loc.t(progress.rank()) != old_rank:
			_label(content, loc.s("promoted", {"rank": loc.t(progress.rank())}), 26, C_CYAN)
	_label(content, loc.s("rank_line", {"rank": loc.t(progress.rank()), "stars": progress.total_stars(), "max": data.cases.size() * 3}), 18, C_MUTED)
	var by := _cases_by_number()
	var nxt = by.get(int(state.case_def["number"]) + 1)
	if state.status == "won" and nxt != null:
		_button(loc.s("next_case", {"title": loc.t(nxt["title"])}), func():
			current_case = nxt["id"]
			_start_case())
	_button(loc.s("play_again"), _start_case)
	_button(loc.s("cases"), show_cases)
	_button(loc.s("menu"), show_menu)
