extends SceneTree
# Magnum in rete: il client spara attraverso tre zombie in fila; l'host
# applica 200, 100 e 50 (l'ordine lo ricalcola lui dalle distanze) e il client
# riceve le tre conferme. Uso: --script net_magnum.gd -- host / client

const PORT := 17791

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


func zombies() -> Array:
	var list := level.get_node("Enemies").get_children().filter(func(n): return n is Enemy)
	list.sort_custom(func(a, b): return a.global_position.z > b.global_position.z)
	return list


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
	other.weapon().host_set_loadout([["magnum"]], 0)
	for i in 3:
		var e: Enemy = EnemyReplicator.of(level).spawn_enemy(load("res://game/enemies/walker.tscn"), Vector3(20, 0, -4 - i * 1.5), 0.0)
		e.set_physics_process(false)
		HealthComponent.of(e).max_health = 1000.0
		HealthComponent.of(e).current = 1000.0
	var hit := await wait_until(func(): return zombies().all(func(z): return HealthComponent.of(z).current < 1000.0), 20.0)
	var taken := zombies().map(func(z): return roundi(1000.0 - HealthComponent.of(z).current))
	check("il colpo del client: 200, 100, 50 decisi dall'host", hit and taken == [200, 100, 50], str(taken))
	await wait_until(func(): return players.get_child_count() == 1, 20.0)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var weapon := me.weapon()
	var got := await wait_until(func(): return weapon.data.catalog_id == "magnum" and zombies().size() == 3, 10.0)
	check("ha la Magnum e vede i tre zombie", got)
	await wait_seconds(0.8)
	var confirmed: Array = []
	weapon.dealt_damage.connect(func(_t, amount, _k): confirmed.append(roundi(amount)))
	me.global_position = Vector3(20, 0.1, 0)
	me.reset_physics_interpolation()
	await wait_seconds(0.3)
	weapon._cooldown = 0.0
	weapon._switch_left = 0.0
	var head := me._head.global_position
	weapon.fire(head, (Vector3(20, 1.0, -30) - head).normalized(), [me.get_rid()])
	var ok := await wait_until(func(): return confirmed.size() == 3, 3.0)
	confirmed.sort()
	check("tre conferme di danno: 50, 100, 200", ok and confirmed == [50, 100, 200], str(confirmed))
	check("sul client il modello mostra lo sparo", (weapon._model as MagnumViewmodel)._anim.current_animation == "Sparo" \
			or weapon.ammo() == 5)
	await wait_seconds(0.5)
	NetSession.leave(self)
	await wait_seconds(0.5)
