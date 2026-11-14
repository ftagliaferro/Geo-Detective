## Procedural mugshot-style portrait for a suspect. Deterministic per suspect id;
## visible traits (glasses, scar, red scarf, tattoo) are drawn so the art supports deduction.
extends Control

const SKIN := [Color("f1d3b3"), Color("e0b48c"), Color("c68e63"), Color("8d5a3b"), Color("5c3a24")]
const HAIR := [Color("1d1a17"), Color("4a3123"), Color("8a5a2b"), Color("c9a16b"), Color("9a9a9a"), Color("6b1f1a")]
const COAT := [Color("2f3b4a"), Color("4a3b2f"), Color("3d4a3a"), Color("5a5a5a"), Color("2a2a33"), Color("6a4a3a")]

var suspect: Dictionary = {}
var crossed := false


func setup(p_suspect: Dictionary, p_crossed := false) -> void:
	suspect = p_suspect
	crossed = p_crossed
	queue_redraw()


func _pick(arr: Array, salt: int) -> Variant:
	return arr[abs(hash(str(suspect.get("id", "")) + str(salt))) % arr.size()]


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("cfd3d6"))
	# height chart lines, like a booking photo
	for i in range(1, 6):
		var y := h * i / 6.0
		draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.12), 1.0)
	var traits: Dictionary = suspect.get("traits", {})
	var skin: Color = _pick(SKIN, 1)
	var hair: Color = _pick(HAIR, 2)
	var coat: Color = _pick(COAT, 3)
	var hair_style: int = abs(hash(str(suspect.get("id", "")) + "4")) % 4
	var hat: bool = abs(hash(str(suspect.get("id", "")) + "5")) % 3 == 0
	var cx := w * 0.5
	var head_r := w * 0.2
	var head_c := Vector2(cx, h * 0.42)

	# shoulders / coat
	var shoulders := PackedVector2Array([
		Vector2(cx - w * 0.42, h), Vector2(cx - w * 0.36, h * 0.74), Vector2(cx - w * 0.1, h * 0.66),
		Vector2(cx + w * 0.1, h * 0.66), Vector2(cx + w * 0.36, h * 0.74), Vector2(cx + w * 0.42, h)])
	draw_colored_polygon(shoulders, coat)
	# collar
	draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.1, h * 0.66), Vector2(cx, h * 0.8), Vector2(cx + w * 0.1, h * 0.66)]), Color("e8e4dc"))
	# neck
	draw_rect(Rect2(cx - w * 0.06, h * 0.55, w * 0.12, h * 0.13), skin.darkened(0.08))
	if traits.get("mark") == "red_scarf":
		draw_rect(Rect2(cx - w * 0.14, h * 0.62, w * 0.28, h * 0.07), Color("b3261e"))
		draw_colored_polygon(PackedVector2Array([Vector2(cx + w * 0.02, h * 0.68), Vector2(cx + w * 0.12, h * 0.68), Vector2(cx + w * 0.09, h * 0.82)]), Color("b3261e"))
	if traits.get("mark") == "tattoo":
		for i in range(3):
			draw_line(Vector2(cx - w * 0.05 + i * w * 0.035, h * 0.58), Vector2(cx - w * 0.03 + i * w * 0.035, h * 0.63), Color("2c3e50"), 2.0)

	# long hair behind head
	if hair_style == 2:
		draw_rect(Rect2(head_c.x - head_r * 1.05, head_c.y - head_r * 0.2, head_r * 2.1, head_r * 1.5), hair)
	# head
	draw_circle(head_c, head_r, skin)
	# hair on top
	if hair_style != 3:
		draw_arc(head_c, head_r * 0.92, PI * 1.05, PI * 1.95, 24, hair, head_r * 0.45)
	if hat:
		draw_rect(Rect2(head_c.x - head_r * 1.5, head_c.y - head_r * 0.85, head_r * 3.0, head_r * 0.22), Color("262626"))
		draw_rect(Rect2(head_c.x - head_r * 0.95, head_c.y - head_r * 1.6, head_r * 1.9, head_r * 0.8), Color("262626"))
		draw_rect(Rect2(head_c.x - head_r * 0.95, head_c.y - head_r * 0.98, head_r * 1.9, head_r * 0.14), Color("7a2a24"))
	# eyes, brows, mouth
	var eye_y := head_c.y + head_r * 0.05
	for sx in [-1, 1]:
		draw_circle(Vector2(head_c.x + sx * head_r * 0.38, eye_y), max(1.5, head_r * 0.08), Color("1d1a17"))
		draw_line(Vector2(head_c.x + sx * head_r * 0.2, eye_y - head_r * 0.25), Vector2(head_c.x + sx * head_r * 0.55, eye_y - head_r * 0.28), hair.darkened(0.2), 2.0)
	draw_line(Vector2(head_c.x - head_r * 0.25, head_c.y + head_r * 0.5), Vector2(head_c.x + head_r * 0.25, head_c.y + head_r * 0.5), Color("7a3b2e"), 2.0)
	if traits.get("mark") == "glasses":
		for sx in [-1, 1]:
			draw_arc(Vector2(head_c.x + sx * head_r * 0.38, eye_y), head_r * 0.24, 0, TAU, 20, Color("3b2a1a"), 2.0)
		draw_line(Vector2(head_c.x - head_r * 0.14, eye_y), Vector2(head_c.x + head_r * 0.14, eye_y), Color("3b2a1a"), 2.0)
	if traits.get("mark") == "scar":
		draw_line(Vector2(head_c.x + head_r * 0.25, eye_y - head_r * 0.45), Vector2(head_c.x + head_r * 0.6, eye_y - head_r * 0.05), Color("a0322a"), 2.0)
	if traits.get("mark") == "gold_ring":
		draw_circle(Vector2(cx + w * 0.3, h * 0.92), max(3.0, w * 0.045), Color("d4a017"))
		draw_circle(Vector2(cx + w * 0.3, h * 0.92), max(1.5, w * 0.022), coat)

	if crossed:
		draw_line(Vector2(4, 4), Vector2(w - 4, h - 4), Color("b3261e"), 4.0)
		draw_line(Vector2(w - 4, 4), Vector2(4, h - 4), Color("b3261e"), 4.0)
