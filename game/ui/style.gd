## Design system (ADR-0011): modern, light, warm. One coral accent, deep navy ink,
## sky-blue for "where" clues, rose for "who" clues. Fonts: Outfit (display),
## Inter (UI), JetBrains Mono (evidence). All static so screens share one look.
extends RefCounted

# --- palette
const BG := Color("f5f2ec")
const BG2 := Color("ebe6dd")
const SURFACE := Color("ffffff")
const SURFACE2 := Color("f8f6f2")
const LINE := Color("e3ddd2")
const INK := Color("1b2433")
const INK2 := Color("4a5568")
const MUTED := Color("8a94a6")
const CORAL := Color("ff5a3c")
const CORAL_DARK := Color("e0442a")
const NAVY := Color("1f2f4d")
const SKY := Color("2b7fff")
const ROSE := Color("e5484d")
const GOLD := Color("f2b233")
const GREEN := Color("1f9d6b")
const SHADOW := Color(0.106, 0.141, 0.2, 0.10)

static var _fonts := {}


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var spec: Array = {
		"display": ["res://assets/fonts/Outfit.ttf", 700],
		"display_md": ["res://assets/fonts/Outfit.ttf", 600],
		"ui": ["res://assets/fonts/Inter.ttf", 450],
		"ui_bold": ["res://assets/fonts/Inter.ttf", 650],
		"mono": ["res://assets/fonts/JetBrainsMono.ttf", 450],
	}[kind]
	var fv := FontVariation.new()
	fv.base_font = load(spec[0])
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: spec[1]}
	_fonts[kind] = fv
	return fv


static func box(bg: Color, radius := 16, pad := 16, border := Color.TRANSPARENT, bw := 0, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.border_color = border
	sb.set_border_width_all(bw)
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing = true
	return sb


static func pill(bg: Color, pad_h := 18, pad_v := 10, border := Color.TRANSPARENT, bw := 0) -> StyleBoxFlat:
	var sb := box(bg, 999, 0, border, bw, false)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font("ui")
	th.default_font_size = 17
	th.set_color("font_color", "Label", INK)
	# secondary button: white pill with line border
	th.set_stylebox("normal", "Button", pill(SURFACE, 18, 11, LINE, 1))
	th.set_stylebox("hover", "Button", pill(SURFACE2, 18, 11, INK2, 1))
	th.set_stylebox("pressed", "Button", pill(BG2, 18, 11, INK2, 1))
	th.set_stylebox("disabled", "Button", pill(Color(SURFACE, 0.6), 18, 11, LINE, 1))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", INK)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", MUTED)
	th.set_font("font", "Button", font("ui_bold"))
	th.set_stylebox("panel", "PanelContainer", box(SURFACE, 18, 18))
	# scrollbars: thin and subtle
	var grab := box(Color(INK, 0.18), 6, 0, Color.TRANSPARENT, 0, false)
	var track := StyleBoxEmpty.new()
	for sc in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("grabber", sc, grab)
		th.set_stylebox("grabber_highlight", sc, box(Color(INK, 0.3), 6, 0, Color.TRANSPARENT, 0, false))
		th.set_stylebox("grabber_pressed", sc, box(Color(INK, 0.4), 6, 0, Color.TRANSPARENT, 0, false))
		th.set_stylebox("scroll", sc, track)
	# slider (used by the wiretap tuner): round knob generated at runtime
	th.set_icon("grabber", "HSlider", _knob(30, SKY))
	th.set_icon("grabber_highlight", "HSlider", _knob(30, SKY.lightened(0.15)))
	th.set_icon("grabber_disabled", "HSlider", _knob(30, GREEN))
	th.set_stylebox("slider", "HSlider", box(BG2, 8, 6, Color.TRANSPARENT, 0, false))
	th.set_stylebox("grabber_area", "HSlider", box(SKY, 6, 4, Color.TRANSPARENT, 0, false))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(SKY, 6, 4, Color.TRANSPARENT, 0, false))
	return th


static func primary(b: Button, color := CORAL) -> void:
	b.add_theme_stylebox_override("normal", pill(color, 22, 13))
	b.add_theme_stylebox_override("hover", pill(color.lightened(0.08), 22, 13))
	b.add_theme_stylebox_override("pressed", pill(color.darkened(0.1), 22, 13))
	b.add_theme_stylebox_override("disabled", pill(Color(color, 0.35), 22, 13))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_font_override("font", font("display_md"))
	b.add_theme_font_size_override("font_size", 19)


static func _knob(px: int, color: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) / 2.0
	for y in range(px):
		for x in range(px):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(c.x - d, 0.0, 1.0)
			var col := Color.WHITE if d < c.x - 4.0 else color
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
