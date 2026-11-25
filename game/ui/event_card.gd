## Event card overlay (ADR-0015 §2): a surprise in the city, or the thief reacting.
## Two (or one) options with their cost written on the button. Emits `chosen(index)`.
extends PanelContainer

signal chosen(index: int)

const Style = preload("res://ui/style.gd")
const IconView = preload("res://ui/icon_view.gd")
const Sfx = preload("res://ui/sfx.gd")

var options: Array = []
var _done := false


## card = {"title", "text", "options": [{"label"}]} already translated to plain strings;
## `reaction` = the thief reacts (darker card).
func setup(tag: String, title: String, text: String, labels: Array, reaction := false) -> void:
	options = labels
	var vp_w: float = get_viewport().get_visible_rect().size.x if is_inside_tree() else 1280.0
	var narrow := vp_w < 600.0
	custom_minimum_size = Vector2(minf(560.0, vp_w - 16.0), 0)
	var bg: Color = Style.NAVY if reaction else Style.SURFACE
	var ink: Color = Color.WHITE if reaction else Style.INK
	add_theme_stylebox_override("panel", Style.box(bg, 22, 16 if narrow else 24))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var ic := IconView.new()
	ic.setup("cuffs" if reaction else "clock", Style.CORAL, 30)
	head.add_child(ic)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	_text(hv, tag, "ui_bold", 12, Style.CORAL if not reaction else Color("ffb59e"))
	_text(hv, title, "display", 22 if narrow else 26, ink)
	_text(col, text, "ui", 16, Color(1, 1, 1, 0.85) if reaction else Style.INK2)
	for k in range(labels.size()):
		var b := Button.new()
		b.name = "Option%d" % k
		b.text = labels[k]
		b.focus_mode = Control.FOCUS_NONE
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 15)
		if k == 0:
			Style.primary(b, Style.CORAL)
		b.pressed.connect(choose.bind(k))
		col.add_child(b)
	Sfx.play("alert", -6.0)


func choose(k: int) -> void:
	if _done:
		return
	_done = true
	chosen.emit(k)


func _text(parent: Control, s: String, f: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Style.font(f))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
