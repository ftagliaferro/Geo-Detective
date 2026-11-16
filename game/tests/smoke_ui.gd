## UI smoke test: drives every screen, overlay, cutscene and mini-game of both modes
## headless; any script error fails CI.
## Run:  godot --headless --path game --script res://tests/smoke_ui.gd
extends SceneTree

var main
var frames := 0
var step := 0
var wait := 0


func _initialize() -> void:
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)


func _overlay_child() -> Node:
	if main.overlay_center.get_child_count() == 0:
		return null
	return main.overlay_center.get_child(main.overlay_center.get_child_count() - 1)


func _finish_overlay() -> void:
	var n := _overlay_child()
	if n == null:
		return
	if n.has_method("debug_solve"):
		n.debug_solve()
		n.done.emit(true)
	elif n.has_signal("done"):
		n.done.emit(false)
	elif n.has_method("hit"):
		if n.kind == "sighting":
			for i in range(3):
				n.hit()
		else:
			n.debug_center_needle()
			n._try_pass()
	elif n.has_method("_finish"):
		n._finish()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		main.progress.path = "user://smoke_progress.json"
	if wait > 0:
		wait -= 1
		return false
	wait = 3
	step += 1
	match step:
		1: main.show_howto()
		2: main.show_cases()
		3:
			main.current_case = "case_01"
			main._start_case()
		4: main._accept_case()          # heist cutscene
		5: _finish_overlay()
		6: main._investigate("wiretap")  # tuning mini-game
		7: _finish_overlay()
		8: main._investigate("cctv")
		9: _finish_overlay()
		10: main._investigate("contact")
		11: _finish_overlay()
		12: main._investigate("money")
		13: _finish_overlay()
		14: main.show_notebook()
		15: main.show_travel()
		16:
			var c: Dictionary = main.data.cities[main.state.route()[1]]
			main.pin = Vector2(c["lat"], c["lon"])
			main._on_fly()
		17: wait = 150                  # flight animation
		18: _finish_overlay()            # trail cutscene
		19: _finish_overlay()            # sighting (if any)
		20: main.show_board()
		21: main.show_chase()
		22:
			main.state.status = "won"
			main.show_results()
		23: main.show_escapes()
		24:
			main.current_escape = "escape_03"
			main._start_escape()
		25: main._accept_escape()
		26: _finish_overlay()
		27: main._escape_act("message")  # boss chat
		28: _finish_overlay()
		29: main._escape_act("map")
		30: _finish_overlay()
		31: main._escape_act("decoy")
		32: _finish_overlay()
		33: main.show_escape_travel()
		34:
			var c2: Dictionary = main.data.cities[main.esc.route()[1]]
			main.esc_pin = Vector2(c2["lat"], c2["lon"])
			main._on_escape_fly()
		35: wait = 150
		36: _finish_overlay()            # flee cutscene
		37: _finish_overlay()            # checkpoint (if any)
		38:
			main.esc.status = "chase"
			main.show_escape_chase()
		39:
			main.esc.finish_chase(true)
			main._after_escape_move()
		40: _finish_overlay()            # safehouse cutscene
		41: main.show_menu()
		42:
			print("UI smoke OK (screen=%s)" % main.screen)
			quit(0)
	return false
