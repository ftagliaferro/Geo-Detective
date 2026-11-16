## Header banner for a city: a crop of the atlas texture around the city,
## a pin, and a dark gradient so the title reads well.
extends Control

const WORLD := preload("res://assets/globe/world.png")
static var _image: Image

var lat := 0.0
var lon := 0.0
var tex: ImageTexture
var photo: Texture2D


func setup(p_lat: float, p_lon: float, photo_path = null) -> void:
	lat = p_lat
	lon = p_lon
	if photo_path != null and ResourceLoader.exists(photo_path):
		photo = load(photo_path)
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
	if photo:
		# cover-fit the city's street photo, anchored to the right half
		var ps := photo.get_size()
		var scale := maxf(size.x * 0.75 / ps.x, size.y / ps.y)
		var dsz := ps * scale
		draw_texture_rect(photo, Rect2(Vector2(size.x - dsz.x, (size.y - dsz.y) / 2.0), dsz), false)
	elif tex:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	# left-to-right dark gradient for legibility
	var dark := Color(1, 1, 1, 0.96)
	var clear := Color(1, 1, 1, 0.0)
	draw_rect(Rect2(0, 0, size.x * 0.25, size.y), dark)
	draw_polygon(PackedVector2Array([Vector2(size.x * 0.25, 0), Vector2(size.x * 0.62, 0), Vector2(size.x * 0.62, size.y), Vector2(size.x * 0.25, size.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	if photo:
		return
	var p: Vector2 = get_meta("pin", Vector2(0.5, 0.5)) * size
	draw_circle(p, 16.0, Color(1.0, 0.35, 0.24, 0.18))
	draw_circle(p, 9.0, Color(1, 1, 1))
	draw_circle(p, 7.0, Color("ff5a3c"))
	draw_circle(p, 2.5, Color.WHITE)

