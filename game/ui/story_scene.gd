## Short dialogue scene before / after a case (ADR-0015 §4): portrait, speaker, line.
## Tap or "Next" advances; "Skip" ends. Emits `finished` once.
extends PanelContainer

signal finished

const Style = preload("res://ui/style.gd")
const SuspectPortrait = preload("res://ui/suspect_portrait.gd")
const Fx = preload("res://ui/fx.gd")

var lines: Array = []      # [{"id": speaker id, "name": display name, "text": line}]
var index := 0
var next_text := "Next"
var last_text := "Start"
var _portrait: Control
var _name: Label
var _line: Label
var _next: Button
var _done := false
var _typing: Tween


func setup(p_lines: Array, p_next: String, p_last: String, skip_text: String) -> void:
	lines = p_lines
	next_text = p_next
	last_text = p_last
	var vp_w: float = get_viewport().get_visible_rect().size.x if is_inside_tree() else 1280.0
	var narrow := vp_w < 600.0
	custom_minimum_size = Vector2(minf(620.0, vp_w - 16.0), 0)
	add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 22, 16 if narrow else 24))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	_portrait = SuspectPortrait.new()
	_portrait.custom_minimum_size = Vector2(84, 100) if narrow else Vector2(110, 132)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 6)
	row.add_child(tv)
	_name = Label.new()
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_font_override("font", Style.font("ui_bold"))
	_name.add_theme_font_size_override("font_size", 13)
	_name.add_theme_color_override("font_color", Style.CORAL)
	tv.add_child(_name)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 17)
	_line.add_theme_color_override("font_color", Style.INK)
	tv.add_child(_line)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	col.add_child(bar)
	var skip := Button.new()
	skip.name = "SkipStory"
	skip.text = skip_text
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_color_override("font_color", Style.MUTED)
	skip.pressed.connect(_finish)
	bar.add_child(skip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	_next = Button.new()
	_next.name = "NextLine"
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size = Vector2(140, 46)
	Style.primary(_next)
	_next.pressed.connect(advance)
	bar.add_child(_next)
	_show()


func _show() -> void:
	if index >= lines.size():
		_finish()
		return
	var ln: Dictionary = lines[index]
	(_portrait as Control).call("setup", ln.get("portrait", {"id": "char_" + str(ln["id"]), "traits": {}}), false)
	_name.text = ln["name"]
	_line.text = ln["text"]
	_next.text = last_text if index == lines.size() - 1 else next_text
	_typing = Fx.type_in(_line)


## First tap while the line is still typing shows it whole; the next one moves on.
func advance() -> void:
	if _typing != null and _typing.is_valid() and _typing.is_running():
		_typing.kill()
		_line.visible_ratio = 1.0
		return
	index += 1
	_show()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
