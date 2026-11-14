## Game UI. Presentation only: all rules live in res://core (ADR-0002, ADR-0006..0009).
## Layout: top bar · body (each screen builds its own layout) · ad banner.
extends Control

const GameData = preload("res://core/game_data.gd")
const CaseState = preload("res://core/case_state.gd")
const Geo = preload("res://core/geo.gd")
const Loc = preload("res://core/loc.gd")
const Progress = preload("res://core/progress.gd")
const GlobeView = preload("res://ui/globe_view.gd")
const ChaseView = preload("res://ui/chase_view.gd")
const SuspectPortrait = preload("res://ui/suspect_portrait.gd")
const IconView = preload("res://ui/icon_view.gd")
const StarRow = preload("res://ui/star_row.gd")
const CityBanner = preload("res://ui/city_banner.gd")
const FONT_TITLE := preload("res://assets/fonts/BebasNeue-Regular.ttf")
const FONT_MONO := preload("res://assets/fonts/SpaceMono-Regular.ttf")

const BG_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.17, 0.19, 0.21), vec3(0.10, 0.11, 0.13), uv.y);
	float v = smoothstep(1.2, 0.3, length(uv - 0.5) * 1.3);
	COLOR = vec4(col * (0.75 + 0.25 * v), 1.0);
}
"""

# Classic detective-dossier palette.
const C_PANEL := Color("2b3036")
const C_CARD := Color("343a41")
const C_RED := Color("c0392b")     # stamp red (primary)
const C_BRASS := Color("d9a441")   # brass (secondary accent)
const C_TEXT := Color("ece7dc")
const C_MUTED := Color("9aa0a6")
const C_PAPER := Color("efe6d2")
const C_INK := Color("1c1a17")
const C_CORK := Color("8a5a33")
const C_GREEN := Color("4f7a4a")
const C_WHO := Color("e08a7f")

const SPOT_QUESTION := {"wiretap": "q_where", "cctv": "q_where", "contact": "q_where", "money": "q_who"}

var data
var loc
var state
var progress
var current_case := "case_01"
var notebook: Array = []
var evidence: Array = []
var last_flight: Dictionary = {}
var crossed: Dictionary = {}
var pin: Vector2 = Vector2.INF
var chase_result := ""
var recorded := false
var promoted := false
var flying := false
var screen := "menu"

var title_label: Label
var clock_box: HBoxContainer
var clock_label: Label
var clock_bar: ProgressBar
var lang_btn: Button
var body: MarginContainer
var ad_bar: PanelContainer
var ad_label: Label


func _ready() -> void:
	data = GameData.new()
	data.load_all()
	progress = Progress.new()
	progress.load_file()
	loc = Loc.new(data.strings, "es" if OS.get_locale_language() == "es" else "en")
	theme = _make_theme()
	_build_layout()
	show_menu()


# ======================================================================
# Layout, theme and widget helpers
# ======================================================================

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = BG_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	bg.material = m
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	title_label = Label.new()
	title_label.add_theme_font_override("font", FONT_TITLE)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", C_PAPER)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	top.add_child(title_label)

	clock_box = HBoxContainer.new()
	clock_box.add_theme_constant_override("separation", 8)
	top.add_child(clock_box)
	clock_box.add_child(_icon("clock", C_BRASS, 28))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	clock_box.add_child(cv)
	clock_label = Label.new()
	clock_label.add_theme_font_override("font", FONT_TITLE)
	clock_label.add_theme_font_size_override("font_size", 24)
	clock_label.add_theme_color_override("font_color", C_BRASS)
	cv.add_child(clock_label)
	clock_bar = ProgressBar.new()
	clock_bar.custom_minimum_size = Vector2(180, 8)
	clock_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_BRASS
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.4)
	back.set_corner_radius_all(3)
	clock_bar.add_theme_stylebox_override("fill", fill)
	clock_bar.add_theme_stylebox_override("background", back)
	cv.add_child(clock_bar)

	lang_btn = Button.new()
	lang_btn.focus_mode = Control.FOCUS_NONE
	lang_btn.pressed.connect(func():
		loc.toggle()
		_refresh())
	top.add_child(lang_btn)

	body = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	ad_bar = PanelContainer.new()
	ad_bar.custom_minimum_size = Vector2(0, 46)
	ad_label = Label.new()
	ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ad_label.add_theme_color_override("font_color", C_MUTED)
	ad_label.add_theme_font_size_override("font_size", 15)
	ad_bar.add_child(ad_label)
	root.add_child(ad_bar)


func _style(bg: Color, border := Color.TRANSPARENT, width := 0, radius := 8, pad := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 18
	th.set_stylebox("normal", "Button", _style(Color("3a4047"), Color("59626d"), 1, 8, 12))
	th.set_stylebox("hover", "Button", _style(Color("454c54"), C_BRASS, 1, 8, 12))
	th.set_stylebox("pressed", "Button", _style(Color("2e3339"), C_BRASS, 1, 8, 12))
	th.set_stylebox("disabled", "Button", _style(Color("2a2e33"), Color("3b4148"), 1, 8, 12))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("6d737a"))
	th.set_stylebox("panel", "PanelContainer", _style(Color(C_PANEL, 0.96), Color("434a52"), 1, 10, 16))
	th.set_color("font_color", "Label", C_TEXT)
	return th


func _clear() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


func _chrome(title: String, show_ad: bool) -> void:
	_clear()
	title_label.text = title
	lang_btn.text = loc.s("lang_button")
	clock_box.visible = state != null
	if state:
		clock_label.text = loc.s("hours", {"used": state.hours_used, "budget": state.budget})
		clock_bar.max_value = state.budget
		clock_bar.value = maxi(0, state.hours_left())
	ad_bar.visible = show_ad
	ad_label.text = loc.s("ad_placeholder")


func _refresh() -> void:
	match screen:
		"menu": show_menu()
		"cases": show_cases()
		"howto": show_howto()
		"briefing": show_briefing()
		"city": show_city()
		"notebook": show_notebook()
		"travel": show_travel()
		"board": show_board()
		"chase": show_chase()
		"results": show_results()


func _label(parent: Control, text: String, size := 18, color := C_TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	if not (parent is HBoxContainer):
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	parent.add_child(l)
	return l


func _title(parent: Control, text: String, size := 34, color := C_PAPER) -> Label:
	return _label(parent, text, size, color, FONT_TITLE)


func _button(parent: Control, text: String, cb: Callable, kind := "secondary", disabled := false, icon_kind := "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	if parent is VBoxContainer:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	if kind == "primary":
		b.add_theme_stylebox_override("normal", _style(C_RED, Color("e0574a"), 1, 8, 14))
		b.add_theme_stylebox_override("hover", _style(Color("d14536"), C_PAPER, 1, 8, 14))
		b.add_theme_stylebox_override("pressed", _style(Color("a33024"), C_PAPER, 1, 8, 14))
		b.add_theme_font_size_override("font_size", 20)
	if icon_kind != "":
		var ic := _icon(icon_kind, C_PAPER if kind == "primary" else C_BRASS, 24)
		ic.position = Vector2(12, 0)
		ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		ic.offset_left = 12
		ic.offset_right = 36
		ic.offset_top = -12
		ic.offset_bottom = 12
		b.add_child(ic)
		b.text = "       " + text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	return b


func _icon(kind: String, color: Color, px := 36.0) -> Control:
	var ic := IconView.new()
	ic.setup(kind, color, px)
	return ic


func _panel(parent: Control, bg := C_PANEL, border := Color("434a52")) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(bg, 0.97), border, 1, 10, 16))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


func _hbox(parent: Control, sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


func _vbox(parent: Control, sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func _scroll(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	sc.add_child(v)
	return v


func _chip(parent: Control, text: String, color := C_BRASS) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(Color(color, 0.18), color, 1, 12, 6))
	parent.add_child(p)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color.lightened(0.25))
	p.add_child(l)


func _side(parent: Control, width := 380.0) -> VBoxContainer:
	var v := _panel(parent)
	(v.get_parent() as Control).custom_minimum_size = Vector2(width, 0)
	return v


func _spacer(parent: Control, vertical := true) -> void:
	var s := Control.new()
	if vertical:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)


func _city(id: String) -> String:
	return loc.t(data.cities[id]["name"])


func _rank_line() -> String:
	return loc.s("rank_line", {"rank": loc.t(progress.rank()), "stars": progress.total_stars(), "max": data.cases.size() * 3})


# ======================================================================
# Menu, cases, how to play
# ======================================================================

func show_menu() -> void:
	screen = "menu"
	state = null
	_chrome("", true)
	var row := _hbox(body, 24)
	var left := _vbox(row, 12)
	left.custom_minimum_size = Vector2(440, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	_title(left, loc.s("game_title"), 84, C_PAPER)
	_label(left, loc.s("tagline"), 19, C_BRASS)
	var card := _panel(left, Color("2f343a"), C_BRASS)
	_label(card, loc.s("your_rank"), 14, C_MUTED)
	_title(card, loc.t(progress.rank()), 34, C_BRASS)
	_label(card, loc.s("stars_total", {"stars": progress.total_stars(), "max": data.cases.size() * 3}), 15, C_TEXT)
	var next := _next_case()
	if next != "":
		_button(left, loc.s("continue_case", {"title": loc.t(data.cases[next]["title"])}), func():
			current_case = next
			_start_case(), "primary", false, "cuffs")
	_button(left, loc.s("cases"), show_cases, "secondary", false, "board")
	_button(left, loc.s("howto"), show_howto, "secondary", false, "notebook")
	_label(left, "Pre-alpha", 12, C_MUTED)

	var hero := GlobeView.new()
	hero.interactive = false
	hero.auto_spin = 0.2
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hero)
	hero.focus(25.0, -20.0)
	hero.camera.position.z = 3.6
	hero.home_marker.visible = false


func _cases_by_number() -> Dictionary:
	var by := {}
	for cid in data.cases:
		by[int(data.cases[cid]["number"])] = data.cases[cid]
	return by


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
	var col := _scroll(body)
	_label(col, _rank_line() + " — " + loc.s("cases_help"), 15, C_MUTED)
	var by := _cases_by_number()
	var nums: Array = by.keys()
	nums.sort()
	var row: HBoxContainer
	var last_net := ""
	for n in nums:
		var cd: Dictionary = by[n]
		if cd["network"] != last_net:
			last_net = cd["network"]
			_title(col, loc.t(cd["network_name"]), 30, C_BRASS)
			row = _hbox(col, 12)
		var unlocked: bool = progress.is_unlocked(n, by)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not unlocked
		b.custom_minimum_size = Vector2(0, 124)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			current_case = cd["id"]
			_start_case())
		row.add_child(b)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14
		v.offset_top = 10
		v.offset_right = -14
		v.offset_bottom = -10
		b.add_child(v)
		_title(v, loc.t(cd["title"]), 24, C_PAPER if unlocked else C_MUTED)
		_label(v, loc.s("case_meta", {"stops": cd["route"].size()}) + ("  ·  " + loc.s("boss") if n % 3 == 0 else ""), 14, C_MUTED)
		if unlocked:
			var stars := StarRow.new()
			stars.setup(progress.best(cd["id"]), 22)
			stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(stars)
		else:
			_label(v, loc.s("locked"), 15, C_MUTED)
	_button(col, loc.s("menu"), show_menu)


func show_howto() -> void:
	screen = "howto"
	state = null
	_chrome(loc.s("howto"), true)
	var col := _scroll(body)
	var icons := ["notebook", "wiretap", "globe", "board", "cuffs"]
	for i in range(1, 6):
		var p := _panel(col)
		var h := _hbox(p, 16)
		h.add_child(_icon(icons[i - 1], C_BRASS, 48))
		var v := _vbox(h, 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_title(v, loc.s("howto_%d_title" % i), 26, C_PAPER)
		_label(v, loc.s("howto_%d" % i), 17, C_TEXT)
	_button(col, loc.s("menu"), show_menu, "primary")


# ======================================================================
# Case flow
# ======================================================================

func _start_case() -> void:
	state = CaseState.new(data, current_case, randi() % 100000 + 1)
	notebook.clear()
	evidence.clear()
	last_flight = {}
	crossed = {}
	chase_result = ""
	recorded = false
	promoted = false
	pin = Vector2.INF
	show_briefing()


func show_briefing() -> void:
	screen = "briefing"
	var cd: Dictionary = state.case_def
	_chrome(loc.s("briefing"), false)
	var center := CenterContainer.new()
	body.add_child(center)
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(880, 0)
	paper.add_theme_stylebox_override("panel", _style(C_PAPER, Color("b9ab88"), 2, 6, 28))
	center.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	paper.add_child(v)
	var head := _hbox(v, 12)
	var hv := _vbox(head, 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(hv, loc.t(cd["network_name"]).to_upper(), 15, Color("7a5a2a"))
	_title(hv, loc.t(cd["title"]), 44, C_INK)
	var stamp := Label.new()
	stamp.text = loc.s("confidential")
	stamp.add_theme_font_override("font", FONT_TITLE)
	stamp.add_theme_font_size_override("font_size", 30)
	stamp.add_theme_color_override("font_color", Color(C_RED, 0.85))
	stamp.rotation_degrees = -8
	head.add_child(stamp)
	_label(v, loc.t(cd["crime"]), 20, C_INK)
	var chips := _hbox(v, 8)
	var arc := int((int(cd["number"]) - 1) / 3) + 1
	var cc := Color("7a5a2a")
	_chip(chips, loc.s("chip_difficulty", {"n": arc}), cc)
	_chip(chips, loc.s("chip_cities", {"n": cd["route"].size()}), cc)
	_chip(chips, loc.s("chip_radius", {"km": int(state.radius_km)}), cc)
	_chip(chips, loc.s("chip_hours", {"h": state.budget}), cc)
	_label(v, loc.s("objective"), 16, C_RED)
	for i in range(1, 4):
		_label(v, "•  " + loc.s("objective_%d" % i), 17, C_INK)
	var bh := _hbox(v, 10)
	bh.alignment = BoxContainer.ALIGNMENT_END
	_button(bh, loc.s("back"), show_cases)
	_button(bh, loc.s("accept_case"), show_city, "primary", false, "cuffs")


func show_city() -> void:
	if state.status != "playing":
		show_results()
		return
	screen = "city"
	var c: Dictionary = data.cities[state.current]
	_chrome(loc.t(state.case_def["title"]), false)
	var col := _vbox(body, 10)

	# --- banner
	var banner := CityBanner.new()
	banner.custom_minimum_size = Vector2(0, 130)
	banner.setup(c["lat"], c["lon"])
	col.add_child(banner)
	var bv := VBoxContainer.new()
	bv.set_anchors_preset(Control.PRESET_FULL_RECT)
	bv.offset_left = 22
	bv.offset_top = 8
	bv.add_theme_constant_override("separation", 0)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(bv)
	_title(bv, loc.t(c["name"]), 58, C_PAPER)
	var sub := _hbox(bv, 10)
	_label(sub, loc.t(c["country"]), 18, C_TEXT)
	if state.is_final():
		_chip(sub, loc.s("status_final"), C_RED)
	elif state.on_trail():
		_chip(sub, loc.s("status_trail", {"n": state.stop + 1}), Color("7fbf6f"))
	else:
		_chip(sub, loc.s("status_cold"), C_RED)
	if not last_flight.is_empty():
		var key := "flight_hit" if last_flight["hit"] else "flight_miss"
		_label(bv, loc.s(key, {"city": _city(last_flight["city"]), "km": int(last_flight["km_off"])}), 15, C_BRASS)

	# --- next step
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _style(Color("3a3324"), C_BRASS, 1, 8, 10))
	col.add_child(strip)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	strip.add_child(sh)
	_title(sh, loc.s("next_step"), 22, C_BRASS)
	var stxt := _label(sh, loc.s(_next_step_key(), {"city": _city(state.route()[state.stop])}), 16, C_TEXT)
	stxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stxt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# --- evidence cards
	var cards := _hbox(col, 10)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for spot in CaseState.SPOTS:
		_evidence_card(cards, spot)

	# --- actions
	var bar := _hbox(col, 10)
	_button(bar, loc.s("notebook_btn", {"n": notebook.size()}), show_notebook, "secondary", false, "notebook").custom_minimum_size = Vector2(230, 0)
	_button(bar, loc.s("board"), show_board, "secondary", false, "board").custom_minimum_size = Vector2(250, 0)
	_spacer(bar, false)
	if state.is_final():
		_button(bar, loc.s("arrest"), show_chase, "primary", false, "cuffs").custom_minimum_size = Vector2(300, 0)
	elif state.can_travel():
		_button(bar, loc.s("travel"), show_travel, "primary", false, "globe").custom_minimum_size = Vector2(300, 0)


func _next_step_key() -> String:
	if not state.on_trail():
		return "step_deadend"
	if state.is_final():
		return "step_final_warrant" if state.warrant == "" else "step_final_arrest"
	if state.visited.size() >= 2:
		return "step_travel"
	return "step_investigate"


func _evidence_card(parent: Control, spot: String) -> void:
	var done: bool = state.visited.has(spot)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _style(Color(C_CARD, 0.97), C_BRASS if done else Color("4a525c"), 1, 10, 12))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := _hbox(v, 10)
	head.add_child(_icon(spot, C_BRASS if done else C_TEXT, 34))
	var hv := _vbox(head, 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title(hv, loc.s("spot_" + spot), 22, C_PAPER)
	var q: String = "q_who" if state.is_final() else SPOT_QUESTION[spot]
	_label(hv, loc.s(q), 13, C_BRASS if q == "q_where" else C_WHO)

	if not done:
		_label(v, loc.s("desc_" + spot), 14, C_MUTED)
		var mid := CenterContainer.new()
		mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(mid)
		mid.add_child(_icon(spot, Color(C_TEXT, 0.08), 110))
		_button(v, loc.s("investigate", {"h": CaseState.SPOT_COST[spot]}), _on_spot.bind(spot))
		return

	var clue: Dictionary = state.visited[spot]
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	sc.add_child(inner)
	if clue.get("kind") == "street":
		var img_path = clue["street"].get("image")
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(0, 104)
		frame.add_theme_stylebox_override("panel", _style(Color("111316"), Color("434a52"), 1, 4, 0))
		inner.add_child(frame)
		if img_path != null and ResourceLoader.exists(img_path):
			var tr := TextureRect.new()
			tr.texture = load(img_path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			frame.add_child(tr)
		else:
			var l := Label.new()
			l.text = loc.s("cctv_pending")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.add_theme_color_override("font_color", C_MUTED)
			l.add_theme_font_size_override("font_size", 13)
			frame.add_child(l)
		var osd := Label.new()
		osd.text = " REC  CAM-%02d" % (state.stop + 3)
		osd.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		osd.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		osd.add_theme_color_override("font_color", Color("ff5040"))
		osd.add_theme_font_size_override("font_size", 12)
		frame.add_child(osd)
	var txt := _label(inner, _card_text(clue), 14, C_PAPER, FONT_MONO)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if clue.get("kind") == "street" and clue["street"].has("credit"):
		var cr: Dictionary = clue["street"]["credit"]
		_label(inner, loc.s("photo_credit", {"artist": cr["artist"], "license": cr["license"]}), 11, C_MUTED)
	if clue.get("hint_locked", false):
		_button(v, loc.s("enhance"), _on_enhance)


## Short text shown inside an evidence card.
func _card_text(clue: Dictionary) -> String:
	match clue.get("kind", ""):
		"dest":
			return "«" + loc.t(clue["text"]) + "»"
		"trait":
			var pre: String = loc.s("near_short") + " " if clue.get("near", false) else ""
			return pre + loc.t(clue["text"]) + "\n" + loc.s("about_trait", {"trait": loc.t(data.traits[clue["trait"]]["name"])})
		"street":
			if clue.get("hint_locked", false):
				return loc.s("cctv_locked")
			return loc.s("cctv_note_short", {"hint": loc.t(clue["street"]["hint"])})
		"near":
			return loc.s("near_only")
		_:
			return loc.s("deadend")


## Full line stored in the notebook (prefixed with city and source).
func _clue_text(clue: Dictionary, spot: String) -> String:
	return "%s · %s — %s" % [_city(state.current), loc.s("spot_" + spot), _card_text(clue).replace("\n", " ")]


func _on_spot(spot: String) -> void:
	var clue: Dictionary = state.visit(spot)
	if clue.is_empty():
		show_city()
		return
	var line := _clue_text(clue, spot)
	if not line in notebook:
		notebook.append(line)
		if clue.get("kind") == "trait":
			evidence.append(line)
	show_city()


func _on_enhance() -> void:
	var old := _clue_text(state.visited["cctv"], "cctv")
	var clue: Dictionary = state.enhance_cctv()
	notebook.erase(old)
	var line := _clue_text(clue, "cctv")
	if not line in notebook:
		notebook.append(line)
	show_city()


func show_notebook() -> void:
	screen = "notebook"
	_chrome(loc.s("notebook"), false)
	var row := _hbox(body, 12)
	for which in ["where", "who"]:
		var p := _panel(row)
		(p.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_title(p, loc.s(which + "_header"), 28, C_BRASS if which == "where" else C_WHO)
		var list := _scroll(p)
		var lines: Array = notebook.filter(func(l): return not l in evidence) if which == "where" else evidence
		if lines.is_empty():
			_label(list, loc.s("none_yet"), 15, C_MUTED)
		for line in lines:
			_label(list, "• " + line, 14, C_PAPER, FONT_MONO)
	var side := _side(row, 240)
	_spacer(side)
	_button(side, loc.s("back"), show_city, "primary")


# ======================================================================
# Pin-drop travel
# ======================================================================

func show_travel() -> void:
	screen = "travel"
	_chrome(loc.s("travel"), true)
	var row := _hbox(body, 12)
	var gp := _panel(row, Color("23272c"))
	(gp.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var globe := GlobeView.new()
	globe.name = "TravelGlobe"
	gp.add_child(globe)
	var here: Dictionary = data.cities[state.current]
	globe.focus(here["lat"], here["lon"])
	globe.add_country_labels(data.countries, loc.lang)
	if pin != Vector2.INF:
		globe.set_pin(pin.x, pin.y)

	var side := _side(row, 400)
	_title(side, loc.s("globe_from", {"city": _city(state.current)}), 26, C_PAPER)
	_label(side, loc.s("globe_help"), 14, C_MUTED)
	var sug: Array = state.suggested_countries()
	if not sug.is_empty():
		_label(side, loc.s("analyst"), 14, C_BRASS)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		side.add_child(grid)
		for code in sug:
			var cc: Dictionary = data.countries[code]
			var b := _button(grid, loc.t(cc["name"]), func(): globe.highlight_country(code, cc["lat"], cc["lon"]))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 15)
	var info := _label(side, "", 16, C_PAPER)
	_spacer(side)
	var fly := _button(side, loc.s("fly_here"), _on_fly, "primary", true, "globe")
	_button(side, loc.s("back"), show_city)
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
	var to: Dictionary = data.cities[state.current]
	var globe := body.find_child("TravelGlobe", true, false)
	for b in body.find_children("*", "Button", true, false):
		b.disabled = true
	if globe:
		globe.clear_pin()
		globe.fly(from["lat"], from["lon"], to["lat"], to["lon"])
		await globe.flight_done
		await get_tree().create_timer(0.3).timeout
	flying = false
	show_city()


# ======================================================================
# Corkboard
# ======================================================================

func show_board() -> void:
	screen = "board"
	_chrome(loc.s("board"), false)
	var row := _hbox(body, 12)
	var cork := PanelContainer.new()
	cork.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cork.add_theme_stylebox_override("panel", _style(C_CORK, Color("5a3a20"), 6, 6, 12))
	row.add_child(cork)
	var col := _scroll(cork)
	_label(col, loc.s("cork_title"), 15, C_PAPER)
	var ids := _gang_ids()
	var grid := GridContainer.new()
	grid.columns = 4 if ids.size() > 6 else 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for sid in ids:
		grid.add_child(_suspect_card(sid))

	var side := _side(row, 330)
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", _style(Color("fff3a8"), Color.TRANSPARENT, 0, 4, 12))
	side.add_child(note)
	var nv := VBoxContainer.new()
	note.add_child(nv)
	_label(nv, loc.s("cork_evidence"), 14, C_RED)
	for line in evidence:
		_label(nv, "• " + line, 13, C_INK)
	if evidence.is_empty():
		_label(nv, loc.s("cork_no_evidence"), 13, C_INK)
	var remaining := ids.filter(func(i): return not crossed.get(i, false))
	if state.warrant != "":
		_label(side, loc.s("warrant_for", {"name": data.suspects[state.warrant]["name"]}), 17, C_BRASS)
	if remaining.size() == 1 and state.warrant != remaining[0]:
		_button(side, loc.s("issue_warrant_for", {"name": data.suspects[remaining[0]]["name"]}), func():
			state.issue_warrant(remaining[0])
			show_board(), "primary")
	elif remaining.size() != 1:
		_label(side, loc.s("issue_warrant_hint"), 15, C_MUTED)
	_spacer(side)
	_button(side, loc.s("back"), show_city)


func _gang_ids() -> Array:
	var ids: Array = data.suspects.keys().filter(func(i): return data.suspects[i]["network"] == state.case_def["network"])
	ids.sort()
	return ids


func _suspect_card(sid: String) -> Control:
	var s: Dictionary = data.suspects[sid]
	var is_out: bool = crossed.get(sid, false)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var warranted: bool = sid == state.warrant
	card.add_theme_stylebox_override("panel", _style(C_PAPER, C_RED if warranted else Color("b9ab88"), 3 if warranted else 1, 4, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	card.add_child(v)
	var head := _hbox(v, 6)
	var portrait := SuspectPortrait.new()
	portrait.custom_minimum_size = Vector2(50, 60)
	portrait.setup(s, is_out)
	head.add_child(portrait)
	var nl := _label(head, str(s["name"]), 14, C_INK)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for tid in data.trait_ids:
		var tr: Dictionary = data.traits[tid]
		var val: String = s["traits"][tid]
		_label(v, "%s: %s" % [loc.t(tr["name"]), loc.t(tr["values"][val]["label"])], 12, C_INK)
	if is_out:
		card.modulate = Color(1, 1, 1, 0.5)
	var b := Button.new()
	b.text = loc.s("restore") if is_out else loc.s("cross_out")
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_stylebox_override("normal", _style(Color("3a4047"), Color("59626d"), 1, 6, 4))
	b.pressed.connect(func():
		crossed[sid] = not is_out
		show_board())
	v.add_child(b)
	return card


# ======================================================================
# Chase & results
# ======================================================================

func show_chase() -> void:
	screen = "chase"
	_chrome(loc.s("chase_title"), false)
	var row := _hbox(body, 12)
	var chase := ChaseView.new()
	chase.labels = {"time": loc.s("chase_time"), "gap": loc.s("chase_gap"), "help": ""}
	row.add_child(chase)
	var side := _side(row, 340)
	_title(side, loc.s("chase_title"), 30, C_RED)
	_label(side, loc.s("chase_text", {"city": _city(state.current)}), 17, C_PAPER)
	if state.warrant == "":
		_label(side, loc.s("chase_no_warrant"), 16, C_WHO)
		_button(side, loc.s("board"), show_board)
	_label(side, loc.s("chase_help"), 14, C_MUTED)
	_spacer(side)
	var start_btn := _button(side, loc.s("chase_start"), func(): pass, "primary", false, "cuffs")
	start_btn.pressed.connect(func():
		start_btn.disabled = true
		chase.start())
	chase.finished.connect(func(caught: bool):
		chase_result = "chase_caught" if caught else "chase_escaped"
		state.arrest(caught)
		await get_tree().create_timer(0.8).timeout
		show_results())
	_button(side, loc.s("back"), show_city)


func show_results() -> void:
	screen = "results"
	_chrome(loc.s("results"), true)
	if not recorded:
		recorded = true
		var old_rank: String = loc.t(progress.rank())
		progress.record(state.case_def["id"], state.stars())
		progress.save_file()
		promoted = loc.t(progress.rank()) != old_rank
	var center := CenterContainer.new()
	body.add_child(center)
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(840, 0)
	paper.add_theme_stylebox_override("panel", _style(C_PAPER, Color("b9ab88"), 2, 6, 26))
	center.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	paper.add_child(v)
	var won: bool = state.status == "won"
	var head := _hbox(v, 18)
	var culprit: Dictionary = data.suspects[state.case_def["culprit"]]
	var portrait := SuspectPortrait.new()
	portrait.custom_minimum_size = Vector2(110, 132)
	portrait.setup(culprit, false)
	head.add_child(portrait)
	var hv := _vbox(head, 4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title(hv, loc.s("stamp_won") if won else loc.s("stamp_lost"), 54, C_GREEN if won else C_RED)
	_label(hv, loc.s("won", {"name": culprit["name"]}) if won else loc.s(state.status), 19, C_INK)
	if chase_result != "" and won:
		_label(hv, loc.s(chase_result), 16, C_INK)
	var stars := StarRow.new()
	stars.star_color = Color("b8860b")
	stars.setup(state.stars(), 34)
	v.add_child(stars)
	_label(v, loc.s("stars_rule"), 13, Color("6b5a3a"))
	_label(v, loc.s("summary", {"used": state.hours_used, "budget": state.budget, "misses": state.misses, "km": int(state.avg_precision_km())}), 16, C_INK)
	if promoted:
		_title(v, loc.s("promoted", {"rank": loc.t(progress.rank())}), 30, Color("7a5a2a"))
	_label(v, _rank_line(), 14, Color("6b5a3a"))
	var bh := _hbox(v, 10)
	bh.alignment = BoxContainer.ALIGNMENT_END
	_button(bh, loc.s("menu"), show_menu)
	_button(bh, loc.s("play_again"), _start_case)
	var by := _cases_by_number()
	var nxt = by.get(int(state.case_def["number"]) + 1)
	if won and nxt != null:
		_button(bh, loc.s("next_case", {"title": loc.t(nxt["title"])}), func():
			current_case = nxt["id"]
			_start_case(), "primary")
