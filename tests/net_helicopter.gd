extends SceneTree
# Passo 3.8 in rete: host e client versano tutti e due alla radio (la cassa è
# comune e la vedono uguale); chiamato, il client vede l'elicottero arrivare;
# atterrato, sale prima il client (l'host lo vede a bordo e l'elicottero
# aspetta chi è ancora in piedi), poi l'host: riparte, e tutti e due vedono la
# vittoria con entrambi i nomi.
# Uso: --script net_helicopter.gd -- host   oppure   -- client

const PORT := 17793
const NEAR_RADIO := Vector3(68, 12.1, -41)
const NEAR_CABIN := Vector3(80, 12.1, -51.6)

var failures := 0
var role := ""
var level: Node
var heli: Helicopter


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


func radio() -> HelicopterPart:
	for child in heli.get_children():
		if child is HelicopterPart and child.role == HelicopterPart.Role.RADIO:
			return child
	return null


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/campus.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	heli = Helicopter.of(level)
	var players: Node = level.get_node("Players")
	if role == "host":
		WaveDirector.of(level).host_pause()
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
	other.inventory().host_add_money(1000)
	me.inventory().host_add_money(4000)
	var client_paid := await wait_until(func(): return heli.fund >= 1000, 15.0)
	check("il client versa 1.000 € alla radio (due volte 500)", client_paid and other.inventory().money == 0, "raccolti %d" % heli.fund)
	move_to(me, NEAR_RADIO)
	await wait_seconds(0.3)
	for i in 8:
		me.interact_with(radio())
	check("l'host completa: 5.000 €, elicottero chiamato", heli.fund == 5000 and heli.phase == Helicopter.Phase.INCOMING)
	await wait_seconds(1.0)
	heli._time_left = 2.0
	var landed := await wait_until(func(): return heli.phase == Helicopter.Phase.LANDED, 4.0)
	check("atterrato", landed)
	var boarded := await wait_until(func(): return other.is_boarded(), 15.0)
	check("il client è salito: l'host lo vede a bordo", boarded)
	await wait_seconds(1.0)
	check("con l'host ancora in piedi l'elicottero aspetta", heli.phase == Helicopter.Phase.LANDED and heli.seconds_left() > 10.0,
			"%.1f s" % heli.seconds_left())
	move_to(me, NEAR_CABIN)
	await wait_seconds(0.3)
	me.interact_with(heli._cabin)
	var leaving := await wait_until(func(): return heli.phase == Helicopter.Phase.DEPARTING, 0.5)
	check("sale anche l'host: riparte subito", me.is_boarded() and leaving)
	var run := RunManager.of(level)
	var won := await wait_until(func(): return run.won, 8.0)
	check("run vinta per tutti e due", won and run.escaped.size() == 2, str(run.escaped))
	await wait_seconds(3.0)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var rich := await wait_until(func(): return me.inventory().money >= 1000, 10.0)
	check("il client ha 1.000 €", rich)
	move_to(me, NEAR_RADIO)
	await wait_seconds(0.5)
	me.interact_with(radio())
	await wait_seconds(0.3)
	me.interact_with(radio())
	var synced := await wait_until(func(): return heli.fund >= 1000, 5.0)
	check("la raccolta si vede anche sul client", synced, "%d €" % heli.fund)
	var called := await wait_until(func(): return heli.phase == Helicopter.Phase.INCOMING, 15.0)
	check("il client vede l'elicottero chiamato", called and heli.fund == 5000 and heli._body.visible)
	var landed := await wait_until(func(): return heli.phase == Helicopter.Phase.LANDED, 10.0)
	check("e atterrato", landed and heli._body.position.is_equal_approx(Vector3.ZERO))
	move_to(me, NEAR_CABIN)
	await wait_seconds(0.3)
	me.interact_with(heli._cabin)
	var aboard := await wait_until(func(): return me.is_boarded(), 3.0)
	check("il client sale a bordo", aboard)
	await wait_seconds(0.5)
	check("e sta seduto al suo posto", me.global_position.distance_to(heli._seats[0].global_position) < 0.3, str(me.global_position))
	var run := RunManager.of(level)
	var won := await wait_until(func(): return run.won, 20.0)
	check("anche il client vede la vittoria con tutti e due i nomi", won and run.escaped.size() == 2, str(run.escaped))
	var hud: PlayerHud = me.get_node("Hud")
	await wait_seconds(0.2)
	check("riepilogo a schermo", hud._death_label.visible and hud._death_label.text.contains("TORNATI A CASA"))
