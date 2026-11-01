extends SceneTree
# Test del passo 1.9: strutture distruttibili a blocchi.

var failures := 0
var level: Node
var p: FpsController
var weapon: Weapon
var melee: MeleeAttack
var nav: LevelNavigation
var walker_scene: PackedScene = load("res://game/enemies/walker.tscn")
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

func place_player(pos: Vector3, yaw := 0.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	p.rotation.y = yaw
	p._pitch = 0.0
	p.reset_physics_interpolation()

func head() -> Vector3:
	return p.get_node("Head").global_position

func new_wall(pos: Vector3, size: Vector3, yaw := 0.0) -> DestructibleBlocks:
	var wall := DestructibleBlocks.new()
	wall.size = size
	wall.position = pos
	wall.rotation.y = yaw
	level.get_node("Destructibles").add_child(wall)
	return wall

func debris_count() -> int:
	return RubbleField.of(level).active_count()

func path_length(from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(nav.get_navigation_map(), from, to, true)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total

func wait_rebake() -> void:
	await frames(2)
	await wait_until(func(): return not nav.is_rebaking(), 3.0)
	await frames(4)

func _initialize() -> void:
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	p = level.get_node("Players/1")
	weapon = p.get_node("Camera3D/Weapon")
	weapon.host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	weapon._switch_left = 0.0
	melee = p.get_node("Camera3D/Melee")
	nav = level.get_node("Navigation")
	level.get_node("Waves").free()
	for s in level.get_node("Enemies").get_children():
		s.free()
	weapon.data.spread_degrees = 0.0
	await wait_until(func(): return nav.get_navigation_map().is_valid() and NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) > 0 and path_length(Vector3(25, 0, 0), Vector3(25, 0, -5)) > 0.0, 5.0)

	# --- Costruzione -------------------------------------------------------------
	var wall: DestructibleBlocks = level.get_node("Destructibles/WallBehindSpawn")
	check("il muro 6x3x0,5 ha 576 blocchi da 0,25 m", wall.block_count() == 576 and wall.blocks_left() == 576, str(wall.block_count()))
	check("e 576 collisioni", wall._shapes.size() == 576)
	var around := path_length(Vector3(0, 0, 10), Vector3(0, 0, 4))
	check("all'inizio gli zombie devono girargli intorno", around > 7.0, "percorso %.1f m" % around)

	# --- La carabina non lo scalfisce -------------------------------------------
	place_player(Vector3(0, 0, 3), PI)
	await frames(3)
	for i in 10:
		weapon._cooldown = 0.0
		weapon.fire(head(), Vector3.BACK, [p.get_rid()])
	check("la carabina non rompe i blocchi", wall.blocks_left() == 576, str(wall.blocks_left()))

	# --- Granata ----------------------------------------------------------------
	weapon.equip(1)
	await seconds(0.35)
	weapon._cooldown = 0.0
	weapon.muzzle = null
	weapon.fire(Vector3(0, 1.5, 5.5), Vector3.BACK, [p.get_rid()])
	await wait_until(func(): return wall.blocks_left() < 576, 1.0)
	var left := wall.blocks_left()
	check("la granata apre un buco", left < 540 and left > 330, "blocchi rimasti %d su 576" % left)
	check("nessun blocco resta sospeso nel vuoto", wall._unsupported_blocks().is_empty())
	await frames(2)
	check("i pezzi diventano detriti fisici", debris_count() > 5, "pezzi fisici=%d" % debris_count())
	var field := RubbleField.of(level)
	await wait_until(func(): return field._active.size() > 0 and field._active.all(func(item): return item[4] >= 0.0), 4.0)
	await seconds(7.0)
	check("a terra restano spostabili per almeno 10 s", debris_count() > 5 and field.rubble_count() == 0, "fisici=%d immobili=%d" % [debris_count(), field.rubble_count()])
	# Un'esplosione rilancia i pezzi ancora fisici (un pezzo fermo in campo aperto)
	field.spawn(Transform3D(Basis(), Vector3(25, 0.2, -3)), 0.24, Color.RED, Vector3.ZERO)
	await seconds(2.0)
	var piece: RigidBody3D = field._active[-1][0]
	var piece_before := piece.global_position
	field.push_sphere(piece_before + Vector3(0.5, -0.2, 0), 3.0, 10.0)
	await frames(10)
	check("un'esplosione li rilancia", piece.global_position.distance_to(piece_before) > 0.5, "spostato di %.2f m" % piece.global_position.distance_to(piece_before))
	await wait_until(func(): return debris_count() == 0, 8.0)
	var rubble := field.rubble_count()
	check("dopo 10 s diventano macerie immobili", debris_count() == 0 and rubble > 5, "fisici=%d immobili=%d" % [debris_count(), rubble])
	await seconds(3.0)
	check("le macerie non spariscono", field.rubble_count() == rubble, "macerie=%d" % field.rubble_count())

	# --- Navigazione: dopo uno sfondamento si passa dal buco ---------------------------
	wall.damage_sphere(Vector3(0, 1.3, 7), 1.6, 200.0)
	await wait_rebake()
	var through := path_length(Vector3(0, 0, 10), Vector3(0, 0, 4))
	check("dopo lo sfondamento si passa attraverso", through < 6.6 and through > 0.0, "percorso %.1f m (prima %.1f)" % [through, around])

	# --- Pugni ------------------------------------------------------------------
	var cover: DestructibleBlocks = level.get_node("Destructibles/CoverEast")
	var total := cover.blocks_left()
	place_player(Vector3(4, 0, -5.6))
	p._pitch = deg_to_rad(-25.0)
	await frames(3)
	melee._cooldown_left = 0.0
	melee.attack(head(), -p._aim_basis().z, p)
	var heavy_loss := total - cover.blocks_left()
	check("Mano pesante: un pugno stacca un pezzo di più blocchi", heavy_loss >= 3 and heavy_loss <= 16, "%d -> %d" % [total, cover.blocks_left()])
	total = cover.blocks_left()
	melee.heavy_hand = false
	melee._cooldown_left = 0.0
	var aim := (Vector3(3.125, 0.625, -6.75) - head()).normalized()
	melee.attack(head(), aim, p)
	var after_one := cover.blocks_left()
	melee._cooldown_left = 0.0
	melee.attack(head(), aim, p)
	check("pugno normale: un blocco a colpo", after_one == total - 1 and cover.blocks_left() == total - 2, "%d -> %d -> %d" % [total, after_one, cover.blocks_left()])

	# --- Crollo enorme: oltre il limite i pezzi si polverizzano -----------------------
	var big: DestructibleBlocks = level.get_node("Destructibles/WallWestYard")
	var flying_before := debris_count()
	var broken := big.damage_sphere(big.to_global(Vector3(0, 1.5, 0)), 3.0, 400.0)
	await frames(1)
	var dust := level.get_children().filter(func(n): return n is CPUParticles3D).size()
	check("crollo enorme: pezzi fisici limitati, il resto in polvere", broken > 150 and debris_count() - flying_before <= big.max_debris_per_break and dust >= 1, "rotti=%d in volo=%d polvere=%d" % [broken, debris_count(), dust])
	melee.heavy_hand = true

	# --- Zombie scaraventati ------------------------------------------------------
	weapon.equip(0)
	var lane := new_wall(Vector3(25, 0, -6), Vector3(4, 3, 0.5))
	await frames(3)
	place_player(Vector3(25, 0, -1.5))
	var zombie: Enemy = walker_scene.instantiate()
	zombie.position = Vector3(25, 0, -3.3)
	zombie.rotation.y = PI
	level.add_child(zombie)
	await frames(3)
	melee._cooldown_left = 0.0
	melee.attack(head(), Vector3.FORWARD, p)
	await wait_until(func(): return lane.blocks_left() < lane.block_count(), 1.0)
	check("zombie lanciato forte sfonda il muro", lane.blocks_left() < lane.block_count(), "%d su %d" % [lane.blocks_left(), lane.block_count()])
	zombie.free()

	var lane2 := new_wall(Vector3(32, 0, -6), Vector3(4, 3, 0.5))
	await frames(3)
	place_player(Vector3(32, 0, -1.5))
	zombie = walker_scene.instantiate()
	zombie.position = Vector3(32, 0, -3.3)
	zombie.rotation.y = PI
	level.add_child(zombie)
	await frames(3)
	melee.heavy_hand = false
	melee._cooldown_left = 0.0
	melee.attack(head(), Vector3.FORWARD, p)
	await seconds(1.0)
	check("una spinta debole non lo rompe", lane2.blocks_left() == lane2.block_count(), "%d su %d" % [lane2.blocks_left(), lane2.block_count()])
	melee.heavy_hand = true
	zombie.free()
	lane.free()
	lane2.free()

	# --- Bestione in carica -------------------------------------------------------
	place_player(Vector3(25, 0, -2))
	var brute: BruteEnemy = brute_scene.instantiate()
	brute.position = Vector3(25, 0, -15)
	brute.rotation.y = PI
	level.add_child(brute)
	brute._charge_cooldown_left = 0.0
	await wait_until(func(): return brute.is_attacking() and brute._charging, 3.0)
	var barrier := new_wall(Vector3(25, 0, -9), Vector3(4, 3, 0.5))
	await wait_until(func(): return brute.global_position.z > -8.0 or brute.is_stunned(), 3.0)
	check("il Bestione sfonda il muro e prosegue", brute.global_position.z > -8.0 and not brute.is_stunned(), "z=%.1f stordito=%s" % [brute.global_position.z, brute.is_stunned()])
	check("e il muro ha un buco grande", barrier.blocks_left() < barrier.block_count() - 10, "%d su %d" % [barrier.blocks_left(), barrier.block_count()])

	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)
