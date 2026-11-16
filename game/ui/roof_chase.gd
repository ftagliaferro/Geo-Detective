## Arrest variant (ADR-0012): side-scrolling rooftop foot chase.
## Jump over chimneys and AC units (space / up / W / click / tap / JUMP button).
## mode "pursue": catch the thief before time runs out. mode "escape": you are the
## thief and must keep the police officer from catching you until time runs out.
extends Control

signal finished(success: bool)

const Style = preload("res://ui/style.gd")
const ThiefArt = preload("res://ui/thief_art.gd")
const Sfx = preload("res://ui/sfx.gd")

const GRAVITY := 2600.0
const JUMP_V := -980.0
const SPEED := 430.0
const PURSUE_GAP := 22.0
const PURSUE_RATE := 1.45
const PURSUE_HIT := 4.0
const PURSUE_TIME := 26.0
const ESCAPE_GAP := 12.0
const ESCAPE_RATE := 0.25
const ESCAPE_HIT := 3.5
const ESCAPE_TIME := 22.0
const POLICE := Color("2f4a7a")

var mode := "pursue"
var labels := {"time": "Time", "gap": "Gap", "jump": "JUMP"}
var running := false
var gap := PURSUE_GAP
var time_left := PURSUE_TIME
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _y := 0.0          # player height above the roof (negative = up)
var _vy := 0.0
var _spawn := 1.2
var _flash := 0.0
var obstacles: Array = []   # [x, w, h]
var _skyline: Array = []
var _hud: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var x := 0.0
	while x < 2400.0:
		var w := r.randf_range(60, 140)
		_skyline.append([x, w, r.randf_range(80, 230)])
		x += w + r.randf_range(4, 16)
	_hud = Label.new()
	_hud.position = Vector2(18, 12)
	_hud.add_theme_font_override("font", Style.font("display"))
	_hud.add_theme_font_size_override("font_size", 26)
	_hud.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_theme_color_override("font_outline_color", Color("1b2433"))
	_hud.add_theme_constant_override("outline_size", 8)
	add_child(_hud)
	var jump := Button.new()
	jump.name = "Jump"
	jump.focus_mode = Control.FOCUS_NONE
	jump.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump.offset_left = -150
	jump.offset_top = -86
	jump.offset_right = -18
	jump.offset_bottom = -18
	Style.primary(jump)
	jump.button_down.connect(do_jump)
	add_child(jump)


func set_escape_mode() -> void:
	mode = "escape"
	gap = ESCAPE_GAP
	time_left = ESCAPE_TIME


func start(seed_value := 0) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	(get_node("Jump") as Button).text = labels.get("jump", "JUMP")
	running = true
	Sfx.play("siren" if mode == "escape" else "whoosh", -4.0)


func do_jump() -> void:
	if running and _y >= -0.5:
		_vy = JUMP_V
		Sfx.play("pop", -10.0, 1.4)


func _input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_UP, KEY_W]:
		do_jump()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if running and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		do_jump()
		accept_event()


func _player_x() -> float:
	return size.x * 0.3


func _roof_y() -> float:
	return size.y * 0.74


func _process(delta: float) -> void:
	_t += delta
	if running:
		time_left -= delta
		gap -= (ESCAPE_RATE if mode == "escape" else PURSUE_RATE) * delta
		_vy += GRAVITY * delta
		_y = minf(0.0, _y + _vy * delta)
		if _y >= 0.0:
			_vy = 0.0
		_spawn -= delta
		if _spawn <= 0.0:
			_spawn = rng.randf_range(0.95, 1.6)
			obstacles.append([size.x + 40.0, rng.randf_range(34, 58), rng.randf_range(46, 78)])
		var px := _player_x()
		for o in obstacles.duplicate():
			o[0] -= SPEED * delta
			if o[0] + o[1] < -20.0:
				obstacles.erase(o)
			elif o[0] < px + 16.0 and o[0] + o[1] > px - 16.0 and -_y < o[2] - 6.0:
				gap += -ESCAPE_HIT if mode == "escape" else PURSUE_HIT
				_flash = 0.35
				obstacles.erase(o)
				Sfx.play("hit")
		_flash = maxf(0.0, _flash - delta)
		if mode == "escape":
			if gap <= 0.0:
				_end(false)
			elif time_left <= 0.0:
				_end(true)
		else:
			if gap <= 0.0:
				_end(true)
			elif time_left <= 0.0:
				_end(false)
	_hud.text = "%s %.0f    %s %.0f m" % [labels.get("time", "Time"), maxf(0.0, time_left), labels.get("gap", "Gap"), maxf(0.0, gap)]
	queue_redraw()


func _end(success: bool) -> void:
	running = false
	finished.emit(success)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var roof := _roof_y()
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color("ff9f7a"), Color("ff9f7a"), Color("ffe3bf"), Color("ffe3bf")]))
	draw_circle(Vector2(w * 0.8, h * 0.42), 60, Color("fff1d6"))
	var scroll := _t * (SPEED * 0.25 if running else 30.0)
	for b in _skyline:
		var x: float = fmod(b[0] - scroll + 2400.0, 2400.0) - 100.0
		if x < w + 20:
			draw_rect(Rect2(x, roof - b[2], b[1], b[2]), Color("e98a6b"))
	draw_rect(Rect2(0, roof, w, h - roof), Color("8c4f45"))
	draw_rect(Rect2(0, roof, w, 5), Color("c9725f"))
	for o in obstacles:
		draw_rect(Rect2(o[0], roof - o[2], o[1], o[2]), Color("6b3d35"))
		draw_rect(Rect2(o[0] - 4, roof - o[2] - 8, o[1] + 8, 8), Color("4a2a25"))
	var px := _player_x()
	var phase := _t * 15.0
	var u := minf(140.0, h * 0.3)
	if mode == "escape":
		var cop_x := px - 50.0 - maxf(gap, 0.0) * 14.0
		ThiefArt.draw(self, Vector2(cop_x, roof), u, phase + 1.0, true, false, false, POLICE)
		ThiefArt.draw(self, Vector2(px, roof + _y), u, phase, true, true)
		if fmod(_t, 0.5) < 0.25:
			draw_circle(Vector2(cop_x, roof - u * 1.05), 7, Color("2050ff"))
		else:
			draw_circle(Vector2(cop_x, roof - u * 1.05), 7, Color("ff2030"))
	else:
		var thief_x := minf(px + 70.0 + maxf(gap, 0.0) * 16.0, w - 30.0)
		ThiefArt.draw(self, Vector2(thief_x, roof), u, phase + 1.0, true, true)
		var col: Color = Color.WHITE if fmod(_flash, 0.1) > 0.05 else POLICE
		ThiefArt.draw(self, Vector2(px, roof + _y), u, phase, true, false, false, col)
		if thief_x >= w - 31.0:
			draw_string(Style.font("display"), Vector2(w - 60, roof - u * 1.2), ">>", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Style.CORAL)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.2, 0.2, _flash * 0.25))
