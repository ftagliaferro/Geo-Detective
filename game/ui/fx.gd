## Small animation helpers (tweens) shared by all screens.
extends RefCounted


## Fade + rise in, optionally delayed (for staggered lists).
static func pop_in(node: CanvasItem, delay := 0.0, rise := 14.0) -> void:
	if not node.is_inside_tree():
		return
	node.modulate.a = 0.0
	var ctrl := node as Control
	var tw := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.35).set_delay(delay)
	if ctrl:
		ctrl.pivot_offset = ctrl.size / 2.0
		ctrl.scale = Vector2(0.97, 0.97)
		tw.tween_property(ctrl, "scale", Vector2.ONE, 0.35).set_delay(delay)


static func fade_in(node: CanvasItem, duration := 0.25) -> void:
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, duration)


## Typewriter effect on a Label (visible_ratio 0 -> 1).
static func type_in(label: Label, chars_per_sec := 55.0, delay := 0.0) -> Tween:
	label.visible_ratio = 0.0
	var dur := clampf(label.text.length() / chars_per_sec, 0.25, 3.0)
	var tw := label.create_tween()
	tw.tween_property(label, "visible_ratio", 1.0, dur).set_delay(delay)
	return tw


## Animate a number in a label using a format string with one %d.
static func count(label: Label, from: int, to: int, fmt: String, duration := 0.6) -> void:
	var tw := label.create_tween()
	tw.tween_method(func(v: float): label.text = fmt % int(round(v)), float(from), float(to), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func shake(node: Control, strength := 8.0) -> void:
	var base := node.position
	var tw := node.create_tween()
	for i in range(6):
		tw.tween_property(node, "position", base + Vector2(randf_range(-strength, strength), 0), 0.04)
	tw.tween_property(node, "position", base, 0.05)


static func pulse(node: Control, times := 2) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	for i in range(times):
		tw.tween_property(node, "scale", Vector2(1.06, 1.06), 0.12)
		tw.tween_property(node, "scale", Vector2.ONE, 0.12)
