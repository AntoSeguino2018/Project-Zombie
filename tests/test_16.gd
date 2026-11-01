extends SceneTree
# Test del passo 1.6: proiettili fisici, esplosioni, cambio arma.

var failures := 0
var level: Node
var p: FpsController
var weapon: Weapon
var hud: PlayerHud
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

func spawn(scene: PackedScene, pos: Vector3, frozen := true) -> Enemy:
	var e: Enemy = scene.instantiate()
	e.position = pos
	e.rotation.y = PI
	level.add_child(e)
	if frozen:
		e.set_physics_process(false)
	return e

func clear_enemies() -> void:
	for n in get_nodes_in_group("enemies"):
		n.free()

func head() -> Vector3:
	return p.get_node("Head").global_position

func shoot(direction: Vector3, origin := Vector3.INF) -> void:
	weapon._cooldown = 0.0
	weapon._switch_left = 0.0
	# Con un'origine scelta dal test il colpo deve partire proprio da lì, non dalla canna.
	var muzzle := weapon.muzzle
	if origin != Vector3.INF:
		weapon.muzzle = null
	weapon.fire(head() if origin == Vector3.INF else origin, direction.normalized(), [p.get_rid()])
	weapon.muzzle = muzzle

func nodes_of(type_name: String) -> Array:
	return level.get_children().filter(func(n): return n.get_script() and n.get_script().get_global_name() == type_name)

func hp(e: Node) -> float:
	return HealthComponent.of(e).current

func _initialize() -> void:
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	p = level.get_node("Players/1")
	weapon = p.get_node("Camera3D/Weapon")
	weapon.host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	weapon._switch_left = 0.0
	hud = p.get_node("Hud")
	level.get_node("Waves").free()
	for s in level.get_node("Enemies").get_children():
		s.free()
	await frames(5)

	# --- Cambio arma -----------------------------------------------------------
	check("si parte con la carabina", weapon.data.display_name == "Carabina" and weapon.muzzle != null, weapon.data.display_name)
	check("etichetta HUD", hud.get_node("WeaponLabel").text == "Carabina", hud.get_node("WeaponLabel").text)
	weapon.equip(1)
	check("passa al lanciagranate", weapon.data.display_name == "Lanciagranate" and hud.get_node("WeaponLabel").text == "Lanciagranate")
	check("durante il cambio non si spara", not weapon.can_fire())
	await seconds(0.35)
	check("dopo 0,3 s si spara", weapon.can_fire())
	await frames(2)
	check("il modello in mano è cambiato", weapon.muzzle != null and weapon.muzzle.get_parent().name == "GrenadeLauncherViewmodel", str(weapon.muzzle.get_parent().name if weapon.muzzle else "-"))
	weapon.cycle(1)
	check("la rotella fa il giro", weapon.current_slot() == 0)
	weapon.cycle(-1)
	check("e all'indietro", weapon.current_slot() == 1)
	weapon.data.spread_degrees = 0.0

	# --- Volo: cade con la gravità, non attraversa i muri ------------------------
	place_player(Vector3(25, 0, 0))
	await frames(3)
	shoot(Vector3.FORWARD)
	var grenade: Projectile = nodes_of("Projectile")[0]
	var start := grenade.global_position
	await seconds(0.3)
	var moved := start.distance_to(grenade.global_position)
	check("vola a ~28 m/s", moved > 7.5 and moved < 9.5, "%.1f m in 0,3 s" % moved)
	check("cade con la gravità", grenade.global_position.y < start.y - 0.3, "da y=%.2f a y=%.2f" % [start.y, grenade.global_position.y])
	await wait_until(func(): return nodes_of("Projectile").is_empty(), 3.0)
	var explosions := nodes_of("ExplosionEffect")
	check("esplode quando tocca il pavimento", explosions.size() == 1 and explosions[0].global_position.y < 0.3, str(explosions[0].global_position) if explosions else "-")
	await seconds(1.0)

	var data: WeaponData = weapon.data
	data.projectile_speed = 400.0
	data.projectile_gravity = 0.0
	place_player(Vector3(25, 0, -35))
	await frames(3)
	shoot(Vector3.FORWARD)
	await wait_until(func(): return nodes_of("Projectile").is_empty(), 1.0)
	explosions = nodes_of("ExplosionEffect")
	check("anche velocissimo si ferma sul muro", explosions.size() == 1 and explosions[0].global_position.z > -40.0, str(explosions[0].global_position) if explosions else "-")
	data.projectile_speed = 28.0
	data.projectile_gravity = 12.0
	await seconds(1.0)

	# Canna dentro il muro: il colpo parte dalla testa e non passa oltre
	place_player(Vector3(25, 0, -39.35))
	await frames(3)
	shoot(Vector3.FORWARD)
	await wait_until(func(): return nodes_of("Projectile").is_empty(), 1.0)
	explosions = nodes_of("ExplosionEffect")
	check("con la canna nel muro non si spara attraverso", explosions.size() == 1 and explosions[0].global_position.z > -40.0, str(explosions[0].global_position) if explosions else "-")
	await seconds(1.0)

	# --- Danni -----------------------------------------------------------------
	place_player(Vector3(25, 0, 0))
	var target := spawn(walker_scene, Vector3(25, 0, -8))
	await frames(3)
	var hits := []
	var on_hit := func(_t, amount, killed): hits.append([amount, killed])
	weapon.dealt_damage.connect(on_hit)
	shoot(target.center() - head())
	await wait_until(func(): return not HealthComponent.of(target).is_alive(), 1.0)
	check("colpo diretto + esplosione uccidono un Camminatore", not HealthComponent.of(target).is_alive(), "vita=%s" % hp(target))
	check("hitmarker dal proiettile", hits.size() >= 1 and hits[-1][1], str(hits))
	weapon.dealt_damage.disconnect(on_hit)
	clear_enemies()

	# Danno ad area che cala con la distanza, e spinta
	var near := spawn(walker_scene, Vector3(24.0, 0, -10), false)
	var mid := spawn(walker_scene, Vector3(27.2, 0, -10), false)
	var far := spawn(walker_scene, Vector3(30.5, 0, -10), false)
	var behind := spawn(walker_scene, Vector3(4.0, 0, 12), false)
	await frames(3)
	weapon.dealt_damage.connect(on_hit)
	shoot(Vector3.DOWN, Vector3(25, 0.6, -10))
	await frames(3)
	check("vicino al centro prende di più", hp(near) < hp(mid), "vicino=%s medio=%s" % [hp(near), hp(mid)])
	check("al bordo prende comunque qualcosa", hp(mid) < 60.0, "medio=%s" % hp(mid))
	check("fuori raggio niente", hp(far) == 60.0, "lontano=%s" % hp(far))
	check("l'esplosione fa volare gli zombie", near.is_launched() or not HealthComponent.of(near).is_alive())
	weapon.dealt_damage.disconnect(on_hit)
	clear_enemies()

	# Riparato da un pilastro (Pillar2: 4, *, 12)
	behind = spawn(walker_scene, Vector3(4.0, 0, 13.6))
	await frames(3)
	shoot(Vector3.DOWN, Vector3(4.0, 0.6, 10.2))
	await frames(3)
	check("il pilastro ripara dall'esplosione", hp(behind) == 60.0, "vita=%s" % hp(behind))
	clear_enemies()

	# Bestione: l'esplosione davanti è attutita dalla corazza
	var b := spawn(brute_scene, Vector3(25, 0, -12))
	b.rotation.y = 0.0
	await frames(3)
	shoot(Vector3.DOWN, Vector3(25, 0.6, -14.0))
	await frames(3)
	var front_loss := 400.0 - hp(b)
	HealthComponent.of(b).reset()
	shoot(Vector3.DOWN, Vector3(25, 0.6, -10.0))
	await frames(3)
	var side_loss := 400.0 - hp(b)
	check("Bestione: esplosione davanti attutita, dietro piena", front_loss > 0.0 and front_loss < side_loss * 0.5, "davanti=%.1f dietro=%.1f" % [front_loss, side_loss])
	clear_enemies()

	# --- Durata: in aria esplode da solo ----------------------------------------
	place_player(Vector3(25, 0, 0))
	await frames(3)
	shoot(Vector3.UP)
	await seconds(1.0)
	check("in volo dopo 1 s", nodes_of("Projectile").size() == 1)
	var gone := await wait_until(func(): return nodes_of("Projectile").is_empty(), 4.0)
	check("sparisce da solo (esplodendo)", gone)

	# --- Il carabina è ancora hitscan ---------------------------------------------
	weapon.equip(0)
	await seconds(0.35)
	shoot(Vector3.FORWARD)
	check("la carabina non crea proiettili", nodes_of("Projectile").is_empty())

	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)
