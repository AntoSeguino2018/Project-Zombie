extends SceneTree
# Passo 3.8, l'elicottero sul tetto della torre: alla radio si versano soldi
# (500 alla volta, o quelli che restano) fino a 5.000 €; chiamato, arriva dopo
# 60 s e scende sull'eliporto; atterrato si sale con E (si resta seduti, gli
# zombie ignorano chi è a bordo); se salgono tutti quelli in piedi riparte e
# la run è vinta (riepilogo con chi si è salvato); alla ripartenza tutto torna
# come prima.
var failures := 0
var level: Node
var p: FpsController
var heli: Helicopter
var run: RunManager


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
	p._yaw = yaw
	p.rotation.y = yaw
	p.reset_physics_interpolation()


func radio() -> HelicopterPart:
	for child in heli.get_children():
		if child is HelicopterPart and child.role == HelicopterPart.Role.RADIO:
			return child
	return null


func _initialize() -> void:
	level = load("res://game/levels/campus.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	p = level.get_node("Players/1")
	heli = Helicopter.of(level)
	run = RunManager.of(level)
	WaveDirector.of(level).host_pause()
	HealthComponent.of(p).damage_filter = func(_a, _s, _h): return 0.0
	await frames(10)
	await test_fund()
	await test_arrival()
	await test_boarding()
	await test_restart()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_fund() -> void:
	check("sul tetto della torre, in attesa e senza elicottero", heli != null and heli.phase == Helicopter.Phase.WAITING \
			and heli.global_position.y > 11.0 and not heli._body.visible)
	var r := radio()
	check("la radio è sul tetto, vicino alla botola", r != null and r.global_position.distance_to(Vector3(68, 12, -43)) < 0.5)
	move_to(Vector3(68, 12.1, -41))
	await frames(5)
	check("scritta della radio con il prezzo", r.interaction_text(p).contains("500 €") and r.interaction_text(p).contains("0 / 5000"),
			r.interaction_text(p))
	p.inventory().money = 1200
	for i in 4:
		r.interact(p, 0)
	check("si versa 500 alla volta finché ci sono soldi", heli.fund == 1200 and p.inventory().money == 0,
			"raccolti %d, in tasca %d" % [heli.fund, p.inventory().money])
	check("l'HUD mostra la raccolta", heli.status_text() == "Elicottero: 1200 / 5000 €", heli.status_text())


func test_arrival() -> void:
	p.inventory().money = 10000
	for i in 10:
		radio().interact(p, 0)
	check("raggiunti 5.000 €: chiamato, e non si versa di più", heli.fund == 5000 and p.inventory().money == 6200 \
			and heli.phase == Helicopter.Phase.INCOMING, "raccolti %d, in tasca %d" % [heli.fund, p.inventory().money])
	check("arriva tra 60 secondi", absf(heli.seconds_left() - 60.0) < 0.5 and heli.status_text().contains("1:00"), heli.status_text())
	await seconds(0.5)
	check("si vede in cielo, alto", heli._body.visible and heli._body.position.y > 40.0)
	heli._time_left = 3.0
	await seconds(1.5)
	check("negli ultimi secondi scende", heli._body.position.y < 40.0 and heli._body.position.y > 0.5, "%.1f" % heli._body.position.y)
	var landed := await wait_until(func(): return heli.phase == Helicopter.Phase.LANDED, 3.0)
	check("atterrato sull'eliporto", landed and heli._body.position.is_equal_approx(Vector3.ZERO))
	check("da atterrato blocca il passaggio", not heli._cabin_shape.disabled)


func test_boarding() -> void:
	move_to(Vector3(80, 12.1, -51.6), 0.0)
	await frames(5)
	check("guardandolo: Sali a bordo", heli._cabin.interaction_text(p) == "Sali a bordo", heli._cabin.interaction_text(p))
	heli._cabin.interact(p, 0)
	check("a bordo, seduto in cabina", p.is_boarded())
	await frames(5)
	check("resta al suo posto", p.global_position.distance_to(heli._seats[0].global_position) < 0.1, str(p.global_position))
	var zombie: Enemy = load("res://game/enemies/walker.tscn").instantiate()
	level.get_node("Enemies").add_child(zombie)
	zombie.global_position = Vector3(84, 12.1, -45)
	check("gli zombie ignorano chi è a bordo", zombie._find_target() == null)
	zombie.queue_free()
	check("da solo a bordo: riparte subito", heli.phase == Helicopter.Phase.DEPARTING)
	var won := await wait_until(func(): return run.won, 6.0)
	check("ripartito: run vinta", won and run.escaped == ["Giocatore 1"], str(run.escaped))
	check("si muove con l'elicottero", p.global_position.y > 20.0, str(p.global_position))
	await frames(3)
	var hud: PlayerHud = p.get_node("Hud")
	check("riepilogo: tornati a casa, chi si è salvato", hud._death_label.visible and hud._death_label.text.contains("TORNATI A CASA") \
			and hud._death_label.text.contains("Giocatore 1"), hud._death_label.text)
	check("ondate ferme", not WaveDirector.of(level).is_physics_processing())


func test_restart() -> void:
	run._restart_left = 0.2
	var again := await wait_until(func(): return not run.won, 2.0)
	await frames(5)
	check("si riparte: elicottero da richiamare, soldi raccolti azzerati", again and heli.phase == Helicopter.Phase.WAITING \
			and heli.fund == 0 and not heli._body.visible)
	check("e il giocatore è sceso, di nuovo nell'aula", not p.is_boarded() and p.global_position.y < -5.0, str(p.global_position))
