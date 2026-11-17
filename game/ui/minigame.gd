## Quick action events (ADR-0011):
##  - "sighting"  (detective): the suspect pops up in windows; tap them 3 times in time.
##  - "checkpoint" (fugitive): stop the moving needle inside the green zone to pass passport control.
## Emits finished(success).
extends PanelContainer

signal finished(success: bool)

const Style = preload("res://ui/style.gd")
const Fx = preload("res://ui/fx.gd")
const Sfx = preload("res://ui/sfx.gd")

const SIGHT_TIME := 7.0
const SIGHT_HITS := 3
const SIGHT_SHOW := 0.85
const COLS := 5
const ROWS := 2

var kind := "sighting"
var texts := {}
var _area: Control
var _status: Label
var _bar: ProgressBar
var _t := 0.0
var _over := false
var rng := RandomNumberGenerator.new()
# sighting
var _cell := -1
var _cell_t := 0.0
var _hits := 0
# checkpoint
var _needle := 0.0
var _dir := 1.0
var _zone := Vector2(0.4, 0.55)
var _speed := 1.1
var _btn: Button


func setup(p_kind: String, p_texts: Dictionary, p_seed := 0) -> void:
	kind = p_kind
	texts = p_texts
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	var vp := _screen_size()
	var vp_w: float = vp.x
	var narrow := vp_w < 600.0
	custom_minimum_size = Vector2(minf(700.0, vp_w - 16.0) if narrow else 700.0, 0)
	add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 22, 16 if narrow else 24))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var title := _text(col, texts.get("title", ""), "display", 24 if narrow else 30, Style.CORAL)
	_text(col, texts.get("hint", ""), "ui", 15, Style.INK2)
	_area = Control.new()
	var short: bool = vp.y < 520.0
	_area.custom_minimum_size = Vector2(0, (150 if short else 230) if kind == "sighting" else (80 if short else 110))
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.draw.connect(_draw_area)
	_area.gui_input.connect(_on_area_input)
	col.add_child(_area)
	var row := HBoxContainer.new()
	col.add_child(row)
	_status = _text(row, "", "ui_bold", 16, Style.INK)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind == "sighting":
		_bar = ProgressBar.new()
		_bar.custom_minimum_size = Vector2(100 if narrow else 180, 10)
		_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bar.show_percentage = false
		_bar.max_value = SIGHT_TIME
		_bar.value = SIGHT_TIME
		_bar.add_theme_stylebox_override("fill", Style.box(Style.CORAL, 6, 0, Color.TRANSPARENT, 0, false))
		_bar.add_theme_stylebox_override("background", Style.box(Style.BG2, 6, 0, Color.TRANSPARENT, 0, false))
		row.add_child(_bar)
		_next_cell()
		_update_status()
	else:
		var zw := rng.randf_range(0.13, 0.18)
		var zs := rng.randf_range(0.15, 0.85 - zw)
		_zone = Vector2(zs, zs + zw)
		_speed = rng.randf_range(0.9, 1.3)
		_btn = Button.new()
		_btn.text = texts.get("action", "GO")
		_btn.focus_mode = Control.FOCUS_NONE
		Style.primary(_btn, Style.NAVY)
		_btn.custom_minimum_size.y = 52
		_btn.pressed.connect(_try_pass)
		col.add_child(_btn)
		_status.text = texts.get("status", "")
	Fx.pulse(title, 1)


func _text(parent: Control, s: String, f: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Style.font(f))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _process(delta: float) -> void:
	if _over:
		return
	_t += delta
	if kind == "sighting":
		_cell_t += delta
		_bar.value = maxf(0.0, SIGHT_TIME - _t)
		if _cell_t > SIGHT_SHOW:
			_next_cell()
		if _t >= SIGHT_TIME:
			_end(false)
	else:
		_needle += _dir * _speed * delta
		if _needle > 1.0:
			_needle = 1.0
			_dir = -1.0
		elif _needle < 0.0:
			_needle = 0.0
			_dir = 1.0
	_area.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if kind == "checkpoint" and not _over and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]:
		_try_pass()
		get_viewport().set_input_as_handled()


func _next_cell() -> void:
	var c := _cell
	while c == _cell:
		c = rng.randi_range(0, COLS * ROWS - 1)
	_cell = c
	_cell_t = 0.0


func _cell_rect(i: int) -> Rect2:
	var w := _area.size.x
	var h := _area.size.y
	var cw := w / COLS
	var ch := h / ROWS
	return Rect2((i % COLS) * cw + 10, (i / COLS) * ch + 10, cw - 20, ch - 20)


func _on_area_input(event: InputEvent) -> void:
	if _over or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if kind == "sighting":
		if _cell >= 0 and _cell_rect(_cell).has_point(event.position):
			hit()
		else:
			Fx.shake(_area, 4)
	else:
		_try_pass()


## One successful tap on the suspect (also used by tests).
func hit() -> void:
	if _over:
		return
	_hits += 1
	Sfx.play("hit")
	_update_status()
	if _hits >= SIGHT_HITS:
		_end(true)
	else:
		_next_cell()


func _update_status() -> void:
	_status.text = texts.get("status", "") % [_hits, SIGHT_HITS]


func _try_pass() -> void:
	if _over:
		return
	_end(_needle >= _zone.x and _needle <= _zone.y)


## Test hook for the checkpoint: put the needle in the zone.
func debug_center_needle() -> void:
	_needle = (_zone.x + _zone.y) / 2.0


func _end(success: bool) -> void:
	_over = true
	Sfx.play("success" if success else "fail")
	_status.text = texts.get("win" if success else "lose", "")
	_status.add_theme_color_override("font_color", Style.GREEN if success else Style.ROSE)
	if _btn:
		_btn.disabled = true
	_area.queue_redraw()
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(finished.emit.bind(success))


func _draw_area() -> void:
	var w := _area.size.x
	var h := _area.size.y
	if kind == "sighting":
		_area.draw_rect(Rect2(Vector2.ZERO, _area.size), Color("e9dccb"))
		for i in range(COLS * ROWS):
			var r := _cell_rect(i)
			var lit := i == _cell and not _over
			_area.draw_rect(r, Color("fbe7b5") if lit else Color("40598a"))
			_area.draw_rect(r, Color("7a5a3c"), false, 3)
			_area.draw_line(Vector2(r.position.x + r.size.x / 2, r.position.y), Vector2(r.position.x + r.size.x / 2, r.end.y), Color("7a5a3c"), 2)
			if lit:
				var c := r.get_center() + Vector2(0, r.size.y * 0.15)
				var u := r.size.y * 0.9
				_area.draw_rect(Rect2(c.x - u * 0.22, c.y - u * 0.05, u * 0.44, u * 0.5), Style.INK)
				_area.draw_rect(Rect2(c.x - u * 0.1, c.y - u * 0.1, u * 0.2, u * 0.06), Style.CORAL)
				_area.draw_circle(c + Vector2(0, -u * 0.2), u * 0.12, Style.INK)
				_area.draw_rect(Rect2(c.x - u * 0.22, c.y - u * 0.3, u * 0.44, u * 0.05), Style.INK)
				_area.draw_rect(Rect2(c.x - u * 0.12, c.y - u * 0.44, u * 0.24, u * 0.15), Style.INK)
	else:
		var y := h * 0.5
		_area.draw_rect(Rect2(0, y - 18, w, 36), Style.BG2)
		_area.draw_rect(Rect2(w * _zone.x, y - 18, w * (_zone.y - _zone.x), 36), Color(Style.GREEN, 0.75))
		var nx := w * _needle
		_area.draw_rect(Rect2(nx - 4, y - 34, 8, 68), Style.INK)
		_area.draw_circle(Vector2(nx, y - 38), 9, Style.CORAL)


## Size of the screen this card is shown on (desktop size when not in a scene yet).
func _screen_size() -> Vector2:
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root:
		return (ml as SceneTree).root.get_visible_rect().size
	return Vector2(1280, 720)
