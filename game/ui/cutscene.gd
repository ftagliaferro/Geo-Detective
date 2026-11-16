## Short animated vignettes drawn in code (no image assets): the thief escaping.
## Kinds: heist, plane, car, rooftop, arrest, safehouse. Click/tap to skip.
## The thief is a recurring character: fedora, dark trench coat, coral scarf.
extends Control

signal finished

const Style = preload("res://ui/style.gd")
const Sfx = preload("res://ui/sfx.gd")
const INK := Color("1b2433")

var kind := "plane"
var caption := ""
var seed_key := ""
var duration := 3.2
var t := 0.0
var done := false
var loop := false   # hero banners: repeat forever, no caption, not clickable
var _sky_top := Color("ffb39a")
var _sky_bottom := Color("ffe6c7")
var _layers: Array = []   # [[color, speed, [building rects...]], ...]
var _caption_label: Label


func setup(p_kind: String, p_caption: String, p_seed_key: String) -> void:
	kind = p_kind
	caption = p_caption
	seed_key = p_seed_key
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var night := kind in ["heist", "rooftop", "arrest"]
	_sky_top = Color("1f2f4d") if night else Color("ff9f7a")
	_sky_bottom = Color("40598a") if night else Color("ffe3bf")
	_build_skyline(night)
	_caption_label = Label.new()
	_caption_label.text = caption
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.add_theme_font_override("font", Style.font("display_md"))
	_caption_label.add_theme_font_size_override("font_size", 24)
	_caption_label.add_theme_color_override("font_color", Color.WHITE)
	_caption_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_caption_label.add_theme_constant_override("outline_size", 8)
	_caption_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption_label.offset_top = -64
	_caption_label.offset_bottom = -18
	_caption_label.offset_left = 24
	_caption_label.offset_right = -24
	_caption_label.visible_ratio = 0.0
	add_child(_caption_label)
	if not loop:
		_play_sound()


func _play_sound() -> void:
	match kind:
		"plane": Sfx.play("plane")
		"arrest": Sfx.play("siren", -4.0)
		"safehouse": Sfx.play("success", -3.0)
		_: Sfx.play("whoosh", -4.0)


func _build_skyline(night: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)
	var palettes := [
		[Color("2c3e66") if night else Color("f4a582"), 0.25],
		[Color("22324f") if night else Color("e98a6b"), 0.5],
		[Color("172236") if night else Color("c96e5a"), 0.9],
	]
	_layers.clear()
	for li in range(palettes.size()):
		var rects: Array = []
		var x := -40.0
		while x < 2600.0:
			var w := rng.randf_range(50, 130)
			var h := rng.randf_range(80, 220) * (0.6 + li * 0.25)
			var roof := rng.randi_range(0, 3)
			rects.append([x, w, h, roof, rng.randi()])
			x += w + rng.randf_range(4, 18)
		_layers.append([palettes[li][0], palettes[li][1], rects])


func _gui_input(event: InputEvent) -> void:
	if loop:
		return
	if event is InputEventMouseButton and event.pressed:
		_finish()
		accept_event()


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	if loop:
		t = fmod(t, duration)
		queue_redraw()
		return
	_caption_label.visible_ratio = clampf(t / 1.2, 0.0, 1.0)
	queue_redraw()
	if t >= duration:
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	finished.emit()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([_sky_top, _sky_top, _sky_bottom, _sky_bottom]))
	var night := kind in ["heist", "rooftop", "arrest"]
	if night:
		draw_circle(Vector2(w * 0.82, h * 0.2), 34, Color("fdf3d8"))
		draw_circle(Vector2(w * 0.82 + 12, h * 0.2 - 8), 30, _sky_top)
	else:
		draw_circle(Vector2(w * 0.78, h * 0.5), 70, Color("fff1d6"))
	var ground := h * 0.78
	var scroll := t * 120.0 if kind in ["car", "heist", "rooftop"] else t * 25.0
	for layer in _layers:
		var col: Color = layer[0]
		var speed: float = layer[1]
		for r in layer[2]:
			var x: float = fmod(r[0] - scroll * speed + 2600.0, 2600.0) - 100.0
			if x > w + 20 or x + r[1] < -20:
				continue
			var top: float = ground - r[2]
			draw_rect(Rect2(x, top, r[1], r[2]), col)
			if r[3] == 1:
				draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + r[1] / 2.0, top - 26), Vector2(x + r[1], top)]), col)
			elif r[3] == 2:
				draw_rect(Rect2(x + r[1] * 0.4, top - 30, 6, 30), col)
			if night and speed > 0.4:
				var wr := RandomNumberGenerator.new()
				wr.seed = r[4]
				for wy in range(int(top) + 12, int(ground) - 10, 22):
					for wx in range(int(x) + 8, int(x + r[1]) - 10, 18):
						if wr.randf() < 0.35:
							draw_rect(Rect2(wx, wy, 8, 10), Color("ffd98a", 0.85))
	draw_rect(Rect2(0, ground, w, h - ground), Color("1b2433") if night else Color("8c4f45"))

	match kind:
		"heist", "rooftop":
			_draw_rooftop_run(w, ground)
		"plane":
			_draw_plane_escape(w, ground)
		"car":
			_draw_car_escape(w, ground)
		"arrest":
			_draw_arrest(w, ground)
		"safehouse":
			_draw_safehouse(w, ground)
	# letterbox bars for a cinematic feel
	draw_rect(Rect2(0, 0, w, 18), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(0, h - 10, w, 10), Color(0, 0, 0, 0.85))


## The thief: fedora, trench coat, coral scarf. `phase` animates legs and arms.
func draw_thief(pos: Vector2, u: float, phase: float, running := true, bag := false, hands_up := false, tint := Color(0, 0, 0, 0)) -> void:
	var ink: Color = tint if tint.a > 0.0 else INK
	var rim := tint.a > 0.0
	var swing := sin(phase) * (0.55 if running else 0.0)
	var hip := pos + Vector2(0, -0.32 * u)
	# legs
	for s in [1, -1]:
		var a: float = swing * s
		var knee := hip + Vector2(sin(a) * 0.17 * u, 0.16 * u)
		var foot := knee + Vector2(sin(a * 1.4) * 0.15 * u, 0.16 * u)
		draw_line(hip, knee, ink, u * 0.07)
		draw_line(knee, foot, ink, u * 0.07)
		draw_line(foot, foot + Vector2(0.06 * u, 0), ink, u * 0.06)
	# coat
	var lean := 0.08 * u if running else 0.0
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-0.13 * u + lean, -0.74 * u), pos + Vector2(0.13 * u + lean, -0.74 * u),
		pos + Vector2(0.2 * u, -0.26 * u), pos + Vector2(-0.18 * u, -0.26 * u)]), ink)
	# arms
	var shoulder := pos + Vector2(lean, -0.7 * u)
	if hands_up:
		draw_line(shoulder, shoulder + Vector2(-0.18 * u, -0.28 * u), ink, u * 0.07)
		draw_line(shoulder, shoulder + Vector2(0.18 * u, -0.28 * u), ink, u * 0.07)
	else:
		var hand_f := shoulder + Vector2(sin(-swing) * 0.26 * u, 0.3 * u)
		var hand_b := shoulder + Vector2(sin(swing) * 0.26 * u, 0.3 * u)
		draw_line(shoulder, hand_f, ink, u * 0.07)
		draw_line(shoulder, hand_b, ink, u * 0.07)
		if bag and not rim:
			draw_circle(hand_f + Vector2(0, 0.08 * u), 0.1 * u, Color("c9a26b"))
			draw_string(Style.font("display"), hand_f + Vector2(-0.05 * u, 0.13 * u), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.14 * u), Color("5a3d1e"))
	# scarf (coral signature) and head
	var neck := pos + Vector2(lean, -0.78 * u)
	draw_rect(Rect2(neck.x - 0.08 * u, neck.y - 0.02 * u, 0.16 * u, 0.06 * u), ink if rim else Style.CORAL)
	var tail := neck + Vector2(-0.22 * u, 0.02 * u + sin(phase * 1.3) * 0.04 * u)
	draw_line(neck + Vector2(-0.06 * u, 0.02 * u), tail, ink if rim else Style.CORAL, u * 0.05)
	var head := pos + Vector2(lean + 0.01 * u, -0.88 * u)
	draw_circle(head, 0.085 * u, ink)
	# fedora
	draw_rect(Rect2(head.x - 0.16 * u, head.y - 0.07 * u, 0.32 * u, 0.035 * u), ink)
	draw_rect(Rect2(head.x - 0.09 * u, head.y - 0.17 * u, 0.18 * u, 0.11 * u), ink)
	draw_rect(Rect2(head.x - 0.09 * u, head.y - 0.085 * u, 0.18 * u, 0.02 * u), ink if rim else Style.CORAL)


func _draw_rooftop_run(w: float, ground: float) -> void:
	var u := 130.0
	var roof := size.y * 0.62
	# foreground rooftop the thief runs on (scrolls fast), with ledge and vents
	draw_rect(Rect2(0, roof, w, size.y - roof), Color("2c3e66"))
	draw_rect(Rect2(0, roof, w, 6), Color("5b74a6"))
	for i in range(6):
		var vx := fmod(i * 260.0 - t * 260.0 + 3000.0, w + 200.0) - 100.0
		draw_rect(Rect2(vx, roof - 26, 34, 26), Color("22324f"))
		draw_rect(Rect2(vx - 4, roof - 30, 42, 6), Color("5b74a6"))
	var x := lerpf(-60, w + 60, t / duration)
	var jump := absf(sin(t * 2.2)) * 40.0
	# moonlight rim so the dark silhouette reads against the night
	draw_thief(Vector2(x + 3, roof - jump - 2), u * 1.04, t * 14.0, true, kind == "heist", false, Color("9fb4dd"))
	draw_thief(Vector2(x, roof - jump), u, t * 14.0, true, kind == "heist")
	# searchlight
	var sx := w * 0.3 + sin(t * 1.4) * w * 0.25
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.15, ground), Vector2(sx - 60, 0), Vector2(sx + 60, 0)]), Color(1, 1, 0.85, 0.12))


func _draw_plane_escape(w: float, ground: float) -> void:
	var u := 110.0
	var p := t / duration
	# runway
	draw_rect(Rect2(0, ground - 6, w, 6), Color("5a5e66"))
	for i in range(0, int(w), 70):
		draw_rect(Rect2(fmod(i - t * 200.0 + w, w), ground - 4, 34, 2), Color.WHITE)
	# plane position: rolls then lifts off
	var px := lerpf(w * 0.15, w * 1.15, p)
	var lift := maxf(0.0, p - 0.35) * 380.0
	var pc := Vector2(px, ground - 40 - lift)
	var tilt := -0.18 if lift > 0 else 0.0
	draw_set_transform(pc, tilt, Vector2.ONE)
	draw_rect(Rect2(-130, -18, 260, 36), Color.WHITE)
	draw_circle(Vector2(130, 0), 18, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(-130, -18), Vector2(-170, -62), Vector2(-140, -62), Vector2(-100, -18)]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 6), Vector2(-70, 60), Vector2(-30, 60), Vector2(40, 6)]), Color("dfe5ee"))
	draw_rect(Rect2(-130, 2, 260, 6), Style.CORAL)
	for i in range(8):
		draw_circle(Vector2(-90 + i * 26, -6), 4.5, Color("1b2433"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# the thief waves from the stairs at the start
	if p < 0.3:
		draw_thief(Vector2(lerpf(w * 0.02, w * 0.12, p / 0.3), ground), u, t * 14.0, true, true)


func _draw_car_escape(w: float, ground: float) -> void:
	var cx := lerpf(-200, w + 200, t / duration)
	var cy := ground - 28
	for i in range(5):
		draw_line(Vector2(cx - 150 - i * 30, cy - 10 + i * 6), Vector2(cx - 220 - i * 30, cy - 10 + i * 6), Color(1, 1, 1, 0.6), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 110, cy), Vector2(cx - 100, cy - 34), Vector2(cx - 40, cy - 38),
		Vector2(cx - 15, cy - 70), Vector2(cx + 55, cy - 70), Vector2(cx + 85, cy - 38), Vector2(cx + 120, cy - 32), Vector2(cx + 125, cy)]), Style.CORAL)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, cy - 40), Vector2(cx + 10, cy - 64), Vector2(cx + 50, cy - 64), Vector2(cx + 72, cy - 40)]), Color("bfe3ff"))
	# thief at the wheel (just the hat)
	draw_rect(Rect2(cx + 22, cy - 62, 22, 8), INK)
	draw_rect(Rect2(cx + 16, cy - 56, 34, 4), INK)
	for wx in [cx - 70, cx + 80]:
		draw_circle(Vector2(wx, cy), 22, Color("1b2433"))
		draw_circle(Vector2(wx, cy), 9, Color("c9ced6"))
	draw_circle(Vector2(cx + 122, cy - 22), 6, Color("fff3b0"))


func _draw_arrest(w: float, ground: float) -> void:
	var on := fmod(t, 0.5) < 0.25
	draw_circle(Vector2(w * 0.25, ground - 120), 160, Color(1, 0.15, 0.2, 0.22 if on else 0.05))
	draw_circle(Vector2(w * 0.75, ground - 120), 160, Color(0.15, 0.35, 1, 0.05 if on else 0.22))
	draw_thief(Vector2(w * 0.5, ground), 150.0, 0.0, false, false, true)
	# handcuffs icon
	var c := Vector2(w * 0.5, ground - 210)
	draw_arc(c + Vector2(-16, 0), 12, 0, TAU, 20, Color("c9ced6"), 5)
	draw_arc(c + Vector2(16, 0), 12, 0, TAU, 20, Color("c9ced6"), 5)


func _draw_safehouse(w: float, ground: float) -> void:
	var door := Vector2(w * 0.68, ground)
	draw_rect(Rect2(door.x - 140, ground - 230, 280, 230), Color("6b4a3a"))
	draw_rect(Rect2(door.x - 36, ground - 120, 72, 120), Color("2b1d17"))
	var p := clampf(t / (duration * 0.8), 0.0, 1.0)
	var open := clampf((p - 0.55) * 4.0, 0.0, 1.0)
	draw_rect(Rect2(door.x - 36, ground - 120, 72 * (1.0 - open), 120), Color("8a5a3c"))
	draw_rect(Rect2(door.x - 36, ground - 120, 72, 120).grow(2), Color("3a2a20"), false, 3)
	if p < 0.95:
		draw_thief(Vector2(lerpf(-40, door.x, minf(p * 1.4, 1.0)), ground), 120.0, t * 12.0, p < 0.7, true)
	draw_rect(Rect2(door.x - 60, ground - 160, 120, 24), Style.GOLD)
