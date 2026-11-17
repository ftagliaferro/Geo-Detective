## Guided-tutorial layer (ADR-0014): a speech bubble plus a pulsing spotlight on the
## control the player should press next. It never blocks the game: taps go through to
## the real buttons; only the bubble itself catches touches.
extends Control

signal ok_pressed
signal skip_pressed

const Style = preload("res://ui/style.gd")

var target: Control = null
var step_id := ""
var _bubble: PanelContainer
var _tag: Label
var _text: Label
var _ok: Button
var _skip: Button
var _t := 0.0
var _step_frames := 0     # frames since the step appeared (scroll target into view meanwhile)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_bubble = PanelContainer.new()
	_bubble.name = "CoachBubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.add_theme_stylebox_override("panel", Style.box(Style.NAVY, 18, 16, Color.TRANSPARENT, 0, true))
	add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_bubble.add_child(v)
	_tag = Label.new()
	_tag.add_theme_font_override("font", Style.font("ui_bold"))
	_tag.add_theme_font_size_override("font_size", 12)
	_tag.add_theme_color_override("font_color", Color("ffb59e"))
	v.add_child(_tag)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_skip = Button.new()
	_skip.name = "CoachSkip"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.flat = true
	_skip.add_theme_font_size_override("font_size", 13)
	_skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_skip.add_theme_color_override("font_hover_color", Color.WHITE)
	_skip.pressed.connect(func(): skip_pressed.emit())
	row.add_child(_skip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_ok = Button.new()
	_ok.name = "CoachOk"
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.custom_minimum_size = Vector2(120, 44)
	Style.primary(_ok)
	_ok.pressed.connect(func(): ok_pressed.emit())
	row.add_child(_ok)


## Show a step. `p_target` = control to spotlight (or null); `ok_text` = "" for steps
## that finish when the player does the action, or a label for "read this" steps.
func show_step(id: String, tag: String, text: String, p_target: Control, ok_text: String, skip_text: String) -> void:
	var same := id == step_id and visible
	step_id = id
	target = p_target
	_tag.text = tag
	_text.text = text
	_ok.text = ok_text
	_ok.visible = ok_text != ""
	_skip.text = skip_text
	visible = true
	if not same:
		_step_frames = 0
		_bubble.modulate.a = 0.0
		_bubble.create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.2)
	_place()


func hide_step() -> void:
	visible = false
	step_id = ""
	target = null


func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_step_frames += 1
	if _target_ok() and _step_frames <= 30:
		# Layout may still settle during the first frames: keep the target inside its page.
		var p := target.get_parent()
		while p != null and not (p is ScrollContainer):
			p = p.get_parent()
		if p is ScrollContainer and not (p as ScrollContainer).get_global_rect().encloses(target.get_global_rect()):
			(p as ScrollContainer).ensure_control_visible(target)
	_place()
	queue_redraw()


## Put the bubble where it does not cover the target: try the free side columns
## (landscape / desktop) and the top and bottom bands, keep the first that stays clear.
func _place() -> void:
	var vp := get_viewport_rect().size
	var tall := vp.y > 600.0
	var top_y := 64.0 if tall else 8.0
	var bottom_gap := 56.0 if tall else 8.0
	var center_w := minf(460.0, vp.x - 16.0)
	var side_w := minf(420.0, vp.x * 0.46)
	var cands: Array = []   # [x, y_mode, width]
	if vp.x > vp.y * 1.2:
		cands += [[vp.x - side_w - 12.0, "bottom", side_w], [vp.x - side_w - 12.0, "top", side_w],
			[12.0, "bottom", side_w], [12.0, "top", side_w]]
	cands += [[(vp.x - center_w) / 2.0, "bottom", center_w], [(vp.x - center_w) / 2.0, "top", center_w]]
	var tr := _target_rect().grow(10.0) if _target_ok() else Rect2()
	var best := Rect2()
	var best_overlap := INF
	for c in cands:
		var w: float = c[2]
		_bubble.custom_minimum_size = Vector2(w, 0)
		_bubble.reset_size()
		var h := _bubble.get_combined_minimum_size().y
		var y: float = top_y if c[1] == "top" else vp.y - h - bottom_gap
		y = clampf(y, 8.0, maxf(8.0, vp.y - h - 8.0))
		var r := Rect2(c[0], y, w, h)
		var overlap := r.intersection(tr).get_area() if _target_ok() and r.intersects(tr) else 0.0
		if overlap < best_overlap:
			best_overlap = overlap
			best = r
		if overlap <= 0.0:
			break
	_bubble.custom_minimum_size = Vector2(best.size.x, 0)
	_bubble.reset_size()
	_bubble.position = best.position


func _target_rect() -> Rect2:
	var r := target.get_global_rect()
	return Rect2(r.position - global_position, r.size)


func _draw() -> void:
	if not _target_ok():
		return
	var r := _target_rect().grow(6.0)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var c := Style.CORAL
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(c, 0.95)
	sb.shadow_color = Color(c, 0.25 + 0.35 * pulse)
	sb.shadow_size = int(6 + 10 * pulse)
	draw_style_box(sb, r)
	var outer := StyleBoxFlat.new()
	outer.draw_center = false
	outer.set_corner_radius_all(22)
	outer.set_border_width_all(2)
	outer.border_color = Color(c, 0.5 * (1.0 - pulse))
	draw_style_box(outer, r.grow(4.0 + 8.0 * pulse))
