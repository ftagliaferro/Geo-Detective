## UI smoke test: opens every screen of both modes headless; any script error fails CI.
## Run:  godot --headless --path game --script res://tests/smoke_ui.gd
extends SceneTree

var main
var frames := 0


func _initialize() -> void:
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	match frames:
		1: main.progress.path = "user://smoke_progress.json"
		3: main.show_escapes()
		6: main._start_escape()
		9: main.show_escape_city()
		12:
			for a in ["message", "message2", "map", "clean", "decoy"]:
				main.esc.act(a)
			main.show_escape_city()
		14: main.show_escape_travel()
		17:
			main.esc.status = "chase"
			main.show_escape_chase()
		20:
			main.esc.finish_chase(true)
			main.show_escape_results()
		24:
			main.current_case = "case_01"
			main._start_case()
			main.show_city()
		27:
			for sp in ["wiretap", "cctv", "contact", "money"]:
				main._on_spot(sp)
			main.show_notebook()
		30: main.show_travel()
		33: main.show_board()
		36: main.show_chase()
		39:
			main.state.status = "won"
			main.show_results()
		42: main.show_howto()
		45: main.show_cases()
		48: main.show_menu()
		50:
			print("UI smoke OK")
			quit(0)
	return false
