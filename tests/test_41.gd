extends SceneTree
# Passo 3.9, armi bianche nel terzo slot (nel campus): tre armi al muro
# (martello nei Centri comuni, katana in biblioteca, martellone nei
# laboratori) col prezzo; comprata va nel terzo slot e quella vecchia resta a
# terra; tasto 3 = in mano (via l'arma da fuoco, HUD col nome); colpi: martello
# 45 e rompe i blocchi, katana 75 a tanti zombie insieme, martellone 130 che
# scaraventa e sfonda; si raccolgono da terra e escono dalle casse; alla
# ripartenza si perdono.
var failures := 0
var level: Node
var p: FpsController
var melee: MeleeAttack
var hud: PlayerHud


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


func wall(wall_name: String) -> WallWeapon:
	return level.get_node("WallWeapons/" + wall_name) as WallWeapon


## Uno zombie fermo e robusto (1000 di vita), per leggere il danno preso.
func dummy(at: Vector3) -> Enemy:
	var e: Enemy = load("res://game/enemies/walker.tscn").instantiate()
	level.get_node("Enemies").add_child(e)
	e.global_position = at
	e.set_physics_process(false)
	var health := HealthComponent.of(e)
	health.max_health = 1000.0
	health.current = 1000.0
	return e


func lost(e: Enemy) -> float:
	return 1000.0 - HealthComponent.of(e).current


func clear_enemies() -> void:
	for e in level.get_node("Enemies").get_children():
		e.free()


func swing_ahead() -> void:
	melee._cooldown_left = 0.0
	melee.swing(p._head.global_position, -p._aim_basis().z, p)


func _initialize() -> void:
	level = load("res://game/levels/campus.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	p = level.get_node("Players/1")
	melee = p.melee()
	hud = p.get_node("Hud")
	WaveDirector.of(level).host_pause()
	RunManager.of(level).set_physics_process(false)
	HealthComponent.of(p).damage_filter = func(_a, _s, _h): return 0.0
	await frames(10)
	test_walls()
	await test_buy_and_hold()
	await test_hammer()
	await test_katana()
	await test_sledgehammer()
	await test_pickups()
	await test_restart()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_walls() -> void:
	var zones := ZoneManager.of(level)
	var places := {"MartelloCentri": [&"centri", 250], "KatanaBiblioteca": [&"biblioteca", 600], "MartelloneLab": [&"laboratori", 900]}
	for wall_name in places:
		var w := wall(wall_name)
		var zone := zones.zone_at(w.global_position)
		check("%s: in %s, %d €" % [wall_name, places[wall_name][0], places[wall_name][1]],
				zone != null and zone.name == places[wall_name][0] and w.weapon.price == places[wall_name][1],
				"%s %d" % [zone.name if zone else "fuori", w.weapon.price])
	var crates_ok := level.get_node("Crates").get_children().all(func(c): return is_equal_approx(c.melee_chance, MeleeCatalog.CRATE_CHANCE))
	check("nelle casse del campus esce un'arma bianca nel 12% dei casi", crates_ok)


func test_buy_and_hold() -> void:
	p._select_melee()
	check("senza arma bianca il tasto 3 non fa nulla", not melee.active and p.weapon().visible)
	var w := wall("MartelloCentri")
	p.inventory().money = 200
	check("scritta col prezzo", w.interaction_text(p).contains("250 €") and w.interaction_text(p).contains("Martello"), w.interaction_text(p))
	w.interact(p, 0)
	check("senza soldi non si compra", melee.weapon == null and p.inventory().money == 200)
	p.inventory().money = 400
	w.interact(p, 0)
	check("comprato: 250 € e martello nel terzo slot", melee.weapon != null and melee.weapon.id == "martello" \
			and p.inventory().money == 150, "%d €" % p.inventory().money)
	check("non si ricompra quello che si ha", w.interaction_text(p).begins_with("Hai già"))
	await frames(2)
	check("non è ancora in mano", not melee.active and p.weapon().visible)
	p._select_melee()
	check("tasto 3: in mano il martello, via la pistola", melee.active and not p.weapon().visible \
			and melee.get_node("Held").visible)
	check("HUD: nome, niente munizioni", hud._weapon_label.text == "Martello da fabbro" and not hud._ammo_display.visible,
			hud._weapon_label.text)
	p._select_guns()
	check("tasto 1: di nuovo la pistola", not melee.active and p.weapon().visible and hud._ammo_display.visible \
			and hud._weapon_label.text == "Pistola", hud._weapon_label.text)
	p._select_melee()


func test_hammer() -> void:
	move_to(Vector3(0, 0.1, 30))
	await frames(3)
	var e := dummy(Vector3(0, 0.1, 28.4))
	await frames(2)
	swing_ahead()
	check("martello: 45 di danno", is_equal_approx(lost(e), 45.0), "%.0f" % lost(e))
	check("e lo spinge, senza danni nell'impatto (non è un lancio)", e.is_launched() and is_zero_approx(e._impact_damage),
			"%.0f" % e._impact_damage)
	clear_enemies()


func test_katana() -> void:
	var w := wall("KatanaBiblioteca")
	move_to(w.global_position + Vector3(1.5, -1.4, 0), -PI / 2.0)
	p.inventory().money = 1000
	w.interact(p, 0)
	check("katana comprata: 600 €, nel terzo slot", melee.weapon.id == "katana" and p.inventory().money == 400)
	await frames(2)
	var left := get_nodes_in_group("weapon_pickups").filter(func(n): return n.spec == ["melee", "martello"])
	check("il martello resta a terra ai propri piedi", left.size() == 1 \
			and (left[0] as Node3D).global_position.distance_to(p.global_position) < 1.5)
	check("in mano subito, è il terzo slot attivo", melee.active and hud._weapon_label.text == "Katana", hud._weapon_label.text)
	move_to(Vector3(0, 0.1, 30))
	await frames(3)
	var hit: Array[Enemy] = []
	for x in [-1.0, -0.4, 0.4, 1.0]:
		hit.append(dummy(Vector3(x, 0.1, 28.5)))
	await frames(2)
	swing_ahead()
	check("katana: 75 a tutti e quattro davanti", hit.all(func(e): return is_equal_approx(lost(e), 75.0)),
			str(hit.map(func(e): return lost(e))))
	clear_enemies()


func test_sledgehammer() -> void:
	melee.host_set_weapon("martellone")
	await frames(2)
	var e := dummy(Vector3(0, 0.1, 28.4))
	e.set_physics_process(true)
	await frames(2)
	swing_ahead()
	check("martellone: 130 e lo scaraventa (35 a chi colpisce in volo)", is_equal_approx(lost(e), 130.0) and e.is_launched() 			and is_equal_approx(e._impact_damage, 35.0), "%.0f %.0f" % [lost(e), e._impact_damage])
	clear_enemies()
	# Sfonda: contro il muretto del viale (alto 1,6), colpendo un po' in basso.
	var wall_blocks := level.get_node("Destructibles/MurettoVialeA") as DestructibleBlocks
	var before := wall_blocks.blocks_left()
	move_to(Vector3(-30, 0.1, 3.6))
	await frames(3)
	melee._cooldown_left = 0.0
	melee.swing(p._head.global_position, Vector3(0, -0.5, -1).normalized(), p)
	await frames(2)
	check("e sfonda i muri: tanti blocchi in un colpo", before - wall_blocks.blocks_left() >= 8,
			"%d blocchi" % (before - wall_blocks.blocks_left()))


func test_pickups() -> void:
	var replicator := PickupReplicator.of(level)
	var pickup := replicator.spawn_pickup(MeleeCatalog.spec_for("katana"), p.global_position + Vector3(0, 1, -1))
	await frames(2)
	check("a terra: nome e scritta", pickup.melee_data != null and pickup.get_node("Label").text == "Katana" \
			and pickup.interaction_text(p).contains("lasci Martellone"), pickup.interaction_text(p))
	pickup.interact(p, 0)
	await frames(2)
	check("raccolta: katana nel terzo slot, il martellone a terra", melee.weapon.id == "katana" \
			and get_nodes_in_group("weapon_pickups").any(func(n): return n.spec == ["melee", "martellone"]))
	var crate := level.get_node("Crates/CassaCentri") as WeaponCrate
	crate.melee_chance = 1.0
	p.inventory().money = 100
	crate.interact(p, 0)
	await frames(2)
	var from_crate := get_nodes_in_group("weapon_pickups").filter(func(n): return n.global_position.distance_to(crate.global_position) < 2.0)
	check("dalla cassa può uscire un'arma bianca", from_crate.size() == 1 and MeleeCatalog.is_spec(from_crate[0].spec),
			str(from_crate.map(func(n): return n.spec)))


func test_restart() -> void:
	RunManager.of(level)._host_restart()
	await frames(5)
	check("ripartenza: niente arma bianca, di nuovo la pistola", melee.weapon == null and not melee.active \
			and p.weapon().visible and hud._ammo_display.visible)
