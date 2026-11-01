extends SceneTree
# Passo 3.1 in rete: il client apre una cassa, raccoglie, scambia, spara a
# pallini e con il fuoco; decide sempre l'host.
# Uso: --script net_crates.gd -- host   oppure   -- client

const PORT := 17785

var failures := 0
var role := ""
var level: Node


func check(name: String, ok: bool, info: String = "") -> void:
	print("[%s] %s %s  %s" % [role, "PASS" if ok else "FAIL", name, info])
	if not ok:
		failures += 1


func wait_until(cond: Callable, max_seconds: float) -> bool:
	for i in int(max_seconds * 60.0):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func wait_seconds(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame


func move_to(player: FpsController, where: Vector3) -> void:
	player.global_position = where
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func pickups() -> Array:
	return level.get_node("Pickups").get_children().filter(func(n): return not n.is_queued_for_deletion())


func pickup_with(spec: Array) -> WeaponPickup:
	for p in pickups():
		if p.spec == spec:
			return p
	return null


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	if role == "host":
		level.get_node("Waves").free()
	var players: Node = level.get_node("Players")
	var ready := await wait_until(func(): return players.get_child_count() == 2 \
			and players.has_node(str(get_multiplayer().get_unique_id())), 15.0)
	check("due giocatori in partita", ready)
	if ready:
		if role == "host":
			await run_host(players)
		else:
			await run_client(players)
	print("[%s] RISULTATO: %d errori" % [role, failures])
	quit(1 if failures > 0 else 0)


func run_host(players: Node) -> void:
	var other: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
	var crate: WeaponCrate = level.get_node("Crates/CrateWest")
	var near := HealthComponent.of(level.get_node("Dummies/DummyNear"))
	var mid := HealthComponent.of(level.get_node("Dummies/DummyMid"))

	# 1) Il client apre la cassa (con i soldi dati dall'host) e prende l'arma.
	other.inventory().host_add_money(100)
	var opened := await wait_until(func(): return crate.is_open, 20.0)
	check("il client apre la cassa (sull'host)", opened)
	var took := await wait_until(func(): return other.weapon().loadout.size() == 2, 10.0)
	check("l'host gli dà l'arma della cassa", took, str(other.weapon().specs()))

	# 2) Un fucile a doppia canna da scambiare con la pistola.
	PickupReplicator.of(level).spawn_pickup(["shotgun", "double"], Vector3(-3, 1, -7))
	var swapped := await wait_until(func(): return other.weapon().specs()[0] == ["shotgun", "double"], 15.0)
	check("scambio fatto sull'host", swapped, str(other.weapon().specs()))
	check("la pistola è rimasta a terra", pickup_with(["pistol"]) != null)

	# 3) Il client spara a pallini al manichino vicino.
	var hit := await wait_until(func(): return near.current < near.max_health, 15.0)
	var lost := near.max_health - near.current
	check("i pallini del client fanno danno sull'host (16 pallini: il manichino va giù)", hit and lost > 9.0, "danno=%.0f" % lost)

	# 4) Mitraglietta incendiaria.
	await wait_seconds(0.5)
	PickupReplicator.of(level).spawn_pickup(["smg", "incendiary"], Vector3(1, 1, -16))
	var burning := await wait_until(func(): return mid.burning, 20.0)
	check("il colpo incendiario del client fa bruciare il manichino", burning)
	var before := mid.current
	await wait_seconds(1.2)
	check("e brucia davvero (perde vita da solo)", mid.current < before, "da %.0f a %.0f" % [before, mid.current])

	var left := await wait_until(func(): return players.get_child_count() == 1, 20.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var crate: WeaponCrate = level.get_node("Crates/CrateWest")
	var near := HealthComponent.of(level.get_node("Dummies/DummyNear"))
	var mid := HealthComponent.of(level.get_node("Dummies/DummyMid"))
	var confirmed: Array = []
	me.weapon().dealt_damage.connect(func(_t, amount, _k): confirmed.append(amount))

	# 1) Apre la cassa.
	await wait_seconds(1.0)
	move_to(me, crate.global_position + Vector3(0, 0.1, 1.6))
	await wait_seconds(0.6)
	me.interact_with(crate)
	check("da client la cassa non si apre da sola", not crate.is_open)
	var opened := await wait_until(func(): return crate.is_open and pickups().size() == 1, 3.0)
	check("la cassa si apre e si vede l'arma", opened)
	if not opened:
		return
	var pickup: WeaponPickup = pickups()[0]
	var pickup_id := pickup.get_instance_id()
	check("l'arma ha nome e colore", pickup.get_node("Label").text == pickup.weapon_data.display_name)
	me.interact_with(pickup)
	var got := await wait_until(func(): return me.weapon().loadout.size() == 2, 3.0)
	check("l'arma arriva nel proprio loadout", got and me.weapon().current_slot() == 1, str(me.weapon().specs()))
	check("e la si ha in mano", me._hud._weapon_label.text == me.weapon().loadout[1].display_name)
	var gone := await wait_until(func(): return instance_from_id(pickup_id) == null 			or instance_from_id(pickup_id).is_queued_for_deletion(), 3.0)
	check("l'arma raccolta sparisce anche qui", gone)

	# 2) Scambio con la pistola.
	var shotgun_seen := await wait_until(func(): return pickup_with(["shotgun", "double"]) != null, 10.0)
	check("si vede l'arma messa dall'host", shotgun_seen)
	move_to(me, Vector3(-3, 0.1, -5.5))
	await wait_seconds(0.6)
	me.weapon().equip(0)
	me.interact_with(pickup_with(["shotgun", "double"]))
	var swapped := await wait_until(func(): return me.weapon().specs()[0] == ["shotgun", "double"], 3.0)
	check("scambio: il fucile prende il posto della pistola", swapped and me.weapon().current_slot() == 0, str(me.weapon().specs()))
	var dropped := await wait_until(func(): return pickup_with(["pistol"]) != null, 3.0)
	check("la pistola resta a terra anche qui", dropped)

	# 3) Pallini sul manichino vicino.
	await wait_seconds(0.5)
	var w := me.weapon()
	w._switch_left = 0.0
	var head := me._head.global_position
	w.fire(head, (near.get_parent().global_position + Vector3.UP - head).normalized(), [me.get_rid()])
	var ok := await wait_until(func(): return not confirmed.is_empty(), 3.0)
	check("una sola conferma per tutti i pallini", ok and confirmed.size() == 1 and confirmed[0] > 9.0, str(confirmed))
	var synced := await wait_until(func(): return near.current < near.max_health, 3.0)
	check("la vita del manichino arriva dall'host", synced, "vita=%.0f" % near.current)

	# 4) Mitraglietta incendiaria sul manichino a metà.
	var smg_seen := await wait_until(func(): return pickup_with(["smg", "incendiary"]) != null, 10.0)
	check("si vede la mitraglietta incendiaria", smg_seen)
	move_to(me, Vector3(1, 0.1, -14.5))
	await wait_seconds(0.6)
	me.interact_with(pickup_with(["smg", "incendiary"]))
	var has_smg := await wait_until(func(): return me.weapon().data.spec() == ["smg", "incendiary"], 3.0)
	check("presa la mitraglietta", has_smg, str(me.weapon().specs()))
	await wait_seconds(0.4)
	w._switch_left = 0.0
	w.data.spread_degrees = 0.0
	head = me._head.global_position
	w.fire(head, (mid.get_parent().global_position + Vector3.UP - head).normalized(), [me.get_rid()])
	var burning := await wait_until(func(): return mid.burning, 3.0)
	check("si vede il manichino bruciare", burning and mid.get_parent().get_children().any(func(n): return n is BurnFlames))
	await wait_seconds(1.5)
	NetSession.leave(self)
	await wait_seconds(0.5)
