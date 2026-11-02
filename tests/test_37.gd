extends SceneTree
# Magnum, prima arma sbroccata: dati e catalogo (niente tratti, caricatore
# fisso), colpo che attraversa gli zombie con danno 200, 100, 50, 25, 25...,
# muri distruttibili intatti e che fermano il colpo, animazioni e LED del modello.
var failures := 0
var level: Node
var p: FpsController
var weapon: Weapon


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
	p._pitch = 0.0
	p.rotation.y = yaw
	p.reset_physics_interpolation()


## Uno zombie fermo e robusto (1000 di vita), per leggere il danno preso.
func tough_walker(at: Vector3) -> HealthComponent:
	var e: Enemy = load("res://game/enemies/walker.tscn").instantiate()
	level.get_node("Enemies").add_child(e)
	e.global_position = at
	e.set_physics_process(false)
	var health := HealthComponent.of(e)
	health.max_health = 1000.0
	health.current = 1000.0
	return health


func shoot(target: Vector3) -> void:
	weapon._cooldown = 0.0
	weapon._switch_left = 0.0
	var head := p._head.global_position
	weapon.fire(head, (target - head).normalized(), [p.get_rid()])


func vm() -> MagnumViewmodel:
	return weapon._model as MagnumViewmodel


func drum() -> int:
	return vm()._drum_leds.get_shader_parameter("lit_mask")


func top() -> int:
	return vm()._frame_leds.get_shader_parameter("lit_mask")


func _initialize() -> void:
	test_data()
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	level.get_node("Waves").free()
	for d in level.get_node("Dummies").get_children(): d.free()
	p = level.get_node("Players/1")
	weapon = p.weapon()
	HealthComponent.of(p).damage_filter = func(_a, _s, _h): return 0.0
	await frames(5)
	await test_pierce()
	await test_walls()
	await test_viewmodel()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_data() -> void:
	var m := WeaponCatalog.build(["magnum"])
	check("Magnum: sbroccata, 200 di danno, 6 colpi", m.rarity == WeaponData.Rarity.UNHINGED and m.damage == 200.0 \
			and m.magazine_size == 6 and m.display_name == "Magnum")
	check("colore arancione delle sbroccate", WeaponCatalog.rarity_color(m) == WeaponCatalog.RARITY_COLORS[2])
	var hacked := WeaponCatalog.build(["magnum", "big_mag", "explosive", "double", "fast"])
	check("nessun tratto, nemmeno forzato", hacked.traits.is_empty() and hacked.magazine_size == 6 \
			and hacked.explosion_radius == 0.0 and hacked.pellets == 1 and hacked.display_name == "Magnum")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var found := 0
	var clean := true
	for i in 2000:
		var spec := WeaponCatalog.roll(rng)
		if spec[0] == "magnum":
			found += 1
			clean = clean and spec.size() == 1
	check("si trova nelle casse, di rado (circa 5%)", found > 50 and found < 160, "%d su 2000" % found)
	check("e dalle casse esce sempre senza tratti", clean)


func test_pierce() -> void:
	weapon.host_set_loadout([["magnum"]], 0)
	await frames(3)
	move_to(Vector3(20, 0.1, 0), 0.0)
	await frames(3)
	# Sei zombie in fila davanti, a 1,5 m l'uno dall'altro.
	var line: Array[HealthComponent] = []
	for i in 6:
		line.append(tough_walker(Vector3(20, 0, -4 - i * 1.5)))
	await frames(3)
	shoot(Vector3(20, 1.0, -30))
	await frames(2)
	var taken := line.map(func(h: HealthComponent): return roundi(1000.0 - h.current))
	check("attraversa tutti: 200, 100, 50, poi mai sotto 25", taken == [200, 100, 50, 25, 25, 25], str(taken))
	check("un solo colpo speso", weapon.ammo() == 5, str(weapon.ammo()))
	for h in line:
		h.get_parent().free()
	# Con il Peperoncino il danno sale per tutti, la regola resta.
	p.inventory().host_add_item(load("res://game/items/peperoncino.tres"))
	line.clear()
	for i in 3:
		line.append(tough_walker(Vector3(20, 0, -4 - i * 1.5)))
	await frames(3)
	shoot(Vector3(20, 1.0, -30))
	await frames(2)
	taken = line.map(func(h: HealthComponent): return roundi(1000.0 - h.current))
	check("con il Peperoncino: 220, 110, 55", taken == [220, 110, 55], str(taken))
	for h in line:
		h.get_parent().free()
	p.inventory().host_reset()
	# Il Caricatore XL non allunga la Magnum.
	p.inventory().host_add_item(load("res://game/items/caricatore_xl.tres"))
	await frames(2)
	check("il Caricatore XL non cambia i 6 colpi", weapon.magazine_of(weapon.data) == 6)
	p.inventory().host_reset()
	await frames(2)


func test_walls() -> void:
	weapon.refill()
	var wall: DestructibleBlocks = level.get_node("Destructibles/WallBehindSpawn")
	var blocks := wall.blocks_left()
	move_to(Vector3(0, 0.1, 2), PI)
	await frames(3)
	var behind := tough_walker(Vector3(0, 0, 10))
	await frames(3)
	for i in 3:
		shoot(Vector3(0, 1.0, 10))
		await frames(2)
	check("non rompe i muri distruttibili", wall.blocks_left() == blocks, "%d -> %d" % [blocks, wall.blocks_left()])
	check("e il muro ferma il colpo", is_equal_approx(behind.current, 1000.0), str(behind.current))
	behind.get_parent().free()


func test_viewmodel() -> void:
	weapon.host_set_loadout([["pistol"], ["magnum"]], 0)
	await frames(2)
	weapon.equip(1)
	await frames(2)
	check("in mano il modello animato", vm() != null and weapon._model_animates())
	check("accensione: i LED partono spenti", drum() != 63, str(drum()))
	await seconds(0.6)
	check("poi tutti e sei accesi, a riposo", drum() == 63 and top() == 63 and vm()._anim.current_animation == "Riposo",
			"%d %d %s" % [drum(), top(), vm()._anim.current_animation])
	check("riposo in ciclo", vm()._anim.get_animation("Riposo").loop_mode == Animation.LOOP_LINEAR)

	move_to(Vector3(0, 0.1, -2), 0.0)
	await frames(2)
	shoot(Vector3(0, 1, -30))
	await frames(1)
	check("sparo: animazione Sparo", vm()._anim.current_animation == "Sparo")
	check("la camera in alto si spegne, il tamburo gira con le altre 5", drum() == 0b111110, "%s" % String.num_int64(drum(), 2))
	check("in cima ne restano 5 (si spegne quello davanti)", top() == 0b111110, "%s" % String.num_int64(top(), 2))
	var finished := await wait_until(func(): return vm()._anim.current_animation == "Riposo", 1.0)
	check("lo sparo finisce prima del colpo successivo (0,67 s)", finished)
	check("tamburo di nuovo a zero: le 5 cariche ripartono dall'alto", drum() == 0b011111, "%s" % String.num_int64(drum(), 2))

	# Fino all'ultimo colpo: la striscia lampeggia.
	for i in 4:
		shoot(Vector3(0, 1, -30))
		await seconds(0.7)
	check("ultimo colpo: un solo LED sul tamburo", weapon.ammo() == 1 and drum() == 0b000001, "%d %s" % [weapon.ammo(), String.num_int64(drum(), 2)])
	var blink := []
	for i in 8:
		blink.append(top())
		await seconds(0.07)
	check("l'ultimo colpo lampeggia in cima", blink.has(0) and blink.has(0b100000), str(blink))

	# Ultimo sparo: ricarica automatica dopo l'animazione dello sparo.
	shoot(Vector3(0, 1, -30))
	await frames(2)
	check("sparando l'ultimo parte la ricarica, ma prima finisce lo sparo",
			weapon.is_reloading() and vm()._anim.current_animation == "Sparo")
	var reloading := await wait_until(func(): return vm()._anim.current_animation == "Ricarica", 1.0)
	check("poi l'animazione di ricarica", reloading)
	await seconds(1.0)
	check("bossoli fuori: LED spenti", drum() == 0 and top() == 0, "%d %d" % [drum(), top()])
	var t0 := Time.get_ticks_msec()
	await wait_until(func(): return not weapon.is_reloading(), 4.0)
	var reload_done := Time.get_ticks_msec()
	await wait_until(func(): return vm()._anim.current_animation == "Riposo", 2.0)
	var anim_done := Time.get_ticks_msec()
	check("animazione e ricarica finiscono insieme", absi(anim_done - reload_done) < 150,
			"%d ms di scarto" % (anim_done - reload_done))
	check("ricaricata: 6 colpi e tutti i LED accesi", weapon.ammo() == 6 and drum() == 63 and top() == 63)
	print("  (durata ricarica da quando i LED erano spenti: %d ms)" % (reload_done - t0))

	# Ispezione con V; sparare la interrompe.
	var press := InputEventAction.new()
	press.action = "inspect"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(3)
	var release := InputEventAction.new()
	release.action = "inspect"
	Input.parse_input_event(release)
	check("V: ispezione", vm()._anim.current_animation == "Ispezione")
	await seconds(0.5)
	var masks := {}
	for i in 10:
		masks[drum()] = true
		await frames(3)
	check("durante l'ispezione i LED fanno il giro", masks.size() >= 3, str(masks.keys()))
	shoot(Vector3(0, 1, -30))
	await frames(1)
	check("sparare interrompe l'ispezione", vm()._anim.current_animation == "Sparo")

	# Cambiando arma il modello sparisce, tornando riparte l'accensione.
	weapon.equip(0)
	await frames(2)
	check("con la pistola niente modello animato", not weapon._model_animates())
	weapon.equip(1)
	await frames(2)
	check("ripresa in mano: riparte l'accensione", vm()._boot_left > 0.0)
	# Il modello a terra (in una cassa) resta carico e a riposo.
	var pickup := PickupReplicator.of(level).spawn_pickup(["magnum"], Vector3(5, 1, 5))
	await frames(5)
	var shown := pickup.get_node("ModelPivot").get_child(0) as MagnumViewmodel
	check("a terra: Magnum carica e a riposo", shown != null and shown._anim.current_animation == "Riposo" \
			and shown._drum_leds.get_shader_parameter("lit_mask") == 63)
	check("a terra: nome arancione", pickup.get_node("Label").modulate == WeaponCatalog.RARITY_COLORS[2])
	# Nel poligono c'è una cassa gratuita che dà sempre la Magnum.
	var crate: WeaponCrate = level.get_node("Crates/CrateMagnum")
	var money := p.inventory().money
	check("cassa Magnum: gratis", crate.interaction_text(p) == "Apri la cassa", crate.interaction_text(p))
	crate.interact(p, 0)
	await frames(3)
	var given := instance_from_id(crate._pickup_id) as WeaponPickup
	check("e dà la Magnum, senza spendere", crate.is_open and given != null and given.spec == ["magnum"] \
			and p.inventory().money == money)
