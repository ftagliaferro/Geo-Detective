## Interactive 3D globe: drag to spin, wheel/pinch to zoom, tap/click to drop a pin.
extends SubViewportContainer

signal pin_dropped(lat: float, lon: float)

const Geo = preload("res://core/geo.gd")
const TEXTURE := preload("res://assets/globe/world.png")
const C_PINK := Color("ff3d7f")
const C_CYAN := Color("31e1f7")
const DRAG_SPEED := 0.006
const TAP_SLOP := 8.0

var viewport: SubViewport
var camera: Camera3D
var pivot: Node3D
var pin_marker: MeshInstance3D
var home_marker: MeshInstance3D
var yaw := 0.0
var pitch := 0.0
var _press_pos := Vector2.ZERO
var _dragging := false
var _moved := 0.0
var interactive := true


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)

	camera = Camera3D.new()
	camera.fov = 35.0
	camera.position = Vector3(0, 0, 3.6)
	viewport.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, 35, 0)
	light.light_energy = 0.9
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.8, 1.0)
	env.environment.ambient_light_energy = 0.7
	viewport.add_child(env)

	pivot = Node3D.new()
	viewport.add_child(pivot)

	var sphere := SphereMesh.new()
	sphere.radial_segments = 96
	sphere.rings = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TEXTURE
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission_texture = TEXTURE
	mat.emission_energy_multiplier = 0.45
	var globe := MeshInstance3D.new()
	globe.mesh = sphere
	globe.material_override = mat
	globe.scale = Vector3.ONE  # SphereMesh default radius 0.5 -> scaled below
	globe.scale = Vector3(2, 2, 2)
	pivot.add_child(globe)

	# Atmosphere rim
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.53
	halo_mesh.height = 1.06
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(C_CYAN, 0.12)
	halo_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.material_override = halo_mat
	halo.scale = Vector3(2, 2, 2)
	viewport.add_child(halo)

	home_marker = _marker(C_CYAN, 0.035)
	pin_marker = _marker(C_PINK, 0.045)
	pin_marker.visible = false


func _marker(color: Color, r: float) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	pivot.add_child(mi)
	return mi


## Spin the globe so (lat, lon) faces the camera and mark it as "you are here".
func focus(lat: float, lon: float) -> void:
	var v := Geo.lat_lon_to_vec(lat, lon)
	yaw = -atan2(v.x, v.z)
	pitch = asin(clampf(v.y, -1.0, 1.0))
	_apply()
	home_marker.position = v * 1.01


func clear_pin() -> void:
	pin_marker.visible = false


func set_pin(lat: float, lon: float) -> void:
	pin_marker.position = Geo.lat_lon_to_vec(lat, lon) * 1.02
	pin_marker.visible = true


func _apply() -> void:
	pitch = clampf(pitch, -1.3, 1.3)
	pivot.basis = Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_moved = 0.0
				_press_pos = mb.position
			else:
				_dragging = false
				if _moved < TAP_SLOP:
					_pick(mb.position)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-0.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.15)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_moved += mm.relative.length()
		yaw += mm.relative.x * DRAG_SPEED
		pitch += mm.relative.y * DRAG_SPEED
		_apply()
		accept_event()
	elif event is InputEventMagnifyGesture:
		_zoom((1.0 - (event as InputEventMagnifyGesture).factor) * 2.0)


func _zoom(delta: float) -> void:
	camera.position.z = clampf(camera.position.z + delta, 1.9, 4.5)


## Ray-sphere intersection (unit sphere at origin) -> lat/lon in globe space.
func _pick(pos: Vector2) -> void:
	var origin := camera.project_ray_origin(pos)
	var dir := camera.project_ray_normal(pos)
	var b := origin.dot(dir)
	var c := origin.dot(origin) - 1.0
	var disc := b * b - c
	if disc < 0.0:
		return
	var hit := origin + dir * (-b - sqrt(disc))
	var local := pivot.global_transform.affine_inverse() * hit
	var ll := Geo.vec_to_lat_lon(local)
	set_pin(ll.x, ll.y)
	pin_dropped.emit(ll.x, ll.y)
