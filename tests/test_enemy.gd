extends SceneTree
# Test del passo 1.5: navigazione, inseguimento, attacco schivabile, morte del
# nemico, morte e rinascita del giocatore, caduta fuori mappa, spawner.
# Va lanciato in tempo reale (niente --fixed-fps): la navigazione si aggiorna su un thread.

var failures := 0
var level: Node
var p: FpsController
var health: HealthComponent
var walker_scene: PackedScene = load("res://game/enemies/walker.tscn")

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func seconds(s: float) -> void:
	await frames(int(s * 60.0))

func wait_until(cond: Callable, max_seconds: float) -> bool:
	for i in int(max_seconds * 60.0):
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func spawn_enemy(pos: Vector3) -> MeleeEnemy:
	var e: MeleeEnemy = walker_scene.instantiate()
	e.position = pos
	level.add_child(e)
	return e

func place_player(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()

func living_enemies() -> Array:
	return root.get_tree().get_nodes_in_group("enemies").filter(func(n): return n is MeleeEnemy and HealthComponent.of(n).is_alive())

func _initialize() -> void:
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	p = level.get_node("Players/1")
	health = HealthComponent.of(p)
	level.get_node("Waves").free()
	for s in level.get_node("Enemies").get_children():
		s.free()
	var weapon: Weapon = p.get_node("Camera3D/Weapon")
	weapon.host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	weapon._switch_left = 0.0
	weapon.data.spread_degrees = 0.0

	# 1. Mappa di navigazione
	var nav: NavigationRegion3D = level.get_node("Navigation")
	var baked := await wait_until(func(): return nav.navigation_mesh.get_polygon_count() > 0, 5.0)
	check("navmesh calcolata", baked, "poligoni=%d" % nav.navigation_mesh.get_polygon_count())
	await wait_until(func(): return NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) > 0 and NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), Vector3(-10, 3.5, -16)).y > 1.0, 3.0)
	var map := nav.get_navigation_map()
	var deck := NavigationServer3D.map_get_closest_point(map, Vector3(-10, 3.5, -16))
	check("navmesh sopra la piattaforma", absf(deck.y - 3.0) < 0.6 and Vector2(deck.x, deck.z).distance_to(Vector2(-10, -16)) < 0.1, str(deck))
	var path := NavigationServer3D.map_get_path(map, Vector3(-10, 0, 0), Vector3(-8, 3, -18), true)
	check("percorso fino alla piattaforma", path.size() > 1 and path[-1].y > 2.7, "punti=%d fine=%s" % [path.size(), str(path[-1]) if path else "-"])

	# 2. Inseguimento aggirando il pilastro (0, 16) e primo colpo
	place_player(Vector3(0, 0, 8))
	var e := spawn_enemy(Vector3(0, 0, 26))
	var detour := [0.0]
	var reached := await wait_until(func():
		detour[0] = maxf(detour[0], absf(e.global_position.x))
		return e.is_attacking(), 15.0)
	check("insegue e arriva ad attaccare", reached, "pos=%s" % e.global_position)
	check("aggira il pilastro", detour[0] > 0.6, "scarto laterale max=%.2f m" % detour[0])
	var before := health.current
	await wait_until(func(): return health.current < before, 1.5)
	check("il colpo toglie 15 di vita", is_equal_approx(before - health.current, 15.0), "vita=%s" % health.current)

	# 3. Il colpo si può schivare allontanandosi durante la preparazione
	await wait_until(func(): return not e.is_attacking(), 2.0)
	await wait_until(func(): return e.is_attacking(), 2.0)
	before = health.current
	place_player(p.global_position + Vector3(5, 0, 0))
	await seconds(e.attack_windup + 0.15)
	check("schivato allontanandosi", health.current == before, "vita=%s" % health.current)

	# 4. Il nemico muore con 5 colpi di carabina e poi sparisce
	await frames(2)
	var head: Vector3 = p.get_node("Head").global_position
	var enemy_health := HealthComponent.of(e)
	var shots := 0
	while enemy_health.is_alive() and shots < 10:
		weapon._cooldown = 0.0
		var aim := (e.global_position + Vector3.UP * 1.1 - head).normalized()
		weapon.fire(head, aim, [p.get_rid()])
		shots += 1
	check("muore con 5 colpi", not enemy_health.is_alive() and shots == 5, "colpi=%d" % shots)
	await frames(2)
	check("da morto non blocca più", e.collision_layer == 0, "")
	await seconds(e.corpse_time + 0.8)
	check("il corpo sparisce", not is_instance_valid(e), "")

	# 5. Sale la rampa per raggiungere il giocatore sulla piattaforma
	health.reset()
	place_player(Vector3(-8, 3.05, -18))
	e = spawn_enemy(Vector3(-10, 0, 0))
	var climbed := await wait_until(func(): return e.global_position.y > 2.5, 15.0)
	check("sale sulla piattaforma dalla rampa", climbed, "pos=%s" % e.global_position)
	var attacked := await wait_until(func(): return e.is_attacking(), 5.0)
	check("attacca anche lassù", attacked, "")
	e.free()

	# 6. Morte e rinascita del giocatore
	health.reset()
	place_player(Vector3(5, 0, 5))
	await frames(2)
	health.take_damage(90.0)
	e = spawn_enemy(Vector3(5, 0, 2))
	var died := await wait_until(func(): return not health.is_alive(), 4.0)
	var hud: PlayerHud = p.get_node("Hud")
	check("il giocatore va a terra", died and p.life == FpsController.Life.DOWNED, "vita=%s" % health.current)
	check("schermata di morte", hud.get_node("DeathLabel").visible and not hud.crosshair.visible, hud.get_node("DeathLabel").text.replace("\n", " | "))
	check("arma nascosta", not weapon.visible, "")
	await seconds(1.0)
	check("i nemici smettono di attaccare chi è a terra", not e.is_attacking() and e._target == null, "")
	# Da soli andare a terra fa perdere la run: si riparte (qui senza aspettare).
	check("da soli: run persa", RunManager.of(level).lost, "")
	RunManager.of(level)._restart_left = 0.1
	var revived := await wait_until(func(): return health.is_alive(), 1.0)
	check("si riparte", revived, "")
	check("al punto di partenza con vita piena", p.global_position.distance_to(Vector3(0, 0.1, 0)) < 0.3 and health.current == 100.0, "pos=%s vita=%s" % [p.global_position, health.current])
	check("HUD ripristinato", not hud.get_node("DeathLabel").visible and hud.crosshair.visible and weapon.visible, "")
	e = spawn_enemy(Vector3(5, 0, 2))
	var chasing := await wait_until(func(): return e.is_attacking(), 5.0)
	check("i nemici tornano a inseguirlo", chasing, "")
	e.free()

	# 7. Caduta fuori dal livello
	await frames(2)
	place_player(Vector3(0, -35, 0))
	var fell := await wait_until(func(): return not health.is_alive(), 0.5)
	check("sotto la quota limite si muore", fell and p.life == FpsController.Life.DEAD, "")
	await frames(2)
	RunManager.of(level)._restart_left = 0.1
	revived = await wait_until(func(): return health.is_alive(), 1.0)
	check("e si rinasce", revived and p.global_position.y > -1.0, "pos=%s" % p.global_position)

	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)
