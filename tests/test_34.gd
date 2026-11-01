extends SceneTree
# Passo 3.4 da soli, con un compagno finto: taglie degli zombie, premio di fine
# ondata, premio per la rianimazione, macchinette e boost, HUD dei soldi.
var failures := 0
var level: Node
var p: FpsController
var buddy: FpsController
var inv: RunInventory


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


func place(player: FpsController, where: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	player.global_position = where
	player.sync_position = where
	player.velocity = Vector3.ZERO
	player._yaw = yaw
	player._pitch = pitch
	player.rotation.y = yaw
	player.reset_physics_interpolation()


func kill(scene_path: String, killer: Node) -> void:
	var enemy: Enemy = load(scene_path).instantiate()
	level.get_node("Enemies").add_child(enemy)
	enemy.global_position = Vector3(20, 0, 20)
	await frames(1)
	HealthComponent.of(enemy).take_damage(9999.0, killer)
	await frames(1)


func look_at_machine(machine: VendingMachine) -> void:
	var front := machine.global_position + machine.global_basis.z * 1.4
	place(p, front + Vector3(0, 0.1, 0))
	var target := machine.global_position + Vector3(0, 1.2, 0)
	var d := target - p._head.global_position
	p._yaw = atan2(-d.x, -d.z)
	p._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await frames(3)


func _initialize() -> void:
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	for d in level.get_node("Dummies").get_children(): d.free()
	WaveDirector.of(level).host_pause()
	p = level.get_node("Players/1")
	inv = p.inventory()
	level.get_node("PlayerSpawner")._add_player(2)
	await frames(5)
	buddy = level.get_node("Players/2")
	place(p, Vector3(0, 0.1, -3))
	place(buddy, Vector3(1.5, 0.1, -3))
	await frames(5)
	check("si parte senza soldi", inv.money == 0 and p._hud._money_label.text == "0 €", p._hud._money_label.text)

	await test_earning()
	await test_machines()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_earning() -> void:
	await kill("res://game/enemies/walker.tscn", p)
	check("Camminatore: 10 €", inv.money == 10, str(inv.money))
	check("HUD: soldi e guadagno", p._hud._money_label.text == "10 €" and p._hud._money_gain.text == "+10 €" \
			and p._hud._money_gain.modulate.a > 0.9, "%s %s" % [p._hud._money_label.text, p._hud._money_gain.text])
	await kill("res://game/enemies/runner.tscn", p)
	check("Scattista: 15 €", inv.money == 25, str(inv.money))
	await kill("res://game/enemies/brute.tscn", p)
	check("Bestione: 60 €", inv.money == 85, str(inv.money))
	await kill("res://game/enemies/walker.tscn", buddy)
	check("i soldi sono personali: la taglia va a chi uccide", inv.money == 85 and buddy.inventory().money == 10)
	await kill("res://game/enemies/walker.tscn", null)
	check("senza uccisore niente soldi", inv.money == 85 and buddy.inventory().money == 10)
	await seconds(1.5)
	check("il guadagno svanisce", p._hud._money_gain.modulate.a < 0.05)
	WaveDirector.of(level).wave_cleared.emit(2)
	await frames(2)
	check("ondata 2 superata: 35 € a tutti", inv.money == 120 and buddy.inventory().money == 45,
			"%d %d" % [inv.money, buddy.inventory().money])
	# Rianimare un compagno vale 20 €.
	HealthComponent.of(buddy).take_damage(999.0)
	await frames(2)
	place(p, Vector3(0.3, 0.1, -3))
	Input.action_press("interact")
	await wait_until(func(): return buddy.is_standing(), 3.5)
	Input.action_release("interact")
	await frames(2)
	check("rianimare un compagno: 20 €", inv.money == 140 and buddy.inventory().money == 45,
			"%d %d" % [inv.money, buddy.inventory().money])


func test_machines() -> void:
	var espresso: VendingMachine = level.get_node("Machines/Espresso")
	var doppio: VendingMachine = level.get_node("Machines/Doppio")
	var snack: VendingMachine = level.get_node("Machines/Merendina")
	for m in [espresso, doppio, snack]:
		m.jam_chance = 0.0
		m.double_chance = 0.0
	check("le macchinette hanno nome e prezzo", espresso.get_node("Label").text == "Espresso\n40 €", espresso.get_node("Label").text)
	await look_at_machine(espresso)
	check("guardandola: cosa fa e quanto costa", p._interact_target == espresso and "Espresso" in p._hud._prompt.text \
			and "40 €" in p._hud._prompt.text and "cadenza" in p._hud._prompt.text, p._hud._prompt.text)
	var weapon := p.weapon()
	var rate := weapon.data.fire_rate
	p.interact_with(espresso)
	await frames(2)
	check("si paga 40 €", inv.money == 100, str(inv.money))
	check("espresso attivo per 60 s", inv.boosts.size() == 1 and inv.boosts.values()[0] > 59.0, str(inv.boosts))
	# Gli oggetti presi a fine ondata (a caso) possono già alzare la cadenza.
	var items_rate := 1.0 + inv.stat("fire_rate")
	check("l'arma spara più veloce del 30%", is_equal_approx(weapon.fire_rate_multiplier, items_rate * 1.3), str(weapon.fire_rate_multiplier))
	weapon._cooldown = 0.0
	weapon.fire(p._head.global_position, Vector3.FORWARD, [p.get_rid()])
	check("la cadenza cambia davvero", is_equal_approx(weapon._cooldown, 1.0 / (rate * items_rate * 1.3)), "%.3f" % weapon._cooldown)
	check("avviso dell'acquisto", p._hud._notice_label.text.begins_with("Espresso:"), p._hud._notice_label.text)
	await frames(2)
	check("HUD: boost con il tempo", "Espresso" in p._hud._boosts_label.text and "1:00" in p._hud._boosts_label.text \
			or "0:59" in p._hud._boosts_label.text, p._hud._boosts_label.text)
	p.interact_with(espresso)
	await frames(2)
	check("ricomprarlo allunga il tempo, non l'effetto", inv.boosts.values()[0] > 118.0 and is_equal_approx(weapon.fire_rate_multiplier, items_rate * 1.3),
			str(inv.boosts))

	await look_at_machine(doppio)
	p.interact_with(doppio)
	await frames(2)
	check("caffè doppio: ricarica del 40% più veloce", is_equal_approx(weapon.reload_speed_multiplier, (1.0 + inv.stat("reload_speed")) * 1.4) and inv.money == -0 + 20 - 0,
			"molt=%.2f soldi=%d" % [weapon.reload_speed_multiplier, inv.money])
	weapon._ammo[weapon.current_slot()] = 0
	weapon._reload_left = 0.0
	weapon._switch_left = 0.0
	weapon.start_reload()
	check("la ricarica dura meno", is_equal_approx(weapon._reload_left, weapon.data.reload_time / weapon.reload_speed_multiplier), "%.2f" % weapon._reload_left)
	weapon._reload_left = 0.0
	check("HUD: due boost", "Espresso" in p._hud._boosts_label.text and "doppio" in p._hud._boosts_label.text, p._hud._boosts_label.text)

	await look_at_machine(snack)
	check("con pochi soldi la scritta lo dice", "hai 20 €" in p._hud._prompt.text, p._hud._prompt.text)
	p.interact_with(snack)
	await frames(2)
	check("merendina comprata (30 €)? no: ne hai 20", inv.money == 20 and p._hud._notice_label.text.begins_with("Servono 30 €"),
			p._hud._notice_label.text)
	inv.host_add_money(100)
	HealthComponent.of(p).take_damage(70.0)
	var hp_before := HealthComponent.of(p).current
	p.interact_with(snack)
	await frames(2)
	check("merendina: +50 di vita subito", is_equal_approx(HealthComponent.of(p).current, hp_before + 50.0) and inv.money == 90,
			"vita=%.0f soldi=%d" % [HealthComponent.of(p).current, inv.money])
	check("la merendina non resta tra i boost", inv.boosts.size() == 2)

	# Le sorprese della macchinetta.
	espresso.jam_chance = 1.0
	await look_at_machine(espresso)
	var before: float = inv.boosts[espresso.boost.resource_path]
	p.interact_with(espresso)
	await frames(2)
	check("a volte si mangia i soldi", inv.money == 50 and inv.boosts[espresso.boost.resource_path] < before \
			and "mangiata" in p._hud._notice_label.text, p._hud._notice_label.text)
	espresso.jam_chance = 0.0
	espresso.double_chance = 1.0
	before = inv.boosts[espresso.boost.resource_path]
	p.interact_with(espresso)
	await frames(2)
	check("a volte dà una dose doppia", inv.boosts[espresso.boost.resource_path] > before + 119.0 \
			and p._hud._notice_label.text.begins_with("Doppia dose!"), p._hud._notice_label.text)

	# Scadenza.
	inv.boosts[doppio.boost.resource_path] = 0.1
	await frames(10)
	check("finito il tempo il boost sparisce", inv.boosts.size() == 1 and is_equal_approx(weapon.reload_speed_multiplier, 1.0 + inv.stat("reload_speed"))
			and not "doppio" in p._hud._boosts_label.text, p._hud._boosts_label.text)
	# A terra non si compra.
	HealthComponent.of(p).take_damage(999.0)
	await frames(2)
	var money := inv.money
	p._host_interact(espresso, 0)
	check("a terra non si compra", inv.money == money)
