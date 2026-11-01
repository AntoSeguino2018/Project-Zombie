extends SceneTree
# Passo 3.5 da soli, con un compagno finto: catalogo, copie che si sommano,
# effetto di ogni oggetto, oggetti a fine ondata e lasciati dagli zombie, HUD,
# ripartenza.
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


func place(player: FpsController, where: Vector3, yaw := 0.0) -> void:
	player.global_position = where
	player.sync_position = where
	player.velocity = Vector3.ZERO
	player._yaw = yaw
	player._pitch = 0.0
	player.rotation.y = yaw
	player.reset_physics_interpolation()


func item(id: String) -> PassiveItem:
	return load("res://game/items/%s.tres" % id)


func give(id: String, count := 1) -> void:
	for i in count:
		inv.host_add_item(item(id))
	await frames(2)


func spawn_walker(at: Vector3) -> Enemy:
	var enemy: Enemy = load("res://game/enemies/walker.tscn").instantiate()
	level.get_node("Enemies").add_child(enemy)
	enemy.global_position = at
	enemy.set_physics_process(false)
	return enemy


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

	test_catalog()
	await test_stacking_and_hud()
	await test_effects()
	await test_sources()
	await test_expiry_and_stats()
	await test_restart()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_catalog() -> void:
	var ok := true
	for path in ItemCatalog.ITEMS:
		var it: PassiveItem = load(path)
		ok = ok and it != null and it.display_name != "" and it.effect_label != ""
	check("10 oggetti nel catalogo, tutti validi", ItemCatalog.ITEMS.size() == 10 and ok)
	check("effetto in parole", item("grilletto_unto").summary(2) == "+20% cadenza di fuoco" \
			and item("felpa_imbottita").summary(1) == "+20 vita massima", item("grilletto_unto").summary(2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := {}
	for i in 300:
		seen[ItemCatalog.roll(rng).resource_path] = true
	check("a caso escono tutti", seen.size() == 10, "%d diversi" % seen.size())
	check("solo i percorsi del catalogo sono accettati", ItemCatalog.is_item("res://game/items/cerotto.tres") \
			and not ItemCatalog.is_item("res://game/player/player.tscn") and not ItemCatalog.is_item(3))


func test_stacking_and_hud() -> void:
	await give("grilletto_unto")
	check("un oggetto", inv.item_count(item("grilletto_unto")) == 1)
	check("avviso con l'effetto", p._hud._notice_label.text == "Grilletto unto: +10% cadenza di fuoco", p._hud._notice_label.text)
	await give("grilletto_unto")
	check("le copie si sommano", inv.item_count(item("grilletto_unto")) == 2 and is_equal_approx(inv.stat("fire_rate"), 0.2))
	check("avviso con le copie e il totale", p._hud._notice_label.text == "Grilletto unto ×2: +20% cadenza di fuoco", p._hud._notice_label.text)
	check("HUD: elenco con copie e totale", "Grilletto unto" in p._hud._items_label.text and "×2" in p._hud._items_label.text \
			and "+20% cadenza" in p._hud._items_label.text, p._hud._items_label.text)
	check("l'arma spara più veloce del 20%", is_equal_approx(p.weapon().fire_rate_multiplier, 1.2), str(p.weapon().fire_rate_multiplier))
	# Si combina con l'espresso (moltiplica).
	inv.host_apply_boost(load("res://game/boosts/espresso.tres"))
	await frames(2)
	check("oggetti e boost si combinano", is_equal_approx(p.weapon().fire_rate_multiplier, 1.2 * 1.3), str(p.weapon().fire_rate_multiplier))
	inv.boosts.clear()


func test_effects() -> void:
	var dummy: Node3D = load("res://game/levels/props/training_dummy.tscn").instantiate()
	level.add_child(dummy)
	dummy.global_position = Vector3(10, 0, 10)
	var dummy_health := HealthComponent.of(dummy)
	await frames(2)
	await give("peperoncino", 2)
	var dealt := dummy_health.take_damage(10.0, p)
	check("Peperoncino ×2: +20% di danno", is_equal_approx(dealt, 12.0), "%.1f" % dealt)
	dealt = dummy_health.take_damage(10.0, null)
	check("solo per i danni del giocatore", is_equal_approx(dealt, 10.0))
	dummy.free()

	await give("dita_da_pianista")
	check("Dita da pianista: ricarica +15%", is_equal_approx(p.weapon().reload_speed_multiplier, 1.15))

	var weapon := p.weapon()
	check("pistola: 12 colpi", weapon.magazine_of(weapon.data) == 12)
	await give("caricatore_xl")
	check("Caricatore XL: 15 colpi (12 × 1,2 per eccesso)", weapon.magazine_of(weapon.data) == 15, str(weapon.magazine_of(weapon.data)))
	weapon._ammo[weapon.current_slot()] = 3
	weapon._switch_left = 0.0
	weapon.start_reload()
	await wait_until(func(): return not weapon.is_reloading(), 3.0)
	check("ricaricando si arriva a 15", weapon.ammo() == 15, str(weapon.ammo()))

	place(p, Vector3(0, 0.1, -3))
	await frames(5)
	var start := p.global_position
	Input.action_press("move_forward")
	await seconds(1.0)
	var base_distance := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	Input.action_release("move_forward")
	await give("scarpe_da_ginnastica", 2)
	place(p, Vector3(0, 0.1, -3))
	await frames(5)
	start = p.global_position
	Input.action_press("move_forward")
	await seconds(1.0)
	Input.action_release("move_forward")
	var fast_distance := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	check("Scarpe ×2: +12% di velocità", absf(fast_distance / base_distance - 1.12) < 0.02,
			"%.2f -> %.2f m" % [base_distance, fast_distance])
	place(p, Vector3(0, 0.1, -3))

	var health := HealthComponent.of(p)
	health.take_damage(30.0)
	await give("felpa_imbottita")
	check("Felpa: vita massima 120, e i 20 in più si aggiungono", is_equal_approx(health.max_health, 120.0) \
			and is_equal_approx(health.current, 90.0), "%.0f/%.0f" % [health.current, health.max_health])
	check("HUD: barra della vita su 120", is_equal_approx(p._hud._health_bar._maximum, 120.0) and is_equal_approx(p._hud._health_bar._current, 90.0))

	await give("salvadanaio")
	var money := inv.money
	var walker := spawn_walker(Vector3(20, 0, 20))
	walker.item_drop_chance = 0.0
	await frames(1)
	HealthComponent.of(walker).take_damage(9999.0, p)
	await frames(1)
	check("Salvadanaio: 10 € diventano 13 (12,5 arrotondato)", inv.money - money == 13, str(inv.money - money))

	await give("cerotto", 2)
	var before := health.current
	walker = spawn_walker(Vector3(20, 0, 22))
	walker.item_drop_chance = 0.0
	await frames(1)
	HealthComponent.of(walker).take_damage(9999.0, p)
	await frames(1)
	check("Cerotto ×2: +6 di vita a uccisione", is_equal_approx(health.current, before + 6.0), "%.0f -> %.0f" % [before, health.current])

	# Pugno: base × danno × pugni.
	var melee: MeleeAttack = p.get_node("Camera3D/Melee")
	walker = spawn_walker(p.global_position + Vector3(0, 0, -1.2))
	await frames(2)
	var walker_health := HealthComponent.of(walker)
	var base_punch: float = melee.heavy_damage if melee.heavy_hand else melee.damage
	var hp := walker_health.current
	melee._hit(walker, p._head.global_position, Vector3.FORWARD, p)
	var plain := hp - walker_health.current
	check("pugno: anche il Peperoncino conta", is_equal_approx(plain, minf(base_punch * 1.2, hp)), "%.1f" % plain)
	walker.free()
	await give("guanto_da_forno")
	walker = spawn_walker(p.global_position + Vector3(0, 0, -1.2))
	await frames(2)
	walker_health = HealthComponent.of(walker)
	hp = walker_health.current
	melee._hit(walker, p._head.global_position, Vector3.FORWARD, p)
	var gloved := hp - walker_health.current
	check("Guanto da forno: pugni +30%", is_equal_approx(gloved, minf(base_punch * 1.2 * 1.3, hp)), "%.1f" % gloved)
	if is_instance_valid(walker):
		walker.queue_free()

	await give("defibrillatore", 1)
	HealthComponent.of(buddy).take_damage(999.0)
	await frames(2)
	place(p, Vector3(0.3, 0.1, -3))
	place(buddy, Vector3(1.5, 0.1, -3))
	Input.action_press("interact")
	var ticks := 0
	while not buddy.is_standing() and ticks < 240:
		await physics_frame
		ticks += 1
	var took := ticks / 60.0
	Input.action_release("interact")
	check("Defibrillatore: si rianima in 3 / 1,3 = 2,3 s", buddy.is_standing() and absf(took - 3.0 / 1.3) < 0.25, "%.2f s" % took)


func test_sources() -> void:
	var mine: int = inv.items.values().reduce(func(a, b): return a + b, 0)
	var theirs: int = buddy.inventory().items.values().reduce(func(a, b): return a + b, 0)
	WaveDirector.of(level).wave_cleared.emit(1)
	await frames(2)
	var mine_after: int = inv.items.values().reduce(func(a, b): return a + b, 0)
	var theirs_after: int = buddy.inventory().items.values().reduce(func(a, b): return a + b, 0)
	check("a fine ondata un oggetto a testa", mine_after == mine + 1 and theirs_after == theirs + 1,
			"%d->%d  %d->%d" % [mine, mine_after, theirs, theirs_after])

	var brute: Enemy = load("res://game/enemies/brute.tscn").instantiate()
	level.get_node("Enemies").add_child(brute)
	brute.global_position = Vector3(3, 0, -8)
	await frames(2)
	HealthComponent.of(brute).take_damage(99999.0, buddy)
	await frames(3)
	var drops := level.get_node("Pickups").get_children().filter(func(n): return n is ItemPickup)
	check("il Bestione lascia sempre un oggetto", drops.size() == 1)
	if drops.is_empty():
		return
	var drop: ItemPickup = drops[0]
	check("a mezz'aria dove è morto", drop.global_position.distance_to(Vector3(3, 0.9, -8)) < 0.6, str(drop.global_position))
	check("con nome e colore", drop.get_node("Label").text == drop.item.display_name)
	# Lo prende chi arriva prima (qui il giocatore, non chi ha ucciso).
	place(p, Vector3(3, 0.1, -6.2))
	var d := drop.global_position - (p.global_position + Vector3.UP * 1.6)
	p._yaw = atan2(-d.x, -d.z)
	p._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await frames(3)
	check("guardandolo: 'Prendi ...' con l'effetto", p._interact_target == drop and "Prendi" in p._hud._prompt.text \
			and drop.item.effect_label in p._hud._prompt.text, p._hud._prompt.text)
	var count := inv.item_count(drop.item)
	var picked := drop.item
	p.interact_with(drop)
	await frames(2)
	check("raccolto: una copia in più", inv.item_count(picked) == count + 1 and not is_instance_valid(drop))


func test_restart() -> void:
	var run := RunManager.of(level)
	HealthComponent.of(buddy).take_damage(999.0)
	HealthComponent.of(p).take_damage(999.0)
	await frames(3)
	run._restart_left = 0.1
	await wait_until(func(): return not run.lost, 1.0)
	await frames(3)
	check("alla ripartenza niente oggetti", inv.items.is_empty() and p._hud._items_label.text == "")
	check("e vita massima di nuovo 100, piena", is_equal_approx(HealthComponent.of(p).max_health, 100.0) \
			and is_equal_approx(HealthComponent.of(p).current, 100.0), "%.0f/%.0f" % [HealthComponent.of(p).current, HealthComponent.of(p).max_health])
	check("pistola di nuovo a 12 colpi", p.weapon().magazine_of(p.weapon().data) == 12 and p.weapon().ammo() == 12, str(p.weapon().ammo()))


func test_expiry_and_stats() -> void:
	var replicator := PickupReplicator.of(level)
	var weapon_drop := replicator.spawn_pickup(["carbine"], Vector3(8, 1, 8))
	var item_drop := replicator.spawn_item(item("cerotto"), Vector3(9, 1, 8))
	await frames(2)
	check("le cose lasciate a terra spariscono dopo 2 minuti", is_equal_approx(weapon_drop.lifetime, 120.0) 			and is_equal_approx(item_drop.lifetime, 120.0))
	weapon_drop.lifetime = 0.1
	item_drop.lifetime = 0.1
	await frames(15)
	check("passato il tempo spariscono", not is_instance_valid(weapon_drop) and not is_instance_valid(item_drop))
	# L'arma di una cassa invece la toglie la cassa.
	var crate: WeaponCrate = level.get_node("Crates/CrateEast")
	inv.host_add_money(100)
	crate.interact(p, 0)
	await frames(2)
	var from_crate: WeaponPickup = instance_from_id(crate._pickup_id)
	check("l'arma della cassa non scade da sola", from_crate != null and from_crate.lifetime == 0.0)
	crate._refill_left = 0.0
	await frames(3)
	check("la toglie la cassa richiudendosi", not is_instance_valid(from_crate) and not crate.is_open)
	# F3: statistiche.
	var stats: Label = p._hud._debug_stats
	check("statistiche nascoste all'inizio", not stats.visible)
	var press := InputEventAction.new()
	press.action = "toggle_stats"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(20)
	check("F3 mostra le statistiche", stats.visible and "FPS" in stats.text and "zombie" in stats.text 			and "macerie" in stats.text and "scheda video" in stats.text and "passi per frame" in stats.text,
			stats.text.replace("
", " | "))
	var release := InputEventAction.new()
	release.action = "toggle_stats"
	release.pressed = false
	Input.parse_input_event(release)
	await frames(3)
	Input.parse_input_event(press)
	await frames(3)
	Input.parse_input_event(release)
	check("F3 di nuovo le nasconde", not stats.visible)
