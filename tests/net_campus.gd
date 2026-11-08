extends SceneTree
# Passo 4.1 in rete, nel campus: il client compra una porta (decide l'host,
# la vedono aperta tutti e due, la zona si apre anche sul client); gli zombie
# arrivano al client solo se sono vicini al suo giocatore (chunk): uno nei
# laboratori, lontano, non gli arriva e i suoi danni non gli vengono mandati;
# quando lo zombie si avvicina compare anche sul client.
# Uso: --script net_campus.gd -- host   oppure   -- client

const PORT := 17792
const NEAR := Vector3(8, 0.1, 30)
const FAR := Vector3(80, -6.9, 60)
const MOVED := Vector3(6, 0.1, 22)

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


func door() -> ZoneDoor:
	return level.get_node("Doors/PortaCentriViale") as ZoneDoor


func enemies() -> Array[Node]:
	if not is_instance_valid(level):
		return []
	return level.get_node("Enemies").get_children()


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
	var other: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
	var client_id := other.get_multiplayer_authority()
	other.inventory().host_add_money(300)
	var opened := await wait_until(func(): return door().is_open, 15.0)
	check("il client compra la porta: per l'host è aperta e il viale pure", opened \
			and ZoneManager.of(level).zone(&"viale_ovest").unlocked)
	check("pagata dal client: 250 €", other.inventory().money == 50, "%d €" % other.inventory().money)
	# Il client è nei Centri comuni: uno zombie lì vicino, uno nei laboratori (lontano, fuori zona).
	await wait_seconds(1.0)
	var replicator := EnemyReplicator.of(level)
	var walker: PackedScene = replicator.enemy_scenes[0]
	var near := replicator.spawn_enemy(walker, NEAR, 0.0)
	var far := replicator.spawn_enemy(walker, FAR, 0.0)
	await wait_seconds(1.5)
	check("lo zombie vicino al client gli arriva, quello lontano no",
			near.net_peers_seeing().has(client_id) and not far.net_peers_seeing().has(client_id))
	check("le chiamate sulla vita dello zombie lontano non vanno al client", far.net_peers_seeing().is_empty(),
			str(far.net_peers_seeing()))
	# Danni allo zombie lontano: l'host non deve mandarli al client, che non ce l'ha.
	HealthComponent.of(far).take_damage(5.0)
	await wait_seconds(2.0)
	far.global_position = MOVED
	far.reset_physics_interpolation()
	var shown := await wait_until(func(): return far.net_peers_seeing().has(client_id), 3.0)
	check("avvicinandosi al client gli arriva", shown)
	var left := await wait_until(func(): return players.get_child_count() == 1, 25.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var rich := await wait_until(func(): return me.inventory().money >= 250, 10.0)
	check("il client ha i soldi", rich, "%d €" % me.inventory().money)
	move_to(me, Vector3(0, 0.1, 14.5))
	await wait_seconds(0.5)
	me.interact_with(door())
	var opened := await wait_until(func(): return door().is_open, 5.0)
	check("la porta si apre anche sul client", opened)
	check("e sul client il viale risulta aperto", ZoneManager.of(level).zone(&"viale_est").unlocked)
	await wait_seconds(0.5)
	check("niente zombie prima che l'host li faccia uscire", enemies().is_empty(), "%d" % enemies().size())
	var first := await wait_until(func(): return enemies().size() >= 1, 10.0)
	await wait_seconds(2.5)
	var list := enemies()
	# Quello vicino nel frattempo cammina verso il client: basta che non sia quello dei laboratori.
	var only_near := list.size() == 1 and (list[0] as Node3D).global_position.distance_to(FAR) > 40.0
	check("arriva solo lo zombie vicino", first and only_near,
			"%d zombie: %s" % [list.size(), str(list.map(func(e): return e.global_position))])
	var second := await wait_until(func(): return enemies().size() == 2, 10.0)
	check("quello lontano compare quando si avvicina", second)
	await wait_seconds(1.0)
