## Arcade chase finale: low-poly 3-lane city street at dusk. Close the gap before time runs out.
## Controls: arrows / A-D (event-driven, every press counts), swipe/drag, tap a side,
## or the on-screen arrow buttons.
extends Control

signal finished(caught: bool)

const C_PLAYER := Color("2f4f7f")   # unmarked navy sedan
const C_SUSPECT := Color("9e2b25")  # dark red getaway car
const C_ORANGE := Color("e67e22")
const C_HUD := Color("d9a441")
const LANES := [-1.6, 0.0, 1.6]
const DURATION := 30.0
const START_GAP := 25.0
const CLOSE_RATE := 1.6       # metres gained per second -> ~16 s on a clean run
const HIT_PENALTY := 4.0
const SPEED := 20.0
const SPAWN_EVERY := 1.1
const HIT_HALF_WIDTH := 0.75
const SWIPE := 30.0
const FONT_TITLE := preload("res://assets/fonts/BebasNeue-Regular.ttf")

const WINDOWS_SHADER := """
shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.55, 0.32, 0.25);
uniform vec3 lit_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
varying vec3 lpos;
varying vec3 lnorm;
void vertex() { lpos = VERTEX; lnorm = NORMAL; }
void fragment() {
	vec2 uv = abs(lnorm.x) > 0.5 ? lpos.zy : lpos.xy;
	vec2 cell = floor(uv * vec2(1.6, 1.4));
	vec2 f = fract(uv * vec2(1.6, 1.4));
	float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.75);
	float on = step(0.75, hash(cell));
	float roof = step(0.5, abs(lnorm.y));
	vec3 glass = vec3(0.18, 0.22, 0.27);
	ALBEDO = mix(base_color, glass, win * (1.0 - roof));
	EMISSION = lit_color * win * on * (1.0 - roof) * 0.5;
	ROUGHNESS = 0.85;
}
"""

const GRID_SHADER := """
shader_type spatial;
uniform float scroll = 0.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = vec2(wpos.x, wpos.z + scroll) / 1.5;
	vec2 d = abs(fract(g - 0.5) - 0.5) / fwidth(g);
	float line = 1.0 - min(min(d.x, d.y), 1.0);
	ALBEDO = mix(vec3(0.58, 0.57, 0.54), vec3(0.42, 0.41, 0.39), line * 0.7);
	ROUGHNESS = 0.95;
}
"""



var svc: SubViewportContainer
var viewport: SubViewport
var camera: Camera3D
var player: Node3D
var suspect: Node3D
var player_body_mat: StandardMaterial3D
var grid_mat: ShaderMaterial
var hud_time: Label
var hud_gap: Label
var gap_bar: ProgressBar
var obstacles: Array = []
var buildings: Array = []
var dashes: Array = []
var rng := RandomNumberGenerator.new()
var lane := 1
var gap := START_GAP
var time_left := DURATION
var spawn_t := 1.5
var elapsed := 0.0
var running := false
var flash := 0.0
var scroll := 0.0
var _press := Vector2.ZERO
var _pressed := false
var labels := {"time": "Time", "gap": "Gap", "help": ""}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true

	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	svc.add_child(viewport)

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4f6d8f")
	sky_mat.sky_horizon_color = Color("e3c7a1")
	sky_mat.ground_horizon_color = Color("8a8378")
	sky_mat.ground_bottom_color = Color("3d3b38")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.78)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color("c9b8a0")
	env.fog_density = 0.01
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 25, 0)
	light.light_color = Color(1.0, 0.9, 0.78)
	light.light_energy = 1.1
	light.shadow_enabled = true
	viewport.add_child(light)

	camera = Camera3D.new()
	camera.position = Vector3(0, 2.6, 5.2)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	camera.fov = 70.0
	viewport.add_child(camera)

	# Pavement on both sides
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	grid_mat = ShaderMaterial.new()
	grid_mat.shader = _shader(GRID_SHADER)
	ground.material_override = grid_mat
	ground.position = Vector3(0, -0.02, -80)
	viewport.add_child(ground)

	var road := _box(Vector3(5.4, 0.06, 200), Color("3b3e43"))
	road.position = Vector3(0, 0.0, -80)
	for x in [-2.7, 2.7]:
		var edge := _box(Vector3(0.1, 0.04, 200), Color("e8e4d8"))
		edge.position = Vector3(x, 0.04, -80)
	for i in range(20):
		for x in [-0.8, 0.8]:
			var d := _box(Vector3(0.1, 0.03, 1.6), Color("f0ece0"))
			d.position = Vector3(x, 0.04, -i * 5.0)
			dashes.append(d)

	var player_car := _car(C_PLAYER)
	player = player_car[0]
	player_body_mat = player_car[1]
	player.position = Vector3(LANES[lane], 0, 0)
	suspect = _car(C_SUSPECT)[0]
	suspect.position = Vector3(0, 0, -2.0 - START_GAP * 0.6)

	var shader := _shader(WINDOWS_SHADER)
	for i in range(28):
		var side := -1 if i % 2 == 0 else 1
		var h := 3.0 + float((i * 37) % 9)
		var w := 2.5 + float((i * 13) % 3)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, 4.5)
		mi.mesh = bm
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("seed", float(i) * 3.7)
		mat.set_shader_parameter("base_color", [Color("8b4a3c"), Color("c4b293"), Color("8d949b"), Color("a8826a")][i % 4])
		mi.material_override = mat
		mi.position = Vector3(side * (4.6 + w / 2.0), h / 2.0, -float(i / 2) * 7.0)
		viewport.add_child(mi)
		buildings.append(mi)

	_build_hud()


func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s


func _box(size3: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	viewport.add_child(mi)
	return mi


## Low-poly car built from primitives. Returns [root, body_material].
func _car(color: Color) -> Array:
	var root := Node3D.new()
	viewport.add_child(root)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.metallic = 0.3
	body_mat.roughness = 0.45
	var parts := [
		[Vector3(1.0, 0.32, 1.8), Vector3(0, 0.34, 0), body_mat],
		[Vector3(0.78, 0.28, 0.9), Vector3(0, 0.62, 0.1), null],
	]
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color("101425")
	cabin_mat.metallic = 0.8
	cabin_mat.roughness = 0.1
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.position = p[1]
		mi.material_override = p[2] if p[2] else cabin_mat
		root.add_child(mi)
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color("0a0a0f")
	for wx in [-0.52, 0.52]:
		for wz in [-0.6, 0.6]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.18
			cm.bottom_radius = 0.18
			cm.height = 0.14
			w.mesh = cm
			w.rotation_degrees = Vector3(0, 0, 90)
			w.position = Vector3(wx, 0.18, wz)
			w.material_override = wheel_mat
			root.add_child(w)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color("ff2030")
	tail_mat.emission_enabled = true
	tail_mat.emission = Color("ff2030")
	tail_mat.emission_energy_multiplier = 1.2
	for tx in [-0.35, 0.35]:
		var t := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.22, 0.08, 0.04)
		t.mesh = tb
		t.position = Vector3(tx, 0.4, 0.91)
		t.material_override = tail_mat
		root.add_child(t)
	return [root, body_mat]


func _build_hud() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 10
	top.add_theme_constant_override("separation", 24)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	hud_time = _hud_label(top)
	hud_gap = _hud_label(top)
	gap_bar = ProgressBar.new()
	gap_bar.max_value = START_GAP + HIT_PENALTY * 3
	gap_bar.show_percentage = false
	gap_bar.custom_minimum_size = Vector2(160, 14)
	gap_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gap_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_HUD
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	gap_bar.add_theme_stylebox_override("fill", fill)
	gap_bar.add_theme_stylebox_override("background", bg)
	gap_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap_bar)

	for dir in [-1, 1]:
		var b := Button.new()
		b.text = "<" if dir < 0 else ">"
		b.add_theme_font_override("font", FONT_TITLE)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 84)
		b.add_theme_font_size_override("font_size", 36)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.12, 0.55)
		sb.border_color = Color("c9c3b6")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(42)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if dir < 0 else Control.PRESET_BOTTOM_RIGHT)
		b.offset_top = -100
		b.offset_bottom = -16
		if dir < 0:
			b.offset_left = 16
			b.offset_right = 100
		else:
			b.offset_left = -100
			b.offset_right = -16
		b.button_down.connect(_move.bind(dir))
		add_child(b)


func _hud_label(parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT_TITLE)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func start(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	running = true
	if is_inside_tree():
		get_viewport().gui_release_focus()


func _process(delta: float) -> void:
	scroll += SPEED * delta * (1.0 if running else 0.3)
	grid_mat.set_shader_parameter("scroll", -scroll)
	player.position.x = lerpf(player.position.x, LANES[lane], minf(1.0, delta * 22.0))
	player.rotation.y = (LANES[lane] - player.position.x) * -0.25
	if not running:
		_update_hud()
		return
	elapsed += delta
	time_left -= delta
	gap -= CLOSE_RATE * delta
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = SPAWN_EVERY
		_spawn()
	var sl: int = int(elapsed / 2.5) % 3
	suspect.position.x = lerpf(suspect.position.x, LANES[sl], minf(1.0, delta * 4.0))
	suspect.position.z = -2.0 - maxf(gap, 0.0) * 0.6
	var dz := SPEED * delta
	for b in buildings:
		b.position.z += dz
		if b.position.z > 10.0:
			b.position.z -= 14 * 7.0
	for d in dashes:
		d.position.z += dz
		if d.position.z > 6.0:
			d.position.z -= 100.0
	for o in obstacles.duplicate():
		o.position.z += dz
		if absf(o.position.z) < 1.0 and absf(o.position.x - player.position.x) < HIT_HALF_WIDTH:
			gap += HIT_PENALTY
			flash = 0.35
			_remove(o)
		elif o.position.z > 8.0:
			_remove(o)
	flash = maxf(0.0, flash - delta)
	player_body_mat.albedo_color = Color.WHITE if fmod(flash, 0.1) > 0.05 else C_PLAYER
	if gap <= 0.0:
		_end(true)
	elif time_left <= 0.0:
		_end(false)
	_update_hud()


func _spawn() -> void:
	# Early on at most one barrier per row; later up to two (always one free lane).
	var max_blocks := 1 if elapsed < 8.0 else 2
	var lanes := [0, 1, 2]
	lanes.shuffle()
	var count := rng.randi_range(1, max_blocks)
	for i in range(count):
		var o := _box(Vector3(1.2, 0.7, 0.5), C_ORANGE)
		o.position = Vector3(LANES[lanes[i]], 0.35, -80.0)
		obstacles.append(o)


func _remove(o: MeshInstance3D) -> void:
	obstacles.erase(o)
	o.queue_free()


func _end(caught: bool) -> void:
	running = false
	finished.emit(caught)


func _update_hud() -> void:
	hud_time.text = "%s %.0f" % [labels["time"], maxf(0.0, time_left)]
	hud_gap.text = "%s %.0f m" % [labels["gap"], maxf(0.0, gap)]
	gap_bar.value = maxf(0.0, gap)


func _move(dir: int) -> void:
	if running:
		lane = clampi(lane + dir, 0, 2)


func _input(event: InputEvent) -> void:
	if not running or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.physical_keycode
	if k == KEY_LEFT or k == KEY_A:
		_move(-1)
		get_viewport().set_input_as_handled()
	elif k == KEY_RIGHT or k == KEY_D:
		_move(1)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = event.position
			_pressed = true
		elif _pressed:
			_pressed = false
			var dx: float = event.position.x - _press.x
			if absf(dx) >= SWIPE:
				_move(1 if dx > 0 else -1)
			else:
				_move(1 if event.position.x > size.x / 2.0 else -1)
		accept_event()
