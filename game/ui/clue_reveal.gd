## Interactive reveal for a piece of evidence, shown in an overlay card.
## Kinds: wiretap (tuning mini-game, fast = bonus), cctv (scan & zoom), contact
## (portrait + speech bubble), money (receipts flip), message (phone chat), note.
## Emits `done(bonus)` when the player closes it. Call setup() after adding it to the tree.
extends PanelContainer

signal done(bonus: bool)

const Style = preload("res://ui/style.gd")
const Fx = preload("res://ui/fx.gd")
const SuspectPortrait = preload("res://ui/suspect_portrait.gd")
const IconView = preload("res://ui/icon_view.gd")
const Sfx = preload("res://ui/sfx.gd")

const TUNE_TIME := 7.0
const TUNE_TOL := 5.0
const TUNE_HOLD := 0.5

var kind := "note"
var narrow := false      # phone layout: fit ~360 px, stack wide rows
var short := false       # landscape phone: shorter pictures so the card fits
var _width := 640.0
var texts := {}          # title, subtitle, body, credit, status_search, status_locked, bonus, continue, ...
var image_path = null
var portrait_data := {}
var bonus := false

var _col: VBoxContainer
var _body: Label
var _wave: Control
var _slider: HSlider
var _status: Label
var _timer_bar: ProgressBar
var _target := 0.0
var _hold := 0.0
var _elapsed := 0.0
var _locked := false
var _phase := 0.0
var _continue: Button
var _scan: Control
var _scan_t := 0.0
## Second interactive variant per source (ADR-0012): voice, focus, interrogate, order.
var variant := ""
var _game_over := false
var _rng := RandomNumberGenerator.new()
# voice match
var _voice_target := 0
var _voice_shapes: Array = []
var _voice_mistake := false
# focus
var _photo: TextureRect
var _focus_mat: ShaderMaterial
# interrogation
var _round := 0
var _good := 0
var _mood := ""
var _round_box: VBoxContainer
# order receipts
var _order_next := 0
var _order_btns: Array = []
var _order_mistake := false
const GAME_TIME := 8.0
const FOCUS_SHADER := """
shader_type canvas_item;
uniform float cells = 12.0;
void fragment() {
	vec2 g = floor(UV * cells) / cells + 0.5 / cells;
	COLOR = texture(TEXTURE, cells > 400.0 ? UV : g);
}
"""


func setup(p_kind: String, p_texts: Dictionary, p_image = null, p_portrait := {}, p_variant := "") -> void:
	kind = p_kind
	variant = p_variant
	_rng.randomize()
	texts = p_texts
	image_path = p_image
	portrait_data = p_portrait
	var vp := _screen_size()
	var vp_w: float = vp.x
	narrow = vp_w < 600.0
	short = vp.y < 520.0
	_width = minf(640.0, vp_w - 16.0) if narrow else 640.0
	custom_minimum_size = Vector2(_width, 0)
	add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 22, 16 if narrow else 26))
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	add_child(_col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_col.add_child(head)
	var ic := IconView.new()
	ic.setup(texts.get("icon", "wiretap"), texts.get("color", Style.SKY), 34)
	head.add_child(ic)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	_text(hv, texts.get("title", ""), "display", 26, Style.INK)
	_text(hv, texts.get("subtitle", ""), "ui_bold", 13, texts.get("color", Style.SKY))

	match [kind, variant]:
		["wiretap", "voice"]: _build_voice()
		["cctv", "focus"]: _build_focus()
		["contact", "interrogate"]: _build_interrogate()
		["money", "order"]: _build_order()
		_:
			variant = ""
			match kind:
				"wiretap": _build_wiretap()
				"cctv": _build_cctv()
				"contact": _build_contact()
				"money": _build_money()
				"message": _build_message()
				_: _build_note()

	_continue = Button.new()
	_continue.text = texts.get("continue", "OK")
	_continue.focus_mode = Control.FOCUS_NONE
	Style.primary(_continue)
	_continue.pressed.connect(func(): done.emit(bonus))
	_continue.visible = kind != "wiretap" and variant == ""
	_col.add_child(_continue)


func _text(parent: Control, s: String, f: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Style.font(f))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _body_label(parent: Control, delay := 0.0) -> Label:
	_body = _text(parent, texts.get("body", ""), "mono", 17, Style.INK)
	_body.visible_ratio = 0.0
	if delay >= 0.0:
		(Engine.get_main_loop() as SceneTree).create_timer(delay).timeout.connect(_type_body)
	return _body


# ----------------------------------------------------------- wiretap (mini-game)

func _build_wiretap() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_target = rng.randf_range(15.0, 85.0)
	_text(_col, texts.get("hint", ""), "ui", 15, Style.INK2)
	_wave = Control.new()
	_wave.custom_minimum_size = Vector2(0, 80 if short else 120)
	_wave.draw.connect(_draw_wave)
	_col.add_child(_wave)
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = 100
	_slider.step = 0.5
	_slider.value = 50.0 if absf(_target - 50.0) > 20.0 else 5.0
	_slider.custom_minimum_size = Vector2(0, 44 if narrow else 28)
	_col.add_child(_slider)
	Sfx.play("static", -10.0)
	_slider.value_changed.connect(func(_v):
		if not _locked and randf() < 0.12:
			Sfx.play("static", -14.0, randf_range(0.8, 1.3)))
	var row := HBoxContainer.new()
	_col.add_child(row)
	_status = _text(row, texts.get("status_search", ""), "ui_bold", 15, Style.INK2)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(90 if narrow else 160, 10)
	_timer_bar.show_percentage = false
	_timer_bar.max_value = TUNE_TIME
	_timer_bar.value = TUNE_TIME
	_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_bar.add_theme_stylebox_override("fill", Style.box(Style.GOLD, 6, 0, Color.TRANSPARENT, 0, false))
	_timer_bar.add_theme_stylebox_override("background", Style.box(Style.BG2, 6, 0, Color.TRANSPARENT, 0, false))
	row.add_child(_timer_bar)
	_body_label(_col, -1.0)


func _draw_wave() -> void:
	var w := _wave.size.x
	var h := _wave.size.y
	_wave.draw_rect(Rect2(Vector2.ZERO, _wave.size), Color("0f1a2b"))
	for i in range(1, 6):
		_wave.draw_line(Vector2(w * i / 6.0, 0), Vector2(w * i / 6.0, h), Color(1, 1, 1, 0.05))
	var f_target := 2.0 + _target / 12.0
	var f_now := 2.0 + (_slider.value if _slider else 50.0) / 12.0
	var pts_t := PackedVector2Array()
	var pts_n := PackedVector2Array()
	var noise := 0.0 if _locked else clampf(absf(f_now - f_target) / 4.0, 0.0, 1.0)
	for i in range(0, 121):
		var x := w * i / 120.0
		var a := float(i) / 120.0 * TAU
		pts_t.append(Vector2(x, h / 2.0 + sin(a * f_target + _phase) * h * 0.3))
		var jitter := sin(a * 37.0 + _phase * 3.0) * h * 0.12 * noise
		pts_n.append(Vector2(x, h / 2.0 + sin(a * f_now + _phase) * h * 0.3 + jitter))
	_wave.draw_polyline(pts_t, Color(1, 1, 1, 0.22), 2.0, true)
	_wave.draw_polyline(pts_n, Style.GREEN.lightened(0.2) if _locked else Style.SKY.lightened(0.25), 3.0, true)


func _process(delta: float) -> void:
	if kind == "wiretap" and not _locked and _slider:
		_elapsed += delta
		_phase += delta * 4.0
		_timer_bar.value = maxf(0.0, TUNE_TIME - _elapsed)
		if absf(_slider.value - _target) <= TUNE_TOL:
			_hold += delta
			_status.text = texts.get("status_close", "")
			if _hold >= TUNE_HOLD:
				_lock(_elapsed <= TUNE_TIME)
		else:
			_hold = 0.0
			_status.text = texts.get("status_search", "")
			if _elapsed > TUNE_TIME:
				_lock(false)
		_wave.queue_redraw()
	elif kind == "wiretap" and _locked:
		_phase += delta * 4.0
		_wave.queue_redraw()
	if kind == "cctv" and _scan:
		_scan_t += delta
		_scan.queue_redraw()
	if variant != "" and not _game_over:
		_elapsed += delta
		if _timer_bar:
			_timer_bar.value = maxf(0.0, GAME_TIME - _elapsed)
		if variant == "focus" and _slider:
			var err := absf(_slider.value - _target) / 100.0
			_focus_mat.set_shader_parameter("cells", lerpf(10.0, 160.0, clampf(1.0 - err * 2.5, 0.0, 1.0)))
			if err <= 0.05:
				_hold += delta
				if _hold >= TUNE_HOLD:
					_win_game(_elapsed <= GAME_TIME)
			else:
				_hold = 0.0


func _lock(fast: bool) -> void:
	_locked = true
	Sfx.play("lock")
	bonus = fast
	_slider.value = _target
	_slider.editable = false
	_status.text = texts.get("status_locked_bonus" if fast else "status_locked", "")
	_status.add_theme_color_override("font_color", Style.GREEN if fast else Style.INK2)
	_timer_bar.visible = false
	Fx.type_in(_body)
	_continue.visible = true
	Fx.pop_in(_continue, 0.3)


## Test hook: lock the tuner as if the player matched the signal in time.
func debug_solve() -> void:
	if variant != "":
		if not _game_over:
			_win_game(true)
		return
	if kind == "wiretap" and not _locked:
		_slider.value = _target
		_lock(true)


# ----------------------------------------------------------- cctv

func _build_cctv() -> void:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 170 if short else 300)
	frame.add_theme_stylebox_override("panel", Style.box(Color("0f1a2b"), 14, 0, Color.TRANSPARENT, 0, false))
	frame.clip_contents = true
	_col.add_child(frame)
	if image_path != null and ResourceLoader.exists(image_path):
		var tr := TextureRect.new()
		tr.texture = load(image_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.add_child(tr)
		tr.pivot_offset = Vector2((_width - (32.0 if narrow else 52.0)) / 2.0, 85 if short else 150)
		tr.scale = Vector2(1.35, 1.35)
		tr.create_tween().tween_property(tr, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		var l := Label.new()
		l.text = texts.get("pending", "")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		frame.add_child(l)
	Sfx.play("shutter")
	_scan = Control.new()
	_scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scan.draw.connect(func():
		var y := fmod(_scan_t * 220.0, _scan.size.y + 40.0) - 20.0
		if _scan_t < 1.8:
			_scan.draw_rect(Rect2(0, y, _scan.size.x, 3), Color(0.5, 1, 0.7, 0.8))
			_scan.draw_rect(Rect2(0, y - 30, _scan.size.x, 30), Color(0.5, 1, 0.7, 0.08))
		if fmod(_scan_t, 1.0) < 0.6:
			_scan.draw_circle(Vector2(18, 18), 6, Color("ff3b30"))
		_scan.draw_string(Style.font("mono"), Vector2(30, 24), "REC  " + str(texts.get("cam", "CAM-03")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		var c := Color(1, 1, 1, 0.7)
		for corner in [Vector2(10, 10), Vector2(_scan.size.x - 10, 10), Vector2(10, _scan.size.y - 10), Vector2(_scan.size.x - 10, _scan.size.y - 10)]:
			var sx := 1.0 if corner.x < 50 else -1.0
			var sy := 1.0 if corner.y < 50 else -1.0
			_scan.draw_line(corner, corner + Vector2(24 * sx, 0), c, 2)
			_scan.draw_line(corner, corner + Vector2(0, 24 * sy), c, 2))
	frame.add_child(_scan)
	if texts.get("credit", "") != "":
		_text(_col, texts["credit"], "ui", 11, Style.MUTED)
	_body_label(_col, 1.4)


# ----------------------------------------------------------- contact

func _build_contact() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_col.add_child(row)
	var portrait := SuspectPortrait.new()
	portrait.custom_minimum_size = Vector2(120, 144)
	portrait.setup(portrait_data, false)
	row.add_child(portrait)
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", Style.box(Style.SURFACE2, 16, 18, Style.LINE, 1, false))
	row.add_child(bubble)
	var bv := VBoxContainer.new()
	bubble.add_child(bv)
	_text(bv, texts.get("who", ""), "ui_bold", 13, Style.MUTED)
	_body_label(bv, 0.5)
	Fx.pop_in(portrait, 0.0)


# ----------------------------------------------------------- money

func _build_money() -> void:
	var row: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if narrow else 10)
	_col.add_child(row)
	var labels: Array = texts.get("receipts", ["", "", ""])
	for i in range(3):
		var r := PanelContainer.new()
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.custom_minimum_size = Vector2(0, 0 if narrow else 92)
		r.add_theme_stylebox_override("panel", Style.box(Color("fffaf0"), 10, 12, Style.LINE, 1, false))
		row.add_child(r)
		var v := VBoxContainer.new()
		r.add_child(v)
		_text(v, "#%04d" % (1000 + i * 137 + hash(texts.get("body", "")) % 900), "mono", 12, Style.MUTED)
		_text(v, str(labels[i]), "ui_bold", 14, Style.INK)
		r.pivot_offset = Vector2(90, 46)
		r.scale = Vector2(0.0, 1.0)
		var tw := r.create_tween()
		tw.tween_property(r, "scale", Vector2.ONE, 0.25).set_delay(0.2 + i * 0.25)
		tw.tween_callback(Sfx.play.bind("coin", -6.0, 1.0 + i * 0.12))
	_body_label(_col, 1.0)


# ----------------------------------------------------------- boss message (fugitive)

func _build_message() -> void:
	var phone := PanelContainer.new()
	phone.add_theme_stylebox_override("panel", Style.box(Color("0f1a2b"), 22, 16, Color.TRANSPARENT, 0, false))
	_col.add_child(phone)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	phone.add_child(v)
	_text(v, texts.get("who", ""), "ui_bold", 13, Color(1, 1, 1, 0.6))
	var typing := _text(v, "• • •", "display", 22, Color(1, 1, 1, 0.7))
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Style.box(Color("26364f"), 16, 14, Color.TRANSPARENT, 0, false))
	bubble.visible = false
	v.add_child(bubble)
	_body = _text(bubble, texts.get("body", ""), "mono", 17, Color.WHITE)
	_body.visible_ratio = 0.0
	typing.name = "Typing"
	bubble.name = "Bubble"
	(Engine.get_main_loop() as SceneTree).create_timer(0.9).timeout.connect(_show_bubble)


func _build_note() -> void:
	_body_label(_col, 0.1)


func _type_body() -> void:
	if is_instance_valid(_body) and _body.is_inside_tree():
		Fx.type_in(_body)


func _show_bubble() -> void:
	if not is_inside_tree():
		return
	Sfx.play("alert", -8.0)
	var typing := find_child("Typing", true, false) as Control
	var bubble := find_child("Bubble", true, false) as Control
	if typing:
		typing.visible = false
	if bubble:
		bubble.visible = true
	_type_body()


# ----------------------------------------------------------- shared for variants

func _timer_row() -> void:
	var row := HBoxContainer.new()
	_col.add_child(row)
	_status = _text(row, texts.get("game_hint_" + variant, ""), "ui_bold", 14, Style.INK2)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(90 if narrow else 150, 10)
	_timer_bar.show_percentage = false
	_timer_bar.max_value = GAME_TIME
	_timer_bar.value = GAME_TIME
	_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_bar.add_theme_stylebox_override("fill", Style.box(Style.GOLD, 6, 0, Color.TRANSPARENT, 0, false))
	_timer_bar.add_theme_stylebox_override("background", Style.box(Style.BG2, 6, 0, Color.TRANSPARENT, 0, false))
	row.add_child(_timer_bar)


## End of an interactive variant: show the clue; `fast` = solved well and in time -> 1 h cheaper.
func _win_game(fast: bool) -> void:
	_game_over = true
	bonus = fast
	Sfx.play("lock" if fast else "tick")
	if _status:
		_status.text = texts.get("game_bonus" if fast else "game_done", "")
		_status.add_theme_color_override("font_color", Style.GREEN if fast else Style.INK2)
	if _timer_bar:
		_timer_bar.visible = false
	if _body:
		_body.visible = true
		Fx.type_in(_body)
	if _continue:
		_continue.visible = true
		Fx.pop_in(_continue, 0.3)


# ----------------------------------------------------------- wiretap: voice match

func _build_voice() -> void:
	_text(_col, texts.get("voice_hint", ""), "ui", 15, Style.INK2)
	_voice_target = _rng.randi_range(0, 2)
	for i in range(3):
		_voice_shapes.append([_rng.randf_range(2.0, 7.0), _rng.randf_range(0.0, TAU), _rng.randf_range(9.0, 15.0)])
	var ref := _wave_box(_voice_shapes[_voice_target], Style.ROSE, texts.get("voice_ref", ""))
	_col.add_child(ref)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_col.add_child(row)
	var order := [0, 1, 2]
	order.shuffle()
	for i in order:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 70 if short else 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		var w := _wave_box(_voice_shapes[i], Style.SKY, "")
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.set_anchors_preset(Control.PRESET_FULL_RECT)
		w.offset_left = 8
		w.offset_right = -8
		w.offset_top = 8
		w.offset_bottom = -8
		b.add_child(w)
		b.pressed.connect(func():
			if _game_over:
				return
			if i == _voice_target:
				b.add_theme_stylebox_override("normal", Style.pill(Color(Style.GREEN, 0.2), 18, 11, Style.GREEN, 2))
				_win_game(not _voice_mistake and _elapsed <= GAME_TIME)
			else:
				_voice_mistake = true
				b.disabled = true
				Sfx.play("fail", -8.0)
				Fx.shake(b, 6))
	_timer_row()
	_body_label(_col, -1.0)
	_body.visible = false


func _wave_box(shape: Array, color: Color, caption: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 70)
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("0f1a2b"))
		var pts := PackedVector2Array()
		for k in range(0, 101):
			var x := c.size.x * k / 100.0
			var a := float(k) / 100.0 * TAU
			var y := sin(a * shape[0] + shape[1]) * 0.6 + sin(a * shape[2]) * 0.25
			pts.append(Vector2(x, c.size.y / 2.0 + y * c.size.y * 0.35))
		c.draw_polyline(pts, color, 2.5, true)
		if caption != "":
			c.draw_string(Style.font("ui_bold"), Vector2(8, 16), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7)))
	return c


# ----------------------------------------------------------- cctv: focus the footage

func _build_focus() -> void:
	_text(_col, texts.get("focus_hint", ""), "ui", 15, Style.INK2)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 170 if short else 280)
	frame.add_theme_stylebox_override("panel", Style.box(Color("0f1a2b"), 14, 0, Color.TRANSPARENT, 0, false))
	frame.clip_contents = true
	_col.add_child(frame)
	_photo = TextureRect.new()
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if image_path != null and ResourceLoader.exists(image_path):
		_photo.texture = load(image_path)
	_focus_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FOCUS_SHADER
	_focus_mat.shader = sh
	_photo.material = _focus_mat
	frame.add_child(_photo)
	_target = _rng.randf_range(15.0, 85.0)
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = 100
	_slider.step = 0.5
	_slider.value = 50.0 if absf(_target - 50.0) > 20.0 else 5.0
	_slider.custom_minimum_size = Vector2(0, 44 if narrow else 28)
	_col.add_child(_slider)
	_timer_row()
	if texts.get("credit", "") != "":
		_text(_col, texts["credit"], "ui", 11, Style.MUTED)
	_body_label(_col, -1.0)
	_body.visible = false
	Sfx.play("shutter")


# ----------------------------------------------------------- contact: interrogation

const MOODS := ["nervous", "greedy", "proud"]


func _build_interrogate() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_col.add_child(row)
	var portrait := SuspectPortrait.new()
	portrait.custom_minimum_size = Vector2(110, 132)
	portrait.setup(portrait_data, false)
	row.add_child(portrait)
	_round_box = VBoxContainer.new()
	_round_box.add_theme_constant_override("separation", 8)
	_round_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_round_box)
	_timer_row()
	_status.text = texts.get("interro_status", "") % [0, 3]
	_body_label(_col, -1.0)
	_body.visible = false
	_next_round()


func _next_round() -> void:
	for c in _round_box.get_children():
		c.queue_free()
	if _round >= 3:
		_win_game(_good >= 2)
		return
	_mood = MOODS[_rng.randi_range(0, 2)]
	var cue := Label.new()
	cue.text = texts.get("mood_" + _mood, "")
	cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cue.add_theme_font_override("font", Style.font("ui_bold"))
	cue.add_theme_color_override("font_color", Style.INK)
	_round_box.add_child(cue)
	var opts := MOODS.duplicate()
	opts.shuffle()
	for m in opts:
		var b := Button.new()
		b.text = texts.get("tone_" + m, "")
		b.focus_mode = Control.FOCUS_NONE
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			if m == _mood:
				_good += 1
				Sfx.play("coin", -6.0)
			else:
				Sfx.play("fail", -8.0)
			_round += 1
			_status.text = texts.get("interro_status", "") % [_good, 3]
			_next_round())
		_round_box.add_child(b)


# ----------------------------------------------------------- money: put movements in order

func _build_order() -> void:
	_text(_col, texts.get("order_hint", ""), "ui", 15, Style.INK2)
	var grid := GridContainer.new()
	grid.columns = 2 if narrow else 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_col.add_child(grid)
	var hours: Array = []
	while hours.size() < 4:
		var h := _rng.randi_range(0, 23) * 60 + _rng.randi_range(0, 59)
		if not h in hours:
			hours.append(h)
	var sorted_h := hours.duplicate()
	sorted_h.sort()
	var labels: Array = texts.get("receipts", ["", "", ""])
	for k in range(4):
		var h: int = hours[k]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 80)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%02d:%02d\n%s" % [h / 60, h % 60, labels[k % labels.size()]]
		if narrow:
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_stylebox_override("normal", Style.box(Color("fffaf0"), 10, 10, Style.LINE, 1, false))
		b.add_theme_font_override("font", Style.font("mono"))
		grid.add_child(b)
		_order_btns.append(b)
		b.pressed.connect(func():
			if _game_over:
				return
			if h == sorted_h[_order_next]:
				_order_next += 1
				b.disabled = true
				b.add_theme_stylebox_override("disabled", Style.box(Color(Style.GREEN, 0.15), 10, 10, Style.GREEN, 2, false))
				Sfx.play("coin", -6.0, 1.0 + _order_next * 0.1)
				if _order_next >= 4:
					_win_game(not _order_mistake and _elapsed <= GAME_TIME)
			else:
				_order_mistake = true
				Sfx.play("fail", -8.0)
				Fx.shake(b, 6))
	_timer_row()
	_body_label(_col, -1.0)
	_body.visible = false


## Size of the screen this card is shown on (desktop size when not in a scene yet).
func _screen_size() -> Vector2:
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root:
		return (ml as SceneTree).root.get_visible_rect().size
	return Vector2(1280, 720)
