extends SceneTree
# Passo 3.1 da soli: catalogo e tratti, casse, raccolta e scambio, pallini,
# perforazione, rimbalzi, esplosioni e fuoco.
var failures := 0
var level: Node
var p: FpsController
var weapon: Weapon


func check(name: String, ok: bool, info: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: failures += 1


func frames(n: int) -> void:
	for i in n: await physics_frame


func move_to(where: Vector3, yaw := 0.0) -> void:
	p.global_position = where
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	p.rotation.y = yaw
	p.reset_physics_interpolation()


func dummy_at(where: Vector3) -> HealthComponent:
	var dummy: Node3D = load("res://game/levels/props/training_dummy.tscn").instantiate()
	level.add_child(dummy)
	dummy.global_position = where
	return HealthComponent.of(dummy)


func shoot_at(target: Vector3, from := Vector3.INF) -> void:
	var head: Vector3 = p._head.global_position if from == Vector3.INF else from
	weapon._cooldown = 0.0
	weapon._switch_left = 0.0
	weapon._reload_left = 0.0
	weapon._ammo[weapon.current_slot()] = 99
	weapon.fire(head, (target - head).normalized(), [p.get_rid()])


func give(specs: Array, slot := 0) -> void:
	weapon.host_set_loadout(specs, slot)
	weapon.data.spread_degrees = 0.0 if weapon.data.pellets == 1 else weapon.data.spread_degrees
	await frames(1)


func _initialize() -> void:
	test_catalog()
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	level.get_node("Waves").free()
	for s in level.get_node("Enemies").get_children(): s.free()
	for d in level.get_node("Dummies").get_children(): d.free()
	p = level.get_node("Players/1")
	weapon = p.weapon()
	await frames(5)
	await test_start_and_crates()
	await test_pellets()
	await test_pierce()
	await test_bounce()
	await test_explosive()
	await test_incendiary()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_catalog() -> void:
	var a := WeaponCatalog.build(["carbine", "fast", "pierce"])
	check("nome con i tratti accordati", a.display_name == "Carabina rapida perforante", a.display_name)
	check("trucco = truccata", a.rarity == WeaponData.Rarity.RIGGED and a.pierce == 2)
	check("i tratti cambiano i numeri", is_equal_approx(a.fire_rate, 8.0 * 1.3), str(a.fire_rate))
	var base: WeaponData = WeaponCatalog.base("carbine")
	check("l'arma base resta com'era", is_equal_approx(base.fire_rate, 8.0) and base.pierce == 0)
	var s := WeaponCatalog.build(["shotgun", "heavy", "double"])
	check("maschile e frasi in fondo", s.display_name == "Fucile a pompa pesante a doppia canna", s.display_name)
	check("doppia canna raddoppia i pallini", s.pellets == 16, str(s.pellets))
	check("lo spec torna uguale", s.spec() == ["shotgun", "heavy", "double"], str(s.spec()))
	check("uno spec sconosciuto dà la pistola", WeaponCatalog.build(["boh"]).catalog_id == "pistol")
	var c := WeaponCatalog.build(["smg"])
	check("senza tratti è comune", c.rarity == WeaponData.Rarity.COMMON and c.display_name == "Mitraglietta")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	var seen := {}
	var tricks_seen := 0
	for i in 2000:
		var spec := WeaponCatalog.roll(rng)
		var data := WeaponCatalog.build(spec)
		seen[spec[0]] = true
		var tricks := 0
		for t in data.traits:
			if WeaponCatalog.TRAITS[t].get("trick", false): tricks += 1
		tricks_seen += tricks
		if tricks > 1 or spec.size() > 3 or data.traits.size() != spec.size() - 1:
			ok = false
		if data.projectile_scene and tricks > 0:
			ok = false
	check("2000 armi a caso valide (max un trucco, niente trucchi sul lanciagranate)", ok)
	check("escono tutte le armi base", seen.size() == WeaponCatalog.BASES.size(), str(seen.keys()))
	check("i trucchi escono ogni tanto", tricks_seen > 100 and tricks_seen < 600, str(tricks_seen))


func test_start_and_crates() -> void:
	check("si parte con la sola pistola", weapon.loadout.size() == 1 and weapon.data.catalog_id == "pistol")
	check("HUD: nome dell'arma", p._hud._weapon_label.text == "Pistola")
	var crate: WeaponCrate = level.get_node("Crates/CrateWest")
	var pickups: Node = level.get_node("Pickups")
	# Davanti alla cassa, guardandola.
	var look := crate.global_position + Vector3(0, 0.3, 0)
	move_to(crate.global_position + Vector3(0, 0.1, 1.8))
	p._yaw = atan2(-(look - p.global_position).x, -(look - p.global_position).z)
	p._pitch = -0.6
	await frames(3)
	check("guardando la cassa compare la scritta", p._hud._prompt.visible and "Apri la cassa" in p._hud._prompt.text, p._hud._prompt.text)
	check("la cassa è il bersaglio", p._interact_target == crate)
	check("la scritta dice il prezzo e quanti soldi hai", "100 €" in p._hud._prompt.text and "hai 0 €" in p._hud._prompt.text, p._hud._prompt.text)
	p.interact_with(crate)
	await frames(2)
	check("senza soldi non si apre", not crate.is_open and p._hud._notice_label.text.begins_with("Servono 100 €"), p._hud._notice_label.text)
	p.inventory().host_add_money(130)
	p.interact_with(crate)
	await frames(2)
	check("la cassa si apre", crate.is_open)
	check("e costa 100 €", p.inventory().money == 30, str(p.inventory().money))
	check("ne esce un'arma", pickups.get_child_count() == 1)
	var pickup: WeaponPickup = pickups.get_child(0)
	check("l'arma fluttua sopra la cassa", pickup.global_position.y > crate.global_position.y + 0.9)
	check("la cassa aperta non si riapre", crate.interaction_text(p) == "")
	var first_spec := pickup.spec
	pickup.interact(p, weapon.current_slot())
	await frames(2)
	check("raccolta: due armi", weapon.loadout.size() == 2 and weapon.loadout[1].spec() == first_spec, str(weapon.specs()))
	check("in mano la nuova", weapon.current_slot() == 1 and p._hud._weapon_label.text == weapon.loadout[1].display_name)
	check("l'arma a terra sparisce", not is_instance_valid(pickup) or pickup.is_queued_for_deletion() or pickups.get_child_count() == 0)
	await frames(2)
	# Mani piene: un'altra arma si scambia con quella in mano.
	var other: WeaponPickup = PickupReplicator.of(level).spawn_pickup(["smg", "precise"], p.global_position + Vector3(0, 1, -1))
	await frames(2)
	check("scritta con lo scambio", "lasci" in other.interaction_text(p), other.interaction_text(p))
	weapon.equip(0)
	other.interact(p, 0)
	await frames(2)
	check("scambio con l'arma in mano", weapon.specs() == [["smg", "precise"], first_spec], str(weapon.specs()))
	var left := pickups.get_children().filter(func(n): return not n.is_queued_for_deletion())
	check("la pistola resta a terra", left.size() == 1 and left[0].spec == ["pistol"], str(left.map(func(n): return n.spec)))
	if left.size() == 1:
		var expected := p.global_position + Vector3.UP * 0.5
		check("ai piedi del giocatore, non dove era l'altra", left[0].global_position.distance_to(expected) < 0.1,
				"%s vs %s" % [left[0].global_position, expected])
	# La cassa si richiude dopo 60 s, anche se l'arma è stata presa.
	check("si richiude dopo 60 s", is_equal_approx(crate.refill_time, 60.0))
	crate._refill_left = 0.05
	await frames(10)
	check("la cassa si richiude", not crate.is_open)
	for n in pickups.get_children(): n.free()
	await frames(2)
	# ...e anche se l'arma è ancora lì: sparisce.
	p.inventory().host_add_money(100)
	crate.interact(p, 0)
	await frames(2)
	var unclaimed: WeaponPickup = pickups.get_children().filter(func(n): return not n.is_queued_for_deletion())[0]
	crate._refill_left = 0.05
	await frames(10)
	check("arma non presa: la cassa si richiude e l'arma sparisce", not crate.is_open and not is_instance_valid(unclaimed))
	# Il caso del lanciagranate: scambiando davanti a una cassa, l'arma lasciata
	# non deve coprire quella che esce dalla cassa dopo.
	weapon.host_set_loadout([["pistol"], ["grenade_launcher"]], 1)
	await frames(2)
	var crate_top := crate.global_position + Vector3(0, 1.15, 0)
	move_to(crate.global_position + Vector3(0, 0.1, 1.8))
	p._yaw = atan2(-(crate_top - p._head.global_position).x, -(crate_top - p._head.global_position).z)
	p._pitch = atan2((crate_top - p._head.global_position).y, Vector2((crate_top - p._head.global_position).x, (crate_top - p._head.global_position).z).length())
	var specs_seen := []
	for i in 4:
		p.inventory().host_add_money(100)
		crate.interact(p, 0)
		await frames(3)
		var target = p._interact_target
		if target is WeaponPickup:
			specs_seen.append(target.get_instance_id() == crate._pickup_id)
			p.interact_with(target)
		await frames(3)
		crate._refill_left = 0.0
		await frames(3)
	check("aprendo più casse si guarda sempre l'arma uscita dalla cassa", specs_seen == [true, true, true, true], str(specs_seen))
	for n in pickups.get_children(): n.free()


func test_pellets() -> void:
	await give([["shotgun"]])
	var target := dummy_at(Vector3(26, 0, -10))
	move_to(Vector3(26, 0.1, -7))
	await frames(2)
	var numbers_before := level.get_children().filter(func(n): return n is DamageNumber).size()
	var dealt := []
	var cb := func(_t, amount, _k): dealt.append(amount)
	weapon.dealt_damage.connect(cb)
	shoot_at(target.get_parent().global_position + Vector3.UP)
	weapon.dealt_damage.disconnect(cb)
	var lost := target.max_health - target.current
	check("pallini: più colpi da 9", lost > 9.0 and is_equal_approx(fmod(lost, 9.0), 0.0), "danno=%.0f" % lost)
	check("un solo numero per bersaglio", dealt.size() == 1 and is_equal_approx(dealt[0], lost), str(dealt))
	var numbers := level.get_children().filter(func(n): return n is DamageNumber).size() - numbers_before
	check("un solo numero a schermo", numbers == 1, str(numbers))
	target.get_parent().free()


func test_pierce() -> void:
	await give([["carbine", "pierce"]])
	var a := dummy_at(Vector3(26, 0, -10))
	var b := dummy_at(Vector3(26, 0, -13))
	var c := dummy_at(Vector3(26, 0, -16))
	var d := dummy_at(Vector3(26, 0, -19))
	move_to(Vector3(26, 0.1, -6))
	await frames(2)
	shoot_at(Vector3(26, 1.0, -30), p._head.global_position)
	check("perforante: attraversa due bersagli e si ferma al terzo",
			a.current < 100.0 and b.current < 100.0 and c.current < 100.0 and d.current == 100.0,
			"%.0f %.0f %.0f %.0f" % [a.current, b.current, c.current, d.current])
	for h in [a, b, c, d]: h.get_parent().free()


func test_bounce() -> void:
	await give([["carbine", "bouncy"]])
	move_to(Vector3(26, 0.1, 38))
	await frames(2)
	var shot := {"segments": PackedVector3Array(), "normals": PackedVector3Array(), "hits": [], "blasts": PackedVector3Array()}
	var head := p._head.global_position
	# Contro il muro a sud, in basso: rimbalza sul muro, poi sul pavimento.
	weapon._trace(head, Vector3(0, -0.3, 1).normalized(), [p.get_rid()], head, shot)
	check("rimbalzante: tre tratti (due rimbalzi)", shot.normals.size() == 3, str(shot.normals.size()))
	check("prima il muro, poi il pavimento", shot.normals.size() == 3 and shot.normals[0].z < -0.9 and shot.normals[1].y > 0.9, str(shot.normals))
	var plain := {"segments": PackedVector3Array(), "normals": PackedVector3Array(), "hits": [], "blasts": PackedVector3Array()}
	await give([["carbine"]])
	weapon._trace(head, Vector3(0, -0.3, 1).normalized(), [p.get_rid()], head, plain)
	check("senza trucco un tratto solo", plain.normals.size() == 1)


func test_explosive() -> void:
	await give([["carbine", "explosive"]])
	var target := dummy_at(Vector3(26, 0, -12))
	move_to(Vector3(26, 0.1, -4))
	await frames(2)
	var effects_before := level.get_children().filter(func(n): return n is ExplosionEffect).size()
	# Colpo a terra accanto al bersaglio: lo prende solo l'esplosione.
	shoot_at(Vector3(26.8, 0.0, -12))
	var effects := level.get_children().filter(func(n): return n is ExplosionEffect).size() - effects_before
	check("esplosivo: si vede l'esplosione", effects == 1, str(effects))
	check("esplosivo: il bersaglio vicino prende danno", target.current < 100.0, "vita=%.0f" % target.current)
	target.get_parent().free()


func test_incendiary() -> void:
	await give([["smg", "incendiary"]])
	var target := dummy_at(Vector3(26, 0, -12))
	move_to(Vector3(26, 0.1, -6))
	await frames(2)
	shoot_at(target.get_parent().global_position + Vector3.UP)
	var after_hit := target.current
	check("incendiario: il bersaglio brucia", target.burning and target.get_parent().get_children().any(func(n): return n is BurnFlames))
	await frames(120)
	check("bruciando perde vita", target.current <= after_hit - 12.0, "da %.0f a %.0f" % [after_hit, target.current])
	await frames(90)
	check("poi il fuoco si spegne", not target.burning and not target.get_parent().get_children().any(func(n): return n is BurnFlames and not n.is_queued_for_deletion()))
	var settled := target.current
	await frames(40)
	check("e non toglie più vita", target.current == settled)
	target.get_parent().free()
