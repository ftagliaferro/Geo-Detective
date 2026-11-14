## Simple vector icons drawn in code (no image assets needed).
extends Control

var kind := "wiretap"
var color := Color("ece7dc")
var line := 3.0


func setup(p_kind: String, p_color: Color, p_size := 40.0) -> void:
	kind = p_kind
	color = p_color
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var c := o + Vector2(s, s) / 2.0
	var w := maxf(2.0, s * 0.07)
	match kind:
		"wiretap":  # headphones
			draw_arc(c + Vector2(0, s * 0.05), s * 0.32, PI, TAU, 24, color, w)
			draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.02), Vector2(s * 0.16, s * 0.3)), color)
			draw_rect(Rect2(c + Vector2(s * 0.24, s * 0.02), Vector2(s * 0.16, s * 0.3)), color)
		"cctv":  # camera
			draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.22), Vector2(s * 0.8, s * 0.5)), color)
			draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.34), Vector2(s * 0.3, s * 0.12)), color)
			draw_circle(c + Vector2(0, s * 0.03), s * 0.17, Color(0, 0, 0, 0.55))
			draw_circle(c + Vector2(0, s * 0.03), s * 0.1, color)
		"contact":  # person with hat
			draw_circle(c + Vector2(0, -s * 0.08), s * 0.16, color)
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.26), Vector2(s * 0.6, s * 0.06)), color)
			draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.42), Vector2(s * 0.32, s * 0.18)), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.36, s * 0.42), c + Vector2(-s * 0.28, s * 0.14), c + Vector2(s * 0.28, s * 0.14), c + Vector2(s * 0.36, s * 0.42)]), color)
		"money":  # coins
			for i in range(3):
				draw_rect(Rect2(c + Vector2(-s * 0.3, s * (0.2 - i * 0.14)), Vector2(s * 0.36, s * 0.11)), color)
			draw_circle(c + Vector2(s * 0.2, -s * 0.12), s * 0.2, color)
			draw_circle(c + Vector2(s * 0.2, -s * 0.12), s * 0.12, Color(0, 0, 0, 0.35))
		"globe":
			draw_arc(c, s * 0.38, 0, TAU, 32, color, w)
			draw_line(c + Vector2(-s * 0.38, 0), c + Vector2(s * 0.38, 0), color, w * 0.7)
			draw_arc(c, s * 0.38, 0, TAU, 32, color, w)
			for k in [0.18, -0.18]:
				draw_line(c + Vector2(-s * 0.33, s * k), c + Vector2(s * 0.33, s * k), color, w * 0.5)
			draw_set_transform(c, 0, Vector2(0.45, 1.0))
			draw_arc(Vector2.ZERO, s * 0.38, 0, TAU, 32, color, w * 1.4)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"board":  # pinned cards
			draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.32), Vector2(s * 0.8, s * 0.64)), color, false, w)
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.2), Vector2(s * 0.24, s * 0.28)), color)
			draw_rect(Rect2(c + Vector2(s * 0.06, -s * 0.12), Vector2(s * 0.24, s * 0.28)), color)
			draw_line(c + Vector2(-s * 0.18, -s * 0.06), c + Vector2(s * 0.18, s * 0.02), Color("c0392b"), w)
		"notebook":
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.38), Vector2(s * 0.6, s * 0.76)), color, false, w)
			for k in range(4):
				draw_line(c + Vector2(-s * 0.18, -s * 0.2 + k * s * 0.14), c + Vector2(s * 0.2, -s * 0.2 + k * s * 0.14), color, w * 0.6)
		"cuffs":
			draw_arc(c + Vector2(-s * 0.18, s * 0.08), s * 0.18, 0, TAU, 20, color, w)
			draw_arc(c + Vector2(s * 0.18, s * 0.08), s * 0.18, 0, TAU, 20, color, w)
			draw_line(c + Vector2(-s * 0.05, -s * 0.12), c + Vector2(s * 0.05, -s * 0.12), color, w)
		"clock":
			draw_arc(c, s * 0.38, 0, TAU, 32, color, w)
			draw_line(c, c + Vector2(0, -s * 0.24), color, w)
			draw_line(c, c + Vector2(s * 0.18, 0), color, w)
		_:
			draw_circle(c, s * 0.3, color)
