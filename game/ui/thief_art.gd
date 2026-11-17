## Draws the recurring thief character (fedora, trench coat, coral scarf) on any CanvasItem.
## Shared by cutscenes and the rooftop chase. `tint` draws a flat silhouette (rim light / police).
extends RefCounted

const Style = preload("res://ui/style.gd")
const INK := Color("1b2433")


static func draw(ci: CanvasItem, pos: Vector2, u: float, phase: float, running := true, bag := false, hands_up := false, tint := Color(0, 0, 0, 0)) -> void:
	var ink: Color = tint if tint.a > 0.0 else INK
	var rim := tint.a > 0.0
	var swing := sin(phase) * (0.55 if running else 0.0)
	var hip := pos + Vector2(0, -0.32 * u)
	# legs
	for s in [1, -1]:
		var a: float = swing * s
		var knee := hip + Vector2(sin(a) * 0.17 * u, 0.16 * u)
		var foot := knee + Vector2(sin(a * 1.4) * 0.15 * u, 0.16 * u)
		ci.draw_line(hip, knee, ink, u * 0.07)
		ci.draw_line(knee, foot, ink, u * 0.07)
		ci.draw_line(foot, foot + Vector2(0.06 * u, 0), ink, u * 0.06)
	# coat
	var lean := 0.08 * u if running else 0.0
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-0.13 * u + lean, -0.74 * u), pos + Vector2(0.13 * u + lean, -0.74 * u),
		pos + Vector2(0.2 * u, -0.26 * u), pos + Vector2(-0.18 * u, -0.26 * u)]), ink)
	# arms
	var shoulder := pos + Vector2(lean, -0.7 * u)
	if hands_up:
		ci.draw_line(shoulder, shoulder + Vector2(-0.18 * u, -0.28 * u), ink, u * 0.07)
		ci.draw_line(shoulder, shoulder + Vector2(0.18 * u, -0.28 * u), ink, u * 0.07)
	else:
		var hand_f := shoulder + Vector2(sin(-swing) * 0.26 * u, 0.3 * u)
		var hand_b := shoulder + Vector2(sin(swing) * 0.26 * u, 0.3 * u)
		ci.draw_line(shoulder, hand_f, ink, u * 0.07)
		ci.draw_line(shoulder, hand_b, ink, u * 0.07)
		if bag and not rim:
			ci.draw_circle(hand_f + Vector2(0, 0.08 * u), 0.1 * u, Color("c9a26b"))
			if int(0.14 * u) >= 1:   # first frame can have zero size (font size 0 is an engine error)
				ci.draw_string(Style.font("display"), hand_f + Vector2(-0.05 * u, 0.13 * u), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.14 * u), Color("5a3d1e"))
	# scarf (coral signature) and head
	var neck := pos + Vector2(lean, -0.78 * u)
	ci.draw_rect(Rect2(neck.x - 0.08 * u, neck.y - 0.02 * u, 0.16 * u, 0.06 * u), ink if rim else Style.CORAL)
	var tail := neck + Vector2(-0.22 * u, 0.02 * u + sin(phase * 1.3) * 0.04 * u)
	ci.draw_line(neck + Vector2(-0.06 * u, 0.02 * u), tail, ink if rim else Style.CORAL, u * 0.05)
	var head := pos + Vector2(lean + 0.01 * u, -0.88 * u)
	ci.draw_circle(head, 0.085 * u, ink)
	# fedora
	ci.draw_rect(Rect2(head.x - 0.16 * u, head.y - 0.07 * u, 0.32 * u, 0.035 * u), ink)
	ci.draw_rect(Rect2(head.x - 0.09 * u, head.y - 0.17 * u, 0.18 * u, 0.11 * u), ink)
	ci.draw_rect(Rect2(head.x - 0.09 * u, head.y - 0.085 * u, 0.18 * u, 0.02 * u), ink if rim else Style.CORAL)

