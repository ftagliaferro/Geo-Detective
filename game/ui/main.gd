## Game UI. Presentation only: all rules live in res://core (ADR-0002, ADR-0006..0011).
## Layout: top bar · body (each screen builds its own layout) · ad banner · overlay layer
## (clue reveals, cutscenes and action events are shown in the overlay).
extends Control

const GameData = preload("res://core/game_data.gd")
const CaseState = preload("res://core/case_state.gd")
const EscapeState = preload("res://core/escape_state.gd")
const Geo = preload("res://core/geo.gd")
const Loc = preload("res://core/loc.gd")
const Progress = preload("res://core/progress.gd")
const Style = preload("res://ui/style.gd")
const Fx = preload("res://ui/fx.gd")
const GlobeView = preload("res://ui/globe_view.gd")
const ChaseView = preload("res://ui/chase_view.gd")
const SuspectPortrait = preload("res://ui/suspect_portrait.gd")
const IconView = preload("res://ui/icon_view.gd")
const StarRow = preload("res://ui/star_row.gd")
const CityBanner = preload("res://ui/city_banner.gd")
const ClueReveal = preload("res://ui/clue_reveal.gd")
const Cutscene = preload("res://ui/cutscene.gd")
const Minigame = preload("res://ui/minigame.gd")
const Sfx = preload("res://ui/sfx.gd")

const BG_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.973, 0.957, 0.929), vec3(0.925, 0.902, 0.863), uv.y);
	vec2 g = fract(FRAGCOORD.xy / 26.0) - 0.5;
	float dotm = 1.0 - smoothstep(0.04, 0.09, length(g));
	col -= dotm * 0.025;
	COLOR = vec4(col, 1.0);
}
"""

const SPOT_QUESTION := {"wiretap": "q_where", "cctv": "q_where", "contact": "q_where", "money": "q_who"}
const ESC_ICON := {"message": "wiretap", "message2": "contact", "map": "globe", "clean": "notebook", "decoy": "board"}

var data
var loc
var state
var esc
var progress
var current_case := "case_01"
var current_escape := "escape_01"
var notebook: Array = []
var evidence: Array = []
var known_traits: Dictionary = {}   # trait id -> value learned from evidence
var last_flight: Dictionary = {}
var crossed: Dictionary = {}
var pin: Vector2 = Vector2.INF
var chase_result := ""
var recorded := false
var promoted := false
var flying := false
var busy := false
var screen := "menu"
var hours_before := -1

var title_label: Label
var clock_box: PanelContainer
var clock_label: Label
var clock_bar: ProgressBar
var lang_btn: Button
var body: MarginContainer
var ad_bar: PanelContainer
var ad_label: Label
var overlay: Control
var overlay_center: CenterContainer


func _ready() -> void:
	data = GameData.new()
	data.load_all()
	progress = Progress.new()
	progress.load_file()
	loc = Loc.new(data.strings, "es" if OS.get_locale_language() == "es" else "en")
	theme = Style.make_theme()
	var sfx := Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	_build_layout()
	show_menu()


# ======================================================================
# Layout & helpers
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
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 18, 10))
	root.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top.add_child(th)
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 8)
	th.add_child(logo)
	logo.add_child(_icon("globe", Style.CORAL, 28))
	_label(logo, "GEO DETECTIVE", 20, Style.INK, "display")
	var sep := ColorRect.new()
	sep.color = Style.LINE
	sep.custom_minimum_size = Vector2(1, 28)
	th.add_child(sep)
	title_label = _label(th, "", 18, Style.INK2, "display_md")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	clock_box = PanelContainer.new()
	clock_box.add_theme_stylebox_override("panel", Style.pill(Style.SURFACE2, 14, 6, Style.LINE, 1))
	th.add_child(clock_box)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	clock_box.add_child(ch)
	ch.add_child(_icon("clock", Style.CORAL, 22))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	ch.add_child(cv)
	clock_label = _label(cv, "", 15, Style.INK, "ui_bold")
	clock_bar = ProgressBar.new()
	clock_bar.custom_minimum_size = Vector2(150, 6)
	clock_bar.show_percentage = false
	clock_bar.add_theme_stylebox_override("fill", Style.box(Style.CORAL, 4, 0, Color.TRANSPARENT, 0, false))
	clock_bar.add_theme_stylebox_override("background", Style.box(Style.BG2, 4, 0, Color.TRANSPARENT, 0, false))
	cv.add_child(clock_bar)

	var snd := Button.new()
	snd.focus_mode = Control.FOCUS_NONE
	snd.name = "SoundButton"
	snd.pressed.connect(func():
		Sfx.muted = not Sfx.muted
		snd.text = loc.s("sound_off") if Sfx.muted else loc.s("sound_on")
		Sfx.play("click"))
	th.add_child(snd)
	lang_btn = Button.new()
	lang_btn.focus_mode = Control.FOCUS_NONE
	lang_btn.pressed.connect(func():
		loc.toggle()
		_refresh())
	th.add_child(lang_btn)

	body = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	ad_bar = PanelContainer.new()
	ad_bar.custom_minimum_size = Vector2(0, 44)
	ad_bar.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 14, 8, Style.LINE, 1, false))
	ad_label = Label.new()
	ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ad_label.add_theme_color_override("font_color", Style.MUTED)
	ad_label.add_theme_font_size_override("font_size", 14)
	ad_bar.add_child(ad_label)
	root.add_child(ad_bar)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.106, 0.141, 0.2, 0.55)
	overlay.add_child(dim)
	overlay_center = CenterContainer.new()
	overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(overlay_center)


func _show_overlay(node: Control) -> void:
	for c in overlay_center.get_children():
		c.queue_free()
	overlay.visible = true
	overlay_center.add_child(node)
	Sfx.play("pop", -4.0)
	Fx.fade_in(overlay, 0.18)


func _close_overlay() -> void:
	overlay.visible = false
	for c in overlay_center.get_children():
		c.queue_free()


func _clear() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


func _chrome(title: String, show_ad: bool) -> void:
	_clear()
	title_label.text = title
	lang_btn.text = loc.s("lang_button")
	var snd := find_child("SoundButton", true, false) as Button
	if snd:
		snd.text = loc.s("sound_off") if Sfx.muted else loc.s("sound_on")
	clock_box.visible = state != null or esc != null
	if state:
		clock_bar.max_value = state.budget
		clock_bar.value = maxi(0, state.hours_left())
		var fmt: String = loc.s("hours", {"used": "%d", "budget": state.budget})
		if hours_before >= 0 and hours_before != state.hours_used:
			Fx.count(clock_label, hours_before, state.hours_used, fmt)
			Fx.pulse(clock_box, 1)
		else:
			clock_label.text = fmt % state.hours_used
		hours_before = state.hours_used
		if state.hours_left() < state.budget * 0.2:
			clock_label.add_theme_color_override("font_color", Style.ROSE)
			clock_bar.add_theme_stylebox_override("fill", Style.box(Style.ROSE, 4, 0, Color.TRANSPARENT, 0, false))
		else:
			clock_bar.add_theme_stylebox_override("fill", Style.box(Style.CORAL, 4, 0, Color.TRANSPARENT, 0, false))
	elif esc:
		var lead: float = maxf(0.0, esc.lead())
		clock_label.text = loc.s("lead_short", {"h": int(floor(lead))})
		clock_bar.max_value = 30
		clock_bar.value = clampf(lead, 0.0, 30.0)
		clock_label.add_theme_color_override("font_color", _lead_color(lead))
	if not esc and not (state and state.hours_left() < state.budget * 0.2):
		clock_label.add_theme_color_override("font_color", Style.INK)
	ad_bar.visible = show_ad
	ad_label.text = loc.s("ad_placeholder")
	body.modulate.a = 0.0
	body.create_tween().tween_property(body, "modulate:a", 1.0, 0.22)


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
		"escapes": show_escapes()
		"esc_briefing": show_escape_briefing()
		"esc_city": show_escape_city()
		"esc_travel": show_escape_travel()
		"esc_chase": show_escape_chase()
		"esc_results": show_escape_results()


func _label(parent: Control, text: String, size := 17, color := Style.INK, font := "ui") -> Label:
	var l := Label.new()
	l.text = text
	if not (parent is HBoxContainer):
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != "ui":
		l.add_theme_font_override("font", Style.font(font))
	parent.add_child(l)
	return l


func _title(parent: Control, text: String, size := 30, color := Style.INK) -> Label:
	return _label(parent, text, size, color, "display")


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(parent: Control, text: String, cb: Callable, kind := "secondary", disabled := false, icon_kind := "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click", -6.0))
	b.pressed.connect(cb)
	if kind == "primary":
		Style.primary(b)
	elif kind == "dark":
		Style.primary(b, Style.NAVY)
	if icon_kind != "":
		var col: Color = Color.WHITE if kind in ["primary", "dark"] else Style.CORAL
		var ic := _icon(icon_kind, col, 22)
		ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		ic.offset_left = 16
		ic.offset_right = 38
		ic.offset_top = -11
		ic.offset_bottom = 11
		b.add_child(ic)
		b.text = "      " + text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	return b


func _icon(kind: String, color: Color, px := 36.0) -> Control:
	var ic := IconView.new()
	ic.setup(kind, color, px)
	return ic


func _icon_badge(kind: String, color: Color, px := 44.0) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Style.box(Color(color, 0.12), int(px / 2), int(px * 0.18), Color.TRANSPARENT, 0, false))
	p.add_child(_icon(kind, color, px * 0.64))
	return p


func _card(parent: Control, pad := 18, bg := Style.SURFACE, border := Color.TRANSPARENT) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.box(bg, 18, pad, border, 1 if border != Color.TRANSPARENT else 0))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
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
	v.add_theme_constant_override("separation", 14)
	sc.add_child(v)
	return v


func _chip(parent: Control, text: String, color := Style.INK2) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Style.pill(Color(color, 0.12), 12, 5))
	parent.add_child(p)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Style.font("ui_bold"))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color.darkened(0.1))
	p.add_child(l)


func _side(parent: Control, width := 380.0) -> VBoxContainer:
	var v := _card(parent)
	(v.get_parent() as Control).custom_minimum_size = Vector2(width, 0)
	return v


func _spacer(parent: Control, vertical := true) -> void:
	var s := Control.new()
	if vertical:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)


func _stagger(nodes: Array, step := 0.06) -> void:
	await get_tree().process_frame
	for i in range(nodes.size()):
		if is_instance_valid(nodes[i]):
			Fx.pop_in(nodes[i], i * step)


func _city(id: String) -> String:
	return loc.t(data.cities[id]["name"])


func _max_stars() -> int:
	return (data.cases.size() + data.escapes.size()) * 3


func _rank_line() -> String:
	return loc.s("rank_line", {"rank": loc.t(progress.rank()), "stars": progress.total_stars(), "max": _max_stars()})


func _lead_color(h: float) -> Color:
	if h < 6.0:
		return Style.ROSE
	if h < 12.0:
		return Style.GOLD.darkened(0.15)
	return Style.GREEN


func _paper(parent: Control, width := 880.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	p.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 22, 30))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	Fx.pop_in(p)
	return v


## Looping animated banner with the thief (cases / escapes screens).
func _hero_strip(parent: Control, kind: String, caption_key: String) -> void:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 20, 0))
	wrap.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	parent.add_child(wrap)
	var cs := Cutscene.new()
	cs.custom_minimum_size = Vector2(0, 170)
	cs.loop = true
	cs.setup(kind, loc.s(caption_key), kind + "_hero")
	cs.duration = 6.0
	cs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cs._caption_label.visible_ratio = 1.0
	wrap.add_child(cs)


## Play a cutscene in the overlay and wait until it ends (or is skipped).
func _cutscene(kind: String, caption: String, seed_key: String) -> void:
	var cs := Cutscene.new()
	cs.custom_minimum_size = Vector2(980, 460)
	_show_overlay(cs)
	cs.setup(kind, caption, seed_key)
	await cs.finished
	_close_overlay()


# ======================================================================
# Menu, cases, how to play
# ======================================================================

func show_menu() -> void:
	screen = "menu"
	state = null
	esc = null
	hours_before = -1
	_chrome(loc.s("menu_title"), true)
	var row := _hbox(body, 22)
	var left := _vbox(row, 12)
	left.custom_minimum_size = Vector2(500, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	var logo := _hbox(left, 8)
	_title(logo, "Geo Detective", 58, Style.INK)
	var dot := _label(logo, ".", 58, Style.CORAL, "display")
	dot.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label(left, loc.s("tagline"), 17, Style.INK2)
	var rank := _card(left, 14)
	var rh := _hbox(rank, 12)
	rh.add_child(_icon_badge("cuffs", Style.CORAL, 42))
	var rv := _vbox(rh, 0)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(rv, loc.s("your_rank"), 12, Style.MUTED, "ui_bold")
	_title(rv, loc.t(progress.rank()), 24)
	var stars := _label(rh, loc.s("stars_total", {"stars": progress.total_stars(), "max": _max_stars()}), 14, Style.INK2, "ui_bold")
	stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var modes := _hbox(left, 12)
	var det := _card(modes, 16)
	(det.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dh := _hbox(det, 10)
	dh.add_child(_icon_badge("cuffs", Style.CORAL, 38))
	_title(dh, loc.s("mode_detective_name"), 22)
	_label(det, loc.s("mode_detective_desc"), 14, Style.INK2)
	var next := _next_case()
	if next != "":
		_button(det, loc.s("play_detective"), func():
			current_case = next
			_start_case(), "primary")
	_button(det, loc.s("cases"), show_cases)
	var fug := _card(modes, 16)
	(fug.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fh := _hbox(fug, 10)
	fh.add_child(_icon_badge("money", Style.NAVY, 38))
	_title(fh, loc.s("mode_fugitive_name"), 22)
	_label(fug, loc.s("mode_fugitive_desc"), 14, Style.INK2)
	_button(fug, loc.s("play_fugitive"), show_escapes, "dark")
	_button(fug, loc.s("howto"), show_howto)
	_stagger([rank.get_parent(), det.get_parent(), fug.get_parent()])

	var hero := GlobeView.new()
	hero.interactive = false
	hero.auto_spin = 0.18
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hero)
	hero.focus(25.0, -20.0)
	hero.camera.position.z = 3.5
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


func _case_card(parent: Control, title: String, sub: String, meta: String, best: int, unlocked: bool, accent: Color, cb: Callable) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not unlocked
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := Style.box(Style.SURFACE, 18, 0)
	b.add_theme_stylebox_override("normal", st)
	var hv := Style.box(Style.SURFACE, 18, 0, accent, 2)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("disabled", Style.box(Color(Style.SURFACE, 0.55), 18, 0, Color.TRANSPARENT, 0, false))
	b.pressed.connect(func(): Sfx.play("click", -6.0))
	b.pressed.connect(cb)
	parent.add_child(b)
	var stripe := ColorRect.new()
	stripe.color = accent if unlocked else Style.LINE
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_right = 6
	b.add_child(stripe)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_top = 14
	v.offset_right = -16
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	_label(v, sub.to_upper(), 12, accent if unlocked else Style.MUTED, "ui_bold")
	_title(v, title, 22, Style.INK if unlocked else Style.MUTED)
	_label(v, meta, 13, Style.MUTED)
	if unlocked:
		var stars := StarRow.new()
		stars.star_color = Style.GOLD
		stars.setup(best, 20)
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(stars)
	else:
		_label(v, loc.s("locked"), 13, Style.MUTED, "ui_bold")
	return b


const GANG_COLOR := {"paper_saints": Color("2b7fff"), "blue_harbour": Color("1f9d6b"), "zero_signal": Color("0e9f9a"), "velvet_hands": Color("e5484d"), "glass_serpent": Color("ff5a3c")}


func show_cases() -> void:
	screen = "cases"
	state = null
	esc = null
	_chrome(loc.s("cases"), true)
	var col := _scroll(body)
	_hero_strip(col, "plane", "hero_cases")
	_label(col, _rank_line() + "  ·  " + loc.s("cases_help"), 15, Style.INK2)
	var by := _cases_by_number()
	var nums: Array = by.keys()
	nums.sort()
	var row: HBoxContainer
	var last_net := ""
	var cards: Array = []
	for n in nums:
		var cd: Dictionary = by[n]
		if cd["network"] != last_net:
			last_net = cd["network"]
			_title(col, loc.t(cd["network_name"]), 24, Style.INK)
			row = _hbox(col, 14)
		var unlocked: bool = progress.is_unlocked(n, by)
		var meta: String = loc.s("case_meta", {"stops": cd["route"].size()}) + ("  ·  " + loc.s("boss") if n % 3 == 0 else "")
		cards.append(_case_card(row, loc.t(cd["title"]), loc.t(cd["network_name"]), meta, progress.best(cd["id"]), unlocked, GANG_COLOR.get(cd["network"], Style.CORAL), func():
			current_case = cd["id"]
			_start_case()))
	_button(col, loc.s("menu"), show_menu)
	_stagger(cards, 0.03)


func show_howto() -> void:
	screen = "howto"
	state = null
	esc = null
	_chrome(loc.s("howto"), true)
	var col := _scroll(body)
	var icons := ["notebook", "wiretap", "globe", "board", "cuffs", "money"]
	var cards: Array = []
	for i in range(1, 7):
		var p := _card(col)
		var h := _hbox(p, 16)
		h.add_child(_icon_badge(icons[i - 1], Style.CORAL if i < 6 else Style.NAVY, 52))
		var v := _vbox(h, 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_title(v, loc.s("howto_%d_title" % i), 22)
		_label(v, loc.s("howto_%d" % i), 16, Style.INK2)
		cards.append(p.get_parent())
	_button(col, loc.s("menu"), show_menu, "primary")
	_stagger(cards)


# ======================================================================
# Detective mode
# ======================================================================

func _start_case() -> void:
	esc = null
	state = CaseState.new(data, current_case, randi() % 100000 + 1)
	hours_before = -1
	notebook.clear()
	evidence.clear()
	known_traits.clear()
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
	var v := _paper(body)
	var head := _hbox(v, 12)
	var hv := _vbox(head, 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(hv, loc.t(cd["network_name"]).to_upper(), 13, GANG_COLOR.get(cd["network"], Style.CORAL), "ui_bold")
	_title(hv, loc.t(cd["title"]), 40)
	var stamp := _label(head, loc.s("confidential"), 22, Style.CORAL, "display")
	stamp.rotation_degrees = -6
	_wrap(_label(v, loc.t(cd["crime"]), 18, Style.INK2))
	var chips := _hbox(v, 8)
	var arc := int((int(cd["number"]) - 1) / 3) + 1
	_chip(chips, loc.s("chip_difficulty", {"n": arc}), Style.CORAL)
	_chip(chips, loc.s("chip_cities", {"n": cd["route"].size()}), Style.SKY)
	_chip(chips, loc.s("chip_radius", {"km": int(state.radius_km)}), Style.NAVY)
	_chip(chips, loc.s("chip_hours", {"h": state.budget}), Style.GREEN)
	_label(v, loc.s("objective"), 13, Style.MUTED, "ui_bold")
	for i in range(1, 4):
		var r := _hbox(v, 10)
		var num := _label(r, str(i), 15, Color.WHITE, "ui_bold")
		num.custom_minimum_size = Vector2(26, 26)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var nb := StyleBoxFlat.new()
		nb.bg_color = Style.CORAL
		nb.set_corner_radius_all(13)
		num.add_theme_stylebox_override("normal", nb)
		_wrap(_label(r, loc.s("objective_%d" % i), 16, Style.INK))
	var bh := _hbox(v, 10)
	bh.alignment = BoxContainer.ALIGNMENT_END
	_button(bh, loc.s("back"), show_cases)
	_button(bh, loc.s("accept_case"), _accept_case, "primary", false, "cuffs")


func _accept_case() -> void:
	if busy:
		return
	busy = true
	await _cutscene("heist", loc.s("cut_heist", {"city": _city(state.route()[0])}), state.route()[0])
	busy = false
	show_city()


func _banner(parent: Control, city_id: String, height := 136.0) -> VBoxContainer:
	var c: Dictionary = data.cities[city_id]
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 20, 0))
	wrap.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	parent.add_child(wrap)
	var banner := CityBanner.new()
	banner.custom_minimum_size = Vector2(0, height)
	banner.setup(c["lat"], c["lon"], (c.get("street") if c.get("street") else {}).get("image"))
	wrap.add_child(banner)
	var bv := VBoxContainer.new()
	bv.set_anchors_preset(Control.PRESET_FULL_RECT)
	bv.offset_left = 26
	bv.offset_top = 14
	bv.add_theme_constant_override("separation", 2)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(bv)
	_title(bv, loc.t(c["name"]), 50, Style.INK)
	return bv


func show_city() -> void:
	if state.status != "playing":
		show_results()
		return
	screen = "city"
	_chrome(loc.t(state.case_def["title"]), false)
	var col := _vbox(body, 12)
	var c: Dictionary = data.cities[state.current]
	var bv := _banner(col, state.current)
	var sub := _hbox(bv, 10)
	_label(sub, loc.t(c["country"]), 17, Style.INK2, "ui_bold")
	if state.is_final():
		_chip(sub, loc.s("status_final"), Style.ROSE)
	elif state.on_trail():
		_chip(sub, loc.s("status_trail", {"n": state.stop + 1}), Style.GREEN)
	else:
		_chip(sub, loc.s("status_cold"), Style.ROSE)
	if not last_flight.is_empty():
		var key := "flight_hit" if last_flight["hit"] else "flight_miss"
		_label(bv, loc.s(key, {"city": _city(last_flight["city"]), "km": int(last_flight["km_off"])}), 14, Style.INK2)

	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", Style.box(Color("fff4e6"), 14, 12, Color("ffd8b0"), 1, false))
	col.add_child(strip)
	var sh := _hbox(strip, 12)
	sh.add_child(_icon("notebook", Style.CORAL, 22))
	_label(sh, loc.s("next_step"), 15, Style.CORAL, "ui_bold")
	_wrap(_label(sh, loc.s(_next_step_key(), {"city": _city(state.route()[state.stop])}), 15, Style.INK))

	var cards := _hbox(col, 12)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: Array = []
	for spot in CaseState.SPOTS:
		list.append(_evidence_card(cards, spot))

	var bar := _hbox(col, 10)
	_button(bar, loc.s("notebook_btn", {"n": notebook.size()}), show_notebook, "secondary", false, "notebook").custom_minimum_size = Vector2(210, 0)
	_button(bar, loc.s("board"), show_board, "secondary", false, "board").custom_minimum_size = Vector2(210, 0)
	_spacer(bar, false)
	if state.is_final():
		_button(bar, loc.s("arrest"), show_chase, "primary", false, "cuffs").custom_minimum_size = Vector2(300, 0)
	elif state.can_travel():
		_button(bar, loc.s("travel"), show_travel, "primary", false, "globe").custom_minimum_size = Vector2(300, 0)
	_stagger(list, 0.05)


func _next_step_key() -> String:
	if not state.on_trail():
		return "step_deadend"
	if state.is_final():
		return "step_final_warrant" if state.warrant == "" else "step_final_arrest"
	if state.visited.size() >= 2:
		return "step_travel"
	return "step_investigate"


func _evidence_card(parent: Control, spot: String) -> Control:
	var done: bool = state.visited.has(spot)
	var q: String = "q_who" if state.is_final() else SPOT_QUESTION[spot]
	var accent: Color = Style.SKY if q == "q_where" else Style.ROSE
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 18, 16, accent if done else Color.TRANSPARENT, 2 if done else 0))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var head := _hbox(v, 10)
	head.add_child(_icon_badge(spot, accent, 44))
	var hv := _vbox(head, 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title(hv, loc.s("spot_" + spot), 19)
	_label(hv, loc.s(q), 12, accent, "ui_bold")
	if not done:
		_label(v, loc.s("desc_" + spot), 14, Style.INK2)
		_spacer(v)
		var b := _button(v, loc.s("investigate", {"h": CaseState.SPOT_COST[spot]}), _investigate.bind(spot))
		Style.primary(b, accent)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return p
	var clue: Dictionary = state.visited[spot]
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var inner := _vbox(sc, 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if clue.get("kind") == "street":
		var img_path = clue["street"].get("image")
		if img_path != null and ResourceLoader.exists(img_path):
			var frame := PanelContainer.new()
			frame.custom_minimum_size = Vector2(0, 96)
			frame.add_theme_stylebox_override("panel", Style.box(Color("0f1a2b"), 10, 0, Color.TRANSPARENT, 0, false))
			frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			inner.add_child(frame)
			var tr := TextureRect.new()
			tr.texture = load(img_path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			frame.add_child(tr)
	_label(inner, _card_text(clue), 14, Style.INK, "mono")
	if clue.get("hint_locked", false):
		_button(v, loc.s("enhance"), _on_enhance).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


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


func _clue_text(clue: Dictionary, spot: String) -> String:
	return "%s · %s — %s" % [_city(state.current), loc.s("spot_" + spot), _card_text(clue).replace("\n", " ")]


func _reveal_texts(spot: String, clue: Dictionary) -> Dictionary:
	var q: String = "q_who" if (state.is_final() or spot == "money") else "q_where"
	var t := {
		"title": loc.s("spot_" + spot), "subtitle": loc.s(q), "icon": spot,
		"color": Style.ROSE if q == "q_who" else Style.SKY,
		"body": _card_text(clue), "continue": loc.s("reveal_continue"),
		"hint": loc.s("tune_hint"), "status_search": loc.s("tune_search"), "status_close": loc.s("tune_close"),
		"status_locked": loc.s("tune_locked"), "status_locked_bonus": loc.s("tune_locked_bonus"),
		"pending": loc.s("cctv_pending"), "cam": "CAM-%02d" % (state.stop + 3),
		"who": loc.s("contact_who", {"city": _city(state.current)}),
		"receipts": [loc.s("receipt_1"), loc.s("receipt_2"), loc.s("receipt_3")],
	}
	if clue.get("kind") == "street" and clue["street"].has("credit"):
		var cr: Dictionary = clue["street"]["credit"]
		t["credit"] = loc.s("photo_credit", {"artist": cr["artist"], "license": cr["license"]})
	return t


func _investigate(spot: String) -> void:
	if busy or state.visited.has(spot):
		return
	busy = true
	var clue: Dictionary = state.peek(spot)
	var kind := spot if clue.get("kind") != "deadend" else "note"
	if kind == "wiretap" and clue.get("kind") != "dest":
		kind = "note"   # final-city wiretap gives a trait: no tuning needed
	if kind == "cctv" and clue.get("kind") != "street":
		kind = "note"   # final-city camera reports a trait, not a photo
	var rv := ClueReveal.new()
	_show_overlay(rv)
	var img = clue["street"].get("image") if clue.get("kind") == "street" else null
	var portrait := {"id": "contact_" + state.current + str(state.stop), "traits": {}}
	rv.setup(kind, _reveal_texts(spot, clue), img, portrait)
	var bonus: bool = await rv.done
	_close_overlay()
	var got: Dictionary = state.visit(spot, 1 if bonus and spot == "wiretap" else 0)
	if not got.is_empty():
		var line := _clue_text(got, spot)
		if not line in notebook:
			notebook.append(line)
			if got.get("kind") == "trait":
				evidence.append(line)
				known_traits[got["trait"]] = got["value"]
	busy = false
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
	var row := _hbox(body, 14)
	for which in ["where", "who"]:
		var p := _card(row)
		(p.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := _hbox(p, 10)
		h.add_child(_icon_badge("globe" if which == "where" else "board", Style.SKY if which == "where" else Style.ROSE, 40))
		_title(h, loc.s(which + "_header"), 24)
		var list := _scroll(p)
		var lines: Array = notebook.filter(func(l): return not l in evidence) if which == "where" else evidence
		if lines.is_empty():
			_label(list, loc.s("none_yet"), 15, Style.MUTED)
		for line in lines:
			var item := PanelContainer.new()
			item.add_theme_stylebox_override("panel", Style.box(Style.SURFACE2, 12, 12, Style.LINE, 1, false))
			list.add_child(item)
			_label(item, line, 14, Style.INK, "mono")
	var side := _side(row, 240)
	_spacer(side)
	_button(side, loc.s("back"), show_city, "primary")


# ---------------------------------------------------------------- travel

func _globe_screen(title_city: String, help: String, chips: Array, on_back: Callable, on_fly: Callable, pin_ref: String) -> Array:
	var row := _hbox(body, 14)
	var gp := _card(row, 8, Color("eaf4fc"))
	(gp.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var globe := GlobeView.new()
	globe.name = "TravelGlobe"
	gp.add_child(globe)
	var here: Dictionary = data.cities[title_city]
	globe.focus(here["lat"], here["lon"])
	globe.add_country_labels(data.countries, loc.lang)
	var side := _side(row, 400)
	_label(side, loc.s("departing"), 12, Style.MUTED, "ui_bold")
	_title(side, _city(title_city), 30)
	_label(side, help, 14, Style.INK2)
	return [globe, side, here]


func show_travel() -> void:
	screen = "travel"
	_chrome(loc.s("travel"), true)
	var parts := _globe_screen(state.current, loc.s("globe_help"), [], show_city, _on_fly, "pin")
	var globe: Control = parts[0]
	var side: VBoxContainer = parts[1]
	var here: Dictionary = parts[2]
	if pin != Vector2.INF:
		globe.set_pin(pin.x, pin.y)
	var sug: Array = state.suggested_countries()
	if not sug.is_empty():
		_label(side, loc.s("analyst"), 13, Style.CORAL, "ui_bold")
		_country_chips(side, sug, globe)
	var info := _label(side, "", 15, Style.INK, "ui_bold")
	_spacer(side)
	var fly := _button(side, loc.s("fly_here"), _on_fly, "primary", true, "globe")
	_button(side, loc.s("back"), show_city)
	_wire_pin(globe, here, info, fly, false)


func _country_chips(parent: Control, codes: Array, globe: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for code in codes:
		var cc: Dictionary = data.countries[code]
		var b := _button(grid, loc.t(cc["name"]), func(): globe.highlight_country(code, cc["lat"], cc["lon"]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)


func _wire_pin(globe: Control, here: Dictionary, info: Label, fly: Button, fugitive: bool) -> void:
	var update_info := func():
		var p: Vector2 = esc_pin if fugitive else pin
		if p == Vector2.INF:
			info.text = loc.s("pin_none")
			fly.disabled = true
		else:
			var km := Geo.distance_km(here["lat"], here["lon"], p.x, p.y)
			info.text = loc.s("pin_at", {"lat": _fmt_lat(p.x), "lon": _fmt_lon(p.y), "hours": Geo.travel_hours(km)})
			fly.disabled = false
	update_info.call()
	globe.pin_dropped.connect(func(lat: float, lon: float):
		if fugitive:
			esc_pin = Vector2(lat, lon)
		else:
			pin = Vector2(lat, lon)
		update_info.call()
		Fx.pulse(fly, 1))


func _fmt_lat(v: float) -> String:
	return "%.1f°%s" % [absf(v), "N" if v >= 0 else "S"]


func _fmt_lon(v: float) -> String:
	return "%.1f°%s" % [absf(v), "E" if v >= 0 else "W"]


func _animate_flight(from: Dictionary, to: Dictionary) -> void:
	var globe := body.find_child("TravelGlobe", true, false)
	for b in body.find_children("*", "Button", true, false):
		b.disabled = true
	if globe:
		globe.clear_pin()
		Sfx.play("plane", -3.0)
		globe.fly(from["lat"], from["lon"], to["lat"], to["lon"])
		await globe.flight_done
		await get_tree().create_timer(0.25).timeout


const TRAIL_SCENES := ["plane", "car", "rooftop"]


func _on_fly() -> void:
	if pin == Vector2.INF or flying:
		return
	flying = true
	var prev_city: String = state.current
	var from: Dictionary = data.cities[state.current]
	last_flight = state.travel_to_pin(pin.x, pin.y)
	pin = Vector2.INF
	await _animate_flight(from, data.cities[state.current])
	if last_flight.get("hit", false):
		var scene: String = TRAIL_SCENES[state.stop % TRAIL_SCENES.size()]
		await _cutscene(scene, loc.s("cut_trail_" + scene, {"from": _city(prev_city), "city": _city(state.current)}), state.current)
		if state.has_sighting():
			await _sighting()
	flying = false
	show_city()


func _sighting() -> void:
	var mg := Minigame.new()
	_show_overlay(mg)
	mg.setup("sighting", {
		"title": loc.s("sighting_title"), "hint": loc.s("sighting_hint", {"city": _city(state.current)}),
		"status": loc.s("sighting_status"), "win": loc.s("sighting_win", {"h": CaseState.SIGHTING_REFUND}), "lose": loc.s("sighting_lose"),
	})
	var ok: bool = await mg.finished
	_close_overlay()
	state.resolve_sighting(ok)


# ---------------------------------------------------------------- suspects board

func show_board() -> void:
	screen = "board"
	_chrome(loc.s("board"), false)
	var row := _hbox(body, 14)
	var main := _card(row, 16)
	(main.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(main, loc.s("cork_title"), 15, Style.INK2)
	var col := _scroll(main)
	var ids := _gang_ids()
	var grid := GridContainer.new()
	grid.columns = 4 if ids.size() > 6 else 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for sid in ids:
		grid.add_child(_suspect_card(sid))

	var side := _side(row, 330)
	var eh := _hbox(side, 10)
	eh.add_child(_icon_badge("money", Style.ROSE, 36))
	_title(eh, loc.s("cork_evidence_title"), 20)
	for line in evidence:
		var item := PanelContainer.new()
		item.add_theme_stylebox_override("panel", Style.box(Color("fdecec"), 12, 10, Color.TRANSPARENT, 0, false))
		side.add_child(item)
		_label(item, line, 13, Style.INK)
	if evidence.is_empty():
		_label(side, loc.s("cork_no_evidence"), 13, Style.MUTED)
	var remaining := ids.filter(func(i): return not crossed.get(i, false))
	if state.warrant != "":
		_chip(side, loc.s("warrant_for", {"name": data.suspects[state.warrant]["name"]}), Style.GREEN)
	_spacer(side)
	if remaining.size() == 1 and state.warrant != remaining[0]:
		_button(side, loc.s("issue_warrant_for", {"name": data.suspects[remaining[0]]["name"]}), func():
			state.issue_warrant(remaining[0])
			show_board(), "primary")
	elif remaining.size() != 1:
		_label(side, loc.s("issue_warrant_hint"), 14, Style.MUTED)
	_button(side, loc.s("back"), show_city)


func _gang_ids() -> Array:
	var ids: Array = data.suspects.keys().filter(func(i): return data.suspects[i]["network"] == state.case_def["network"])
	ids.sort()
	return ids


func _suspect_card(sid: String) -> Control:
	var s: Dictionary = data.suspects[sid]
	var is_out: bool = crossed.get(sid, false)
	var warranted: bool = sid == state.warrant
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Style.box(Style.SURFACE2 if not is_out else Color("efeae2"), 16, 10, Style.GREEN if warranted else Style.LINE, 2 if warranted else 1, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := _hbox(v, 8)
	var portrait := SuspectPortrait.new()
	portrait.custom_minimum_size = Vector2(52, 62)
	portrait.setup(s, is_out)
	head.add_child(portrait)
	_wrap(_label(head, str(s["name"]), 14, Style.INK if not is_out else Style.MUTED, "ui_bold"))
	for tid in data.trait_ids:
		var tr: Dictionary = data.traits[tid]
		var val: String = s["traits"][tid]
		var r := _hbox(v, 4)
		_label(r, loc.t(tr["name"]) + ":", 11, Style.MUTED)
		var vcol: Color = Style.INK if not is_out else Style.MUTED
		var mark := ""
		if known_traits.has(tid) and not is_out:
			var ok: bool = known_traits[tid] == val
			vcol = Style.GREEN if ok else Style.ROSE
			mark = "  ✓" if ok else "  ✗"
		_label(r, loc.t(tr["values"][val]["label"]) + mark, 11, vcol, "ui_bold")
	var b := Button.new()
	b.text = loc.s("restore") if is_out else loc.s("cross_out")
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func():
		crossed[sid] = not is_out
		show_board())
	v.add_child(b)
	return card


# ---------------------------------------------------------------- chase & results

func show_chase() -> void:
	screen = "chase"
	_chrome(loc.s("chase_title"), false)
	var row := _hbox(body, 14)
	var cw := _card(row, 6)
	(cw.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chase := ChaseView.new()
	chase.labels = {"time": loc.s("chase_time"), "gap": loc.s("chase_gap"), "help": ""}
	cw.add_child(chase)
	var side := _side(row, 340)
	_title(side, loc.s("chase_title"), 28, Style.CORAL)
	_label(side, loc.s("chase_text", {"city": _city(state.current)}), 16, Style.INK)
	if state.warrant == "":
		_label(side, loc.s("chase_no_warrant"), 15, Style.ROSE, "ui_bold")
		_button(side, loc.s("board"), show_board)
	_label(side, loc.s("chase_help"), 14, Style.INK2)
	_spacer(side)
	var start_btn := _button(side, loc.s("chase_start"), func(): pass, "primary", false, "cuffs")
	start_btn.pressed.connect(func():
		start_btn.disabled = true
		chase.start())
	chase.finished.connect(func(caught: bool):
		chase_result = "chase_caught" if caught else "chase_escaped"
		state.arrest(caught)
		await get_tree().create_timer(0.6).timeout
		if state.status == "won":
			await _cutscene("arrest", loc.s("cut_arrest", {"name": data.suspects[state.case_def["culprit"]]["name"]}), state.current)
		show_results())
	_button(side, loc.s("back"), show_city)


func _result_card(won: bool, stamp: String, line1: String, line2: String, stars_n: int, rule: String, summary: String, art: Control, route_pts: Array = [], misses: Array = []) -> VBoxContainer:
	var outer := _hbox(body, 16)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(760, 0)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 22, 28))
	outer.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	Fx.pop_in(pc)
	if not route_pts.is_empty():
		var rc := _card(outer, 10, Color("eaf4fc"))
		var rp := rc.get_parent() as Control
		rp.custom_minimum_size = Vector2(420, 420)
		rp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_label(rc, loc.s("your_route"), 13, Style.NAVY, "ui_bold")
		var g := GlobeView.new()
		g.interactive = false
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rc.add_child(g)
		g.show_route(route_pts, misses)
		Fx.pop_in(rp, 0.15)
	var head := _hbox(v, 20)
	head.add_child(art)
	var hv := _vbox(head, 6)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := _title(hv, stamp, 46, Style.GREEN if won else Style.ROSE)
	_wrap(_label(hv, line1, 17, Style.INK))
	if line2 != "":
		_wrap(_label(hv, line2, 15, Style.INK2))
	var stars := StarRow.new()
	stars.star_color = Style.GOLD
	stars.setup(stars_n, 34)
	v.add_child(stars)
	_label(v, rule, 13, Style.MUTED)
	var sumc := PanelContainer.new()
	sumc.add_theme_stylebox_override("panel", Style.box(Style.SURFACE2, 12, 12, Style.LINE, 1, false))
	v.add_child(sumc)
	_label(sumc, summary, 15, Style.INK, "ui_bold")
	if promoted:
		_title(v, loc.s("promoted", {"rank": loc.t(progress.rank())}), 26, Style.CORAL)
	_label(v, _rank_line(), 13, Style.MUTED)
	Sfx.play("stamp")
	Sfx.play("success" if won else "fail", -2.0)
	var tw := st.create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(Fx.pulse.bind(st, 2))
	return v


func _pts(city_ids: Array) -> Array:
	return city_ids.map(func(id): return Vector2(data.cities[id]["lat"], data.cities[id]["lon"]))


func show_results() -> void:
	screen = "results"
	_chrome(loc.s("results"), true)
	if not recorded:
		recorded = true
		var old_rank: String = loc.t(progress.rank())
		progress.record(state.case_def["id"], state.stars())
		progress.save_file()
		promoted = loc.t(progress.rank()) != old_rank
	var won: bool = state.status == "won"
	var culprit: Dictionary = data.suspects[state.case_def["culprit"]]
	var portrait := SuspectPortrait.new()
	portrait.custom_minimum_size = Vector2(120, 144)
	portrait.setup(culprit, false)
	var v := _result_card(won, loc.s("stamp_won") if won else loc.s("stamp_lost"),
		loc.s("won", {"name": culprit["name"]}) if won else loc.s(state.status),
		loc.s(chase_result) if (chase_result != "" and won) else "", state.stars(), loc.s("stars_rule"),
		loc.s("summary", {"used": state.hours_used, "budget": state.budget, "misses": state.misses, "km": int(state.avg_precision_km())}), portrait,
		_pts(state.route().slice(0, state.stop + 1)))
	var bh := _hbox(v, 10)
	bh.alignment = BoxContainer.ALIGNMENT_END
	_button(bh, loc.s("menu"), show_menu)
	_button(bh, loc.s("play_again"), _start_case)
	var nxt = _cases_by_number().get(int(state.case_def["number"]) + 1)
	if won and nxt != null:
		_button(bh, loc.s("next_case", {"title": loc.t(nxt["title"])}), func():
			current_case = nxt["id"]
			_start_case(), "primary")


# ======================================================================
# Fugitive mode (ADR-0010/0011)
# ======================================================================

var esc_flight: Dictionary = {}
var esc_pin: Vector2 = Vector2.INF


func _escapes_by_number() -> Dictionary:
	var by := {}
	for eid in data.escapes:
		by[int(data.escapes[eid]["number"])] = data.escapes[eid]
	return by


func _escape_unlocked(n: int) -> bool:
	var by := _escapes_by_number()
	return n <= 1 or (by.has(n - 1) and progress.is_solved(by[n - 1]["id"]))


func show_escapes() -> void:
	screen = "escapes"
	state = null
	esc = null
	_chrome(loc.s("play_fugitive"), true)
	var col := _scroll(body)
	_hero_strip(col, "rooftop", "hero_escapes")
	_label(col, loc.s("escapes_help"), 16, Style.INK2)
	var by := _escapes_by_number()
	var nums: Array = by.keys()
	nums.sort()
	var row: HBoxContainer
	var cards: Array = []
	for i in range(nums.size()):
		if i % 3 == 0:
			row = _hbox(col, 14)
		var ed: Dictionary = by[nums[i]]
		var meta: String = loc.s("escape_meta", {"from": _city(ed["route"][0]), "stops": ed["route"].size()})
		cards.append(_case_card(row, loc.t(ed["title"]), loc.t(ed["network_name"]), meta, progress.best(ed["id"]), _escape_unlocked(nums[i]), GANG_COLOR.get(ed["network"], Style.NAVY), func():
			current_escape = ed["id"]
			_start_escape()))
	_button(col, loc.s("menu"), show_menu)
	_stagger(cards, 0.04)


func _start_escape() -> void:
	state = null
	esc = EscapeState.new(data, current_escape, randi() % 100000 + 1)
	esc_flight = {}
	esc_pin = Vector2.INF
	recorded = false
	promoted = false
	chase_result = ""
	show_escape_briefing()


func show_escape_briefing() -> void:
	screen = "esc_briefing"
	var ed: Dictionary = esc.def
	_chrome(loc.s("esc_briefing"), false)
	var v := _paper(body, 900)
	var head := _hbox(v, 12)
	var hv := _vbox(head, 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(hv, loc.t(ed["network_name"]).to_upper(), 13, GANG_COLOR.get(ed["network"], Style.NAVY), "ui_bold")
	_title(hv, loc.t(ed["title"]), 40)
	head.add_child(_icon_badge("money", Style.NAVY, 60))
	_wrap(_label(v, loc.t(ed["heist"]), 18, Style.INK2))
	var chips := _hbox(v, 8)
	_chip(chips, loc.s("chip_cities", {"n": ed["route"].size()}), Style.SKY)
	_chip(chips, loc.s("chip_radius", {"km": int(ed["radius_km"])}), Style.NAVY)
	_chip(chips, loc.s("chip_head_start", {"h": int(ed["head_start"])}), Style.GREEN)
	_chip(chips, loc.s("chip_inspector", {"h": int(ed["inspector_hours"])}), Style.ROSE)
	_label(v, loc.s("objective"), 13, Style.MUTED, "ui_bold")
	for i in range(1, 5):
		var r := _hbox(v, 10)
		r.add_child(_icon_badge(["wiretap", "clock", "board", "globe"][i - 1], Style.NAVY, 30))
		_wrap(_label(r, loc.s("esc_objective_%d" % i), 15, Style.INK))
	var bh := _hbox(v, 10)
	bh.alignment = BoxContainer.ALIGNMENT_END
	_button(bh, loc.s("back"), show_escapes)
	_button(bh, loc.s("start_escape"), _accept_escape, "dark", false, "money")


func _accept_escape() -> void:
	if busy:
		return
	busy = true
	await _cutscene("heist", loc.s("cut_esc_heist", {"city": _city(esc.route()[0])}), esc.route()[0])
	busy = false
	show_escape_city()


func show_escape_city() -> void:
	if esc.status != "playing":
		_after_escape_move()
		return
	screen = "esc_city"
	_chrome(loc.t(esc.def["title"]), false)
	var col := _vbox(body, 12)
	var c: Dictionary = data.cities[esc.current]
	var bv := _banner(col, esc.current, 124)
	var sub := _hbox(bv, 10)
	_label(sub, loc.t(c["country"]), 17, Style.INK2, "ui_bold")
	if esc.on_route():
		_chip(sub, loc.s("esc_status_route", {"n": esc.stop + 1, "total": esc.route().size()}), Style.GREEN)
	else:
		_chip(sub, loc.s("esc_status_wrong"), Style.ROSE)
	if not esc_flight.is_empty():
		_label(bv, loc.s("esc_flight_hit" if esc_flight["hit"] else "esc_flight_miss", {"city": _city(esc_flight["city"])}), 14, Style.INK2)

	var lead: float = esc.lead()
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", Style.box(Color(_lead_color(lead), 0.1), 14, 12, Color(_lead_color(lead), 0.4), 1, false))
	col.add_child(strip)
	var sh := _hbox(strip, 14)
	sh.add_child(_icon("clock", _lead_color(lead), 26))
	_label(sh, loc.s("lead_title"), 15, _lead_color(lead), "ui_bold")
	_title(sh, loc.s("lead_hours", {"h": int(floor(lead))}), 28, _lead_color(lead))
	_wrap(_label(sh, loc.s("lead_explain", {"city": _city(esc.current)}), 14, Style.INK))

	var cards := _hbox(col, 10)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: Array = []
	for action in EscapeState.ACTIONS:
		list.append(_escape_card(cards, action))
	var bar := _hbox(col, 10)
	_button(bar, loc.s("abandon"), show_escapes).custom_minimum_size = Vector2(180, 0)
	_spacer(bar, false)
	_button(bar, loc.s("flee"), show_escape_travel, "dark", false, "globe").custom_minimum_size = Vector2(320, 0)
	_stagger(list, 0.05)


func _escape_card(parent: Control, action: String) -> Control:
	var leg_rev: Dictionary = esc.revealed.get(esc.stop, {})
	var here: Dictionary = esc.path[-1]
	var done := false
	match action:
		"message", "message2", "map":
			done = leg_rev.has(action)
		"clean":
			done = here["clean"]
		"decoy":
			done = here["decoy"]
	var go := action in ["message", "message2", "map"]
	var accent: Color = Style.SKY if go else Style.ROSE
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 18, 14, accent if done else Color.TRANSPARENT, 2 if done else 0))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var badge := _icon_badge(ESC_ICON[action], accent, 42)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(badge)
	_title(v, loc.s("esc_" + action), 18)
	_label(v, loc.s("q_go" if go else "q_slow"), 11, accent, "ui_bold")
	if done:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sc)
		var l := _label(sc, _escape_text(action, leg_rev), 13, Style.INK, "mono")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return p
	var desc: String = loc.s("esc_desc_" + action)
	if action == "decoy":
		desc += " " + loc.s("esc_decoys_left", {"n": esc.decoys_left})
	_label(v, desc, 13, Style.INK2)
	_spacer(v)
	var b := _button(v, loc.s("esc_do", {"h": EscapeState.COST[action]}), _escape_act.bind(action), "secondary", not esc.can_act(action))
	Style.primary(b, accent)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _escape_text(action: String, leg_rev: Dictionary) -> String:
	match action:
		"message", "message2":
			return "«" + loc.t(leg_rev[action]["text"]) + "»"
		"map":
			var names: Array = []
			for code in leg_rev["map"]["countries"]:
				names.append(loc.t(data.countries[code]["name"]))
			return loc.s("esc_map_done", {"list": ", ".join(names)})
		"clean":
			return loc.s("esc_clean_done", {"h": EscapeState.CLEAN_BONUS})
		"decoy":
			return loc.s("esc_decoy_done", {"h": EscapeState.DECOY_BONUS})
	return ""


func _escape_act(action: String) -> void:
	if busy or not esc.can_act(action):
		return
	busy = true
	var preview: Dictionary = {}
	if action in ["message", "message2", "map"]:
		preview = {action: esc.leg_info[esc.stop][action]}
	var rv := ClueReveal.new()
	_show_overlay(rv)
	var texts := {
		"title": loc.s("esc_" + action), "subtitle": loc.s("q_go" if action in ["message", "message2", "map"] else "q_slow"),
		"icon": ESC_ICON[action], "color": Style.SKY if action in ["message", "message2", "map"] else Style.ROSE,
		"body": _escape_text(action, preview) if not preview.is_empty() else _escape_text(action, {}),
		"continue": loc.s("reveal_continue"), "who": loc.s("boss_who"),
	}
	rv.setup("message" if action in ["message", "message2"] else "note", texts)
	await rv.done
	_close_overlay()
	esc.act(action)
	busy = false
	show_escape_city()


func show_escape_travel() -> void:
	screen = "esc_travel"
	_chrome(loc.s("flee"), true)
	var parts := _globe_screen(esc.current, loc.s("esc_globe_help"), [], show_escape_city, _on_escape_fly, "esc")
	var globe: Control = parts[0]
	var side: VBoxContainer = parts[1]
	var here: Dictionary = parts[2]
	if esc_pin != Vector2.INF:
		globe.set_pin(esc_pin.x, esc_pin.y)
	var leg_rev: Dictionary = esc.revealed.get(esc.stop, {})
	for m in ["message", "message2"]:
		if leg_rev.has(m):
			var item := PanelContainer.new()
			item.add_theme_stylebox_override("panel", Style.box(Color("eef4ff"), 12, 10, Color.TRANSPARENT, 0, false))
			side.add_child(item)
			_label(item, "«" + loc.t(leg_rev[m]["text"]) + "»", 13, Style.INK, "mono")
	if leg_rev.has("map"):
		_label(side, loc.s("esc_map_title"), 13, Style.NAVY, "ui_bold")
		_country_chips(side, leg_rev["map"]["countries"], globe)
	else:
		_label(side, loc.s("esc_no_map"), 13, Style.MUTED)
	var info := _label(side, "", 15, Style.INK, "ui_bold")
	_spacer(side)
	var fly := _button(side, loc.s("fly_here"), _on_escape_fly, "dark", true, "globe")
	_button(side, loc.s("back"), show_escape_city)
	_wire_pin(globe, here, info, fly, true)


func _on_escape_fly() -> void:
	if esc_pin == Vector2.INF or flying:
		return
	flying = true
	var from: Dictionary = data.cities[esc.current]
	esc_flight = esc.travel_to_pin(esc_pin.x, esc_pin.y)
	esc_pin = Vector2.INF
	await _animate_flight(from, data.cities[esc.current])
	if esc.status != "caught":
		await _cutscene("plane" if esc_flight.get("hit", false) else "car", loc.s("cut_esc_flee" if esc_flight.get("hit", false) else "cut_esc_wrong", {"city": _city(esc.current)}), esc.current)
	if esc.status == "playing" and esc.has_checkpoint():
		var mg := Minigame.new()
		_show_overlay(mg)
		mg.setup("checkpoint", {
			"title": loc.s("checkpoint_title"), "hint": loc.s("checkpoint_hint", {"city": _city(esc.current)}),
			"action": loc.s("checkpoint_action"), "status": loc.s("checkpoint_status"),
			"win": loc.s("checkpoint_win"), "lose": loc.s("checkpoint_lose", {"h": EscapeState.CHECKPOINT_DELAY}),
		})
		var ok: bool = await mg.finished
		_close_overlay()
		esc.resolve_checkpoint(ok)
	flying = false
	_after_escape_move()


func _after_escape_move() -> void:
	match esc.status:
		"playing": show_escape_city()
		"chase": show_escape_chase()
		_:
			if not busy:
				busy = true
				if esc.status == "escaped":
					await _cutscene("safehouse", loc.s("cut_safehouse", {"city": _city(esc.current)}), esc.current)
				else:
					await _cutscene("arrest", loc.s("cut_esc_arrest", {"city": _city(esc.current)}), esc.current)
				busy = false
			show_escape_results()


func show_escape_chase() -> void:
	screen = "esc_chase"
	_chrome(loc.s("esc_chase_title"), false)
	var row := _hbox(body, 14)
	var cw := _card(row, 6)
	(cw.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chase := ChaseView.new()
	chase.labels = {"time": loc.s("chase_time"), "gap": loc.s("esc_chase_gap"), "help": ""}
	cw.add_child(chase)
	chase.set_escape_mode()
	var side := _side(row, 340)
	_title(side, loc.s("esc_chase_title"), 28, Style.ROSE)
	_label(side, loc.s("esc_chase_text", {"city": _city(esc.current), "h": int(floor(maxf(0.0, esc.lead())))}), 16, Style.INK)
	_label(side, loc.s("esc_chase_help"), 14, Style.INK2)
	_spacer(side)
	var start_btn := _button(side, loc.s("esc_chase_start"), func(): pass, "dark", false, "money")
	start_btn.pressed.connect(func():
		start_btn.disabled = true
		chase.start())
	chase.finished.connect(func(ok: bool):
		chase_result = "esc_chase_won" if ok else "esc_chase_lost"
		esc.finish_chase(ok)
		await get_tree().create_timer(0.6).timeout
		_after_escape_move())


func show_escape_results() -> void:
	screen = "esc_results"
	_chrome(loc.s("results"), true)
	if not recorded:
		recorded = true
		var old_rank: String = loc.t(progress.rank())
		progress.record(esc.def["id"], esc.stars())
		progress.save_file()
		promoted = loc.t(progress.rank()) != old_rank
	var won: bool = esc.status == "escaped"
	var art := _icon_badge("money" if won else "cuffs", Style.GREEN if won else Style.ROSE, 120)
	var v := _result_card(won, loc.s("esc_stamp_won") if won else loc.s("esc_stamp_lost"),
		loc.s("esc_won_text" if won else "esc_lost_text", {"city": _city(esc.current)}),
		loc.s(chase_result) if chase_result != "" else "", esc.stars(), loc.s("esc_stars_rule", {"h": int(EscapeState.COMFORT_LEAD)}),
		loc.s("esc_summary", {"h": int(floor(maxf(0.0, esc.lead()))), "wrong": esc.wrong_flights, "hours": esc.now}), art,
		_pts(esc.path.filter(func(e): return e["on_route"]).map(func(e): return e["city"])),
		_pts(esc.path.filter(func(e): return not e["on_route"]).map(func(e): return e["city"])))
	var bh := _hbox(v, 10)
	bh.alignment = BoxContainer.ALIGNMENT_END
	_button(bh, loc.s("menu"), show_menu)
	_button(bh, loc.s("play_again"), _start_escape)
	var nxt = _escapes_by_number().get(int(esc.def["number"]) + 1)
	if won and nxt != null:
		_button(bh, loc.s("next_case", {"title": loc.t(nxt["title"])}), func():
			current_escape = nxt["id"]
			_start_escape(), "dark")
