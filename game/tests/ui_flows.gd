## Exhaustive UI flow test (headless). Drives the real screens and buttons of main.gd:
##  * every case and every escape, every leg: presses every suggested country chip and
##    every city button, checks the pin, the "fly" button and the city it would land in;
##  * plays every case and escape to the end through the UI (investigate all spots,
##    travel by chip, board, warrant, chase, results, next case unlocked);
##  * on every screen, in both languages, scans all visible text for missing strings
##    ("<key>") or unfilled placeholders ("{name}");
##  * with -- --phone / --landscape: same run in the phone layout (360x740 / 844x390),
##    plus on every screen nothing may stick out past the screen edge, and a touch test
##    (dragging on a button scrolls the page without pressing it; a tap presses it).
## Any failed check or script error makes the process exit with code 1.
## Run:  godot --headless --path game --script res://tests/ui_flows.gd [-- --phone|--landscape]
extends SceneTree

const Geo = preload("res://core/geo.gd")
const CaseState = preload("res://core/case_state.gd")

var main
var checks := 0
var failures := 0
var _missing := RegEx.new()
var _placeholder := RegEx.new()
var _scanned := {}
var phone_size := Vector2i.ZERO   # set for --phone / --landscape
var host: SubViewport
var touch_index := 0   # Android numbers fingers 0, 1, 2; iOS Safari uses big arbitrary ids


func _initialize() -> void:
	_missing.compile("<[a-z0-9_]+>")
	_placeholder.compile("\\{[a-z_]+\\}")
	Engine.time_scale = 12.0
	for a in OS.get_cmdline_user_args():
		if a == "--phone":
			phone_size = Vector2i(360, 740)   # small Android phone; bigger ones only have more room
		elif a == "--landscape":
			phone_size = Vector2i(844, 390)
	main = load("res://ui/main.tscn").instantiate()
	if phone_size != Vector2i.ZERO:
		# A fixed-size viewport stands in for the phone screen.
		main.layout_override = "phone"
		host = SubViewport.new()
		host.size = phone_size
		host.gui_disable_input = false
		root.add_child(host)
		host.add_child(main)
	else:
		root.add_child(main)
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)


# ------------------------------------------------------------------ helpers

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _overlay_child() -> Node:
	for i in range(main.overlay_center.get_child_count() - 1, -1, -1):
		var n: Node = main.overlay_center.get_child(i)
		if not n.is_queued_for_deletion():
			return n
	return null


func _finish_overlay(n: Node) -> void:
	if n.has_method("debug_solve"):        # clue reveal mini-games
		n.debug_solve()
		n.done.emit(true)
	elif n.has_method("hit"):              # sighting / checkpoint
		if n.kind == "sighting":
			for i in range(3):
				n.hit()
		else:
			n.debug_center_needle()
			n._try_pass()
	elif n.has_method("choose"):           # event card: first option
		n.choose(0)
	elif n.has_method("_finish"):          # cutscene / story scene
		n._finish()


## Let pending flights, cutscenes and mini-games finish (resolving every overlay).
func _settle(label: String, max_frames := 4000) -> void:
	var handled := {}
	var quiet := 0
	for i in range(max_frames):
		await process_frame
		var n := _overlay_child()
		if n != null:
			quiet = 0
			if not handled.has(n.get_instance_id()):
				handled[n.get_instance_id()] = true
				await process_frame
				await _check_overlay(label, n)
				_finish_overlay(n)
			continue
		if main.busy or main.flying:
			quiet = 0
			continue
		quiet += 1
		if quiet >= 4:
			return
	check(false, "%s: UI did not settle (screen=%s)" % [label, main.screen])


func _wait_screen(label: String, screens: Array, max_frames := 4000) -> void:
	var handled := {}
	for i in range(max_frames):
		await process_frame
		var n := _overlay_child()
		if n != null and not handled.has(n.get_instance_id()):
			handled[n.get_instance_id()] = true
			await process_frame
			await _check_overlay(label, n)
			_finish_overlay(n)
		if main.screen in screens and _overlay_child() == null and not main.busy:
			return
	check(false, "%s: expected screen %s, got %s" % [label, screens, main.screen])


func _all(of_type: String) -> Array:
	var out: Array = []
	for n in main.find_children("*", of_type, true, false):
		if not n.is_queued_for_deletion() and n.is_visible_in_tree():
			out.append(n)
	return out


func _button(text: String) -> Button:
	for b in _all("Button"):
		if b.text.strip_edges() == text:
			return b
	return null


func _press(label: String, text: String) -> bool:
	var b := _button(text)
	check(b != null, "%s: button '%s' exists on %s" % [label, text, main.screen])
	if b == null:
		return false
	check(not b.disabled, "%s: button '%s' is enabled" % [label, text])
	if b.disabled:
		return false
	b.pressed.emit()
	return true


## Scan the current screen (and overlay) for missing strings in both languages.
func _scan(label: String) -> void:
	for pass_i in range(2):
		await process_frame
		var key: String = main.screen + "/" + main.loc.lang
		var texts: Array = []
		for n in _all("Label") + _all("Button") + _all("RichTextLabel"):
			texts.append(str(n.text))
		for n in main.find_children("*", "Label3D", true, false):
			texts.append(str(n.text))
		for t in texts:
			if _missing.search(t) != null or _placeholder.search(t) != null:
				check(false, "%s [%s]: bad text '%s'" % [label, key, t])
		if phone_size != Vector2i.ZERO:
			await _check_fits(label + " [" + key + "]")
		_scanned[key] = true
		if pass_i == 0:
			if main.screen in ["chase", "esc_chase"] or _overlay_child() != null:
				return   # don't rebuild live chases / overlays
			main.lang_btn.pressed.emit()
	main.lang_btn.pressed.emit()   # back to the original language
	await process_frame


## Phone layout: overlays (mini-games, events, cutscenes) must fit the screen width too.
func _check_overlay(label: String, n: Node) -> void:
	if phone_size == Vector2i.ZERO or not is_instance_valid(n):
		return
	var what: String = "%s/%s/%s" % [n.get_class(), n.get("kind"), n.get("variant")]
	await _check_fits("%s overlay %s" % [label, what])


## Phone layout: no visible control may extend past the left/right screen edge.
func _check_fits(label: String) -> void:
	await process_frame
	var w := float(phone_size.x)
	var worst := ""
	for n in main.find_children("*", "Control", true, false):
		if n.is_queued_for_deletion() or not n.is_visible_in_tree():
			continue
		var r: Rect2 = n.get_global_rect()
		if r.size.x <= 0.0:
			continue
		if r.position.x < -4.0 or r.end.x > w + 4.0:
			worst = "%s %s x=%.0f..%.0f" % [n.get_class(), str(n.get("text")).left(30) if n.get("text") != null else n.name, r.position.x, r.end.x]
			break
	check(worst == "", "%s: fits the %d px screen (%s)" % [label, phone_size.x, worst])


## Phone: a drag that starts on a button scrolls the page and does not press it;
## a tap on the same button presses it. Simulates the browser's touch + emulated mouse.
func _touch_check() -> void:
	var label := "touch (finger id %d)" % touch_index
	main.current_case = "case_02"   # no guide: nothing floats over the page
	main._start_case()
	await _settle(label + " story")
	main._accept_case()
	await _wait_screen(label, ["city"])
	await _frames(6)
	if main.coach.visible and main.coach._ok.visible:
		main.coach._ok.pressed.emit()   # a first-time tip: the player taps "Got it"
		await _frames(3)
	var sc: ScrollContainer = main.body.find_child("PageScroll", true, false)
	check(sc != null, "%s: city page scrolls on phones" % label)
	if sc == null:
		return
	var btn := main._find("Investigate_money") as Button
	check(btn != null, "%s: investigate button found" % label)
	if btn == null:
		return
	# Put the button in the upper part of the screen, with room left to scroll down.
	sc.scroll_vertical = maxi(0, sc.scroll_vertical + int(btn.get_global_rect().position.y - sc.get_global_rect().position.y) - 40)
	await _frames(3)
	var p: Vector2 = btn.get_global_rect().get_center()
	check(sc.get_global_rect().has_point(p), "%s: button on screen at %s" % [label, p])
	var before := sc.scroll_vertical
	_touch(p, true)
	for k in range(1, 9):
		await process_frame
		_drag(p + Vector2(0, 12.0 * k), Vector2(0, 12))
	await process_frame
	_touch(p + Vector2(0, 96), false)
	await _frames(4)
	check(sc.scroll_vertical < before - 40, "%s: drag scrolled the page (%d -> %d)" % [label, before, sc.scroll_vertical])
	check(not main.overlay.visible and not main.busy, "%s: drag did not press the button" % label)
	await _frames(30)   # let any fling settle
	var b2 := main._find("Investigate_money") as Button
	sc.scroll_vertical = maxi(0, sc.scroll_vertical + int(b2.get_global_rect().position.y - sc.get_global_rect().position.y) - 40)
	await _frames(3)
	var q: Vector2 = b2.get_global_rect().get_center()
	check(sc.get_global_rect().has_point(q), "%s: button on screen for the tap at %s" % [label, q])
	_touch(q, true)
	await process_frame
	_touch(q, false)
	await _frames(3)
	check(main.overlay.visible, "%s: a tap presses the button" % label)
	await _settle("touch tap")
	check(main.state.visited.has("money"), "%s: tap investigated" % label)


func _push(ev: InputEvent) -> void:
	host.push_input(ev, true)


## Browser order: emulated mouse event first, then the touch event.
func _touch(p: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.device = InputEvent.DEVICE_ID_EMULATION
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = p
	mb.global_position = p
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_push(mb)
	var t := InputEventScreenTouch.new()
	t.index = touch_index
	t.pressed = pressed
	t.position = p
	_push(t)


func _drag(p: Vector2, rel: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.device = InputEvent.DEVICE_ID_EMULATION
	mm.position = p
	mm.global_position = p
	mm.relative = rel
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	_push(mm)
	var d := InputEventScreenDrag.new()
	d.index = touch_index
	d.position = p
	d.relative = rel
	_push(d)


func _city_name(id: String) -> String:
	return main.loc.t(main.data.cities[id]["name"])


func _country_name(code: String) -> String:
	return main.loc.t(main.data.countries[code]["name"])


func _fly_button() -> Button:
	return _button(main.loc.s("fly_here"))


## On a travel screen: press every chip and city button; check what each would do.
## Returns nothing; leaves the target country/city selected.
func _check_chips(label: String, codes: Array, here: String, target: String, fugitive: bool, also_hits: Array = []) -> void:
	var data = main.data
	var eliminated: bool = not fugitive and main.state.eliminated.has(main.state.stop)
	check(codes.size() == (2 if eliminated else 4), "%s: %d chips (got %s)" % [label, 2 if eliminated else 4, codes])
	check(main.data.cities[target]["country_code"] in codes, "%s: chips include destination" % label)
	for code in codes + [data.cities[target]["country_code"]]:   # target last: leaves it selected
		var chip := _button(_country_name(code))
		check(chip != null, "%s: chip %s shown" % [label, code])
		if chip == null:
			continue
		chip.pressed.emit()
		await process_frame
		var in_country: Array = data.cities.keys().filter(func(id): return data.cities[id]["country_code"] == code and id != here)
		in_country.sort()
		check(not in_country.is_empty(), "%s: chip %s has a city to fly to" % [label, code])
		if code == data.cities[target]["country_code"]:
			in_country.erase(target)
			in_country.append(target)   # target last
		for cid in in_country:
			if in_country.size() > 1:
				var cb := _button(_city_name(cid))
				check(cb != null, "%s: city button %s for %s" % [label, cid, code])
				if cb == null:
					continue
				cb.pressed.emit()
				await process_frame
			var p: Vector2 = main.esc_pin if fugitive else main.pin
			check(p != Vector2.INF, "%s: %s/%s sets the pin" % [label, code, cid])
			if p == Vector2.INF:
				continue
			check(main._city_at(p) == cid, "%s: pin for %s is on %s (got '%s')" % [label, code, cid, main._city_at(p)])
			var fly := _fly_button()
			check(fly != null and not fly.disabled, "%s: can fly to %s" % [label, cid])
			var st = main.esc if fugitive else main.state
			var r: Dictionary = st.resolve_pin(p.x, p.y)
			check(r["city"] == cid, "%s: choosing %s lands in %s" % [label, cid, r["city"]])
			check(bool(r["hit"]) == (cid == target or cid in also_hits), "%s: %s hit=%s, target %s" % [label, cid, r["hit"], target])


# ------------------------------------------------------------------ flows

## Places a careful player investigates: the clearest truthful where-clue and the money
## trail; every third city also the camera (with the trail cold) to cover that path.
func _ui_plan(st, i: int) -> Array:
	if st.is_final():
		return ["money", "wiretap"]
	if not st.on_trail():
		return []
	var best := ""
	for spot in ["wiretap", "contact"]:
		var c: Dictionary = st.peek(spot)
		if c.get("kind") == "dest" and not c.get("fake", false) and not st.is_burned(spot):
			if best == "" or int(c["tier"]) < int(st.peek(best)["tier"]):
				best = spot
	var out: Array = [best if best != "" else "wiretap", "money"]
	if i % 3 == 2:
		out.append("cctv")
	return out.filter(func(sp): return not st.is_burned(sp))


func _play_case(cid: String, take_b := false) -> void:
	var label := cid
	main.current_case = cid
	main.show_cases()
	await _scan(label + " cases")
	main._start_case()
	await _settle(label + " story intro")
	await _scan(label + " briefing")
	_press(label, main.loc.s("accept_case"))
	await _wait_screen(label + " heist", ["city"])
	var st = main.state
	var i := 0
	while st.status == "playing" and i < 20:
		label = "%s stop %d (%s)" % [cid, i, st.current]
		check(st.current == st.route()[st.stop] and st.stop == i, "%s: on the trail" % label)
		await _scan(label + " city")
		check(main._find("CityMap") != null, "%s: city map shown" % label)
		for spot in _ui_plan(st, i):
			var before: int = st.visited.size()
			check(main._find("Investigate_" + spot) != null, "%s: %s place has an investigate button" % [label, spot])
			main._investigate(spot)
			await _settle(label + " " + spot)
			check(st.visited.has(spot) and st.visited.size() == before + 1, "%s: %s investigated" % [label, spot])
			check(main.screen == "city", "%s: back on city after %s" % [label, spot])
		if st.status != "playing":
			check(false, "%s: ran out of time while investigating (%d/%d h)" % [label, st.hours_used, st.budget])
			return
		main.show_notebook()
		await _scan(label + " notebook")
		main.show_city()
		await process_frame
		if st.is_final():
			break
		_press(label, main.loc.s("travel"))
		await process_frame
		check(main.screen == "travel", "%s: travel screen" % label)
		await _scan(label + " travel")
		var target: String = st.route()[st.stop + 1]
		var also: Array = []
		if st.is_split_city():
			var b: String = st.case_def["route_b"][0]
			also = [b] if not take_b else [target]
			if take_b:
				target = b
		var codes: Array = st.suggested_countries()
		if st.is_sea_leg() and codes.is_empty():
			# By sea: no shortlist; the player finds the city on the globe.
			var tc: Dictionary = main.data.cities[target]
			main.pin = Vector2(tc["lat"], tc["lon"])
			main.show_travel()
			await process_frame
		else:
			await _check_chips(label, codes, st.current, target, false, also)
		_press(label, main.loc.s("fly_here"))
		await _wait_screen(label + " flight", ["city", "results"])
		check(main.last_flight.get("hit", false), "%s: flight hit the trail" % label)
		i += 1
		if st.status != "playing":
			check(false, "%s: case ended early (%s)" % [label, st.status])
			return
	label = cid + " final"
	check(st.is_final(), "%s: reached the final city" % label)
	if take_b:
		check(st.branch == "b", "%s: followed the second thief" % label)
	if st.objective == "recover":
		main.show_board()
		await _scan(label + " hideout board")
		main.show_city()
		await process_frame
		await _scan(label + " raid map")
		var raid := main._find("Raid_" + st.target_place) as Button
		check(raid != null, "%s: raid button for the hideout" % label)
		if raid == null:
			return
		raid.pressed.emit()
		await _wait_screen(label + " raid", ["results"])
	else:
		main.show_board()
		await _scan(label + " board")
		var culprit: String = st.culprit()
		for sid in main._gang_ids():
			if sid != culprit:
				main.crossed[sid] = true
		main.show_board()
		await process_frame
		_press(label, main.loc.s("issue_warrant_for", {"name": main.data.suspects[culprit]["name"]}))
		await process_frame
		check(st.warrant == culprit, "%s: warrant issued" % label)
		main.show_city()
		await process_frame
		_press(label, main.loc.s("rescue_button") if st.objective == "rescue" else main.loc.s("arrest"))
		await process_frame
		check(main.screen == "chase", "%s: chase screen" % label)
		await _scan(label + " chase")
		var chase: Node = null
		for n in main.body.find_children("*", "", true, false):
			if n.has_signal("finished") and n.has_method("start") and not n.is_queued_for_deletion():
				chase = n
		check(chase != null, "%s: chase view present" % label)
		if chase == null:
			return
		_press(label, main.loc.s("chase_start_rescue") if st.objective == "rescue" else main.loc.s("chase_start"))
		await _frames(3)
		chase.finished.emit(true)
		await _wait_screen(label + " arrest", ["results"])
	check(st.status == "won", "%s: case won (%s)" % [label, st.status])
	check(main.progress.best(cid) >= 1, "%s: stars recorded" % label)
	await _settle(label + " story outro")
	await _scan(label + " results")


func _play_escape(eid: String) -> void:
	var label := eid
	main.current_escape = eid
	main.show_escapes()
	await _scan(label + " escapes")
	main._start_escape()
	await _scan(label + " briefing")
	_press(label, main.loc.s("start_escape"))
	await _wait_screen(label + " heist", ["esc_city"])
	var e = main.esc
	var route: Array = e.route()
	for i in range(route.size() - 1):
		label = "%s leg %d (%s)" % [eid, i, e.current]
		check(e.current == route[i] and e.stop == i, "%s: on the route" % label)
		await _scan(label + " city")
		main._escape_act("map")
		await _settle(label + " map")
		check(e.revealed.get(e.stop, {}).has("map"), "%s: map bought" % label)
		main.show_escape_city()
		_press(label, main.loc.s("flee"))
		await process_frame
		check(main.screen == "esc_travel", "%s: flee screen" % label)
		await _scan(label + " travel")
		await _check_chips(label, e.leg_info[e.stop]["map"]["countries"], e.current, route[i + 1], true)
		_press(label, main.loc.s("fly_here"))
		await _wait_screen(label + " flight", ["esc_city", "esc_chase", "esc_results"])
		check(main.esc_flight.get("hit", false), "%s: flight via chip stayed on route" % label)
		if main.screen == "esc_chase":
			await _scan(label + " chase")
			var chase: Node = null
			for n in main.body.find_children("*", "", true, false):
				if n.has_signal("finished") and n.has_method("start"):
					chase = n
			check(chase != null, "%s: escape chase view present" % label)
			_press(label, main.loc.s("esc_chase_start"))
			await _frames(3)
			chase.finished.emit(true)
			await _wait_screen(label + " chase end", ["esc_results"])
		if main.screen == "esc_results":
			break
	label = eid + " end"
	check(main.screen == "esc_results", "%s: results shown (%s)" % [label, main.screen])
	check(e.status == "escaped", "%s: escaped (%s)" % [label, e.status])
	await _scan(label + " results")


## A wrong chip lands in the chosen decoy city and the case can recover.
func _wrong_chip_recovers() -> void:
	seed(3)
	main.current_case = "case_04"
	main._start_case()
	main._accept_case()
	await _wait_screen("recover", ["city"])
	var st = main.state
	main.show_travel()
	await process_frame
	var target_code: String = main.data.cities[st.route()[1]]["country_code"]
	var decoy := ""
	for c in st.suggested_countries():
		if c != target_code:
			decoy = c
	_button(_country_name(decoy)).pressed.emit()
	await process_frame
	var p: Vector2 = main.pin
	var expected: String = main._city_at(p)
	var city_btns: Array = main.data.cities.keys().filter(func(id): return main.data.cities[id]["country_code"] == decoy)
	if city_btns.size() > 1:
		_button(_city_name(city_btns[0])).pressed.emit()
		await process_frame
		expected = city_btns[0]
	_press("recover", main.loc.s("fly_here"))
	await _wait_screen("recover flight", ["city"])
	check(st.current == expected and main.data.cities[st.current]["country_code"] == decoy, "recover: landed in the decoy country (%s)" % st.current)
	check(not st.on_trail(), "recover: off the trail after a decoy")
	await _scan("recover cold city")
	main.show_travel()
	await process_frame
	var back: Dictionary = main.data.cities[st.route()[1]]
	main.pin = Vector2(back["lat"], back["lon"])
	main.show_travel()
	await process_frame
	_press("recover", main.loc.s("fly_here"))
	await _wait_screen("recover flight 2", ["city"])
	check(st.on_trail() and st.current == st.route()[1], "recover: back on the trail")
	# Pin on the city you are in: flying is blocked with a clear message.
	var here: Dictionary = main.data.cities[st.current]
	main.pin = Vector2(here["lat"], here["lon"])
	main.show_travel()
	await process_frame
	var fly := _fly_button()
	check(fly != null and fly.disabled, "pin on current city disables flying")
	check(_all("Label").any(func(l): return l.text == main.loc.s("pin_here", {"city": _city_name(st.current)})), "pin on current city explains why")
	main.pin = Vector2.INF


## First-time tips and story scenes: a tip shows on the screen that asked for it, is
## dropped (not marked as read) when the player moves on, and returns next time; a tap
## on a story line that is still typing shows it whole instead of skipping it.
func _tips_and_story() -> void:
	main.progress.flags.erase("tip_lead")
	main.current_case = "case_05"
	main._start_case()
	await _settle("tips: briefing")
	var sc: Node = null
	main._accept_case()
	await _settle("tips: case start")
	var st = main.state
	var c: Dictionary = main.data.cities[st.route()[1]]
	while not st.pending_event.is_empty():
		st.choose_event(0)
		if not st.pending_minigame.is_empty():
			st.resolve_event_minigame(true)
	st.travel_to_pin(c["lat"], c["lon"])
	st.pending_event = {}
	main._pending_tip = ""
	main.show_city()
	await _frames(4)
	check(main.coach.visible and main.coach.step_id == "tip_lead", "tips: lead tip shows on the city screen (%s)" % main.coach.step_id)
	main.show_notebook()
	await _frames(4)
	check(not main.coach.visible, "tips: an unread tip does not follow the player to another screen")
	check(not main.progress.flag("tip_lead"), "tips: a tip the player never saw is not marked as read")
	main.show_city()
	await _frames(4)
	check(main.coach.visible and main.coach.step_id == "tip_lead", "tips: the tip returns on the city screen")
	main._on_coach_ok()
	await _frames(2)
	check(not main.coach.visible and main.progress.flag("tip_lead"), "tips: 'Got it' closes it for good")
	main.show_city()
	await _frames(4)
	check(not main.coach.visible, "tips: a read tip stays away")
	# Story: tap while typing completes the line first.
	var Story = load("res://ui/story_scene.gd")
	sc = Story.new()
	main._show_overlay(sc)
	sc.setup([{"id": "nico", "name": "Nico", "text": "A fairly long line so that typing takes a while to finish."},
		{"id": "rivas", "name": "Rivas", "text": "Second line."}], "Next", "Start", "Skip")
	await _frames(2)
	sc.advance()
	check(sc.index == 0 and is_equal_approx(sc._line.visible_ratio, 1.0), "story: first tap shows the whole line")
	sc.advance()
	check(sc.index == 1, "story: second tap moves on")
	sc._finish()
	main._close_overlay()
	await _frames(2)


func _run() -> void:
	await process_frame
	main.progress.path = "user://ui_flows_progress.json"
	main.progress.stars = {}
	main.show_menu()
	await _scan("menu")
	main.show_howto()
	await _scan("howto")
	var cases: Array = main.data.cases.keys()
	cases.sort()
	for cid in cases:
		seed(hash(cid))
		await _play_case(cid)
		if main.data.cases[cid].get("objective") == "split":
			seed(hash(cid) + 1)
			await _play_case(cid, true)
	var escapes: Array = main.data.escapes.keys()
	escapes.sort()
	for eid in escapes:
		seed(hash(eid))
		await _play_escape(eid)
	await _wrong_chip_recovers()
	await _tips_and_story()
	if phone_size != Vector2i.ZERO:
		for id in [0, 1837465291]:   # Android-style, then iOS-style finger id
			touch_index = id
			await _touch_check()
	main.show_menu()
	await _scan("menu end")
	print("UI flows%s: %d checks, %d failed, screens scanned: %s" % [" (%dx%d)" % [phone_size.x, phone_size.y] if phone_size != Vector2i.ZERO else "", checks, failures, _scanned.keys().size()])
	quit(1 if failures > 0 else 0)
