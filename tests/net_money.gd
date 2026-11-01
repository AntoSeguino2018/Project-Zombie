extends SceneTree
# Passo 3.4 in rete: soldi decisi dall'host e visti dal client, acquisti del
# client alle macchinette e alle casse, avvisi solo a chi compra, stato a chi entra.
# Uso: --script net_money.gd -- host   oppure   -- client

const PORT := 17788

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


func move_to(player: FpsController, where: Vector3, yaw := 0.0) -> void:
	player.global_position = where
	player.velocity = Vector3.ZERO
	player._yaw = yaw
	player.rotation.y = yaw
	player.reset_physics_interpolation()


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var players: Node = level.get_node("Players")
	if role == "host":
		WaveDirector.of(level).host_pause()
		var me: FpsController = players.get_node("1")
		me.inventory().host_add_money(77)
		me.inventory().host_apply_boost(load("res://game/boosts/doppio.tres"))
		for m in level.get_node("Machines").get_children():
			m.jam_chance = 0.0
			m.double_chance = 0.0
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
	var me: FpsController = players.get_node("1")
	var other: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
	await wait_seconds(1.5)
	# Il client "uccide" un Bestione (il danno lo decide comunque l'host).
	var brute: Enemy = EnemyReplicator.of(level).spawn_enemy(load("res://game/enemies/brute.tscn"), Vector3(20, 0, 20), 0.0)
	await wait_seconds(0.5)
	HealthComponent.of(brute).take_damage(9999.0, other)
	check("la taglia va al client", other.inventory().money == 60, str(other.inventory().money))
	var bought := await wait_until(func(): return other.inventory().boosts.size() == 1, 15.0)
	check("il client compra un espresso (sull'host)", bought and other.inventory().money == 20, str(other.inventory().money))
	check("i soldi dell'host non cambiano", me.inventory().money == 77)
	var left := await wait_until(func(): return players.get_child_count() == 1, 25.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var host: FpsController = players.get_node("1")
	var synced := await wait_until(func(): return host.inventory().money == 77, 3.0)
	check("entrando si vedono soldi e boost dell'host", synced and host.inventory().boosts.size() == 1,
			"%d %s" % [host.inventory().money, host.inventory().boosts])
	var paid := await wait_until(func(): return me.inventory().money == 60, 10.0)
	check("arrivano i soldi del Bestione", paid)
	await wait_seconds(0.1)
	check("HUD: 60 € e +60 €", me._hud._money_label.text == "60 €" and me._hud._money_gain.text == "+60 €",
			me._hud._money_label.text)
	# Alla macchinetta dell'espresso.
	var espresso: VendingMachine = level.get_node("Machines/Espresso")
	move_to(me, espresso.global_position + espresso.global_basis.z * 1.4 + Vector3(0, 0.1, 0), PI / 2.0)
	await wait_seconds(0.3)
	me.interact_with(espresso)
	var got := await wait_until(func(): return me.inventory().boosts.size() == 1, 3.0)
	check("comprato: boost e soldi arrivano dall'host", got and me.inventory().money == 20, str(me.inventory().money))
	await wait_seconds(0.2)
	check("l'arma del client spara più veloce", is_equal_approx(me.weapon().fire_rate_multiplier, 1.3), str(me.weapon().fire_rate_multiplier))
	check("avviso dell'acquisto", me._hud._notice_label.text.begins_with("Espresso:"), me._hud._notice_label.text)
	# Cassa da 100 € con 20 €: avviso.
	var crate: WeaponCrate = level.get_node("Crates/CrateWest")
	move_to(me, crate.global_position + Vector3(0, 0.1, 1.6))
	await wait_seconds(0.3)
	me.interact_with(crate)
	var told := await wait_until(func(): return me._hud._notice_label.text.begins_with("Servono 100 €"), 3.0)
	check("la cassa non si apre e arriva l'avviso", told and not crate.is_open, me._hud._notice_label.text)
	NetSession.leave(self)
	await wait_seconds(0.5)
