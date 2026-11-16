## Screenshot tour: drives both modes and saves a PNG per screen.
## Needs a display (e.g. xvfb-run). Usage:
##   xvfb-run -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tests/screenshot_tour.gd -- <out_dir>
extends SceneTree

var main
var out_dir := "user://shots"
var steps: Array = []
var idx := 0
var wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		[func(): main.progress.stars = {}; main.loc.lang = "es"; main.show_menu(), "01_menu"],
		[func(): main.show_cases(), "02_cases"],
		[func(): main.current_case = "case_02"; main._start_case(), "03_briefing"],
		[func(): main._accept_case(), "04_cutscene_heist", 70],
		[func(): _finish(), ""],
		[func(): main.show_city(), "05_city"],
		[func(): main._investigate("wiretap"), "06_wiretap_tuning", 40],
		[func(): _overlay().debug_solve(), "07_wiretap_locked", 120],
		[func(): _overlay().done.emit(true), ""],
		[func(): main._investigate("cctv"), "08_cctv", 140],
		[func(): _overlay().done.emit(false), ""],
		[func(): main._investigate("contact"), "09_contact", 140],
		[func(): _overlay().done.emit(false), ""],
		[func(): main._investigate("money"), "10_money", 140],
		[func(): _overlay().done.emit(false), "11_city_done", 40],
		[func(): main.show_notebook(), "12_notebook"],
		[func(): main.show_travel(), "13_globe", 60],
		[func(): _globe_pick_suggestion(), "14_globe_highlight", 60],
		[func(): _fly_correct(), "15_flight", 50],
		[func(): pass, "16_cutscene_trail", 150],
		[func(): _finish(), "17_after_trail", 20],
		[func(): main._sighting(), "18_sighting", 40],
		[func(): _hit(2), "19_sighting_progress", 20],
		[func(): _hit(1), "", 90],
		[func(): main.show_board(), "20_board"],
		[func(): main.show_chase(), "21_chase", 60],
		[func(): main.state.status = "won"; main.state.chase_caught = true; main.chase_result = "chase_caught"; main.show_results(), "22_results", 60],
		[func(): main.show_escapes(), "23_escapes"],
		[func(): main.current_escape = "escape_01"; main._start_escape(), "24_esc_briefing"],
		[func(): main._accept_escape(), "25_esc_cutscene", 70],
		[func(): _finish(), ""],
		[func(): main.show_escape_city(), "26_esc_city"],
		[func(): main._escape_act("message"), "27_boss_message", 130],
		[func(): _overlay().done.emit(false), ""],
		[func(): main._escape_act("map"), "", 30],
		[func(): _overlay().done.emit(false), "28_esc_city_after", 40],
		[func(): main.show_escape_travel(), "29_esc_globe", 60],
		[func(): _esc_checkpoint(), "30_checkpoint", 50],
		[func(): main._close_overlay(), "", 5],
		[func(): main._cutscene("safehouse", main.loc.s("cut_safehouse", {"city": "Madrid"}), "madrid"), "32_cutscene_safehouse", 110],
		[func(): _finish(), ""],
		[func(): main._cutscene("arrest", main.loc.s("cut_arrest", {"name": "Lucía Ferraz"}), "london"), "33_cutscene_arrest", 70],
		[func(): _finish(), ""],
		[func(): main._cutscene("plane", main.loc.s("cut_esc_flee", {"city": "Lisboa"}), "lisbon"), "34_cutscene_plane", 110],
		[func(): _finish(), ""],
		[func(): main.esc.status = "chase"; main.show_escape_chase(), "31_esc_chase", 60],
		[func(): main.esc.status = "escaped"; main.esc.finish_chase(true); main.chase_result = ""; main.show_escape_results(), "35_esc_results", 60],
	]


func _overlay() -> Node:
	var n: int = main.overlay_center.get_child_count()
	return main.overlay_center.get_child(n - 1) if n > 0 else null


func _hit(n: int) -> void:
	var o := _overlay()
	if o and o.has_method("hit"):
		for i in range(n):
			o.hit()


func _finish() -> void:
	var o := _overlay()
	if o and o.has_method("_finish"):
		o._finish()


func _globe_pick_suggestion() -> void:
	var globe = main.body.find_child("TravelGlobe", true, false)
	var target: String = main.data.cities[main.state.route()[1]]["country_code"]
	var c: Dictionary = main.data.countries[target]
	globe.highlight_country(target, c["lat"], c["lon"])


func _fly_correct() -> void:
	var c: Dictionary = main.data.cities[main.state.route()[1]]
	main.pin = Vector2(c["lat"], c["lon"])
	main._on_fly()


func _esc_checkpoint() -> void:
	var mg = main.Minigame.new()
	main._show_overlay(mg)
	mg.setup("checkpoint", {"title": main.loc.s("checkpoint_title"), "hint": main.loc.s("checkpoint_hint", {"city": "Río de Janeiro"}),
		"action": main.loc.s("checkpoint_action"), "status": main.loc.s("checkpoint_status"), "win": "", "lose": ""})


func _process(_delta: float) -> bool:
	if wait > 0:
		wait -= 1
		if wait == 0 and idx > 0:
			var name: String = steps[idx - 1][1]
			if name != "":
				var img := root.get_texture().get_image()
				img.save_png(out_dir.path_join(name + ".png"))
		return false
	if idx >= steps.size():
		print("tour done: %d steps" % steps.size())
		quit(0)
		return false
	var st: Array = steps[idx]
	idx += 1
	st[0].call()
	wait = st[2] if st.size() > 2 else 30
	return false
