extends SceneTree
# Test del passo 1.7: munizioni e ricarica, uccisioni e tempo, direzione del
# danno, schermata di morte con riepilogo, comandi all'avvio.

var failures := 0
var level: Node
var p: FpsController
var weapon: Weapon
var hud: PlayerHud
var walker_scene: PackedScene = load("res://game/enemies/walker.tscn")

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

func spawn(pos: Vector3, frozen := true) -> Enemy:
	var e: Enemy = walker_scene.instantiate()
	e.position = pos
	e.rotation.y = PI
	level.add_child(e)
	if frozen:
		e.set_physics_process(false)
	return e

func head() -> Vector3:
	return p.get_node("Head").global_position

func shoot_at(point: Vector3) -> void:
	weapon._cooldown = 0.0
	weapon.fire(head(), (point - head()).normalized(), [p.get_rid()])

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
	weapon.data.spread_degrees = 0.0

	# --- Munizioni e ricarica -------------------------------------------------
	check("carabina: 30 colpi", weapon.ammo() == 30, str(weapon.ammo()))
	place_player(Vector3(25, 0, 0))
	await frames(2)
	for i in 5:
		shoot_at(Vector3(25, 1.5, -40))
	check("ogni colpo ne toglie uno", weapon.ammo() == 25, str(weapon.ammo()))
	weapon.start_reload()
	check("R avvia la ricarica", weapon.is_reloading() and not weapon.can_fire())
	await seconds(0.8)
	check("a metà ricarica la barra è a metà", absf(weapon.reload_progress() - 0.5) < 0.1, "%.2f" % weapon.reload_progress())
	await seconds(0.9)
	check("dopo 1,6 s il caricatore è pieno", weapon.ammo() == 30 and not weapon.is_reloading() and weapon.can_fire(), str(weapon.ammo()))
	weapon.start_reload()
	check("col caricatore pieno R non fa nulla", not weapon.is_reloading())
	for i in 30:
		shoot_at(Vector3(25, 1.5, -40))
	check("a caricatore vuoto ricarica da sola", weapon.ammo() == 0 and weapon.is_reloading())
	weapon.equip(1)
	await seconds(0.35)
	check("il cambio arma interrompe la ricarica", not weapon.is_reloading())
	check("il lanciagranate ha i suoi 6 colpi", weapon.ammo() == 6, str(weapon.ammo()))
	weapon.equip(0)
	await seconds(0.35)
	check("la carabina è ancora vuota", weapon.ammo() == 0, str(weapon.ammo()))
	p._handle_fire()
	check("provando a sparare a vuoto riparte la ricarica", weapon.is_reloading())
	await seconds(1.7)
	check("e si riempie", weapon.ammo() == 30)

	# --- Uccisioni (anche indirette) e tempo ------------------------------------
	var stats: Label = hud.get_node("StatsLabel")
	var a := spawn(Vector3(25, 0, -6))
	await frames(2)
	for i in 5:
		shoot_at(a.center())
	check("uccisione con la carabina contata", p._kills == 1, "uccisioni=%d" % p._kills)
	await frames(2)
	check("HUD aggiornato", stats.text.begins_with("1 uccisioni"), stats.text)

	var b := spawn(Vector3(25, 0, -2.2))
	var c := spawn(Vector3(25, 0, -5.5))
	HealthComponent.of(c).take_damage(45.0)
	await frames(2)
	b.set_physics_process(true)
	c.set_physics_process(true)
	var melee: MeleeAttack = p.get_node("Camera3D/Melee")
	melee._cooldown_left = 0.0
	melee.attack(head(), Vector3.FORWARD, p)
	await wait_until(func(): return not HealthComponent.of(c).is_alive(), 1.5)
	check("uccisione indiretta (zombie lanciato contro un altro) contata", p._kills == 2, "uccisioni=%d" % p._kills)
	for e in get_nodes_in_group("enemies"):
		e.free()

	var d := spawn(Vector3(26, 0, -9))
	HealthComponent.of(d).take_damage(50.0)
	weapon.equip(1)
	await seconds(0.35)
	shoot_at(Vector3(26, 0.2, -8.2))
	await wait_until(func(): return not HealthComponent.of(d).is_alive(), 1.5)
	check("uccisione con l'esplosione contata", p._kills == 3, "uccisioni=%d, vita zombie=%s" % [p._kills, HealthComponent.of(d).current])
	for e in get_nodes_in_group("enemies"):
		e.free()
	weapon.equip(0)
	var t0 := p._run_time
	await seconds(1.0)
	check("il tempo della run scorre", absf(p._run_time - t0 - 1.0) < 0.1, "%.2f" % (p._run_time - t0))
	check("formato del tempo", PlayerHud.format_time(83.7) == "1:23", PlayerHud.format_time(83.7))

	# --- Direzione del danno -----------------------------------------------------
	var indicator: DamageIndicator = hud.get_node("DamageIndicator")
	var attacker := spawn(Vector3(28, 0, 0))
	await frames(2)
	HealthComponent.of(p).take_damage(5.0, attacker, p.global_position)
	check("arco di danno creato", indicator._hits.size() == 1)
	await frames(3)
	var camera := p.get_node("Camera3D") as Camera3D
	var local: Vector3 = camera.global_basis.inverse() * (attacker.global_position - camera.global_position)
	check("punta a destra (zombie a destra)", local.x > 0.0 and absf(atan2(local.x, -local.z) - PI / 2) < 0.3, "%.2f rad" % atan2(local.x, -local.z))
	await seconds(1.3)
	check("l'arco svanisce", indicator._hits.is_empty())
	attacker.free()

	# --- Comandi all'avvio ---------------------------------------------------------
	var gone := await wait_until(func(): return not hud.get_node("ControlsLabel").visible, 12.0)
	check("i comandi spariscono dopo un po'", gone)

	# --- Morte con riepilogo -----------------------------------------------------
	var kills_before := p._kills
	HealthComponent.of(p).take_damage(999.0)
	await frames(2)
	var death_text: String = hud.get_node("DeathLabel").text
	check("riepilogo nella schermata di fine run", death_text.contains("RUN PERSA") and death_text.contains("%d uccisioni" % kills_before), death_text.replace("\n", " | "))
	RunManager.of(level)._restart_left = 0.1
	await wait_until(func(): return HealthComponent.of(p).is_alive(), 1.0)
	await frames(2)
	check("alla ripartenza si riparte da zero", p._kills == 0 and p._run_time < 0.2 and stats.text.begins_with("0 uccisioni"), stats.text)

	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)
