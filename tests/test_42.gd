extends SceneTree
# Passo 3.10, proiettili da carro armato (nel campus): 5 casse dell'esercito
# (3 nei laboratori, 2 vicino ai camion) col proiettile, che ricompare dopo
# 90 s; in spalla: mani occupate (niente armi), più lenti, lo vedono gli altri;
# G lo posa a terra e si può riprendere; una martellata da un compagno lo fa
# partire a razzo dove guarda chi lo porta (esplosione grossa, contraccolpo),
# la katana no; chi cade lo lascia a terra; alla ripartenza tutto torna pieno.
var failures := 0
var level: Node
var p: FpsController


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


func move_to(where: Vector3, yaw := 0.0) -> void:
	p.global_position = where
	p.velocity = Vector3.ZERO
	p._push = Vector3.ZERO
	p._yaw = yaw
	p._pitch = 0.0
	p.rotation.y = yaw
	p.reset_physics_interpolation()


func rack(rack_name: String) -> ShellRack:
	return level.get_node("ShellRacks/" + rack_name) as ShellRack


func shells_on_ground() -> Array[Node]:
	return get_nodes_in_group("shell_pickups").filter(func(n): return not n.is_queued_for_deletion())


## Martellata da dietro, da un compagno finto (in singolo non ce n'è uno vero).
func hammer_from_behind(weapon_id: String) -> void:
	var mate := Node3D.new()
	level.add_child(mate)
	var origin := p.global_position + Vector3(0, 1.6, 1.2)
	p.melee()._strike(origin, Vector3(0, 0, -1), mate, MeleeCatalog.data(weapon_id))
	mate.queue_free()


func _initialize() -> void:
	level = load("res://game/levels/campus.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	p = level.get_node("Players/1")
	WaveDirector.of(level).host_pause()
	RunManager.of(level).set_physics_process(false)
	HealthComponent.of(p).damage_filter = func(_a, _s, _h): return 0.0
	await frames(10)
	test_racks()
	await test_carry()
	await test_drop()
	await test_fire()
	await test_fall()
	await test_restart()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_racks() -> void:
	var zones := ZoneManager.of(level)
	var where := level.get_node("ShellRacks").get_children().map(func(r): return zones.zone_at(r.global_position + Vector3.UP * 0.5).name)
	check("5 casse coi proiettili: 3 nei laboratori, 2 nel parcheggio", where.count(&"laboratori") == 3 \
			and where.count(&"parcheggio") == 2, str(where))
	check("tutte con il proiettile", level.get_node("ShellRacks").get_children().all(func(r): return r.stocked))


func test_carry() -> void:
	var r := rack("ProiettileCamion1")
	move_to(r.global_position + Vector3(0, 0.1, 1.5))
	await frames(3)
	check("scritta: in spalla", r.interaction_text(p).contains("spalla"), r.interaction_text(p))
	r.interact(p, 0)
	await frames(2)
	check("in spalla, la cassa è vuota", p.carrying_shell and not r.stocked and not r._shell.visible)
	check("mani occupate: niente arma, proiettile in vista", not p.weapon().visible and p._shell_view.visible \
			and p.get_node("Hud")._weapon_label.text == "Proiettile in spalla")
	check("gli altri lo vedono sulla spalla", (p.get_node("Body") as PlayerModel).shell_visible())
	check("non se ne prende un secondo", rack("ProiettileCamion2").interaction_text(p).is_empty())
	p.melee().host_set_weapon("martello")
	p._select_melee()
	check("niente arma bianca in mano col proiettile", not p.melee().active)
	r._refill_left = 0.3
	var back := await wait_until(func(): return r.stocked, 2.0)
	check("dopo un po' nella cassa ricompare il proiettile", back and r._shell.visible)


func test_drop() -> void:
	p.host_drop_shell()
	await frames(3)
	var ground := shells_on_ground()
	check("G: posato a terra, mani libere", not p.carrying_shell and ground.size() == 1 and p.weapon().visible \
			and not p._shell_view.visible)
	check("e lo si riprende", ground[0].interaction_text(p).contains("spalla"))
	ground[0].interact(p, 0)
	await frames(2)
	check("ripreso", p.carrying_shell and shells_on_ground().is_empty())


func test_fire() -> void:
	move_to(Vector3(0, 0.1, 30), 0.0)
	await frames(3)
	var zombie: Enemy = load("res://game/enemies/walker.tscn").instantiate()
	level.get_node("Enemies").add_child(zombie)
	zombie.global_position = Vector3(0, 0.1, 15)
	zombie.set_physics_process(false)
	HealthComponent.of(zombie).max_health = 2000.0
	HealthComponent.of(zombie).current = 2000.0
	await frames(2)
	hammer_from_behind("katana")
	check("una katana non lo fa partire", p.carrying_shell)
	hammer_from_behind("martello")
	await frames(1)
	var rockets := level.get_children().filter(func(n): return n is Projectile)
	check("martellata: il proiettile parte a razzo", not p.carrying_shell and rockets.size() == 1)
	if rockets.size() == 1:
		var rocket := rockets[0] as Projectile
		check("verso dove guarda chi lo porta (nord)", rocket.velocity.normalized().dot(Vector3(0, 0, -1)) > 0.99 \
				and rocket.velocity.length() > 40.0, str(rocket.velocity))
	check("contraccolpo all'indietro su chi lo portava", p._push.z > 5.0, str(p._push))
	var hit := await wait_until(func(): return HealthComponent.of(zombie).current < 2000.0, 2.0)
	var lost := 2000.0 - HealthComponent.of(zombie).current
	check("lo zombie a 15 m prende il colpo pieno più l'esplosione", hit and lost >= 500.0, "%.0f" % lost)
	zombie.queue_free()


func test_fall() -> void:
	rack("ProiettileLab1").interact(p, 0)
	await frames(2)
	p._host_set_life(FpsController.Life.DOWNED)
	await frames(3)
	check("chi cade lascia il proiettile a terra", not p.carrying_shell and shells_on_ground().size() == 1)
	p.host_revive()
	await frames(2)


func test_restart() -> void:
	rack("ProiettileLab2").interact(p, 0)
	await frames(2)
	RunManager.of(level)._host_restart()
	await frames(5)
	check("ripartenza: niente in spalla, nessuno a terra, casse piene", not p.carrying_shell and shells_on_ground().is_empty() \
			and level.get_node("ShellRacks").get_children().all(func(r): return r.stocked))
