extends SceneTree
# Test del passo 1.4: danno ai manichini, numeri, hitmarker, distruzione e respawn.
# Con un argomento utente (percorso png) salva anche uno screenshot.

var failures := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func shoot(p, weapon: Weapon) -> void:
	weapon._cooldown = 0.0
	weapon.fire(p.get_node("Head").global_position, Vector3.FORWARD, [p.get_rid()])

func _initialize() -> void:
	var level: Node = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var p = level.get_node("Players/1")
	var weapon: Weapon = p.get_node("Camera3D/Weapon")
	weapon.host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	weapon._switch_left = 0.0
	var crosshair: Crosshair = p.get_node("Hud/Crosshair")
	var dummy: Node = level.get_node("Dummies/DummyNear")
	var health := HealthComponent.of(dummy)
	weapon.data.spread_degrees = 0.0
	if not OS.get_cmdline_user_args().is_empty(): weapon.data.spread_degrees = 0.8
	await frames(10)
	p.global_position = Vector3(-3, 0, -5)
	p._yaw = 0.0
	await frames(10)

	var hits := []
	weapon.hit.connect(func(c, pos, n): hits.append([c, pos]))
	shoot(p, weapon)
	check("il colpo prende il manichino", hits.size() == 1 and hits[0][0] == dummy, "colpito=%s" % (hits[0][0].name if hits else "niente"))
	check("vita 100 -> 88", is_equal_approx(health.current, 88.0), "vita=%s" % health.current)
	check("etichetta aggiornata", dummy.get_node("HealthLabel").text == "88 / 100", dummy.get_node("HealthLabel").text)
	var numbers := level.get_children().filter(func(n): return n is DamageNumber)
	check("numero di danno '12'", numbers.size() == 1 and numbers[0].text == "12", "numeri=%d" % numbers.size())
	check("hitmarker attivo", crosshair._hit_time_left > 0.0 and not crosshair._hit_killed, "")

	if not OS.get_cmdline_user_args().is_empty():
		for i in 3:
			await frames(4)
			shoot(p, weapon)
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		print("screenshot salvato")

	var died := [false]
	health.died.connect(func(_s): died[0] = true)
	while health.is_alive():
		shoot(p, weapon)
	check("distrutto dopo 9 colpi totali", died[0] and hits.size() == 9, "colpi=%d" % hits.size())
	check("hitmarker rosso sul colpo finale", crosshair._hit_killed, "")
	var kill_numbers := level.get_children().filter(func(n): return n is DamageNumber and n.modulate.r > 0.99 and n.modulate.g < 0.5)
	check("numero finale rosso", kill_numbers.size() == 1, "rossi=%d" % kill_numbers.size())

	await frames(2)
	check("sparisce e non blocca i colpi", not dummy.get_node("Visual").visible and dummy.get_node("CollisionShape3D").disabled, "")
	hits.clear()
	shoot(p, weapon)
	check("il colpo passa oltre (muro nord)", hits.size() == 1 and absf(hits[0][1].z + 40.0) < 0.05, "hit=%s" % (str(hits[0][1]) if hits else "nessuno"))

	await create_timer(3.2).timeout
	await frames(2)
	check("ricompare con vita piena", dummy.get_node("Visual").visible and health.current == 100.0 and not dummy.get_node("CollisionShape3D").disabled, "vita=%s" % health.current)
	var leftover := level.get_children().filter(func(n): return n is DamageNumber)
	check("i numeri di danno spariscono", leftover.is_empty(), "rimasti=%d" % leftover.size())

	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)
