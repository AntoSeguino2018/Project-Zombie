extends SceneTree
# Test del passo 1.5b: Scattista, Bestione, pugno e Mano pesante.
# Va lanciato in tempo reale (niente --fixed-fps): la navigazione si aggiorna su un thread.

var failures := 0
var level: Node
var p: FpsController
var health: HealthComponent
var melee: MeleeAttack
var weapon: Weapon
var walker_scene: PackedScene = load("res://game/enemies/walker.tscn")
var runner_scene: PackedScene = load("res://game/enemies/runner.tscn")
var brute_scene: PackedScene = load("res://game/enemies/brute.tscn")

func check(name: String, ok: bool, info: String = "") -> void:
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

func spawn(scene: PackedScene, pos: Vector3, yaw := 0.0) -> Enemy:
	var e: Enemy = scene.instantiate()
	e.position = pos
	e.rotation.y = yaw
	level.add_child(e)
	return e

func place_player(pos: Vector3, yaw := 0.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p._push = Vector3.ZERO
	p._yaw = yaw
	p.rotation.y = yaw
	p.reset_physics_interpolation()

func clear_enemies() -> void:
	for n in get_nodes_in_group("enemies"):
		n.free()

func punch() -> void:
	melee._cooldown_left = 0.0
	melee.attack(p.get_node("Head").global_position, -p._aim_basis().z, p)

func hp(e: Node) -> float:
	return HealthComponent.of(e).current

func _initialize() -> void:
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	p = level.get_node("Players/1")
	health = HealthComponent.of(p)
	melee = p.get_node("Camera3D/Melee")
	weapon = p.get_node("Camera3D/Weapon")
	weapon.host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	weapon._switch_left = 0.0
	weapon.data.spread_degrees = 0.0
	level.get_node("Waves").free()
	for s in level.get_node("Enemies").get_children():
		s.free()
	var nav: NavigationRegion3D = level.get_node("Navigation")
	await wait_until(func(): return nav.get_navigation_map().is_valid() and NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) > 0 and NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), Vector3(25, 0, 0)).y > 0.1, 5.0)

	# --- Scattista -----------------------------------------------------------
	place_player(Vector3(25, 0, 0))
	var r := spawn(runner_scene, Vector3(25, 0, 25))
	var swing := [0.0]
	var t0 := Time.get_ticks_msec()
	var started := await wait_until(func():
		swing[0] = maxf(swing[0], absf(r.global_position.x - 25.0))
		return r.is_attacking(), 6.0)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	check("Scattista: arriva in fretta", started and took < 4.0, "%.1f s per ~20 m" % took)
	check("Scattista: zig-zag", swing[0] > 1.0, "scarto laterale max=%.2f m" % swing[0])
	var before := health.current
	var hit := await wait_until(func(): return health.current < before, 1.5)
	check("Scattista: il tuffo colpisce (10)", hit and is_equal_approx(before - health.current, 10.0), "vita=%s" % health.current)
	await wait_until(func(): return not r.is_attacking(), 2.0)
	check("Scattista: dopo un tuffo a segno non è stordito", not r.is_stunned())

	# Tuffo a vuoto: il giocatore si sposta mentre è in volo
	health.reset()
	place_player(Vector3(25, 0, 0))
	r.global_position = Vector3(25, 0, 4.5)
	await wait_until(func(): return r.is_attacking() and r._lunge == RunnerEnemy.Lunge.AIR, 3.0)
	place_player(Vector3(33, 0, 0))
	var stunned := await wait_until(func(): return r.is_stunned(), 1.5)
	check("Scattista: tuffo a vuoto -> stordito", stunned and health.current == 100.0, "vita=%s" % health.current)
	var head: Vector3 = p.get_node("Head").global_position
	var shots := 0
	while HealthComponent.of(r).is_alive() and shots < 10:
		weapon._cooldown = 0.0
		weapon.fire(head, (r.center() - head).normalized(), [p.get_rid()])
		shots += 1
	check("Scattista: muore con 3 colpi", shots == 3, "colpi=%d" % shots)
	clear_enemies()

	# --- Bestione: corazza -----------------------------------------------------
	var b := spawn(brute_scene, Vector3(25, 0, 10))
	b.set_physics_process(false)
	var bh := HealthComponent.of(b)
	var front := bh.take_damage(12.0, null, b.global_position + Vector3(0, 1.5, -0.7))
	var back := bh.take_damage(12.0, null, b.global_position + Vector3(0, 1.5, 0.7))
	var side := bh.take_damage(12.0, null, b.global_position + Vector3(0.7, 1.5, 0))
	var low_back := bh.take_damage(12.0, null, b.global_position + Vector3(0, 0.5, 0.7))
	check("Bestione: davanti 1/4 del danno", is_equal_approx(front, 3.0), str(front))
	check("Bestione: punto debole x2,5", is_equal_approx(back, 30.0), str(back))
	check("Bestione: di lato danno pieno", is_equal_approx(side, 12.0), str(side))
	check("Bestione: dietro ma in basso danno pieno", is_equal_approx(low_back, 12.0), str(low_back))
	# Con l'arma vera, dal davanti e da dietro
	bh.reset()
	place_player(Vector3(25, 0, 0))
	await frames(2)
	head = p.get_node("Head").global_position
	weapon._cooldown = 0.0
	weapon.fire(head, (b.global_position + Vector3(0, 1.45, 0) - head).normalized(), [p.get_rid()])
	check("Bestione: sparato davanti", is_equal_approx(bh.current, 397.0), "vita=%s" % bh.current)
	place_player(Vector3(25, 0, 20), PI)
	await frames(2)
	head = p.get_node("Head").global_position
	weapon._cooldown = 0.0
	weapon.fire(head, (b.global_position + Vector3(0, 1.45, 0) - head).normalized(), [p.get_rid()])
	check("Bestione: sparato sul punto debole", is_equal_approx(bh.current, 367.0), "vita=%s" % bh.current)
	b.set_physics_process(true)
	b.apply_knockback(Vector3(0, 5, -14), 20.0, p)
	await frames(3)
	check("Bestione: le spinte non lo lanciano, lo stordiscono", b.is_stunned() and not b.is_launched() and _flat_len(b.velocity) < 0.1)
	clear_enemies()

	# --- Bestione: carica -----------------------------------------------------
	health.reset()
	place_player(Vector3(25, 0, 0))
	b = spawn(brute_scene, Vector3(25, 0, 11))
	b._charge_cooldown_left = 0.0
	var charging := await wait_until(func(): return b.is_charging(), 3.0)
	check("Bestione: carica da lontano", charging, "pos=%s" % b.global_position)
	before = health.current
	var z_before := p.global_position.z
	hit = await wait_until(func(): return health.current < before, 2.0)
	check("Bestione: la carica toglie 30", hit and is_equal_approx(before - health.current, 30.0), "vita=%s" % health.current)
	await seconds(0.5)
	check("Bestione: la carica scaraventa via il giocatore", z_before - p.global_position.z > 3.0, "spostato di %.1f m" % (z_before - p.global_position.z))
	clear_enemies()

	health.reset()
	place_player(Vector3(25, 0, -37))
	b = spawn(brute_scene, Vector3(25, 0, -27), 0.0)
	b._charge_cooldown_left = 0.0
	await wait_until(func(): return b.is_charging(), 3.0)
	place_player(Vector3(35, 0, -30))
	stunned = await wait_until(func(): return b.is_stunned(), 2.0)
	check("Bestione: contro il muro resta stordito", stunned, "pos=%s" % b.global_position)
	check("Bestione: il giocatore schivato è illeso", health.current == 100.0, "vita=%s" % health.current)
	clear_enemies()

	# --- Pugno e Mano pesante --------------------------------------------------
	health.reset()
	place_player(Vector3(25, 0, 0))
	var a := spawn(walker_scene, Vector3(25, 0, -2), PI)
	var c := spawn(walker_scene, Vector3(25, 0, -6), PI)
	await frames(2)
	punch()
	check("Mano pesante: 25 di danno", is_equal_approx(hp(a), 35.0), "vita=%s" % hp(a))
	check("Mano pesante: lo zombie vola", a.is_launched())
	check("il pugno ha un tempo di ricarica", not melee.can_attack())
	var c_hit := await wait_until(func(): return hp(c) < 60.0, 1.0)
	check("lo zombie lanciato ne colpisce un altro (20)", c_hit and is_equal_approx(hp(c), 40.0), "vita=%s" % hp(c))
	await frames(2)
	check("e lo spinge via", c.is_launched() or c.is_stunned())
	await wait_until(func(): return not a.is_launched(), 2.0)
	check("atterrato resta stordito", a.is_stunned(), "pos=%s" % a.global_position)
	clear_enemies()

	place_player(Vector3(25, 0, -36))
	a = spawn(walker_scene, Vector3(25, 0, -38), PI)
	await frames(2)
	punch()
	var wall := await wait_until(func(): return hp(a) < 35.0, 1.0)
	check("contro il muro si fa male (20)", wall and is_equal_approx(hp(a), 15.0), "vita=%s" % hp(a))
	clear_enemies()

	place_player(Vector3(25, 0, 0))
	a = spawn(walker_scene, Vector3(25, 0, -2), PI)
	HealthComponent.of(a).take_damage(45.0)
	await frames(2)
	punch()
	await frames(2)
	check("il colpo finale fa volare il corpo", not HealthComponent.of(a).is_alive() and _flat_len(a.velocity) > 5.0, "vel=%s" % a.velocity)
	await seconds(0.8)
	check("il corpo atterra (non resta in aria)", a.is_on_floor(), "pos=%s" % a.global_position)
	clear_enemies()

	melee.heavy_hand = false
	a = spawn(walker_scene, Vector3(25, 0, -2), PI)
	c = spawn(walker_scene, Vector3(25, 0, -5), PI)
	await frames(2)
	punch()
	check("pugno normale: 10 di danno", is_equal_approx(hp(a), 50.0), "vita=%s" % hp(a))
	await seconds(1.0)
	check("pugno normale: niente danni da urto", is_equal_approx(hp(c), 60.0) and is_equal_approx(hp(a), 50.0), "a=%s c=%s" % [hp(a), hp(c)])
	melee.heavy_hand = true
	clear_enemies()

	b = spawn(brute_scene, Vector3(25, 0, -2.2), PI)
	b.set_physics_process(false)
	await frames(2)
	b.set_physics_process(true)
	punch()
	await frames(2)
	check("pugno al Bestione da davanti: 1/4 e stordito", is_equal_approx(hp(b), 400.0 - 6.25) and b.is_stunned(), "vita=%s" % hp(b))
	clear_enemies()

	place_player(Vector3(0, 0, 13.5))
	a = spawn(walker_scene, Vector3(0, 0, 18), PI)
	a.set_physics_process(false)
	await frames(2)
	punch()
	check("niente pugni attraverso i pilastri", is_equal_approx(hp(a), 60.0), "vita=%s" % hp(a))
	clear_enemies()

	# --- Spinta sul giocatore ---------------------------------------------------
	place_player(Vector3(25, 0, 0))
	await frames(2)
	p.apply_knockback(Vector3(0, 4, 12))
	await seconds(1.0)
	var moved := p.global_position.z
	await seconds(0.5)
	check("il giocatore viene spinto e poi si ferma", moved > 3.0 and absf(p.global_position.z - moved) < 0.3, "z=%.2f poi %.2f" % [moved, p.global_position.z])

	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)

func _flat_len(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
