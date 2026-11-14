## Game UI. Presentation only: all rules live in res://core (ADR-0002, ADR-0006).
extends Control

const GameData = preload("res://core/game_data.gd")
const CaseState = preload("res://core/case_state.gd")
const Geo = preload("res://core/geo.gd")
const Loc = preload("res://core/loc.gd")
const GlobeView = preload("res://ui/globe_view.gd")
const ChaseView = preload("res://ui/chase_view.gd")

const C_BG := Color("0b0d16")
const C_PANEL := Color("12152a")
const C_PINK := Color("ff3d7f")
const C_CYAN := Color("31e1f7")
const C_TEXT := Color("ece9e4")
const C_MUTED := Color("8a90a8")
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
	loc = Loc.new(data.strings, "es" if OS.get_locale_language() == "es" else "en")
	theme = _make_theme()
	_build_layout()
	show_menu()


# ---------- layout & helpers ----------

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", C_PINK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	clock_label = Label.new()
	clock_label.add_theme_color_override("font_color", C_CYAN)
	clock_label.add_theme_font_size_override("font_size", 24)
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


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("1b1f38")
	btn.border_color = C_PINK
	btn.set_border_width_all(2)
	btn.set_corner_radius_all(6)
	btn.set_content_margin_all(12)
	var hov := btn.duplicate()
	hov.bg_color = Color("2a2f55")
	hov.border_color = C_CYAN
	var dis := btn.duplicate()
	dis.bg_color = Color("14162a")
	dis.border_color = Color("3a3f5a")
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", hov)
	th.set_stylebox("pressed", "Button", hov)
	th.set_stylebox("disabled", "Button", dis)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_hover_color", "Button", C_CYAN)
	th.set_color("font_disabled_color", "Button", C_MUTED)
	var panel := StyleBoxFlat.new()
	panel.bg_color = C_PANEL
	panel.border_color = Color("2b3160")
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
	parent.add_child(l)
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
	_chrome(loc.s("game_title"), true)
	_label(content, loc.s("tagline"), 26, C_CYAN)
	_label(content, "Pre-alpha — placeholder art", 16, C_MUTED)
	_button(loc.s("play_case", {"title": loc.t(data.cases[current_case]["title"])}), _start_case)


func _start_case() -> void:
	state = CaseState.new(data, current_case, randi() % 100000 + 1)
	notebook.clear()
	evidence.clear()
	last_clue = {}
	last_flight = {}
	crossed = {}
	chase_result = ""
	show_briefing()


func show_briefing() -> void:
	screen = "briefing"
	var cd: Dictionary = state.case_def
	_chrome(loc.s("briefing"), false)
	_label(content, loc.t(cd["title"]), 28, C_PINK)
	_label(content, loc.t(cd["crime"]), 22, C_PAPER)
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
		_label(content, "• " + line, 18, C_PAPER)

	for spot in CaseState.SPOTS:
		var done: bool = state.visited.has(spot)
		var txt: String = loc.s("spot_" + spot) + "  " + (loc.s("done") if done else loc.s("spot_cost"))
		_button(txt, _on_spot.bind(spot))
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


func _clue_text(clue: Dictionary) -> String:
	var city: String = _city(state.current)
	match clue.get("kind", ""):
		"dest":
			return city + " — " + loc.s("wiretap_says", {"text": loc.t(clue["text"])})
		"trait":
			if clue.get("near", false):
				return city + " — " + loc.s("near_evidence", {"text": loc.t(clue["text"])})
			return city + " — " + loc.s("money_says", {"text": loc.t(clue["text"])})
		"street":
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
		frame.add_theme_stylebox_override("panel", _flat_panel(Color("05070d"), Color("2b3160"), 2))
		var img_path = street.get("image")
		if img_path != null and ResourceLoader.exists(img_path):
			var tr := TextureRect.new()
			tr.texture = load(img_path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.modulate = Color(0.85, 1.0, 0.9)
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
	_label(content, _clue_text(clue), 22, C_TEXT)


# ---------- pin-drop travel ----------

func show_travel() -> void:
	screen = "travel"
	_chrome(loc.s("travel"), true)
	var globe := GlobeView.new()
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
	if pin == Vector2.INF:
		return
	last_flight = state.travel_to_pin(pin.x, pin.y)
	pin = Vector2.INF
	last_clue = {}
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
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	var ids: Array = data.suspects.keys()
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
	v.add_child(head)
	var mug := PanelContainer.new()
	mug.custom_minimum_size = Vector2(44, 48)
	mug.add_theme_stylebox_override("panel", _flat_panel(Color("3b3f4f")))
	var ini := Label.new()
	var parts: PackedStringArray = str(s["name"]).replace("\"", "").split(" ", false)
	ini.text = parts[0].substr(0, 1) + parts[parts.size() - 1].substr(0, 1)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ini.add_theme_font_size_override("font_size", 20)
	ini.add_theme_color_override("font_color", C_PAPER)
	mug.add_child(ini)
	head.add_child(mug)
	var name_l := _label(head, str(s["name"]), 17, C_INK)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tid in data.trait_ids:
		var tr: Dictionary = data.traits[tid]
		var val: String = s["traits"][tid]
		var tl := _label(v, "%s: %s" % [loc.t(tr["name"]), loc.t(tr["values"][val]["label"])], 14, C_INK)
		tl.add_theme_constant_override("line_spacing", -2)
	if is_out:
		ini.text = "X"
		ini.add_theme_color_override("font_color", Color("ff5a5a"))
		mug.tooltip_text = loc.s("discarded")
		card.modulate = Color(1, 1, 1, 0.55)
	var b := _button(loc.s("restore") if is_out else loc.s("cross_out"), func():
		crossed[sid] = not is_out
		show_board(), false, v)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 15)
	var bs := _flat_panel(Color("1b1f38"), C_PINK, 2)
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
	_button(loc.s("play_again"), _start_case)
	_button(loc.s("menu"), show_menu)
