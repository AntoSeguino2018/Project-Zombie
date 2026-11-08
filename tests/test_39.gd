extends SceneTree
# Passo 4.1, il campus di Monte Sant'Arcangelo: si parte nell'aula studio
# sotterranea (lavagna su tutta la parete sinistra guardando l'uscita), solo
# aula e Centri comuni aperti; le porte si comprano e aprono le zone (soldi,
# collisione, navigazione); ogni zona ha punti di comparsa sulla navigazione ed
# è raggiungibile a porte aperte; gli zombie escono solo vicino ai giocatori e
# quelli rimasti lontani tornano in coda; la ripartenza richiude tutto.
var failures := 0
var level: Node
var p: FpsController
var zones: ZoneManager
var waves: WaveDirector


func check(name: String, ok: bool, info: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: failures += 1


func frames(n: int) -> void:
	for i in n: await physics_frame


func seconds(s: float) -> void:
	await frames(int(s * 60.0))


func wait_until(cond: Callable, max_seconds: float) -> bool:
	for i in int(max_seconds * 60.0):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func nav() -> LevelNavigation:
	return level.get_node("Navigation") as LevelNavigation


## Fin dove arriva un percorso da a verso b (l'ultimo punto).
func reach(a: Vector3, b: Vector3) -> Vector3:
	var path := NavigationServer3D.map_get_path(nav().get_navigation_map(), a, b, true)
	return path[path.size() - 1] if path.size() > 0 else Vector3.INF


func door(door_name: String) -> ZoneDoor:
	return level.get_node("Doors/" + door_name) as ZoneDoor


func _initialize() -> void:
	level = load("res://game/levels/campus.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	p = level.get_node("Players/1")
	zones = ZoneManager.of(level)
	waves = WaveDirector.of(level)
	waves.host_pause()
	RunManager.of(level).set_physics_process(false)
	HealthComponent.of(p).damage_filter = func(_a, _s, _h): return 0.0
	await wait_until(func(): return nav().navigation_mesh.get_polygon_count() > 0, 5.0)
	await frames(10)
	test_start()
	test_spawn_points()
	await test_doors()
	await test_reachable()
	await test_waves()
	await test_reset()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_start() -> void:
	var here := zones.zone_at(p.global_position)
	check("si parte nell'aula studio, sottoterra e coi piedi a terra", here != null and here.name == &"aula" \
			and p.global_position.y < -5.0 and p.is_on_floor(), str(p.global_position))
	check("aperte solo aula e Centri comuni", zones.unlocked_names() == [&"aula", &"centri"], str(zones.unlocked_names()))
	check("11 zone, 12 porte", zones.zones().size() == 11 and level.get_node("Doors").get_child_count() == 12)
	# Guardando l'uscita (nord, -Z) la parete sinistra è quella a ovest (-X).
	var board := level.get_node("Geometry/Lavagna") as CSGBox3D
	check("lavagna bianca su tutta la parete sinistra (27 m su 28)", board.global_position.x < -9.0 \
			and board.size.z >= 26.0 and board.size.y >= 2.5, "%s %s" % [board.global_position, board.size])
	check("dall'aula si sale ai Centri comuni a piedi (scala)",
			reach(p.global_position, Vector3(0, 0, 30)).distance_to(Vector3(0, 0, 30)) < 1.5)


func test_spawn_points() -> void:
	var counts := {}
	var bad: Array[String] = []
	for point in waves.get_children():
		if not point is Marker3D:
			continue
		var zone := zones.zone_at(point.global_position)
		if zone == null:
			bad.append(point.name + " fuori zona")
			continue
		counts[zone.name] = counts.get(zone.name, 0) + 1
		var closest := NavigationServer3D.map_get_closest_point(nav().get_navigation_map(), point.global_position)
		if closest.distance_to(point.global_position) > 1.0:
			bad.append("%s lontano dalla navigazione (%.1f m)" % [point.name, closest.distance_to(point.global_position)])
	check("ogni punto di comparsa è in una zona e sulla navigazione", bad.is_empty(), str(bad))
	var few: Array = zones.zones().filter(func(z): return counts.get(z.name, 0) < 2)
	check("almeno 2 punti di comparsa per zona", few.is_empty(), str(few.map(func(z): return z.name)))


func test_doors() -> void:
	var inventory := p.inventory()
	var first := door("PortaCentriViale")
	check("porta chiusa: la navigazione si ferma davanti", reach(Vector3(0, 0, 30), Vector3(0, 0, 0)).z > 12.5)
	inventory.money = 100
	first.interact(p, 0)
	check("senza soldi non si apre", not first.is_open and inventory.money == 100)
	check("scritta con il prezzo", first.interaction_text(p).contains("250 €") and first.interaction_text(p).contains("Viale"),
			first.interaction_text(p))
	inventory.money = 300
	first.interact(p, 0)
	check("comprata: 250 € in meno, aperta, viale aperto", first.is_open and inventory.money == 50 \
			and zones.zone(&"viale_ovest").unlocked and zones.zone(&"viale_est").unlocked, "%d €" % inventory.money)
	await seconds(1.0)
	check("non blocca più", first.get_child(0) is CollisionShape3D and (first.get_child(0) as CollisionShape3D).disabled)
	var opened := await wait_until(func(): return reach(Vector3(0, 0, 30), Vector3(0, 0, 0)).distance_to(Vector3(0, 0, 0)) < 1.5, 5.0)
	check("la navigazione si ricalcola e passa", opened)
	check("una porta comprata non si ricompra", first.interaction_text(p).is_empty())


func test_reachable() -> void:
	p.inventory().money = 100000
	for d in level.get_node("Doors").get_children():
		(d as ZoneDoor).interact(p, 0)
	check("tutte le zone aperte", zones.unlocked_names().size() == 11, str(zones.unlocked_names()))
	await seconds(1.5)
	await wait_until(func(): return not nav().is_rebaking(), 5.0)
	var unreachable: Array[String] = []
	for point in waves.get_children():
		if point is Marker3D:
			var end := reach(Vector3(0, -6, 80), point.global_position)
			if end.distance_to(point.global_position) > 1.5:
				unreachable.append("%s (%.1f m)" % [point.name, end.distance_to(point.global_position)])
	check("a porte aperte ogni punto di comparsa si raggiunge dall'aula", unreachable.is_empty(), str(unreachable))
	var top := reach(Vector3(0, -6, 80), Vector3(80, 12, -55))
	check("anche l'eliporto sul tetto della torre", top.distance_to(Vector3(80, 12, -55)) < 1.5, str(top))


func test_waves() -> void:
	# Il giocatore nell'aula: escono solo dall'aula e dai Centri comuni (le zone accanto).
	p.global_position = Vector3(0, -5.9, 80)
	await frames(2)
	var players: Array[Node3D] = [p]
	var allowed := waves._usable_points(players).map(func(m): return zones.zone_at(m.global_position).name)
	var only_near := allowed.all(func(n): return n == &"aula" or n == &"centri")
	check("dall'aula escono solo da aula e Centri comuni", only_near and not allowed.is_empty(), str(allowed))
	p.global_position = Vector3(75, -6.9, 60)
	await frames(2)
	allowed = waves._usable_points(players).map(func(m): return zones.zone_at(m.global_position).name)
	check("nei laboratori: laboratori e parcheggio", allowed.all(func(n): return n == &"laboratori" or n == &"parcheggio"), str(allowed))
	# Uno zombie lasciato lontano (in biblioteca, con il giocatore nei laboratori) torna in coda.
	waves.recycle_time = 1.0
	waves.phase = WaveDirector.Phase.ACTIVE
	waves.remaining = 1
	waves._spawn(waves.enemies[0])
	var enemy := waves._alive[0] as Enemy
	enemy.global_position = Vector3(0, 0.1, -40)
	enemy.set_physics_process(false)
	var queued_before := waves._queue.size()
	waves.set_physics_process(true)
	var enemy_id := enemy.get_instance_id()
	var gone := await wait_until(func(): return instance_from_id(enemy_id) == null, 4.0)
	waves.set_physics_process(false)
	check("lo zombie lontano da tutti sparisce e torna in coda", gone and waves._queue.size() == queued_before + 1 \
			and waves.remaining == 1, "coda %d, restano %d" % [waves._queue.size(), waves.remaining])
	# In rete arriva solo a chi è vicino.
	check("rilevanza: vicino sì, lontano e fuori zona no", zones.is_relevant(1, Vector3(80, -7, 50)) \
			and not zones.is_relevant(1, Vector3(-80, 0, -60)))


func test_reset() -> void:
	RunManager.of(level)._host_restart()
	await seconds(1.0)
	var closed := level.get_node("Doors").get_children().all(func(d): return not d.is_open)
	check("ripartenza: porte chiuse, aperte solo aula e Centri comuni", closed \
			and zones.unlocked_names() == [&"aula", &"centri"], str(zones.unlocked_names()))
	check("e si torna nell'aula", zones.zone_at(p.global_position) != null and zones.zone_at(p.global_position).name == &"aula",
			str(p.global_position))
