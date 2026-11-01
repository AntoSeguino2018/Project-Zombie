extends SceneTree
# Passo 3.5 in rete: oggetti decisi dall'host, effetti sul client (arma, vita
# massima, HUD), oggetto lasciato dal Bestione raccolto dal client, stato a chi entra.
# Uso: --script net_items.gd -- host   oppure   -- client

const PORT := 17789

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


func item(id: String) -> PassiveItem:
	return load("res://game/items/%s.tres" % id)


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
		me.inventory().host_add_item(item("cerotto"))
		me.inventory().host_add_item(item("cerotto"))
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
	await wait_seconds(1.5)
	other.inventory().host_add_item(item("caricatore_xl"))
	other.inventory().host_add_item(item("grilletto_unto"))
	other.inventory().host_add_item(item("felpa_imbottita"))
	check("vita massima del client 120 (sull'host)", is_equal_approx(HealthComponent.of(other).max_health, 120.0))
	await wait_seconds(1.0)
	var brute: Enemy = EnemyReplicator.of(level).spawn_enemy(load("res://game/enemies/brute.tscn"), Vector3(3, 0, -8), 0.0)
	await wait_seconds(0.5)
	HealthComponent.of(brute).take_damage(99999.0, players.get_node("1"))
	var drop := level.get_node("Pickups").get_children().filter(func(n): return n is ItemPickup)
	check("il Bestione lascia un oggetto", drop.size() == 1)
	var dropped_path: String = drop[0].item_path if not drop.is_empty() else ""
	var before := other.inventory().items.get(dropped_path, 0) as int
	var got := await wait_until(func(): return other.inventory().items.get(dropped_path, 0) == before + 1, 15.0)
	check("lo raccoglie il client (sull'host)", got)
	var left := await wait_until(func(): return players.get_child_count() == 1, 25.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var host: FpsController = players.get_node("1")
	var synced := await wait_until(func(): return host.inventory().item_count(item("cerotto")) == 2, 3.0)
	check("entrando si vedono gli oggetti dell'host", synced)
	var mine := await wait_until(func(): return me.inventory().items.size() == 3, 10.0)
	check("arrivano i tre oggetti", mine)
	await wait_seconds(0.3)
	var weapon := me.weapon()
	check("caricatore da 15 e cadenza +10%", weapon.magazine_of(weapon.data) == 15 \
			and is_equal_approx(weapon.fire_rate_multiplier, 1.1), "%d %.2f" % [weapon.magazine_of(weapon.data), weapon.fire_rate_multiplier])
	check("vita massima 120 anche qui (HUD)", is_equal_approx(HealthComponent.of(me).max_health, 120.0) \
			and is_equal_approx(me._hud._health_bar._maximum, 120.0), str(HealthComponent.of(me).max_health))
	check("HUD: elenco oggetti", "Caricatore XL" in me._hud._items_label.text and "Felpa imbottita" in me._hud._items_label.text)
	var seen := await wait_until(func(): return not level.get_node("Pickups").get_children().filter(
			func(n): return n is ItemPickup).is_empty(), 10.0)
	check("si vede l'oggetto lasciato dal Bestione", seen)
	if not seen:
		return
	var drop: ItemPickup = level.get_node("Pickups").get_children().filter(func(n): return n is ItemPickup)[0]
	var count := me.inventory().item_count(drop.item)
	var picked := drop.item
	move_to(me, drop.global_position + Vector3(0, -0.8, 1.5))
	await wait_seconds(0.3)
	me.interact_with(drop)
	var got := await wait_until(func(): return me.inventory().item_count(picked) == count + 1, 3.0)
	check("raccolto: arriva nell'inventario", got)
	var gone := await wait_until(func(): return level.get_node("Pickups").get_children().filter(
			func(n): return n is ItemPickup and not n.is_queued_for_deletion()).is_empty(), 3.0)
	check("e sparisce da terra", gone)
	check("avviso dell'oggetto", me._hud._notice_label.text.begins_with(picked.display_name), me._hud._notice_label.text)
	NetSession.leave(self)
	await wait_seconds(0.5)
