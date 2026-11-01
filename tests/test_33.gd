extends SceneTree
# Passo 3.3 da soli, con un compagno finto: a terra, strisciare, rianimare e
# farsi rianimare, morte per dissanguamento, ritorno a fine ondata, caduta
# fuori dal livello, run persa e ripartenza.
var failures := 0
var level: Node
var p: FpsController
var buddy: FpsController
var run: RunManager
var waves: WaveDirector


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


func place(player: FpsController, where: Vector3, yaw := 0.0) -> void:
	player.global_position = where
	player.sync_position = where
	player.velocity = Vector3.ZERO
	player._yaw = yaw
	player.rotation.y = yaw
	player.reset_physics_interpolation()


func knock_down(player: FpsController) -> void:
	var health := HealthComponent.of(player)
	health.take_damage(health.current)


func _initialize() -> void:
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	for d in level.get_node("Dummies").get_children(): d.free()
	p = level.get_node("Players/1")
	run = RunManager.of(level)
	waves = WaveDirector.of(level)
	waves._time_left = 9999.0
	level.get_node("PlayerSpawner")._add_player(2)
	await frames(5)
	buddy = level.get_node("Players/2")
	place(p, Vector3(0, 0.1, -3))
	place(buddy, Vector3(1.5, 0.1, -3))
	await frames(10)
	check("ci sono la run e un compagno", run != null and buddy != null and buddy.player_number == 2)

	await test_downed()
	await test_revive_by_buddy()
	await test_revive_buddy()
	await test_bleed_out_and_wave_end()
	await test_fall_out()
	await test_run_lost()
	await test_solo()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_downed() -> void:
	knock_down(p)
	await frames(2)
	check("finita la vita si va a terra", p.life == FpsController.Life.DOWNED and not p.is_standing(),
			"stato=%d" % p.life)
	check("con un compagno in piedi la run continua", not run.lost)
	check("30 s prima di morire", p.bleed_left > 29.0 and p.bleed_left <= 30.0, "%.1f" % p.bleed_left)
	check("HUD: A TERRA", p._hud._death_label.visible and p._hud._death_label.text.begins_with("A TERRA"),
			p._hud._death_label.text)
	check("l'arma non si vede", not p._weapon.visible)
	check("sopra la testa: A TERRA, visibile attraverso i muri",
			p._name_tag.text.ends_with("A TERRA") and p._name_tag.no_depth_test, p._name_tag.text)
	# Gli zombie lasciano stare chi è a terra.
	var walker: Enemy = load("res://game/enemies/walker.tscn").instantiate()
	level.get_node("Enemies").add_child(walker)
	walker.global_position = Vector3(0, 0, -8)
	await frames(2)
	check("gli zombie puntano chi è in piedi", walker._find_target() == buddy)
	walker.free()
	# Si striscia piano.
	var start := p.global_position
	Input.action_press("move_forward")
	await seconds(1.0)
	Input.action_release("move_forward")
	var moved := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	check("a terra si striscia piano", moved > 1.0 and moved < 2.0, "%.2f m in 1 s" % moved)
	var shot_before := p._weapon.ammo()
	Input.action_press("fire")
	await frames(10)
	Input.action_release("fire")
	check("a terra non si spara", p._weapon.ammo() == shot_before)
	var bleed := p.bleed_left
	await seconds(1.0)
	check("il tempo scorre", p.bleed_left < bleed - 0.9, "%.1f -> %.1f" % [bleed, p.bleed_left])


func test_revive_by_buddy() -> void:
	place(p, Vector3(0, 0.1, -3))
	place(buddy, Vector3(1.5, 0.1, -3))
	await frames(2)
	# Il compagno tiene premuto E (come farebbe arrivando dalla rete).
	buddy._reviving = p
	var bleed := p.bleed_left
	await seconds(1.5)
	check("rianimazione a metà dopo 1,5 s", p.revive_progress > 0.4 and p.revive_progress < 0.6, "%.2f" % p.revive_progress)
	check("mentre ti rianimano non ti dissangui", absf(p.bleed_left - bleed) < 0.05, "%.1f -> %.1f" % [bleed, p.bleed_left])
	check("HUD: ti stanno rianimando, con la barra", p._hud._death_label.text.contains("rianimando") \
			and p._hud._revive_bar.visible, p._hud._death_label.text)
	# Si allontana: si riparte da zero.
	place(buddy, Vector3(6, 0.1, -3))
	await frames(3)
	check("se il compagno si allontana la rianimazione si azzera", p.revive_progress == 0.0, "%.2f" % p.revive_progress)
	place(buddy, Vector3(1.5, 0.1, -3))
	var up := await wait_until(func(): return p.is_standing(), 3.3)
	check("dopo 3 s ci si rialza", up)
	check("con il 40% della vita", is_equal_approx(HealthComponent.of(p).current, 40.0), str(HealthComponent.of(p).current))
	check("HUD normale e arma in mano", not p._hud._death_label.visible and p._weapon.visible and not p._hud._revive_bar.visible)
	check("sopra la testa di nuovo solo il nome", p._name_tag.text == "Giocatore 1" and not p._name_tag.no_depth_test)
	buddy._reviving = null


func test_revive_buddy() -> void:
	HealthComponent.of(p).reset()
	knock_down(buddy)
	await frames(2)
	check("il compagno va a terra", buddy.life == FpsController.Life.DOWNED)
	place(p, Vector3(4, 0.1, -3), PI / 2.0)
	await frames(2)
	check("lontani: niente scritta", not p._hud._prompt.visible or not p._hud._prompt.text.contains("rianima"))
	place(p, Vector3(3.3, 0.1, -3), PI / 2.0)
	await frames(2)
	check("vicini: 'Tieni premuto: rianima Giocatore 2'", p._hud._prompt.text.contains("Tieni premuto: rianima Giocatore 2"),
			p._hud._prompt.text)
	Input.action_press("interact")
	await seconds(1.5)
	check("HUD: rianimando, con la barra", p._hud._prompt.text.contains("Rianimando Giocatore 2") \
			and p._hud._revive_bar.visible and p._hud._revive_bar.value > 0.4, p._hud._prompt.text)
	Input.action_release("interact")
	await frames(3)
	check("lasciando E si azzera", buddy.revive_progress == 0.0 and not p._hud._revive_bar.visible)
	Input.action_press("interact")
	var up := await wait_until(func(): return buddy.is_standing(), 3.3)
	Input.action_release("interact")
	check("tenendo premuto E per 3 s il compagno si rialza", up)
	await frames(2)
	check("dopo, niente più barra", not p._hud._revive_bar.visible)


func test_bleed_out_and_wave_end() -> void:
	knock_down(buddy)
	await frames(2)
	buddy.bleed_left = 0.3
	var dead := await wait_until(func(): return buddy.life == FpsController.Life.DEAD, 1.0)
	check("se nessuno ti rianima, muori", dead)
	check("da morto il nome non si vede attraverso i muri", not buddy._name_tag.no_depth_test)
	check("la run continua (tu sei in piedi)", not run.lost)
	# Anche il giocatore va a terra... no: resta in piedi. Fine ondata:
	place(p, Vector3(-6, 0.1, 8))
	await frames(2)
	waves.wave_cleared.emit(1)
	await frames(3)
	check("a fine ondata chi è morto rinasce", buddy.is_standing() and HealthComponent.of(buddy).current == 100.0)
	check("vicino a un compagno", buddy.global_position.distance_to(p.global_position) < 2.0,
			"%.1f m" % buddy.global_position.distance_to(p.global_position))
	knock_down(buddy)
	await frames(2)
	waves.wave_cleared.emit(2)
	await frames(2)
	check("a fine ondata chi è a terra si rialza", buddy.is_standing())


func test_fall_out() -> void:
	place(buddy, Vector3(1.5, 0.1, -3))
	await frames(70)
	place(p, Vector3(0, -40, 0))
	await frames(2)
	check("chi cade fuori dal livello muore subito", p.life == FpsController.Life.DEAD, "stato=%d" % p.life)
	check("HUD: SEI MORTO, si rinasce a fine ondata", p._hud._death_label.text.begins_with("SEI MORTO"), p._hud._death_label.text)
	waves.wave_cleared.emit(3)
	await frames(3)
	check("e rinasce a fine ondata", p.is_standing() and p.global_position.y > -1.0)


func test_run_lost() -> void:
	await frames(70)
	# Un po' di partita: una cassa aperta, un'arma in mano, uno zombie in campo.
	var crate: WeaponCrate = level.get_node("Crates/CrateWest")
	p.inventory().host_add_money(150)
	crate.interact(p, 0)
	p.inventory().host_apply_boost(load("res://game/boosts/espresso.tres"))
	p.weapon().host_set_loadout([["pistol"], ["shotgun"]], 1)
	p._kills = 7
	waves._time_left = 0.0
	await wait_until(func(): return not level.get_node("Enemies").get_children().filter(func(n): return n is Enemy).is_empty(), 3.0)
	check("prima: un'ondata in corso", waves.wave == 1 and waves.phase == WaveDirector.Phase.ACTIVE)
	knock_down(buddy)
	await frames(2)
	check("uno a terra: la run continua", not run.lost)
	knock_down(p)
	await frames(2)
	check("tutti a terra: run persa", run.lost and run.lost_wave == 1)
	check("le ondate si fermano", not waves.is_physics_processing())
	await frames(2)
	check("HUD: RUN PERSA con ondata, uccisioni e record", p._hud._death_label.text.begins_with("RUN PERSA") \
			and p._hud._death_label.text.contains("Ondata 1") and p._hud._death_label.text.contains("7 uccisioni") \
			and p._hud._death_label.text.contains("Record: ondata 1"), p._hud._death_label.text.replace("\n", " | "))
	run._restart_left = 0.3
	var again := await wait_until(func(): return not run.lost, 1.0)
	await frames(3)
	check("si riparte", again)
	check("tutti in piedi con la vita piena", p.is_standing() and buddy.is_standing() \
			and HealthComponent.of(p).current == 100.0 and HealthComponent.of(buddy).current == 100.0)
	check("al punto di partenza", p.global_position.distance_to(p._spawn_transform.origin) < 0.5)
	check("solo con la pistola", p.weapon().specs() == [["pistol"]], str(p.weapon().specs()))
	check("niente soldi e niente boost", p.inventory().money == 0 and p.inventory().boosts.is_empty(), str(p.inventory().money))
	check("uccisioni da zero", p.kills() == 0 and p._hud._stats_label.text.begins_with("0 uccisioni"))
	check("ondate da capo", waves.wave == 0 and waves.phase == WaveDirector.Phase.WAITING and waves.is_physics_processing())
	check("niente zombie", level.get_node("Enemies").get_children().filter(func(n): return n is Enemy and not n.is_queued_for_deletion()).is_empty())
	check("casse chiuse, niente armi a terra", not crate.is_open \
			and level.get_node("Pickups").get_children().filter(func(n): return not n.is_queued_for_deletion()).is_empty())
	check("HUD normale", not p._hud._death_label.visible)
	await frames(5)
	check("togliere gli zombie non fa finire l'ondata", waves.phase == WaveDirector.Phase.WAITING and waves.remaining == 0)


func test_solo() -> void:
	waves._time_left = 9999.0
	buddy.queue_free()
	await frames(3)
	knock_down(p)
	await frames(2)
	check("da soli, andare a terra fa perdere la run", run.lost)
