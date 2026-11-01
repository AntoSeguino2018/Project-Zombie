extends SceneTree
# Passo 3.6: la mappa grande. Navigazione che collega tutto (zone, punti di
# comparsa, casse, macchinette, soppalco e piattaforma), partenza nell'atrio,
# zombie che arrivano da lontano, casse e macchinette che funzionano.
var failures := 0
var level: Node
var p: FpsController
var map: RID


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


## Vero se dal punto start si arriva camminando entro tolerance da goal.
func reachable(start: Vector3, goal: Vector3, tolerance := 1.2) -> bool:
	var from := NavigationServer3D.map_get_closest_point(map, start)
	var path := NavigationServer3D.map_get_path(map, from, goal, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(goal) <= tolerance


func _initialize() -> void:
	var t := Time.get_ticks_msec()
	level = load("res://game/levels/complex.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	map = level.get_node("Navigation").get_navigation_map()
	var baked := await wait_until(func(): return NavigationServer3D.map_get_iteration_id(map) > 0 \
			and level.get_node("Navigation").navigation_mesh.get_polygon_count() > 0, 10.0)
	await frames(5)
	check("la navigazione si calcola all'avvio", baked, "%d ms, %d poligoni" % [Time.get_ticks_msec() - t,
			level.get_node("Navigation").navigation_mesh.get_polygon_count()])
	WaveDirector.of(level).host_pause()
	p = level.get_node("Players/1")
	await frames(10)
	var start := p.global_position
	check("si parte nell'atrio, a terra", start.distance_to(Vector3(-2, 0, 15)) < 0.5 and p.is_on_floor(), str(start))

	var zones := {"Aula studio": Vector3(-35, 0, 9), "Cortile": Vector3(35, 0, 20), "Corridoio": Vector3(0, 0, -3),
			"Archivio": Vector3(-37, 0, -24), "Sala alta": Vector3(0, 0, -18), "Soppalco": Vector3(0, 3, -34),
			"Magazzino": Vector3(30, 0, -20), "Piattaforma": Vector3(48, 2, -33)}
	var missing := []
	for zone in zones:
		if not reachable(start, zones[zone]):
			missing.append(zone)
	check("dall'atrio si arriva a piedi in tutte le zone (anche soppalco e piattaforma)", missing.is_empty(), str(missing))

	missing = []
	for marker: Marker3D in level.get_node("Waves").get_children():
		var closest := NavigationServer3D.map_get_closest_point(map, marker.global_position)
		if closest.distance_to(marker.global_position) > 0.5 or not reachable(marker.global_position, start, 1.5):
			missing.append(marker.name)
	check("ogni punto di comparsa è sulla navigazione e porta all'atrio", missing.is_empty(), str(missing))
	check("almeno 12 punti di comparsa", level.get_node("Waves").get_child_count() >= 12)

	missing = []
	for thing in level.get_node("Crates").get_children() + level.get_node("Machines").get_children():
		var front: Vector3 = thing.global_position + thing.global_basis.z * 1.2
		if not reachable(start, front, 1.0):
			missing.append(thing.name)
	check("casse e macchinette raggiungibili (davanti)", missing.is_empty(), str(missing))
	check("6 casse e almeno 6 macchinette", level.get_node("Crates").get_child_count() == 6 \
			and level.get_node("Machines").get_child_count() >= 6)

	# Una cassa e una macchinetta lontane funzionano.
	var crate: WeaponCrate = level.get_node("Crates/CassaSoppalco")
	p.inventory().host_add_money(200)
	crate.interact(p, 0)
	await frames(2)
	check("la cassa sul soppalco si apre", crate.is_open)
	var machine: VendingMachine = level.get_node("Machines/EspressoCortile")
	machine.jam_chance = 0.0
	machine.interact(p, 0)
	check("la macchinetta del cortile vende", p.inventory().boosts.size() == 1)

	# Uno zombie dal fondo del magazzino arriva fino all'atrio.
	var walker: Enemy = load("res://game/enemies/walker.tscn").instantiate()
	level.get_node("Enemies").add_child(walker)
	walker.global_position = Vector3(53, 0, -9)
	HealthComponent.of(p).damage_filter = func(_a, _s, _h): return 0.0
	var arrived := await wait_until(func(): return walker.global_position.distance_to(p.global_position) < 3.0, 40.0)
	check("uno zombie dal magazzino raggiunge il giocatore nell'atrio", arrived,
			"distanza %.1f m" % walker.global_position.distance_to(p.global_position))
	walker.queue_free()

	# Prima ondata: escono dai punti lontani e fuori vista.
	var waves := WaveDirector.of(level)
	waves.set_physics_process(true)
	waves._time_left = 0.1
	# Dove compare ogni zombie (la prima posizione vista).
	var first_seen := {}
	for i in 60 * 10:
		await physics_frame
		for z in level.get_node("Enemies").get_children():
			if z is Enemy and not first_seen.has(z):
				first_seen[z] = z.global_position
		if waves._queue.is_empty() and waves.wave == 1:
			break
	var closest := INF
	for z in first_seen:
		closest = minf(closest, first_seen[z].distance_to(p.global_position))
	check("ondata 1: 6 zombie, comparsi tutti lontano dal giocatore", first_seen.size() == 6 and closest >= 14.0,
			"%d zombie, il più vicino a %.1f m" % [first_seen.size(), closest])
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)
