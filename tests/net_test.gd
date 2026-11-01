extends SceneTree
# Test del passo 2.1 con due istanze vere: una fa da host, l'altra da client.
# Uso: --script net_test.gd -- host   oppure   -- client
# Porta di prova 17777, per non disturbare una partita vera.

const PORT := 17777

var failures := 0
var role := ""

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

func move_to(player: FpsController, where: Vector3) -> void:
	player.global_position = where
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()

func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	var level: Node = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var players: Node = level.get_node("Players")
	if role == "host":
		await run_host(players)
	else:
		await run_client(players)
	print("[%s] RISULTATO: %d errori" % [role, failures])
	quit(1 if failures > 0 else 0)

func run_host(players: Node) -> void:
	check("l'host ha il suo giocatore", players.has_node("1") and players.get_node("1").is_multiplayer_authority())
	var joined := await wait_until(func(): return players.get_child_count() == 2, 15.0)
	check("il client entra e compare il suo giocatore", joined, "giocatori=%d" % players.get_child_count())
	if not joined:
		return
	var host_player: FpsController = players.get_node("1")
	var remote: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
	check("il giocatore del client non è controllato dall'host", not remote.is_multiplayer_authority())
	check("numeri e posizioni di partenza diversi", remote.player_number == 2 and remote.global_position.distance_to(host_player.global_position) > 1.0,
			"numero=%d distanza=%.1f" % [remote.player_number, remote.global_position.distance_to(host_player.global_position)])
	move_to(host_player, Vector3(-5, 0.1, -5))
	var followed := await wait_until(func(): return remote.global_position.distance_to(Vector3(5, 0.1, 5)) < 0.3, 8.0)
	check("l'host vede il client muoversi", followed, "pos=%s" % remote.global_position)
	# Il client resta qualche secondo e poi esce: il suo giocatore deve sparire.
	var left := await wait_until(func(): return players.get_child_count() == 1, 15.0)
	check("quando il client esce il suo giocatore sparisce", left, "giocatori=%d" % players.get_child_count())

func run_client(players: Node) -> void:
	var me := str(get_multiplayer().get_unique_id())
	var ready := await wait_until(func(): return get_multiplayer().get_unique_id() != 1 and players.has_node(str(get_multiplayer().get_unique_id())) and players.has_node("1"), 15.0)
	check("collegato: vede sé stesso e l'host", ready, "id=%d giocatori=%s" % [get_multiplayer().get_unique_id(), players.get_children().map(func(n): return n.name)])
	if not ready:
		return
	me = str(get_multiplayer().get_unique_id())
	var mine: FpsController = players.get_node(me)
	var host_player: FpsController = players.get_node("1")
	check("controlla solo il proprio giocatore", mine.is_multiplayer_authority() and not host_player.is_multiplayer_authority())
	check("la propria camera è attiva", mine.get_node("Camera3D").is_current())
	check("il giocatore dell'host ha nome e visiera visibili", host_player.get_node("NameTag").visible and host_player.get_node("NameTag").text == "Giocatore 1")
	move_to(mine, Vector3(5, 0.1, 5))
	var followed := await wait_until(func(): return host_player.global_position.distance_to(Vector3(-5, 0.1, -5)) < 0.3, 8.0)
	check("il client vede l'host muoversi", followed, "pos=%s" % host_player.global_position)
	# Il movimento remoto è morbido: niente salti (si controlla il passo massimo per tick).
	move_to(mine, Vector3(5, 0.1, 5))
	for i in 120:
		await physics_frame
	NetSession.leave(self)
	for i in 30:
		await physics_frame
