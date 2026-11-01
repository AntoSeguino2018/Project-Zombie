extends SceneTree
# Test dei passi 2.3 e 2.4 con tre istanze: zombie e muri in rete.
# Uso: --script net_zombies.gd -- host | client | late
# "late" entra a partita iniziata (quando l'host crea il file late_go) e deve
# trovare i muri già rotti e gli zombie già in campo.
# Ogni istanza stampa "HASH muro ..." alla fine: devono coincidere.

const PORT := 17782
const GO_FILE := "user://late_go"
const WALKER := "res://game/enemies/walker.tscn"

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


func zombies() -> Array:
	return level.get_node("Enemies").get_children().filter(func(n): return n is Enemy)


func wall() -> DestructibleBlocks:
	return level.get_node("Destructibles/WallBehindSpawn")


func print_wall_hash() -> void:
	print("[%s] HASH muro %d blocchi=%d" % [role, hash(wall()._alive), wall().blocks_left()])


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	if role == "host" and FileAccess.file_exists(GO_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GO_FILE))
	if role == "late":
		# Entra solo quando l'host è pronto.
		for i in 120 * 60:
			if FileAccess.file_exists(GO_FILE):
				break
			await physics_frame
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var players: Node = level.get_node("Players")
	match role:
		"host":
			# Niente zombie a caso: li crea il test.
			level.get_node("Waves").free()
			await run_host(players)
		"client":
			await run_client(players)
		"late":
			await run_late(players)
	print("[%s] RISULTATO: %d errori" % [role, failures])
	quit(1 if failures > 0 else 0)


## L'host dà a tutti carabina e lanciagranate (come facevano i vecchi test);
## gli altri aspettano di riceverle.
func give_test_loadouts(players: Node, count: int) -> void:
	if role == "host":
		for player: FpsController in players.get_children():
			player.weapon().host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	var got := await wait_until(func(): return players.get_child_count() == count and players.get_children().all(
			func(pl): return pl.weapon().specs() == [["carbine"], ["grenade_launcher"]]), 15.0)
	check("armi di prova arrivate a tutti", got, str(players.get_children().map(func(pl): return pl.weapon().specs())))


func run_host(players: Node) -> void:
	var me: FpsController = players.get_node("1")
	move_to(me, Vector3(25, 0.1, 25))
	var connections := [0]
	get_multiplayer().peer_connected.connect(func(_id): connections[0] += 1)
	var joined := await wait_until(func(): return players.get_child_count() == 2, 15.0)
	check("il client entra", joined)
	if not joined:
		return
	var other: FpsController = players.get_children().filter(func(n): return n != me)[0]
	await give_test_loadouts(players, 2)
	var kills: Array = []
	# La bacheca è statica e vive più dello script: il collegamento va tolto alla fine.
	var on_kill := func(_enemy, killer): kills.append(killer)
	CombatEvents.bus.enemy_killed.connect(on_kill)
	var replicator := EnemyReplicator.of(level)
	var walker: PackedScene = load(WALKER)

	# 1) Zombie A: insegue il client, lo colpisce, il client lo uccide.
	await wait_seconds(1.5)
	var a := replicator.spawn_enemy(walker, Vector3(0, 0.1, -14), 0.0)
	var a_health := HealthComponent.of(a)
	var dead := await wait_until(func(): return not a_health.is_alive(), 30.0)
	check("il client uccide lo zombie A", dead)
	check("l'uccisione è del giocatore del client", kills.size() == 1 and kills[0] == other, str(kills))
	var a_id := a.get_instance_id()
	var gone := await wait_until(func(): return not is_instance_id_valid(a_id), 4.0)
	check("il corpo sparisce", gone)

	# 2) Zombie B davanti al client: il pugno lo scaraventa via.
	await wait_seconds(1.0)
	var b := replicator.spawn_enemy(walker, other.global_position + Vector3(0, 0, -1.6), PI)
	var launched := await wait_until(func(): return b.is_launched(), 6.0)
	check("il pugno del client scaraventa lo zombie B (sull'host)", launched)
	await wait_seconds(1.0)
	HealthComponent.of(b).take_damage(1000.0)

	# 3) La granata del client rompe il muro: lo calcola l'host.
	var broke := await wait_until(func(): return wall().blocks_left() < wall().block_count(), 30.0)
	check("la granata del client rompe il muro sull'host", broke, "blocchi=%d" % wall().blocks_left())
	await wait_seconds(2.0)
	print_wall_hash()

	# 4) Uno zombie in campo e via libera a chi entra dopo.
	replicator.spawn_enemy(walker, Vector3(-20, 0.1, 30), 0.0)
	var file := FileAccess.open(GO_FILE, FileAccess.WRITE)
	file.store_string("go")
	file.close()
	var late := await wait_until(func(): return connections[0] >= 2, 60.0)
	check("entra un terzo giocatore a partita iniziata", late)
	var all_left := await wait_until(func(): return players.get_child_count() == 1, 40.0)
	check("tutti escono", all_left)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GO_FILE))
	CombatEvents.bus.enemy_killed.disconnect(on_kill)


func run_client(players: Node) -> void:
	var ready := await wait_until(func(): return players.has_node(str(get_multiplayer().get_unique_id())) \
			and players.get_child_count() == 2, 15.0)
	check("collegato", ready)
	if not ready:
		return
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var my_health := HealthComponent.of(me)
	await give_test_loadouts(players, 2)
	move_to(me, Vector3(0, 0.1, -6))

	# 1) Arriva lo zombie A.
	var appeared := await wait_until(func(): return zombies().size() == 1, 10.0)
	check("lo zombie creato dall'host compare anche qui", appeared)
	if not appeared:
		return
	var a: Enemy = zombies()[0]
	check("stesso nome e posizione di partenza", a.name == "Zombie1" and a.global_position.distance_to(Vector3(0, 0.1, -14)) < 1.0,
			"%s %s" % [a.name, a.global_position])
	check("qui lo zombie non pensa: lo muove l'host", not a.is_multiplayer_authority())
	var near := await wait_until(func(): return a.global_position.distance_to(me.global_position) < 2.5, 10.0)
	check("lo zombie insegue il client", near, "distanza=%.1f" % a.global_position.distance_to(me.global_position))
	var arms: Node3D = a.get_node("Visual/Arms")
	var max_arms := [0.0]
	var hurt := await wait_until(func():
		max_arms[0] = maxf(max_arms[0], arms.rotation.x)
		return my_health.current < my_health.max_health, 10.0)
	check("lo zombie colpisce il client (danno deciso dall'host)", hurt, "vita=%.0f" % my_health.current)
	check("si vedono le braccia alzate prima del colpo", max_arms[0] > 1.1, "angolo=%.2f" % max_arms[0])

	var kills_before := me._kills
	var a_health := HealthComponent.of(a)
	var max_fall := [0.0]
	for i in 80:
		if not a_health.is_alive():
			break
		me._weapon.fire(me._head.global_position, (a.center() - me._head.global_position).normalized(), [me.get_rid()])
		for f in 8:
			await physics_frame
	check("lo zombie muore anche qui", not a_health.is_alive())
	var a_id := a.get_instance_id()
	var gone := await wait_until(func():
		var alive_a := instance_from_id(a_id) as Enemy
		if alive_a:
			max_fall[0] = maxf(max_fall[0], alive_a.get_node("Visual").rotation.x)
		return alive_a == null, 5.0)
	check("si vede cadere all'indietro", max_fall[0] > 1.0, "angolo=%.2f" % max_fall[0])
	check("e poi sparisce", gone)
	check("l'uccisione conta per il client", me._kills == kills_before + 1, "uccisioni=%d" % me._kills)

	# 2) Zombie B davanti: pugno.
	var appeared_b := await wait_until(func(): return zombies().size() == 1, 10.0)
	check("compare lo zombie B", appeared_b)
	if appeared_b:
		var b: Enemy = zombies()[0]
		await wait_seconds(0.4)
		var start := b.global_position
		var punched: Array = []
		me._melee.dealt_damage.connect(func(_t, amount, _k): punched.append(amount))
		me._melee.attack(me._head.global_position, (b.center() - me._head.global_position).normalized(), me)
		var b_id := b.get_instance_id()
		var flew := await wait_until(func():
			var alive_b := instance_from_id(b_id) as Enemy
			return alive_b != null and alive_b.global_position.distance_to(start) > 4.0, 3.0)
		check("si vede lo zombie volare via", flew)
		check("il danno del pugno arriva dall'host", not punched.is_empty(), str(punched))
		await wait_until(func(): return zombies().is_empty(), 6.0)

	# 3) Granata sul muro dietro la partenza.
	move_to(me, Vector3(0, 0.1, 2), PI)
	me._weapon.equip(1)
	await wait_seconds(0.6)
	var before := wall().blocks_left()
	me._weapon.fire(me._head.global_position, (Vector3(0, 1.5, 6.75) - me._head.global_position).normalized(), [me.get_rid()])
	var broke := await wait_until(func(): return wall().blocks_left() < before, 5.0)
	check("il muro si rompe anche qui", broke, "blocchi=%d" % wall().blocks_left())
	await wait_seconds(0.5)
	check("con i propri detriti", RubbleField.of(level).active_count() > 0)
	await wait_seconds(1.5)
	print_wall_hash()
	await wait_seconds(1.0)
	NetSession.leave(self)
	await wait_seconds(0.5)


func run_late(players: Node) -> void:
	var ready := await wait_until(func(): return players.has_node(str(get_multiplayer().get_unique_id())), 15.0)
	check("entrato a partita iniziata", ready)
	await wait_seconds(1.0)
	var host_player: FpsController = players.get_node("1")
	check("chi entra tardi vede le armi già date agli altri",
			host_player.weapon().specs() == [["carbine"], ["grenade_launcher"]], str(host_player.weapon().specs()))
	check("i muri sono già rotti come per gli altri", wall().blocks_left() < wall().block_count(), "blocchi=%d" % wall().blocks_left())
	print_wall_hash()
	check("lo zombie già in campo si vede", zombies().size() == 1, "zombie=%d" % zombies().size())
	if zombies().size() == 1:
		var z: Enemy = zombies()[0]
		var start := z.global_position
		var moved := await wait_until(func(): return z.global_position.distance_to(start) > 1.0, 5.0)
		check("e si muove", moved)
	NetSession.leave(self)
	await wait_seconds(0.5)
