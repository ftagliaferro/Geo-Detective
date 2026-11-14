## Arcade chase finale: low-poly 3-lane runner. Close the gap before time runs out.
## Controls: arrows / A-D, mouse drag or swipe, or tap left/right half.
extends SubViewportContainer

signal finished(caught: bool)

const C_PINK := Color("ff3d7f")
const C_CYAN := Color("31e1f7")
const LANES := [-1.6, 0.0, 1.6]
const DURATION := 25.0
const START_GAP := 30.0
const CLOSE_RATE := 1.7      # metres gained per second
const HIT_PENALTY := 6.0
const SPEED := 24.0
const SPAWN_EVERY := 0.85
const SWIPE := 30.0

var viewport: SubViewport
var camera: Camera3D
var player: MeshInstance3D
var suspect: MeshInstance3D
var hud: Label
var obstacles: Array = []
var buildings: Array = []
var rng := RandomNumberGenerator.new()
var lane := 1
var gap := START_GAP
var time_left := DURATION
var spawn_t := 0.0
var running := false
var flash := 0.0
var _press := Vector2.ZERO
var _pressed := false
var labels := {"time": "Time", "gap": "Gap", "help": ""}


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	add_child(viewport)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("0b0d16")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.65, 0.9)
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color("1a1030")
	env.environment.fog_density = 0.03
	viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	viewport.add_child(light)

	camera = Camera3D.new()
	camera.position = Vector3(0, 3.2, 5.5)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	viewport.add_child(camera)

	var road := _box(Vector3(6, 0.1, 140), Color("1b1f38"))
	road.position = Vector3(0, -0.05, -60)
	for x in [-0.8, 0.8]:
		var stripe := _box(Vector3(0.06, 0.02, 140), Color(C_CYAN, 1.0), true)
		stripe.position = Vector3(x, 0.01, -60)

	player = _box(Vector3(0.9, 0.9, 1.4), C_PINK, true)
	player.position = Vector3(LANES[lane], 0.45, 0)
	suspect = _box(Vector3(0.9, 0.9, 1.4), C_CYAN, true)
	suspect.position = Vector3(0, 0.45, -2.0 - START_GAP * 0.6)

	for i in range(24):
		var side := -1 if i % 2 == 0 else 1
		var h := 2.0 + (i * 37 % 7)
		var b := _box(Vector3(2.5, h, 4.0), Color("232a52"))
		b.position = Vector3(side * 5.0, h / 2.0, -i * 6.0)
		buildings.append(b)

	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 24)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	add_child(hud)


func _box(size3: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	viewport.add_child(mi)
	return mi


func start(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	running = true
	if is_inside_tree():
		grab_focus()


func _process(delta: float) -> void:
	if not running:
		_update_hud()
		return
	time_left -= delta
	gap -= CLOSE_RATE * delta
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = SPAWN_EVERY
		_spawn()
	player.position.x = lerpf(player.position.x, LANES[lane], minf(1.0, delta * 14.0))
	suspect.position = Vector3(LANES[(int(time_left) / 2) % 3], 0.45, -2.0 - gap * 0.6)
	for b in buildings:
		b.position.z += SPEED * delta
		if b.position.z > 8.0:
			b.position.z -= 24 * 6.0
	for o in obstacles.duplicate():
		o.position.z += SPEED * delta
		if absf(o.position.z) < 0.9 and absf(o.position.x - player.position.x) < 0.9:
			gap += HIT_PENALTY
			flash = 0.3
			_remove(o)
		elif o.position.z > 8.0:
			_remove(o)
	flash = maxf(0.0, flash - delta)
	(player.material_override as StandardMaterial3D).albedo_color = Color.WHITE if flash > 0.0 else C_PINK
	if gap <= 0.0:
		_end(true)
	elif time_left <= 0.0:
		_end(false)
	_update_hud()


func _spawn() -> void:
	var free_lane := rng.randi_range(0, 2)
	for i in range(3):
		if i != free_lane and rng.randf() < 0.45:
			var o := _box(Vector3(1.1, 0.8, 0.8), Color("ffb02e"), true)
			o.position = Vector3(LANES[i], 0.4, -70.0)
			obstacles.append(o)


func _remove(o: MeshInstance3D) -> void:
	obstacles.erase(o)
	o.queue_free()


func _end(caught: bool) -> void:
	running = false
	finished.emit(caught)


func _update_hud() -> void:
	hud.text = "%s: %.0f s    %s: %.0f m\n%s" % [labels["time"], maxf(0.0, time_left), labels["gap"], maxf(0.0, gap), labels["help"]]


func _move(dir: int) -> void:
	lane = clampi(lane + dir, 0, 2)


func _input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A):
		_move(-1)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D):
		_move(1)


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
