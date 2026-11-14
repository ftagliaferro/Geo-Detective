## Header banner for a city: a crop of the atlas texture around the city,
## a pin, and a dark gradient so the title reads well.
extends Control

const WORLD := preload("res://assets/globe/world.png")
static var _image: Image

var lat := 0.0
var lon := 0.0
var tex: ImageTexture


func setup(p_lat: float, p_lon: float) -> void:
	lat = p_lat
	lon = p_lon
	if _image == null:
		_image = WORLD.get_image()
		if _image.is_compressed():
			_image.decompress()
	var w := _image.get_width()
	var h := _image.get_height()
	var span_x := int(w * 0.16)   # ~58 degrees of longitude
	var span_y := int(span_x * 0.32)
	var cx := int((lon + 180.0) / 360.0 * w)
	var cy := int((90.0 - lat) / 180.0 * h)
	var x0 := clampi(cx - span_x / 2, 0, w - span_x)
	var y0 := clampi(cy - span_y / 2, 0, h - span_y)
	tex = ImageTexture.create_from_image(_image.get_region(Rect2i(x0, y0, span_x, span_y)))
	set_meta("pin", Vector2(float(cx - x0) / span_x, float(cy - y0) / span_y))
	clip_contents = true
	queue_redraw()


func _draw() -> void:
	if tex:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	# left-to-right dark gradient for legibility
	var dark := Color(0.11, 0.12, 0.14, 0.94)
	var clear := Color(0.11, 0.12, 0.14, 0.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x * 0.7, 0), Vector2(size.x * 0.7, size.y), Vector2(0, size.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	var p: Vector2 = get_meta("pin", Vector2(0.5, 0.5)) * size
	draw_circle(p, 9.0, Color(0, 0, 0, 0.35))
	draw_circle(p, 7.0, Color("c0392b"))
	draw_circle(p, 2.5, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color("5c646e"), false, 1.0)
