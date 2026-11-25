## Tutorial test: a newcomer who only does what the guide says must win the first case
## and the first escape. For every step: the guide's target exists and is on screen, the
## bubble fits the screen and does not cover the target, "read this" steps have an OK
## button, and the guide never gets stuck. Runs headless (CI) in three layouts; with a
## display and an output dir it also saves one screenshot per step.
## Run: godot --headless --path game --script res://tests/tutorial_flow.gd [-- --phone|--landscape] [-- <out_dir>]
extends SceneTree

var main
var host: SubViewport
var phone_size := Vector2i.ZERO
var out_dir := ""
var checks := 0
var failures := 0
var shots := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--phone":
			phone_size = Vector2i(360, 740)
		elif a == "--landscape":
			phone_size = Vector2i(844, 390)
		elif not a.begins_with("--"):
			out_dir = a
	Engine.time_scale = 12.0
	main = load("res://ui/main.tscn").instantiate()
	if phone_size != Vector2i.ZERO:
		main.layout_override = "phone"
		host = SubViewport.new()
		host.size = phone_size
		host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(host)
		host.add_child(main)
	else:
		root.add_child(main)
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _vp() -> Vector2:
	return Vector2(phone_size) if phone_size != Vector2i.ZERO else root.get_visible_rect().size


func _overlay_child() -> Node:
	for i in range(main.overlay_center.get_child_count() - 1, -1, -1):
		var n: Node = main.overlay_center.get_child(i)
		if not n.is_queued_for_deletion():
			return n
	return null


func _finish_overlay(n: Node) -> void:
	if n.has_method("debug_solve"):
		n.debug_solve()
		n.done.emit(true)
	elif n.has_method("hit"):
		if n.kind == "sighting":
			for i in range(3):
				n.hit()
		else:
			n.debug_center_needle()
			n._try_pass()
	elif n.has_method("_finish"):
		n._finish()


## Let flights, cutscenes and mini-games finish (the guide is hidden meanwhile).
func _settle() -> void:
	var handled := {}
	var quiet := 0
	for i in range(4000):
		await process_frame
		var n := _overlay_child()
		if n != null:
			quiet = 0
			if not handled.has(n.get_instance_id()):
				handled[n.get_instance_id()] = true
				await process_frame
				_finish_overlay(n)
			continue
		if main.busy or main.flying:
			quiet = 0
			continue
		quiet += 1
		if quiet >= 6:
			return
	check(false, "UI did not settle on %s" % main.screen)


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await process_frame
	var img: Image = (host.get_texture() if host else root.get_texture()).get_image()
	if img:
		shots += 1
		img.save_png(out_dir.path_join("%02d_%s.png" % [shots, name]))


func _button_by_text(text: String) -> Button:
	for b in main.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.is_queued_for_deletion() and b.text.strip_edges() == text:
			return b
	return null


## The player works out the destination on their own (later legs): pick it like a player.
func _pick_destination(answer: String) -> void:
	var code: String = main.data.cities[answer]["country_code"]
	var chip: Button = main._find("Chip_" + code)
	if chip:
		chip.pressed.emit()
		await process_frame
		var cb: Button = main._find("City_" + answer)
		if cb:
			cb.pressed.emit()
	else:
		var c: Dictionary = main.data.cities[answer]
		var globe = main._find("TravelGlobe")
		globe.select_city(answer) if globe else null
		if main.esc:
			main.esc_pin = Vector2(c["lat"], c["lon"])
		else:
			main.pin = Vector2(c["lat"], c["lon"])
	await _frames(2)
	main._coach_update()


## Follow the guide until it ends. Returns the number of steps taken.
func _follow(label: String) -> int:
	var coach = main.coach
	var repeats := {}
	var steps := 0
	for it in range(160):
		await _settle()
		await _frames(2)
		if main.tutorial == "":
			return steps
		if not coach.visible:
			if main.screen in ["chase", "esc_chase"]:
				var chase: Node = null
				for n in main.body.find_children("*", "", true, false):
					if n.has_signal("finished") and n.has_method("start") and not n.is_queued_for_deletion():
						chase = n
				check(chase != null, "%s: chase view present" % label)
				if chase:
					chase.finished.emit(true)
				continue
			check(false, "%s: the guide disappeared on screen '%s' (player would be lost)" % [label, main.screen])
			return steps
		var id: String = coach.step_id
		repeats[id] = repeats.get(id, 0) + 1
		if repeats[id] > 8:
			check(false, "%s: guide stuck on step '%s'" % [label, id])
			return steps
		steps += 1
		var vp := _vp()
		var bubble: Control = coach.get_node("CoachBubble")
		var br: Rect2 = bubble.get_global_rect()
		check(br.position.x >= -1 and br.end.x <= vp.x + 1 and br.position.y >= -1 and br.end.y <= vp.y + 1,
			"%s/%s: bubble fits the screen (%s in %s)" % [label, id, br, vp])
		check(not coach._text.text.contains("<") and not coach._text.text.contains("{"), "%s/%s: guide text complete ('%s')" % [label, id, coach._text.text])
		if repeats[id] == 1:
			await _shot(id)
		if coach._ok.visible:
			coach._ok.pressed.emit()
			continue
		var t: Control = coach.target
		if t == null or not is_instance_valid(t):
			# Steps where the player decides alone: act like a player would.
			if id.ends_with("pick_self") and main.screen in ["travel", "esc_travel"]:
				var st = main.esc if main.esc else main.state
				await _pick_destination(st.route()[st.stop + 1])
				continue
			check(false, "%s/%s: guide gives no button to press" % [label, id])
			return steps
		await _frames(3)   # the guide scrolls its target into view
		var tr: Rect2 = t.get_global_rect()
		check(tr.position.y >= -2 and tr.end.y <= vp.y + 2 and tr.position.x >= -2 and tr.end.x <= vp.x + 2,
			"%s/%s: target '%s' is on screen (%s)" % [label, id, t.name, tr])
		check(not br.intersects(tr.grow(-2)), "%s/%s: bubble does not cover '%s' (bubble %s, target %s)" % [label, id, t.name, br, tr])
		check(t is Button and not t.disabled, "%s/%s: target '%s' can be pressed" % [label, id, t.name])
		if t is Button and not t.disabled:
			t.pressed.emit()
	check(false, "%s: guide never finished" % label)
	return steps


func _run() -> void:
	await process_frame
	main.progress.path = "user://tutorial_flow_progress.json"
	main.progress.stars = {}
	main.progress.flags = {}
	main.show_menu()
	await _frames(3)
	var ft: Button = main._find("FirstTimeButton")
	check(ft != null, "menu shows the first-time card")
	if ft:
		ft.pressed.emit()
	await _frames(3)
	check(main.tutorial == "detective", "first-time button starts the guided case")
	var n := await _follow("detective")
	check(main.state != null and main.state.status == "won", "guided case won (status %s)" % (main.state.status if main.state else "?"))
	check(main.progress.flag("tutorial_detective_done"), "guide marked as done")
	main.show_menu()
	await _frames(3)
	check(main._find("FirstTimeButton") == null, "first-time card gone after the guide")
	# Replay from How to play
	main.show_howto()
	await _frames(3)
	var lb: Button = main._find("LearnButton")
	check(lb != null, "How to play offers the guided case")
	# Fugitive guide
	main.current_escape = main._first_id(main.data.escapes)
	main._start_escape()
	await _frames(3)
	check(main.tutorial == "fugitive", "first escape starts with the guide")
	var m := await _follow("fugitive")
	check(main.esc != null and main.esc.status == "escaped", "guided escape won (status %s)" % (main.esc.status if main.esc else "?"))
	check(main.progress.flag("tutorial_fugitive_done"), "fugitive guide marked as done")
	# A second detective case has no guide
	main.current_case = "case_02"
	main._start_case()
	await _frames(3)
	check(main.tutorial == "" and not main.coach.visible, "no guide after the first case")
	print("Tutorial%s: %d detective steps, %d fugitive steps, %d checks, %d failed%s" % [
		" (%dx%d)" % [phone_size.x, phone_size.y] if phone_size != Vector2i.ZERO else "", n, m, checks, failures,
		", %d screenshots" % shots if shots > 0 else ""])
	quit(1 if failures > 0 else 0)
