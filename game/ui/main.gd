## Vertical-slice UI. Presentation only: all rules live in res://core (ADR-0002).
## Placeholder visuals — the 3D globe, art and the arcade chase come in later phases.
extends Control

const GameData = preload("res://core/game_data.gd")
const CaseState = preload("res://core/case_state.gd")
const Deduction = preload("res://core/deduction.gd")
const Loc = preload("res://core/loc.gd")

const C_BG := Color("0b0d16")
const C_PANEL := Color("12152a")
const C_PINK := Color("ff3d7f")
const C_CYAN := Color("31e1f7")
const C_TEXT := Color("ece9e4")
const C_MUTED := Color("8a90a8")
const C_PAPER := Color("e9dfc6")

var data
var loc
var state
var current_case := "case_01"
var notebook: Array = []
var last_clue: Dictionary = {}
var board_sel: Dictionary = {}

var title_label: Label
var clock_label: Label
var content: VBoxContainer
var actions: VBoxContainer
var ad_bar: PanelContainer
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
	var lang_btn := Button.new()
	lang_btn.name = "LangButton"
	lang_btn.pressed.connect(func():
		loc.toggle()
		_refresh())
	top.add_child(lang_btn)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	root.add_child(mid)

	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	mid.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	mid.add_child(right)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	right.add_child(actions)

	ad_bar = PanelContainer.new()
	ad_bar.custom_minimum_size = Vector2(0, 50)
	var ad_label := Label.new()
	ad_label.name = "AdLabel"
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


func _button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	actions.add_child(b)
	return b


func _chrome(title: String, show_ad: bool) -> void:
	_clear()
	title_label.text = title
	(find_child("LangButton", true, false) as Button).text = loc.s("lang_button")
	clock_label.text = loc.s("hours", {"used": state.hours_used, "budget": state.budget}) if state else ""
	ad_bar.visible = show_ad
	(ad_bar.get_node("AdLabel") as Label).text = loc.s("ad_placeholder")


func _refresh() -> void:
	match screen:
		"menu": show_menu()
		"briefing": show_briefing()
		"city": show_city()
		"travel": show_travel()
		"board": show_board()
		"chase": show_chase()
		"results": show_results()


func _city_name(id: String) -> String:
	var c: Dictionary = data.cities[id]
	return "%s, %s" % [loc.t(c["name"]), loc.t(c["country"])]


# ---------- screens ----------

func show_menu() -> void:
	screen = "menu"
	state = null
	_chrome(loc.s("game_title"), true)
	_label(content, loc.s("tagline"), 26, C_CYAN)
	_label(content, "Vertical slice — placeholder art", 16, C_MUTED)
	_button(loc.s("play_case", {"title": loc.t(data.cases[current_case]["title"])}), _start_case)


func _start_case() -> void:
	state = CaseState.new(data, current_case, randi() % 100000 + 1)
	notebook.clear()
	last_clue = {}
	board_sel = {}
	show_briefing()


func show_briefing() -> void:
	screen = "briefing"
	var cd: Dictionary = state.case_def
	_chrome(loc.s("briefing"), false)
	_label(content, loc.t(cd["title"]), 28, C_PINK)
	_label(content, loc.t(cd["crime"]), 22, C_PAPER)
	_label(content, loc.s("budget_info", {"hours": state.budget}), 20, C_CYAN)
	_button(loc.s("start"), show_city)


func show_city() -> void:
	if state.status != "playing":
		show_results()
		return
	screen = "city"
	_chrome(loc.t(data.cities[state.current]["name"]), false)
	var c: Dictionary = data.cities[state.current]
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
	if not state.travel_options().is_empty():
		_button(loc.s("travel"), show_travel)
	_button(loc.s("board"), show_board)
	if state.is_final():
		_button(loc.s("arrest"), show_chase)


func _on_spot(spot: String) -> void:
	var clue: Dictionary = state.visit(spot)
	if clue.is_empty():
		show_city()
		return
	var already := false
	for n in notebook:
		if n == _clue_text(clue):
			already = true
	if not already:
		notebook.append(_clue_text(clue))
	last_clue = clue
	show_city()


func _clue_text(clue: Dictionary) -> String:
	var city: String = loc.t(data.cities[state.current]["name"])
	match clue.get("kind", ""):
		"dest":
			return city + " — " + loc.s("witness_says", {"text": loc.t(clue["text"])})
		"trait":
			var pre: String = loc.s("near_prefix") if clue.get("near", false) else ""
			return city + " — " + pre + loc.s("informant_says", {"text": loc.t(clue["text"])})
		"street":
			return city + " — " + loc.s("street_hint", {"hint": loc.t(clue["street"]["hint"])})
		"near":
			return city + " — " + loc.s("near_only")
		_:
			return city + " — " + loc.s("deadend")


func _render_clue(clue: Dictionary) -> void:
	if clue.get("kind") == "street":
		_label(content, loc.s("street_title"), 18, C_PINK)
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(0, 200)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1d2440")
		sb.border_color = C_PAPER
		sb.set_border_width_all(6)
		frame.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = loc.s("street_pending")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", C_MUTED)
		frame.add_child(l)
		content.add_child(frame)
	_label(content, _clue_text(clue), 22, C_TEXT)


func show_travel() -> void:
	screen = "travel"
	_chrome(loc.s("travel"), true)
	_label(content, loc.s("choose_destination", {"city": loc.t(data.cities[state.current]["name"])}), 22, C_CYAN)
	for id in state.travel_options():
		_button("%s  —  %d h" % [_city_name(id), state.travel_cost(id)], _on_travel.bind(id))
	_button(loc.s("back"), show_city)


func _on_travel(id: String) -> void:
	state.travel(id)
	last_clue = {}
	show_city()


func show_board() -> void:
	screen = "board"
	_chrome(loc.s("board"), false)
	_label(content, loc.s("board_title"), 22, C_CYAN)
	for tid in data.trait_ids:
		var tr: Dictionary = data.traits[tid]
		var row := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = loc.t(tr["name"])
		name_l.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_l)
		var ob := OptionButton.new()
		ob.add_item(loc.s("unknown"))
		var selected_idx := 0
		var i := 1
		for vid in tr["order"]:
			ob.add_item(loc.t(tr["values"][vid]["label"]))
			if board_sel.get(tid, "") == vid:
				selected_idx = i
			i += 1
		ob.select(selected_idx)
		ob.item_selected.connect(_on_board_select.bind(tid))
		row.add_child(ob)
		content.add_child(row)

	var matches: Array = Deduction.matching(data.suspects, board_sel)
	_label(content, loc.s("matches", {"n": matches.size()}), 20, C_PINK)
	for sid in matches:
		_label(content, "• " + str(data.suspects[sid]["name"]), 20, C_PAPER)
	if state.warrant != "":
		_label(content, loc.s("warrant_for", {"name": data.suspects[state.warrant]["name"]}), 20, C_CYAN)
	else:
		_label(content, loc.s("no_warrant"), 18, C_MUTED)

	_button(loc.s("issue_warrant"), _on_warrant.bind(matches), matches.size() != 1)
	_button(loc.s("back"), show_city)


func _on_board_select(idx: int, tid: String) -> void:
	if idx == 0:
		board_sel.erase(tid)
	else:
		board_sel[tid] = data.traits[tid]["order"][idx - 1]
	show_board()


func _on_warrant(matches: Array) -> void:
	if matches.size() == 1:
		state.issue_warrant(matches[0])
	show_board()


func show_chase() -> void:
	screen = "chase"
	_chrome(loc.s("chase_title"), false)
	_label(content, loc.s("chase_text", {"city": loc.t(data.cities[state.current]["name"])}), 24, C_PAPER)
	if state.warrant == "":
		_label(content, loc.s("chase_no_warrant"), 20, C_PINK)
		_button(loc.s("board"), show_board)
	_button(loc.s("catch"), func():
		state.arrest()
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
	_label(content, loc.s("stars", {"stars": state.stars()}), 24, C_PAPER)
	_label(content, loc.s("summary", {"used": state.hours_used, "budget": state.budget, "wrong": state.wrong_trips}), 20, C_TEXT)
	_button(loc.s("play_again"), _start_case)
	_button(loc.s("menu"), show_menu)
