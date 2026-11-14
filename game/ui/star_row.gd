## Row of 3 drawn stars (filled = earned).
extends Control

var earned := 0
var star_color := Color("d9a441")


func setup(p_earned: int, p_size := 36.0) -> void:
	earned = p_earned
	custom_minimum_size = Vector2(p_size * 3.4, p_size)
	queue_redraw()


func _star(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return pts


func _draw() -> void:
	var r := size.y * 0.48
	for i in range(3):
		var pts := _star(Vector2(r + i * r * 2.3, size.y / 2.0), r)
		if i < earned:
			draw_colored_polygon(pts, star_color)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(star_color, 0.5), 2.0)
