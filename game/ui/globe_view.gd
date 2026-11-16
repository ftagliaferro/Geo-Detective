## Interactive 3D globe: drag to spin, wheel/pinch to zoom, tap/click to drop a pin.
extends SubViewportContainer

signal pin_dropped(lat: float, lon: float)
signal flight_done

const Geo = preload("res://core/geo.gd")
const TEXTURE := preload("res://assets/globe/world.png")
const C_PINK := Color("ff5a3c")
const C_CYAN := Color("1f2f4d")
const DRAG_SPEED := 0.006
const TAP_SLOP := 8.0

var viewport: SubViewport
var camera: Camera3D
var pivot: Node3D
var pin_marker: Node3D
var home_marker: MeshInstance3D
var yaw := 0.0
var pitch := 0.0
var _press_pos := Vector2.ZERO
var _dragging := false
var _moved := 0.0
var interactive := true
var auto_spin := 0.0
var labels: Dictionary = {}      # country id -> Label3D
var label_rank: Dictionary = {}  # country id -> label rank
var highlighted := ""
var _spin_tween: Tween
var _preview: MeshInstance3D
const INK := Color("1b2433")
const Style = preload("res://ui/style.gd")


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
	light.light_energy = 0.45
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.55
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
	mat.emission_energy_multiplier = 0.5
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
	halo_mat.albedo_color = Color(1, 1, 1, 0.0)
	halo_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.material_override = halo_mat
	halo.scale = Vector3(2, 2, 2)
	viewport.add_child(halo)

	home_marker = _marker(C_CYAN, 0.03)
	pin_marker = _pin_mesh()
	pin_marker.visible = false


## A map pin: needle + glowing head, pointing away from the globe surface.
func _pin_mesh() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = C_PINK
	var needle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.006
	cyl.bottom_radius = 0.002
	cyl.height = 0.16
	needle.mesh = cyl
	needle.position = Vector3(0, 0.08, 0)
	needle.material_override = mat
	root.add_child(needle)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	head.mesh = sm
	head.position = Vector3(0, 0.17, 0)
	head.material_override = mat
	root.add_child(head)
	pivot.add_child(root)
	return root


func _process(delta: float) -> void:
	if auto_spin != 0.0:
		yaw += auto_spin * delta
		_apply()
	_update_labels()


## Country name labels (Label3D). `countries` = id -> {name, lat, lon, rank}.
func add_country_labels(countries: Dictionary, lang: String) -> void:
	for id in countries:
		var c: Dictionary = countries[id]
		var l := Label3D.new()
		l.text = str(c["name"].get(lang, c["name"]["en"]))
		l.font = Style.font("display_md")
		l.font_size = 46
		l.pixel_size = 0.0008
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = INK
		l.outline_modulate = Color(1, 1, 1, 0.92)
		l.outline_size = 10
		l.position = Geo.lat_lon_to_vec(c["lat"], c["lon"]) * 1.01
		pivot.add_child(l)
		labels[id] = l
		label_rank[id] = int(c["rank"])


func _update_labels() -> void:
	if labels.is_empty():
		return
	var z := camera.position.z
	var max_rank := 2 if z > 3.1 else (3 if z > 2.6 else (4 if z > 2.2 else 6))
	var cam_dir := camera.global_position.normalized()
	# Greedy screen-space decluttering: important (low-rank) names first,
	# skip any label that would overlap one already placed.
	var placed: Array = []
	var order: Array = labels.keys()
	order.sort_custom(func(a, b): return (0 if a == highlighted else int(label_rank[a])) < (0 if b == highlighted else int(label_rank[b])))
	for id in order:
		var l: Label3D = labels[id]
		var world := pivot.global_transform * l.position
		var facing := world.normalized().dot(cam_dir)
		var wanted: bool = id == highlighted or int(label_rank[id]) <= max_rank
		if not wanted or facing < 0.3:
			l.visible = false
			continue
		var sp := camera.unproject_position(world)
		var half := Vector2(l.text.length() * 4.2 + 8.0, 12.0)
		var rect := Rect2(sp - half, half * 2.0)
		var clash := false
		for r in placed:
			if rect.intersects(r):
				clash = true
				break
		l.visible = not clash or id == highlighted
		if l.visible:
			placed.append(rect)

## Spin smoothly to a country, mark its name in red and pulse it.
func highlight_country(id: String, lat: float, lon: float) -> void:
	if highlighted != "" and labels.has(highlighted):
		var old: Label3D = labels[highlighted]
		old.modulate = INK
		old.font_size = 46
	highlighted = id
	if labels.has(id):
		var l: Label3D = labels[id]
		l.modulate = C_PINK
		l.font_size = 64
	spin_to(lat, lon)


func spin_to(lat: float, lon: float, duration := 0.7) -> void:
	var v := Geo.lat_lon_to_vec(lat, lon)
	var ty := -atan2(v.x, v.z)
	var tp := asin(clampf(v.y, -1.0, 1.0))
	while ty - yaw > PI:
		ty -= TAU
	while ty - yaw < -PI:
		ty += TAU
	if _spin_tween:
		_spin_tween.kill()
	_spin_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var y0 := yaw
	var p0 := pitch
	_spin_tween.tween_method(func(t: float):
		yaw = lerpf(y0, ty, t)
		pitch = lerpf(p0, tp, t)
		_apply(), 0.0, 1.0, duration)
	if camera.position.z > 3.0:
		create_tween().tween_property(camera, "position:z", 3.0, duration)


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


## Animate a flight: dashed great-circle arc, a moving plane marker, globe follows.
func fly(from_lat: float, from_lon: float, to_lat: float, to_lon: float, duration := 1.8) -> void:
	interactive = false
	var va := Geo.lat_lon_to_vec(from_lat, from_lon)
	var vb := Geo.lat_lon_to_vec(to_lat, to_lon)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = C_PINK
	var arc := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	arc.mesh = im
	arc.material_override = mat
	pivot.add_child(arc)
	var plane := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.03
	pm.height = 0.06
	plane.mesh = pm
	plane.material_override = mat
	pivot.add_child(plane)
	var path := func(t: float) -> Vector3:
		return va.slerp(vb, t).normalized() * (1.0 + 0.12 * sin(PI * t))
	var tw := create_tween()
	tw.tween_method(func(t: float):
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		var steps := 48
		for i in range(steps):
			var a := float(i) / steps
			var b := float(i + 1) / steps
			if a > t:
				break
			if i % 2 == 0:
				im.surface_add_vertex(path.call(a))
				im.surface_add_vertex(path.call(minf(b, t)))
		im.surface_end()
		var p: Vector3 = path.call(t)
		plane.position = p
		var n := p.normalized()
		yaw = -atan2(n.x, n.z)
		pitch = asin(clampf(n.y, -1.0, 1.0))
		_apply(), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func(): flight_done.emit())


## Spin the globe so (lat, lon) faces the camera and mark it as "you are here".
func focus(lat: float, lon: float) -> void:
	var v := Geo.lat_lon_to_vec(lat, lon)
	yaw = -atan2(v.x, v.z)
	pitch = asin(clampf(v.y, -1.0, 1.0))
	_apply()
	home_marker.position = v * 1.01


func clear_pin() -> void:
	pin_marker.visible = false
	if _preview:
		_preview.visible = false


func set_pin(lat: float, lon: float) -> void:
	var v := Geo.lat_lon_to_vec(lat, lon)
	pin_marker.position = v
	pin_marker.basis = Basis(Quaternion(Vector3.UP, v.normalized()))
	pin_marker.visible = true
	_draw_preview(home_marker.position.normalized(), v)


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


## Dashed preview arc from "you are here" to the dropped pin.
func _draw_preview(a: Vector3, b: Vector3) -> void:
	if a.length() < 0.5:
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.mesh = ImmediateMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(C_PINK, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_preview.material_override = m
		pivot.add_child(_preview)
	var im := _preview.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var steps := 40
	for i in range(0, steps, 2):
		for k in [i, i + 1]:
			var t := float(k) / steps
			im.surface_add_vertex(a.slerp(b, t).normalized() * (1.0 + 0.1 * sin(PI * t)))
	im.surface_end()
	_preview.visible = true


## Static recap of a whole journey: dashed arcs between stops and a dot per stop.
## `points` = [Vector2(lat, lon), ...]; wrong stops can be passed in `misses`.
func show_route(points: Array, misses: Array = []) -> void:
	if points.is_empty():
		return
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = C_PINK
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mi.mesh = im
	mi.material_override = line_mat
	pivot.add_child(mi)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in range(points.size() - 1):
		var a := Geo.lat_lon_to_vec(points[k].x, points[k].y)
		var b := Geo.lat_lon_to_vec(points[k + 1].x, points[k + 1].y)
		var steps := 30
		for i in range(0, steps, 2):
			for j in [i, i + 1]:
				var t := float(j) / steps
				im.surface_add_vertex(a.slerp(b, t).normalized() * (1.0 + 0.08 * sin(PI * t)))
	im.surface_end()
	for k in range(points.size()):
		var dot := _marker(Color("1f2f4d") if k > 0 else C_PINK, 0.03)
		dot.position = Geo.lat_lon_to_vec(points[k].x, points[k].y) * 1.01
	for m in misses:
		var x := _marker(Color("e5484d"), 0.022)
		x.position = Geo.lat_lon_to_vec(m.x, m.y) * 1.01
	# centre the view on the journey
	var mid := Vector3.ZERO
	for p in points:
		mid += Geo.lat_lon_to_vec(p.x, p.y)
	var ll := Geo.vec_to_lat_lon(mid if mid.length() > 0.01 else Geo.lat_lon_to_vec(points[0].x, points[0].y))
	focus(ll.x, ll.y)
	home_marker.visible = false
