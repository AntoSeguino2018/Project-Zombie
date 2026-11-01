extends SceneTree
# Passo 3.2 da soli: budget, composizione, punti di comparsa fuori vista,
# ondate che partono, finiscono e ripartono, limite di zombie vivi, HUD.
var failures := 0
var level: Node
var p: FpsController
var waves: WaveDirector


func check(name: String, ok: bool, info: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: failures += 1


func frames(n: int) -> void:
	for i in n: await physics_frame


func wait_until(cond: Callable, max_seconds: float) -> bool:
	for i in int(max_seconds * 60.0):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func move_to(where: Vector3, yaw := 0.0) -> void:
	p.global_position = where
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	p.rotation.y = yaw
	p.reset_physics_interpolation()


func zombies() -> Array:
	return level.get_node("Enemies").get_children().filter(func(n): return n is Enemy \
			and HealthComponent.of(n).is_alive())


func cost_of(list: Array) -> int:
	var total := 0
	for e: WaveEnemy in list:
		total += e.cost
	return total


func names_of(list: Array) -> String:
	return ",".join(list.map(func(e): return e.scene.resource_path.get_file().get_basename()))


func _initialize() -> void:
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	for d in level.get_node("Dummies").get_children(): d.free()
	p = level.get_node("Players/1")
	waves = WaveDirector.of(level)
	check("c'è il director con 3 tipi di zombie", waves != null and waves.enemies.size() == 3,
			str(waves.enemies.size()) if waves else "")
	# Il giocatore non muore durante il test.
	HealthComponent.of(p).damage_filter = func(_amount, _source, _at): return 0.0
	test_budget()
	await frames(5)
	await test_spawn_points()
	await test_waves()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_budget() -> void:
	check("budget prima ondata = 6", is_equal_approx(waves.budget_for(1, 1), 6.0), str(waves.budget_for(1, 1)))
	check("budget sale e accelera", waves.budget_for(2, 1) < waves.budget_for(3, 1) \
			and waves.budget_for(3, 1) - waves.budget_for(2, 1) > waves.budget_for(2, 1) - waves.budget_for(1, 1),
			"%s %s %s %s" % [waves.budget_for(1, 1), waves.budget_for(2, 1), waves.budget_for(3, 1), waves.budget_for(4, 1)])
	check("con più giocatori il budget è più alto", waves.budget_for(1, 4) > waves.budget_for(1, 2) \
			and waves.budget_for(1, 2) > waves.budget_for(1, 1), "%s %s" % [waves.budget_for(1, 2), waves.budget_for(1, 4)])
	var first := waves.compose(1, 6.0)
	check("ondata 1: solo camminatori, budget speso tutto", first.size() == 6 \
			and first.all(func(e): return e.cost == 1), names_of(first))
	var only_basic := true
	for i in 30:
		if waves.compose(2, 10.0).any(func(e): return e.cost >= 5):
			only_basic = false
	check("ondata 2: niente Bestioni", only_basic)
	var compositions := {}
	var saw_brute := false
	var spent_all := true
	for i in 40:
		var list := waves.compose(5, 26.0)
		compositions[names_of(list)] = true
		saw_brute = saw_brute or list.any(func(e): return e.cost == 5)
		spent_all = spent_all and cost_of(list) == 26
	check("ondata 5: composizioni sempre diverse", compositions.size() > 30, "%d diverse su 40" % compositions.size())
	check("dall'ondata 3 arrivano anche i Bestioni", saw_brute)
	check("il budget si spende sempre tutto", spent_all)


func test_spawn_points() -> void:
	var map: RID = level.get_node("Navigation").get_navigation_map()
	await frames(10)
	var all_on_mesh := true
	var info := ""
	for point: Marker3D in waves.get_children():
		var closest := NavigationServer3D.map_get_closest_point(map, point.global_position)
		if closest.distance_to(point.global_position) > 0.5:
			all_on_mesh = false
			info += "%s " % point.name
	check("tutti i punti di comparsa sono sulla navigazione", all_on_mesh, info)

	# Al centro guardando a nord: i punti a nord si vedono, si esce da dietro.
	move_to(Vector3(0, 0.1, 0), 0.0)
	await frames(3)
	var picked := {}
	for i in 30:
		picked[waves._pick_spawn_point().name] = true
	var north_ok := not picked.has("SpawnNorth") and not picked.has("SpawnNorthWest") and not picked.has("SpawnNorthEast")
	check("niente zombie dai punti che si stanno guardando", north_ok, str(picked.keys()))
	check("si sceglie tra più punti", picked.size() >= 2, str(picked.keys()))
	# Girandosi a sud cambiano i punti scelti.
	move_to(Vector3(0, 0.1, 0), PI)
	await frames(3)
	picked = {}
	for i in 30:
		picked[waves._pick_spawn_point().name] = true
	check("guardando a sud si esce da nord", not picked.has("SpawnSouth") and picked.keys().any(
			func(n): return n.begins_with("SpawnNorth")), str(picked.keys()))
	# Vicino a un punto: quel punto non si usa, anche alle spalle.
	move_to(Vector3(-30, 0.1, -30), PI / 4.0 + PI)
	await frames(3)
	picked = {}
	for i in 30:
		picked[waves._pick_spawn_point().name] = true
	check("mai a meno di 14 m dal giocatore", not picked.has("SpawnNorthWest"), str(picked.keys()))
	move_to(Vector3(0, 0.1, 0), 0.0)


func test_waves() -> void:
	var started: Array = []
	var cleared: Array = []
	waves.wave_started.connect(func(w): started.append(w))
	waves.wave_cleared.connect(func(w): cleared.append(w))
	var hud: PlayerHud = p._hud
	check("prima dell'inizio: niente zombie", zombies().is_empty() and waves.phase == WaveDirector.Phase.WAITING)
	await frames(2)
	check("HUD: conto alla rovescia", hud._wave_label.text.begins_with("Ondata 1 tra"), hud._wave_label.text)
	waves._time_left = 0.3
	var go := await wait_until(func(): return started == [1], 1.0)
	check("parte l'ondata 1", go and waves.phase == WaveDirector.Phase.ACTIVE and waves.remaining == 6, "rimasti=%d" % waves.remaining)
	await frames(2)
	check("HUD: ondata e zombie rimasti", hud._wave_label.text == "Ondata 1   ·   6 zombie", hud._wave_label.text)
	check("HUD: scritta ONDATA 1", hud._wave_banner.text == "ONDATA 1")
	var all_out := await wait_until(func(): return zombies().size() == 6, 6.0)
	check("escono tutti e 6, uno alla volta", all_out, "in campo=%d" % zombies().size())
	var far := zombies().all(func(z): return z.global_position.distance_to(p.global_position) > 13.0)
	check("lontani dal giocatore", far)
	HealthComponent.of(zombies()[0]).take_damage(999.0, p)
	await frames(2)
	check("uccidendone uno scende il conto", waves.remaining == 5 and hud._wave_label.text.ends_with("5 zombie"), hud._wave_label.text)
	for z in zombies():
		HealthComponent.of(z).take_damage(999.0, p)
	var done := await wait_until(func(): return cleared == [1], 1.0)
	check("ondata 1 superata", done and waves.phase == WaveDirector.Phase.BREAK, str(cleared))
	await frames(2)
	check("HUD: pausa e prossima ondata", hud._wave_label.text == "Ondata 2 tra 12", hud._wave_label.text)
	check("HUD: scritta di fine ondata", hud._wave_banner.text == "Ondata 1 superata!")

	# Ondata 2 con al massimo 3 zombie vivi insieme.
	waves.max_alive = 3
	waves._time_left = 0.2
	go = await wait_until(func(): return started == [1, 2], 1.0)
	var expected := waves.remaining
	check("parte l'ondata 2 con il budget nuovo", go and expected >= 5, "rimasti=%d" % expected)
	var most := 0
	var killed := 0
	for i in 60 * 40:
		await physics_frame
		most = maxi(most, zombies().size())
		# Ogni tanto se ne uccide uno, come farebbe un giocatore.
		if i % 120 == 119 and not zombies().is_empty():
			HealthComponent.of(zombies()[0]).take_damage(999.0, p)
			killed += 1
		if waves.phase != WaveDirector.Phase.ACTIVE:
			break
	check("mai più di 3 zombie vivi insieme", most == 3, "massimo=%d" % most)
	check("finita uccidendoli tutti", cleared == [1, 2] and killed == expected, "uccisi=%d attesi=%d" % [killed, expected])

	# Uno zombie che sparisce senza morire non blocca l'ondata.
	waves.max_alive = 10
	waves._time_left = 0.1
	go = await wait_until(func(): return started == [1, 2, 3], 1.0)
	await wait_until(func(): return waves._queue.is_empty(), 15.0)
	var left := waves.remaining
	zombies()[0].queue_free()
	await frames(2)
	check("se uno zombie sparisce il conto scende", waves.remaining == left - 1, "%d -> %d" % [left, waves.remaining])
