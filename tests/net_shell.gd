extends SceneTree
# Passo 3.10 in rete: il client prende un proiettile dalla cassa vicino al
# camion (l'host lo vede in spalla, anche sul modello); l'host gli dà una
# martellata vera da dietro: il proiettile parte a razzo dove guarda il client,
# tutti e due vedono il razzo, il client sente il contraccolpo e ha di nuovo
# le mani libere.
# Uso: --script net_shell.gd -- host   oppure   -- client

const PORT := 17795
const CARRIER_AT := Vector3(0, 0.1, 30)
const HAMMER_FROM := Vector3(0, 0.1, 31.2)

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
	player._pitch = 0.0
	player.rotation.y = yaw
	player.reset_physics_interpolation()


func rack() -> ShellRack:
	return level.get_node("ShellRacks/ProiettileCamion1") as ShellRack


func rockets() -> Array:
	return level.get_children().filter(func(n): return n is Projectile)


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/campus.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var players: Node = level.get_node("Players")
	if role == "host":
		WaveDirector.of(level).host_pause()
		RunManager.of(level).set_physics_process(false)
	var ready := await wait_until(func(): return players.get_child_count() == 2 \
			and players.has_node(str(get_multiplayer().get_unique_id())), 15.0)
	check("due giocatori nel campus", ready)
	if ready:
		for player in players.get_children():
			HealthComponent.of(player).damage_filter = func(_a, _s, _h): return 0.0
		if role == "host":
			await run_host(players)
		else:
			await run_client(players)
	print("[%s] RISULTATO: %d errori" % [role, failures])
	quit(1 if failures > 0 else 0)


func run_host(players: Node) -> void:
	var me: FpsController = players.get_node("1")
	var other: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
	var carrying := await wait_until(func(): return other.carrying_shell, 15.0)
	check("il client prende il proiettile: per l'host è in spalla", carrying and not rack().stocked)
	check("e si vede sul suo modello", (other.get_node("Body") as PlayerModel).shell_visible())
	# Il client va nei Centri comuni e guarda a nord; l'host gli va dietro col martello.
	var placed := await wait_until(func(): return other.global_position.distance_to(CARRIER_AT) < 0.5, 10.0)
	await wait_seconds(0.5)
	me.melee().host_set_weapon("martello")
	move_to(me, HAMMER_FROM, 0.0)
	await wait_seconds(0.3)
	me.melee()._cooldown_left = 0.0
	me.melee().swing(me._head.global_position, -me._aim_basis().z, me)
	await physics_frame
	var fired := rockets()
	check("martellata dell'host: il proiettile del client parte", placed and not other.carrying_shell and fired.size() == 1)
	if fired.size() == 1:
		check("verso nord, dove guarda il client", (fired[0] as Projectile).velocity.normalized().z < -0.95,
				str((fired[0] as Projectile).velocity))
	var left := await wait_until(func(): return players.get_child_count() == 1, 20.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	move_to(me, rack().global_position + Vector3(0, 0.1, 1.5))
	await wait_seconds(0.5)
	me.interact_with(rack())
	var carrying := await wait_until(func(): return me.carrying_shell, 5.0)
	check("in spalla anche per il client, mani occupate", carrying and not me.weapon().visible and me._shell_view.visible)
	move_to(me, CARRIER_AT, 0.0)
	var fired := await wait_until(func(): return not me.carrying_shell, 15.0)
	check("dopo la martellata le mani sono libere", fired and me.weapon().visible)
	var seen := await wait_until(func(): return rockets().size() >= 1, 0.4)
	check("il client vede il razzo", seen)
	await wait_seconds(0.1)
	check("e sente il contraccolpo all'indietro", me._push.z > 1.0, str(me._push))
	await wait_seconds(1.0)
